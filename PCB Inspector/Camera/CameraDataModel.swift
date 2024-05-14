//
//  DataModel.swift
//  PCB Inspector
//
//  Created by Jack Smith on 22/11/2023.
//
//  Acts as an interface between CameraController and CameraView

import Foundation
import AVFoundation
import SwiftUI
import os.log
import CoreImage



final class CameraDataModel: ObservableObject {
    
    let camera = CameraController()
    
    @Published var imagePreview: Image? // Contains the image preview
    @Published var imagePreviewUI: UIImage? // Image preview in UIImage format
    @Published var takenImagePreview: Image? // Taken image preview
    @Published var imageBluriness: Int? // Bluriness rating of image
    var takenImageRaw: AVCapturePhoto?
    var takenImageCG: CGImage?
    var ori: String = ""
    var savePhotoOtherLocation: Bool = false
    
    init() {
        logger.debug("initialised")
        Task {
            await cameraPreview()
        }
        Task {
            await takeImage()
        }
    }
    
    deinit {
        print("heelo")
    }
    
    func cameraPreview() async { // Gets the image previews from the CameraController
        if GlobalStorage.shared.isInPreview { // Sets a placeholder image for use in simulator
            Task { @MainActor in
                imagePreviewUI = UIImage(named: "PCB Placeholder")
                
            }
        } else { // Real device
            let previewImages = camera.imagePreviews.map{ ($0.image, $0) }
            
            for await (image, ci) in previewImages {
                Task { @MainActor in
                    imagePreview = image
                    imagePreviewUI = UIImage(ciImage: ci)
                }
            }
        }
    }
    
    func takeImage() async { // Takes the image and returns a format for processing and one for preview
        if GlobalStorage.shared.isInPreview { // Setup for simulator
            Task { @MainActor in
                takenImageRaw = nil
                takenImagePreview = Image("PCB Placeholder")
            }
        } else { // Real device 
            let takenImages = camera.imageCaptures
            
            for await image in takenImages {
                Task { @MainActor in
                    takenImageRaw = image // RAW image
                    logger.debug("this has been called")
                    if let cgImage = image.cgImageRepresentation() { // Preview image
//                        guard let orientation = image.metadata[String(kCGImagePropertyOrientation)] as? UInt32, let cgOrientation = CGImagePropertyOrientation(rawValue: orientation) else { return }
                        let cgOrientation = UIDevice.current.orientation.toCGOrientation()
//                        logger.debug("IMAGE ORIENTATION IS: \(orientation)")
                        switch cgOrientation {
                        case .up: ori = "up"
                        case .left: ori = "left"
                        case .right: ori = "right"
                        case .down: ori = "down"
                        default: ori = "n/a"
                        }
                        print(ori)
                        let preImage = Image(decorative: cgImage, scale: 1, orientation: getOrientation(cgOrientation))
                        takenImagePreview = preImage
                        takenImageCG = cgImage
                        
                        self.imageBluriness = ImageOperations.determineImageBluriness(cgImage)
                        
                        if savePhotoOtherLocation { // If there has been a non-default destination specified
                            GlobalStorage.shared.otherTakenImage = cgImage
                            GlobalStorage.shared.otherImageOrientation = cgOrientation
                        } else { // Use default destination
                            GlobalStorage.shared.takenImage = cgImage
                            GlobalStorage.shared.imageOrientation = cgOrientation
                        }
                        logger.debug("image has been added ")
                    }
                }
            }
        }
    }
    
}

fileprivate extension CIImage { // Extension to convert CIImage to Image format
    var image: Image? {
        let context = CIContext()
        guard let image = context.createCGImage(self, from: self.extent) else {return nil}
        return Image(decorative: image, scale: 1, orientation: .up)
    }
    
    var uiImage: UIImage? { // Convert CIImage to UIImage
        return UIImage(ciImage: self)
    }
}


fileprivate let logger = Logger()
