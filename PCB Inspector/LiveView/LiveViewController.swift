//
//  LiveViewController.swift
//  PCB Inspector
//
//  Created by Jack Smith on 19/02/2024.
//
//  Provides logic to allow the live capture feature

import Foundation
import CoreML
import SwiftUI
import Vision
import OrderedCollections


final class LiveViewController: ObservableObject {
    let camera = CameraController() // Camera information
    @Published var liveImageUI: UIImage? // Preview UIimage
    @Published var liveImage: Image? // Preview Image
    @Published var currentIdentifiedObjects: [(ComponentType, CGRect)] = [] // Components detected from the ML model
    @Published var loading: Bool = false // Model is currently loading
    @Published var inferencePaused: Bool = false // If inference is currently paused
    @Published var isBinarisig: Bool = false
    
    var currentCGImage: CGImage?
    var currentIdentifiedComponents: [LiveCompInfo] = []
    let detectionWorker = ComponentDetection()
    
    init() {
        camera.liveCaptureMode = true
        Task {
            await liveCaptureFromCamera()
        }
    }
    
    deinit {
        print("gello")
    }
    
    /// Runs on each new camera frame and performs the inference from the ML model
    func liveCaptureFromCamera() async {
        if GlobalStorage.shared.isInPreview { // If running in XCode preview
            Task { @MainActor in
                liveImageUI = UIImage(named: "PCB Placeholder")
            }
        } else {
            let liveImages = camera.imagePreviews.map{ ($0, $0.image) }
            for await (ciImage, img) in liveImages { // For each new camera frame
                if !inferencePaused { // Only update if inderence is not paused
                    let ui = UIImage(ciImage: ciImage)
                    guard let cgImage = await img.toCG() else { continue }
                    // Get the ML model output
                    let modelOutputs = await parseImage(cgImage)
                    
                    Task { @MainActor in // Perform the UI updates on the main frame for immediate feedback
                        loading = true
                        liveImage = img
                        liveImageUI = ui
                        currentIdentifiedObjects = modelOutputs
                        currentCGImage = cgImage
                    }
                }
            }
        }
    }
    
    /// Takes a CGImage and performs the ML model recognition and returns the findings as a list of component types and rectangles
    func parseImage(_ image: CGImage) async -> [(ComponentType, CGRect)] {
        let time1 = DispatchTime.now()
        let outputs = detectionWorker.identifyComponentsSimple(image)
        let time2 = DispatchTime.now()
        let runTime = Double(time2.uptimeNanoseconds - time1.uptimeNanoseconds) / 1_000_000
        print("runtime", runTime, "ms")
        return outputs
    }
    
    /// Function to get information for a selected component
    func inspectComponent(_ component: (ComponentType, CGRect)) async -> LiveCompInfo? {
        guard component.0 == .ic else { return nil }
        guard let pcbImage = currentCGImage else { return nil }
        
        // Extraction workers
        let extractionWorker = TextExtraction()
        var currentComp = LiveCompInfo()
        
        let width = CGFloat(pcbImage.width)
        let height = CGFloat(pcbImage.height)
        
        let compWidth = component.1.width * width
        let compHeight = component.1.height * height
        
        let cropRect: CGRect = CGRect(x: (component.1.minX * width) - (compWidth / 2), y: (component.1.minY * height) - (compHeight / 2), width: compWidth, height: compHeight)
        
        // Binarise and blur image
        guard let componentImage = pcbImage.cropping(to: cropRect) else { return nil }
        let binarisedImage = isBinarisig ? ImageOperations.textExtractionImage(componentImage) : componentImage
        
        // Get text
        let extractionResultNorm = extractionWorker.performImageRecognition(image: componentImage)
        let extractionResultBin = extractionWorker.performImageRecognition(image: binarisedImage)
        let rawTextNormal = extractionResultNorm.text?.filter { $0.count >= 3 }
        let rawTextBin = extractionResultBin.text?.filter { $0.count >= 3 }
        
        // Check if this component has already been identified, and if it has, return it
//        let alreadyIdentified = hasComponentBeenIdentified(rawText ?? [])
//        if alreadyIdentified.0, let i = alreadyIdentified.1 {
//            if let comp = currentIdentifiedComponents.conditionalGet(i) {
//                return comp
//            }
//        }
        
        
        
        let infoLookup = ICInfoExtraction()
        
        // Attempt component lookup
        if (rawTextNormal?.isEmpty ?? true) && (rawTextBin?.isEmpty ?? true) {
            currentComp.hasPerformedLookup = true
            // Rotate image by specified amount
            currentComp.componentImage = componentImage
        } else {
            let retrievedInfo: InfoExtractionReturn
            switch await infoLookup.findComponentDetailsCompare(rawTextNormal ?? [], rawTextBin ?? []) {
            case .Left(let norm):
                // Rotate image by specified amount
                let finalImage = ImageOperations.rotateImage(componentImage, radians: extractionResultNorm.orientation ?? 0)
                currentComp.componentImage = finalImage
                currentComp.rawText = rawTextNormal
                
                retrievedInfo = norm
            case .Right(let bin):
                // Rotate image by specified amount
                let finalImage = ImageOperations.rotateImage(binarisedImage, radians: extractionResultBin.orientation ?? 0)
                currentComp.componentImage = finalImage
                currentComp.rawText = rawTextBin
                
                retrievedInfo = bin
            }
            print("retrieved info \(retrievedInfo)")
            currentComp.hasPerformedLookup = true
            if retrievedInfo.icState == .loaded {
                currentComp.hasGotResult = true
                currentComp.identifiedInfo = retrievedInfo.dictionary
            } else if retrievedInfo.icState == .notAvaliable {
                currentComp.identifiedInfo = retrievedInfo.dictionary
            }
            
            currentIdentifiedComponents.append(currentComp)
        }
        
        return currentComp
    }
    
    /// Determines if the new component has already been identified
    func hasComponentBeenIdentified(_ rawText: [String]) -> (Bool, Int?) {
        let compText = rawText.joined()
        
        for (i, component) in currentIdentifiedComponents.enumerated() { // Iterate through current components
            guard let currentText = component.rawText?.joined() else { continue }
            if StringOperations.stringDistance(compText, currentText) <= 4 { // If the difference between the two is less than 4, then return
                return (true, i)
            }
        }
        
        return (false, nil)
    }
    
    func tests() {
        var inputObservations = [UUID: VNDetectedObjectObservation]()
        var trackedObjects = [UUID: CGRect]()
        for object in currentIdentifiedObjects {
            let ob = VNDetectedObjectObservation(boundingBox: object.1)
            inputObservations[ob.uuid] = ob
            trackedObjects[ob.uuid] = object.1
        }
    }
    
}

/// Structure used in the live view section to provide simple information 
struct LiveCompInfo {
    var componentImage: CGImage?
    var rawText: [String]?
    var identifiedInfo: OrderedDictionary<String, String>?
    var hasPerformedLookup: Bool = false
    var hasGotResult: Bool = false // If an API result has been retrieved 
}

fileprivate extension CIImage {
    func renderCGImage() -> CGImage? {
        let context = CIContext(options: nil)
        return context.createCGImage(self, from: self.extent)
    }
    
    var image: Image? {
        let context = CIContext()
        guard let image = context.createCGImage(self, from: self.extent) else {return nil}
        return Image(decorative: image, scale: 1, orientation: .up)
    }
}
