//
//  ComponentDetection.swift
//  PCB Inspector
//
//  Created by Jack Smith on 20/12/2023.
//
//  File with the purpose of providing access to the ML model

import Foundation
import CoreGraphics
import CoreVideo
import CoreML
import CoreImage
import UIKit
import SwiftUI

class ComponentDetection { // Class used to perform component detection using the ML model
    fileprivate let targetDimensions: (width: Int, height: Int) = (960, 960) // Target image dimensions for model input
    fileprivate let confidenceThreshold: Float = 0.2 // Mininum confidence threshold required to be used
//    fileprivate let iouThreshold: Float = 0.5 // Maximum intersection between two predictions of the same class
    fileprivate let componentNameDictionary: [ComponentType: String] = [ // Dictionary used to convert the component type to the small internal description
        .ic : "IC",
        .cap : "CAP",
        .res : "RES",
    ]
    
    fileprivate lazy var largeModel: large_items_obb? = {
        let modelConfig = MLModelConfiguration()
        return try? large_items_obb(configuration: modelConfig) // Load model
    }()
    
    /// Takes an image and runs the ML model on it, cleaning the output
    func identifyComponents(_ image: CGImage, _ imgOrientation: CGImagePropertyOrientation, ignoringComponents: [ComponentType] = []) -> ([ComponentInfo], [ICInfo])? {
        do {
            let imagePixelBuffer = try MLFeatureValue(cgImage: image, pixelsWide: targetDimensions.width, pixelsHigh: targetDimensions.height, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue // Convert image to image buffer
            guard imagePixelBuffer != nil else { return nil }
            guard let prediction = try largeModel?.prediction(image: imagePixelBuffer!) else { return nil } // Predict 
            var parsedOutputs = parseOBBOutput(output: prediction.var_1256) // Parse outputs
            parsedOutputs = parsedOutputs.sorted(by: { ($0.height * $0.width) > ($1.height * $1.width) }) // Make it so the largest items are listed first
            let modelOutput = modelOutputsToComponents(parsedOutputs, image, imgOrientation,  largeItemsPredicitionDictionary) // Set outputs to component types
            return filterComponents(modelOutput, ignoringComponents)
        } catch {
            pubLogger.warning("An error occured: \(error)")
        }
        return nil
    }
    
    /// Performs inference on a given image, with less processing, for use in Live view
    func identifyComponentsSimple(_ image: CGImage) -> [(ComponentType, CGRect)] {
        do {
            let imagePixelBuffer = try MLFeatureValue(cgImage: image, pixelsWide: targetDimensions.width, pixelsHigh: targetDimensions.height, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue // Convert image to image buffer
            guard imagePixelBuffer != nil else { return [] }
            guard let prediction = try largeModel?.prediction(image: imagePixelBuffer!) else { return [] } // Predict
            let parsedOutputs = parseOBBOutput(output: prediction.var_1256) // Parse outputs
            return parsedOutputs.map { (largeItemsPredicitionDictionary[$0.prediction] ?? .other, CGRect(x: CGFloat($0.xVal) + CGFloat($0.width / 2), y: CGFloat($0.yVal) + CGFloat($0.height / 2), width: CGFloat($0.width), height: CGFloat($0.height))) }
        } catch {
            return []
        }
    }
    
    /// Performs inference on a given image, with less processing, for use in Live view
    func identTmp(_ image: CGImage) -> [(ComponentType, CGRect)] {
        do {
            let imagePixelBuffer = try MLFeatureValue(cgImage: image, pixelsWide: 640, pixelsHigh: 640, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue // Convert image to image buffer
            guard imagePixelBuffer != nil else { return [] }
            let modelConfig = MLModelConfiguration()
            let model = try small_items_obb(configuration: modelConfig) // Load model
            guard let prediction = try? model.prediction(image: imagePixelBuffer!) else { return [] } // Predict
            let parsedOutputs = parseOBBOutput(output: prediction.var_1256, targetDimensions: (640, 640)) // Parse outputs
            return parsedOutputs.map { (largeItemsPredicitionDictionary[$0.prediction] ?? .other, CGRect(x: CGFloat($0.xVal) + CGFloat($0.width / 2), y: CGFloat($0.yVal) + CGFloat($0.height / 2), width: CGFloat($0.width), height: CGFloat($0.height))) }
        } catch {
            return []
        }
    }
    
    /// Function to split the image into sub-sections and perform the ML identification on those subsections, combining the results (a number of 4 windows will create a 16 window image (4x4))
    func identifyComponentsWindowing(_ image: CGImage, _ imgOrientation: CGImagePropertyOrientation, _ windowNumber: Int, ignoringComponents: [ComponentType] = []) -> ([ComponentInfo], [ICInfo])? {
        // Set of components (such as ics) that are ignored in the sub image identfidication
        do {
            let modelConfig = MLModelConfiguration()
            let model = try small_items_obb(configuration: modelConfig) // Load model
            
            let rotatedImage = image.createRotatedImage(orienation: imgOrientation.toUIOrientation()) ?? image
            
            print("THE ORIENTATION IS", imgOrientation.getRotationRadians())
            
            print("LOADED ROTATE")
            
            let splitImages = ImageOperations.sectionImageFaster(rotatedImage, windowNumber)
            print("LOADED SPLIT")
            
            
            var componentInfos: [ComponentInfo] = []
            var icInfos: [ICInfo] = []
            
            for height in 0..<windowNumber {
                for width in 0..<windowNumber { // Iterate over the width and the height
                    let currentImage = splitImages[height][width]
                    
                    guard let currentImageBuffer = try MLFeatureValue(cgImage: currentImage, pixelsWide: 640, pixelsHigh: 640, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue else { continue } // Convert current image to a buffer
                    let currentPrediction = try model.prediction(image: currentImageBuffer) // Predict
                    let currentParsedOutputs = parseOBBOutput(output: currentPrediction.var_1256, targetDimensions: (640, 640), iouThreshold: 0.5) // Parse outputs and filter out necessary ones
                    let currentFormattedOutput = modelOutputsToComponents(currentParsedOutputs, currentImage, imgOrientation, smallItemsPredictionDictionary, fixingOrientation: false)
                    
                    var currentComponentList = currentFormattedOutput.0
                    var currentICList = currentFormattedOutput.1
                    
                    // Filter out the components in the ignoring components type, and for the others perform the subImage conversion process
                    currentComponentList = currentComponentList.map { convertSubComponentToGlobal($0, windowNumber, (width, height)) }
                    
                    // If not including ICs, then set the list to empty
                    if ignoringComponents.contains(.ic) {
                        currentICList = []
                    }
                    
                    // Append the new components to the list
                    componentInfos.append(contentsOf: currentComponentList)
                    icInfos.append(contentsOf: currentICList)
                }
            }
            
            // Fix errors in naming
            for type in ComponentType.allCases {
                print("TYPE: ", type)
                var count = 1
                componentInfos = componentInfos.map { comp in
                    var comp = comp
                    if comp.type == type {
                        print("TYPE count", count)
                        comp.internalName = (componentNameDictionary[comp.type] ?? "Other").appending(" \(count)")
                        count += 1
                    }
                    return comp
                }
            }
            
            return (componentInfos, icInfos)
        } catch {
            pubLogger.warning("An error occured during the processing")
        }
        return nil
    }
    
    /// Function to take a tuple of lists of components and ICs and filter out the specified component types
    fileprivate func filterComponents(_ lists: ([ComponentInfo], [ICInfo])?, _ ignoringComponents: [ComponentType]) -> ([ComponentInfo], [ICInfo])? {
        guard let lists else { return nil }
        var comps = lists.0
        var ics = lists.1
        comps = comps.filter { !ignoringComponents.contains($0.type) }
        if ignoringComponents.contains(.ic) { ics = [] }
        return (comps, ics)
    }
    
    /// Function to take a component identified in the sub image process and alter the location parameters to match the global image
    fileprivate func convertSubComponentToGlobal(_ component: ComponentInfo, _ windowNumber: Int, _ currentPosition: (w: Int, h: Int)) -> ComponentInfo {
        var component = component
        var currentImageInfo = component.imageInfo
        let scalingFactor = 1 / CGFloat(windowNumber)
        let currentSize = currentImageInfo.imageSize
        let currentLocation = currentImageInfo.imageLocation
        
        // Scale the size
        let newSize: (x: CGFloat, y: CGFloat) = (currentSize.x * scalingFactor, currentSize.y * scalingFactor)
        // Scale the location and add the new constant to it
        //FIXME: need to check the logic of the direction of splits as well as orientation
        let newLocation: (x: CGFloat, y: CGFloat) = ((CGFloat(currentPosition.w) * scalingFactor) + (currentLocation.x * scalingFactor), (CGFloat(currentPosition.h) * scalingFactor) + (currentLocation.y * scalingFactor))
        
        // Update the location and sizes
        currentImageInfo.imageSize = newSize
        currentImageInfo.imageLocation = newLocation
        
        // Update the image info and return
        component.imageInfo = currentImageInfo
        return component
    }
    
    /// Convert the raw model output to a component that can be more easily worked with
    fileprivate func modelOutputsToComponents(_ input: [ModelOutput], _ baseImage: CGImage, _ imgOrientation: CGImagePropertyOrientation, _ outputDictionary: [Int: ComponentType], fixingOrientation: Bool = true) -> ([ComponentInfo], [ICInfo]) {
        var comps: [ComponentInfo] = []
        var ics: [ICInfo] = []
        for rawDetected in input {
            let detected = fixingOrientation ? determineComponentPosition(rawDetected, imgOrientation) : rawDetected // Change the orientation of the identified locations based on image orientation
            let type = outputDictionary[detected.prediction] ?? .other // Convert the model output to component type
            //        pubLogger.debug("x \(detected.xVal), y \(detected.yVal), w \(detected.width), h \(detected.height)")
            let imageInfo = ComponentImageInfo(imageLocation: (CGFloat(detected.xVal), CGFloat(detected.yVal)), imageSize: (CGFloat(detected.width), CGFloat(detected.height))) // Convert the output points to percentages of the image resolution
            let compNum = comps.filter { $0.type == type }.count + 1 // Count the number of elements with the same type
            let compName = (componentNameDictionary[type] ?? "OTHER").appending(" \(compNum)") // Create the internal name by the type and the number of other components of that type
            let compInfo = ComponentInfo(type: type, imageInfo: imageInfo, internalName: compName) // Set the internal name
            if type == .ic {
                let icInfo = identifyIC(compInfo, baseImage, rawDetected, imgOrientation)
                ics.append(icInfo)
            }
            comps.append(compInfo)
        }
        return (comps, ics)
    }
    
    /// Perform the text extraction on the specified IC
    fileprivate func identifyIC(_ baseInfo: ComponentInfo, _ baseImage: CGImage, _ rawDetected: ModelOutput, _ imgOrientation: CGImagePropertyOrientation) -> ICInfo {
        var icInfo = ICInfo(baseInfo: baseInfo, informationDescription: [:]) // If the type is an IC
        let icImg = getICImage(baseImage, rawDetected) // Get subimage of IC
        if let icImg { // If image is identified
            let icImg = ImageOperations.rotateImage(icImg, radians: imgOrientation.getRotationRadians())
            icInfo.infoState = .unloaded
            icInfo.baseInfo.imageInfo.subImage = UIImage(cgImage: icImg)
        }
        return icInfo
    }
    
    /// Parses the raw output of a OBB Model into ModelOutput format
    fileprivate func parseOBBOutput(output: MLMultiArray, targetDimensions: (width: Int, height: Int) = (960, 960), iouThreshold: Float = 0.5) -> [ModelOutput] {
        // 1 × 7 × 18900
        let shape = output.shape
        // box[x,y,w,h] + (2 classes) + [theta]
        let rows = Int(truncating: shape[2]) // 18900
        
        var modelOutputs: [ModelOutput] = []
        
        for r in 0..<rows { // Iterate over predictions
            var maxClassIndex: Int = 0
            var maxClassScore: Float = 0
            for c in 0..<2 { // Get the highest confidence and the class
                let current = Float(truncating: output[(rows * (4 + c)) + r])
                if current > maxClassScore {
                    maxClassIndex = c
                    maxClassScore = current
                    
                }
            }
            // Make sure the confidence is greater than the threshold, else continue to next prediciton
            guard maxClassScore > confidenceThreshold else { continue }
            
            let theta = Float(truncating: output[(rows * 6) + r])
            // If the detection needs rotating by 90 degrees
            let rotate = abs(theta - (Float.pi) / 2) < 0.5
            
            let x = Float(truncating: output[(rows * 0) + r]) / Float(targetDimensions.width)
            let y = Float(truncating: output[(rows * 1) + r]) / Float(targetDimensions.height)
            let tmpW = Float(truncating: output[(rows * 2) + r]) / Float(targetDimensions.width)
            let tmpH = Float(truncating: output[(rows * 3) + r]) / Float(targetDimensions.height)
            
            let w = rotate ? tmpH : tmpW
            let h = rotate ? tmpW : tmpH
            
            let currentOutput = ModelOutput(xVal: x - (w / 2), yVal: y - (h / 2), width: w, height: h, prediction: maxClassIndex, confidence: maxClassScore)
            modelOutputs.append(currentOutput)
        }
        // Perform NMS to remove overlapping predicitions and return
        return nonMaximumSupression(modelOutputs, iouThreshold: iouThreshold)
    }
    
    /// Performs the nonMaximumSupression operation on predictions to prevent duplicates
    fileprivate func nonMaximumSupression(_ modelOutputs: [ModelOutput], iouThreshold: Float) -> [ModelOutput] {
        var modelOutputs = modelOutputs
        var finalOutputs: [ModelOutput] = []
        while !modelOutputs.isEmpty {
            let current = modelOutputs.removeFirst() // Get first prediction
            finalOutputs.append(current)
            var tmpOutputs: [ModelOutput] = []
            for box in modelOutputs { // Check against each of the other boxes
                if current.prediction == box.prediction { // If the two boxes have the same prediciton
                    let iou = calculateIOU(box1: current, box2: box) // Calculate the IOU between the two boxes
                    if modelOutputs.count == 4 {
                        print("iou", iou)
                    }
                    if iou < iouThreshold { // If the IOU is less than the threshold, add it to the temp list of viable boxes
                        tmpOutputs.append(box)
                    }
                } else {
                    tmpOutputs.append(box)
                }
            }
            // Set the temp boxes to the main boxes list
            modelOutputs = tmpOutputs
        }
        return finalOutputs
    }
    
    /// Returns the Euclidean distance between two points
    fileprivate func euclideanDistance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        sqrt(pow(abs(p1.x - p2.x), 2) + pow(abs(p2.y - p1.y), 2))
    }
    
    /// Calculates the Intersection over Union between two boxes
    /// Adapted from: https://github.com/hollance/CoreMLHelpers/blob/master/CoreMLHelpers/NonMaxSuppression.swift
    fileprivate func calculateIOU(box1: ModelOutput, box2: ModelOutput) -> Float {
        let area1 = box1.width * box1.height
        guard area1 > 0 else { return 0 }
        
        let area2 = box2.width * box2.height
        guard area2 > 0 else { return 0 }
        
        let minX = max(box1.xVal, box2.xVal)
        let minY = max(box1.yVal, box2.yVal)
        let maxX = min(box1.xVal + box1.width, box2.xVal + box2.width)
        let maxY = min(box1.yVal + box1.height, box2.yVal + box2.height)
        
        let intersectionArea = max(maxY - minY, 0) * max(maxX - minX, 0)
        
        return intersectionArea / (area1 + area2 - intersectionArea)
        
    }
    
    /// Converts the raw model output into a format that is easier to work with
    fileprivate func parseOutput(coords: [Float], confs: MLMultiArray) -> [ModelOutput] {
        var outputs: [ModelOutput] = []
        print("counts", coords.count, confs.count)
        for i in 0..<min(coords.count / 4, confs.count) {
            let currentCoords = Array(coords[(i*4)..<((i*4)+4)]) // Current prediction coordinates
            if let predictedType = getPredictionAndConfidence(confs, i), predictedType.confidence >= confidenceThreshold {
                let x = currentCoords[0] // X coordinate of centre of box
                let y = currentCoords[1] // Y coordinate of centre of box
                let w = currentCoords[2] // Wdith of box
                let h = currentCoords[3] // Height of box
                let prediction = ModelOutput(xVal: x - (w / 2), yVal: y - (h / 2), width: w, height: h, prediction: predictedType.prediction, confidence: predictedType.confidence) // Add the prediction to the array
                outputs.append(prediction)
            }
        }
        return outputs
    }
    
    /// Takes an array of confidences and returns the prediction and the max confidences
    func getPredictionAndConfidence(_ confidences: MLMultiArray, _ index: Int) -> (prediction: Int, confidence: Float)? {
        guard let confidencePossibilites = confidences.shape.last else { return nil }
        let possibilities = Int(truncating: confidencePossibilites)
        
        var currentPredicitions: [Float] = []
        for i in 0..<possibilities {
            currentPredicitions.append(Float(truncating: confidences[(index * possibilities) + i]))
        }
        
        guard let maxConfidence = currentPredicitions.max() else { return nil }
        guard let maxPredicition = currentPredicitions.firstIndex(of: maxConfidence) else { return nil }
        
        return (maxPredicition, maxConfidence)
    }
    
    /// Crops the main PCB image down to the specified size
    fileprivate func getICImage(_ baseImage: CGImage, _ icInfo: ModelOutput) -> CGImage? {
        let location = (x: icInfo.xVal, y: icInfo.yVal) // Location of component
        let dimension = (x: icInfo.width, y: icInfo.height) // Dimensions of component
        let imageWidth = CGFloat(baseImage.width)
        let imageHeight = CGFloat(baseImage.height)
        
        pubLogger.warning("w: \(dimension.x), h: \(dimension.y)")
        
        let cropRect = CGRect(x: CGFloat(location.x) * imageWidth, y: CGFloat(location.y) * imageHeight, width: CGFloat(dimension.x) * imageWidth, height: CGFloat(dimension.y) * imageHeight)
        return baseImage.cropping(to: cropRect)
    }
    
    /// Takes a model input and changes the width and height parameters based on the input image orientation
    fileprivate func determineComponentPosition(_ input: ModelOutput, _ imageOrientation: CGImagePropertyOrientation) -> ModelOutput {
        let w = input.width // width of identified component
        let h = input.height // height of identified component
        let x = input.xVal + (w / 2) // x position of centre of component
        let y = input.yVal + (h / 2) // y position of centre of component
        let prediction = input.prediction
        let confidence = input.confidence
        switch imageOrientation {
        case .up, .upMirrored: return ModelOutput(xVal: x - (w / 2), yVal: y - (h / 2), width: w, height: h, prediction: prediction, confidence: confidence) // Identity
        case .left, .leftMirrored: return ModelOutput(xVal: y - (h / 2), yVal: 1 - x - (w / 2), width: h, height: w, prediction: prediction, confidence: confidence)
        case .right, .rightMirrored: return ModelOutput(xVal: 1 - y - (h / 2), yVal: x - (w / 2), width: h, height: w, prediction: prediction, confidence: confidence)
        case .down, .downMirrored: return ModelOutput(xVal: 1 - x - (w / 2), yVal: 1 - y - (h / 2), width: w, height: h, prediction: prediction, confidence: confidence)
        }
    }
    
    /// Convenience wrapper for determineComponentPosition to be able to use ImageInfo instead
    fileprivate func determineComponentPosition(_ input: ComponentImageInfo, _ imageOrientation: CGImagePropertyOrientation) -> ComponentImageInfo {
        let (x, y) = input.imageLocation
        let (w, h) = input.imageSize
        let output = ModelOutput(xVal: Float(x), yVal: Float(y), width: Float(w), height: Float(h), prediction: 0, confidence: 0)
        
        var info = input
        info.imageSize = (CGFloat(output.width), CGFloat(output.height))
        info.imageLocation = (CGFloat(output.xVal), CGFloat(output.yVal))
        
        return info
    }
}

/// Model output structure
fileprivate struct ModelOutput {
    let xVal: Float // X pos of component
    let yVal: Float // Y pos of component
    let width: Float // Width of component
    var height: Float // Height of component
    let prediction: Int // Predicted class of component
    let confidence: Float // Confidence value of component
}
