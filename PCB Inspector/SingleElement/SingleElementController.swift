//
//  SingleElementController.swift
//  PCB Inspector
//
//  Created by Jack Smith on 08/12/2023.
//
//  Provides the logic and text extraction for a single element view 

import Foundation
import SwiftUI
import Accelerate
import CoreGraphics
import Vision
import OrderedCollections

@Observable class SingleElementController {
    var elementImage: Image? // Raw image of element
    var cgImage: CGImage? // Black and white representation
    var extractedText: [String]? // Text extracted from the image
    var extractionWorker: TextExtraction = TextExtraction() // Worker to perform the text extraction
    var icInfoState: ICInfoState = .unloaded // State of the identification process for the component
    var loadingProgress: LoadingProgress = .stopped
    var identifiedInformation: OrderedDictionary<String, String> = [:] // Used as a dictionary of the identified qualities and the values
    
    /// Initialise the class with the image
    init(_ normalInit: Bool = true) {
        if normalInit {
            if GlobalStorage.shared.isInPreview { // When running in the iOS preview
                if let uiimg = UIImage(named: "SingleElementTest"), let cgimg = uiimg.cgImage {
                    elementImage = Image(uiImage: uiimg)
                    cgImage = cgimg
                }
            } else { // For running normally 
                if let currentImage = GlobalStorage.shared.takenImage { // Get the taken image from the shared GlobalStorage class
                    elementImage = currentImage.toImage(GlobalStorage.shared.imageOrientation)
                    cgImage = currentImage
                }
            }
        }
    }
    
    
    func getInfoFromText() async {
        if let cgImage {
            self.cgImage = ImageOperations.meanAdaptiveThresholdWindowNumbers(cgImage)
        }
        if let cgImage {
            self.extractedText = extractionWorker.performImageRecognition(image: cgImage).text
        }
    }
    
    /// Used to return Google search information about the current component.
    /// UUID parameter in function call only to preserve functionality with the web-search view
    func performGoogleSearch(_ : UUID?) async -> (String, [(String, String)])? {
        var manufacturer = identifiedInformation["Manufacturer"] ?? identifiedInformation["Potential Manufacturers"]
        if manufacturer?.components(separatedBy: ", ").count != 1 {
            manufacturer = nil
        }
        
        let code = identifiedInformation["Most Likely Code"] ?? identifiedInformation.elements.first?.value
        
        guard let term = (manufacturer != nil && code != nil) ? "\(manufacturer!) \(code!)" : code else { return nil }
        
        let ret = await GoogleSearchAPI.shared.makeRequest(term)
        if let ret {
            return (term, ret)
        }
        return nil
    }
    
    /// Get the information from the API and parse the results 
    func getInformation() async {
        let infoExtractor = ICInfoExtraction()
        infoExtractor.testingMode = (true, .noInformation, .notAvaliable)
        
        if icInfoState == .unloaded { // Only load if the info has not yet been loaded
            loadingProgress = .loading
            if let extractedText {
                let extractionResult = await infoExtractor.findComponentDetailsSingle(extractedText) // Attempt to get information
                if extractionResult.isError { // Error state
                    self.loadingProgress = .error
                    return
                } else { // Success state
                    self.icInfoState = extractionResult.icState
                    self.identifiedInformation = extractionResult.dictionary ?? [:]
                    self.loadingProgress = .stopped
                    return
                }
            }
        }
    }
}
