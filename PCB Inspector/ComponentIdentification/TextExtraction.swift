//
//  TextExtraction.swift
//  PCB Inspector
//
//  Created by Jack Smith on 11/12/2023.
//
//  Stores all necessary logic for extracting text from images

import Foundation
import CoreImage
import Vision

// Developed with help of documentation at https://developer.apple.com/documentation/vision/recognizing_text_in_images

class TextExtraction {
    var extractedText: [String]? // Stores the text extracted from the image
    var orientation: CGFloat? // Angle of rotation needed to make the text align vertically
    
    fileprivate func textRecognitionHandler(request: VNRequest, error: Error?) { // Handles the result of the image identification
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return
        }
        orientation = determineOrientation(observations)
        let recognisedStrings = observations.compactMap { observation in
            return observation.topCandidates(1).first?.string
        }

        extractedText = recognisedStrings
        print(recognisedStrings)
    }
    
    /// Function to take the observations and determine orientation from them, returns the rotation angle of the image
    fileprivate func determineOrientation(_ observations: [VNRectangleObservation]) -> CGFloat {
        guard observations.count > 1 else { return 0 }
        
        // Vote for either horizontal or vertical
        var horizontal = 0
        var vertical = 0
        var xTotal = 0
        var yTotal = 0
        
        for observation in observations { // Iterate through observations and "vote" for direction
            let yDist = observation.topRight.y - observation.bottomLeft.y
            let xDist = observation.bottomLeft.x - observation.bottomRight.x
            if abs(yDist) > abs(xDist) { // If Y is smaller, then text is vertical
                vertical += 1
                yTotal += yDist < 0 ? -1 : 1
            } else { // Else horizontal
                horizontal += 1
                xTotal += xDist < 0 ? -1 : 1
            }
            
        }
        
        print(horizontal, vertical, xTotal, yTotal)
        
        if horizontal > vertical { // Going horizontal text
            if xTotal < 0 { return (0) } else { return (CGFloat.pi) }
        } // Vertical text
        if yTotal > 0 { return (CGFloat.pi / 2) } else { return (-CGFloat.pi / 2) }
    }

    func performImageRecognition(image: CGImage) -> (text: [String]?, orientation: CGFloat?) { // Perform text recognition and extraction on the given image
        extractedText = nil
        orientation = nil
        
        let requestHandler = VNImageRequestHandler(cgImage: image)
        let request = VNRecognizeTextRequest(completionHandler: textRecognitionHandler)
        
        request.automaticallyDetectsLanguage = false
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        do {
            try requestHandler.perform([request]) // Perform text extraction request
            return (extractedText, orientation)
        } catch {
            print("An error has occurred: \(error)")
        }
        return (nil, nil)
    }
}
