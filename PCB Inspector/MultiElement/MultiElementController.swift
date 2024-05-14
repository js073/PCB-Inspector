//
//  MultiElementController.swift
//  PCB Inspector
//
//  Created by Jack Smith on 13/12/2023.
//
//  Provides the logic backend when using the multielement view

import Foundation
import Observation
import SwiftUI
import SwiftData

@Observable class MultiElementController {
    var elementImage: Image? // Image of the PCB
    var uiImage: UIImage? // Image of PCB in UIImage format
    var originalComponents: [ComponentInfo]? // Original components passed from the ML model
    var identifiedComponents: [ComponentInfo]? // Current list of components
    var identifiedICs: [ICInfo]? // List of ICs identified
    var currentComponentFilter : [ComponentType] = ComponentType.allCases.filter { $0 != .other }
    var isSet: Bool { // Checks if all values have been set
        elementImage != nil && uiImage != nil && identifiedICs != nil && identifiedComponents != nil
    }
    var isError = false // Is set if an error occurs in execution 
    var dataController = DataHandler.handlerShared // Data storage
    var componentDetector = ComponentDetection() // Component detection object
    var hasSaved = false // Used to autosave when the user has saved a model
    var savedName: String? // Name of the saved model
    
    /// Gets the components from the ML model and sets them
    func getProperties() async {
        let shared = GlobalStorage.shared
        
        if GlobalStorage.shared.isInPreview { // For simulation
            identifiedComponents = [ci, ci2, tempComponent.baseInfo]
            originalComponents = identifiedComponents
            identifiedICs = [ic, tempComponent]
            let tmp = UIImage(named: "PCB Placeholder")!
            uiImage = tmp
            elementImage = Image(uiImage: tmp)
        } else { // Normal execution in-app
            if let cgImg = shared.takenImage { // Image of PCB
                var tmpComps: [ComponentInfo] = [] // Temp values
                var tmpICs: [ICInfo] = []
                if let (comps, ics) = componentDetector.identifyComponents(cgImg, shared.imageOrientation) { // Perform component identfication
                    tmpComps.append(contentsOf: comps)
                    tmpICs.append(contentsOf: ics)
                }
                //FIXME: Add the proper windowing feature, really slow rotation 
                
                let numWindows = max(cgImg.width, cgImg.height) / 640
                
                if let (comps, ics) = componentDetector.identifyComponentsWindowing(cgImg, shared.imageOrientation, numWindows) { // Perform windowing identification
                    print("comp count", comps.count)
                    tmpComps.append(contentsOf: comps)
                    tmpICs.append(contentsOf: ics)
                }
                identifiedComponents = tmpComps
                originalComponents = tmpComps
                identifiedICs = tmpICs
                uiImage = shared.getUIImage()
                elementImage = shared.getImage()
            } else {
                isError = true
            }
        }
    }
    
    /// Function to convert the saved PCB to the values needed for the controller/
    func setPropertiesFromExisting(_ saved: IdentifiedPCBStorage) async {
        savedName = saved.boardName
        hasSaved = true
        let imgData = saved.boardImage
        if !imgData.isEmpty {
            print("not empty")
            uiImage = UIImage(data: imgData)
            if let uiImage {
                elementImage = Image(uiImage: uiImage)
            }
            identifiedComponents = saved.identifiedComponents
            originalComponents = saved.identifiedComponents
            identifiedICs = saved.identifiedICs
        } else {
            isError = true
        }
    }
    
    /// Applies a filter of the passed component type to the current component list/
    func applyFilter(_ filterTypes: [ComponentType]) {
        currentComponentFilter = filterTypes
        if let orComps = originalComponents {
            identifiedComponents = orComps.filter { filterTypes.contains($0.type) }
        }
    }
    
    /// Used as a convenience wrapper to specify the savedName/
    func saveCurrent(_ name: String) -> Bool {
        savedName = name
        return saveCurrent()
    }
    
    /// Saves the current identified PCB to the model and returns boolean on success/
    func saveCurrent() -> Bool {
        let imgData = if let uiImage { // Get the PNG data
            uiImage.pngData() ?? Data.init()
        } else {
            Data.init()
        }
        
        let current = IdentifiedPCBStorage(boardName: savedName ?? "err", boardImage: imgData, identifiedComponents: originalComponents ?? [], identifiedICs: identifiedICs ?? []) // Set up item to be saved
        let returnState = dataController.saveCurrentPCB(current) // Save the item to the model
        hasSaved = returnState
        return returnState
    }
    
    /// Performs autosave if there has already been a save
    fileprivate func autoSave() {
        if hasSaved {
            let _ = saveCurrent()
        }
    }
    
    /// Calls the identification functions on the part with the given ID, and returns the new ICInfo, with nil meaning an error occured/
    func retrieveInformation(_ icID: UUID?, _ performBinarisation: Bool) async -> ICInfo? {
        guard identifiedICs != nil else { return nil }
        guard let index = identifiedICs!.firstIndex(where: { item in
            item.baseInfo.id == icID
        }) else { return nil }
        
        let item = identifiedICs![index]
        guard item.infoState == .unloaded else { return nil } // Check the IC has not yet been loaded
        guard let image = item.baseInfo.imageInfo.subImage?.cgImage else { return nil }
        let binarisedImage = ImageOperations.textExtractionImage(image) // Binarise image
        
        let extractionWorker = TextExtraction()
        
        // Perform extraction for both images
        let (normalRawText, normalOrientation) = extractionWorker.performImageRecognition(image: image)
        let (binarisedRawText, binarisedOrientation) = extractionWorker.performImageRecognition(image: binarisedImage)
        
        // Compare the reults of the two text outputs
        let lookupResult = await ICInfoExtraction.shared.findComponentDetailsCompare(binarisedRawText ?? [], normalRawText ?? [])
        let extractionResult: InfoExtractionReturn
        let finalImage: CGImage
        switch lookupResult {
        case .Left(let bin): // If the binarisation is better, set the image for that and perform lookup on that text
            extractionResult = bin
            finalImage = ImageOperations.rotateImage(binarisedImage, radians: binarisedOrientation ?? 0)
        case .Right(let norm): // If the normal image is better
            extractionResult = norm
            finalImage = ImageOperations.rotateImage(image, radians: normalOrientation ?? 0)
        }
        
        // Set the sub-image 
        self.identifiedICs![index].baseInfo.imageInfo.subImage = UIImage(cgImage: finalImage)
        
        if !extractionResult.isError && extractionResult.icState == .loaded { // Info has been identified and retrieved from the API
            self.identifiedICs![index].infoState = .loaded
            self.identifiedICs![index].informationDescription = extractionResult.dictionary ?? [:]
            autoSave()
            return self.identifiedICs![index]
        } else if extractionResult.icState == .notAvaliable && !extractionResult.isError { // No information was avaliable for this IC
            self.identifiedICs![index].infoState = .notAvaliable
            self.identifiedICs![index].informationDescription = extractionResult.dictionary ?? [:]
            autoSave()
            return self.identifiedICs![index]
        } else if extractionResult.icState == .noText {
            self.identifiedICs![index].infoState = .noText
            autoSave()
            return self.identifiedICs![index]
        } else { // ERROR CASE
            return nil
        }
    }
    
    /// Add a note to the current IC, and autosave if necessary
    func addNote(_ icID: UUID?, _ note: String?) {
        if identifiedICs != nil {
            if let index = identifiedICs!.firstIndex(where: { item in item.baseInfo.id == icID }) {
                identifiedICs![index].note = note
                autoSave()
            }
        }
    }
    
    /// Remove the note from the current IC, simply pass nil to addNote
    func removeNote(_ icID: UUID?) {
        addNote(icID, nil)
    }
    
    /// Peforms the Google Search for the IC with the specified ID, returns the search term followed by the list of page titles and URLs
    func performGoogleSearch(_ icID: UUID?) async -> (String, [(String, String)])? {
        guard identifiedICs != nil else { return nil }
        guard let index = identifiedICs!.firstIndex(where: { item in item.baseInfo.id == icID }) else { return nil }
        let ic = identifiedICs![index] // Get the identified IC
        var manufacturer = (ic.informationDescription["Manufacturer"] ?? ic.informationDescription["Potential Manufacturers"])
        if manufacturer?.components(separatedBy: ", ").count != 1 { // If there is more than 1 potential manufacturer, don't use it in the search
            manufacturer = nil
        }
        let code = ic.informationDescription["Most Likely Code"] ?? ic.informationDescription.elements.first?.value // Get the most likely code or the first value in the list
        
        guard let term = (manufacturer != nil && code != nil) ? "\(manufacturer!) \(code!)" : code else { return nil } // If we have a manufacturer and a code, search that, else search just the code 
        let ret = await GoogleSearchAPI.shared.makeRequest(term)
        if let ret {
            return (term, ret)
        }
        return nil
    }
    
    /// If the user chooses to select the URL for the componet then set it
    func setComponentURL(_ icID: UUID?, _ url: String?) {
        guard identifiedICs != nil else { return }
        guard let index = identifiedICs!.firstIndex(where: { item in item.baseInfo.id == icID }) else { return }
        identifiedICs![index].infoState = .webLoaded
        identifiedICs![index].informationURL = url
        autoSave()
    }
    
    /// Clear the info URL for the given component
    func clearComponentURL(_ icID: UUID?) {
        guard identifiedICs != nil else { return }
        guard let index = identifiedICs!.firstIndex(where: { item in item.baseInfo.id == icID }) else { return }
        identifiedICs![index].infoState = .notAvaliable
        identifiedICs![index].informationURL = nil
        autoSave()
    }
    
    /// Returns an IC from the list with the given UUID, returns nil on failure 
    func getICByID(_ icID: UUID?) -> ICInfo? {
        guard identifiedICs != nil else { return nil }
        guard let index = identifiedICs!.firstIndex(where: { item in item.baseInfo.id == icID }) else { return nil }
        return identifiedICs![index]
    }
    
    /// Deletes the IC with the given UUID
    func deleteIC(_ icID: UUID?) {
        identifiedICs?.removeAll(where: { $0.baseInfo.id == icID })
        originalComponents?.removeAll(where:  { $0.id == icID })
        identifiedComponents?.removeAll(where: { $0.id == icID })
        autoSave()
    }
    
    /// Given an IC id, take a new image of the same component and run the testing again
    func setNewICImage(_ icID: UUID?) async -> ICInfo? {
        // Get the image and orientation
        guard identifiedICs != nil else { return nil }
        guard let index = identifiedICs!.firstIndex(where: { item in item.baseInfo.id == icID }) else { return nil }
        guard let image = GlobalStorage.shared.otherTakenImage else { return nil }
        let _ = GlobalStorage.shared.otherImageOrientation
        
        print("Got taken image")
        
        //FIXME: Add a identification worker to retake option to make sure the current image contains an IC, and extract the location of the largest one
        // Use ML model on new image to identify the region of the main IC in new image
        let identificationWorker = LiveViewController()
        var identificationResults = await identificationWorker.parseImage(image)
        identificationResults = identificationResults.sorted { $0.1.calcArea() > $1.1.calcArea() }.sorted { $0.1.distanceToCentre() < $1.1.distanceToCentre() }
        
        print("Identified component in image")
        
        var componentImage = image
        
        // If there is a component that goes through the centre
        if let top = identificationResults.first {
            let width = CGFloat(image.width)
            let height = CGFloat(image.height)
            
            let compWidth = top.1.width * width
            let compHeight = top.1.height * height
            
            let cropRect: CGRect = CGRect(x: (top.1.minX * width) - (compWidth / 2), y: (top.1.minY * height) - (compHeight / 2), width: compWidth, height: compHeight)
            
            // Crop the image
            componentImage = image.cropping(to: cropRect)!
            print("image has been cropped")
        }
        
        identifiedICs![index].baseInfo.imageInfo.subImage = UIImage(cgImage: componentImage)
        identifiedICs![index].infoState = .unloaded
        
        return await retrieveInformation(icID, true)
    }
}

fileprivate extension CGRect {
    /// Calculates the area of a CGFloat
    func calcArea() -> CGFloat {
        return self.width * self.height
    }
    
    /// Determines if a CGRect passes through the centre of the image
    func goesThroughCentre() -> Bool {
        return abs(0.5 - self.minX) < self.width / 2 && abs(0.5 - self.minY) < self.height / 2
    }
    
    /// Calculate the distance from a rectangle to centre of the frame
    func distanceToCentre() -> CGFloat {
        return sqrt(pow(abs(0.5 - self.minX), 2) + pow(abs(0.5 - self.minY), 2))
    }
}
