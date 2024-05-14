//
//  GlobalStorage.swift
//  PCB Inspector
//
//  Created by Jack Smith on 10/12/2023.
//
//  Used as a singleton class to store data for use in many other classes
//  Used as a temporary global storage class for when the app is running, to pass data between views 

import Foundation
import SwiftUI
import CoreGraphics
import os.log
import SwiftData

struct GlobalStorage { // Shared storage structure
    static var shared = GlobalStorage() // Access for the singleton class
    
    var takenImage: CGImage? // Stores the image that has been taken for use later
    var imageOrientation: CGImagePropertyOrientation = .up // Orienation of the taken image, defualt value of up
    var nextScene: SceneViews = .notSet // Stores the next view in cases where multiple views may be avaliable
    var identifiedComponents: [ComponentInfo]?
    var identifiedICs: [ICInfo]?
    var isInPreview: Bool = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    var otherTakenImage: CGImage? // Another storage location for a taken image
    var otherImageOrientation: CGImagePropertyOrientation = .up // Storage for the orientation of the other taken image
    
    func getUIImage() -> UIImage? {
        if let img = takenImage {
            return UIImage(cgImage: img, scale: 1.0, orientation: imageOrientation.toUIOrientation())
        }
        return nil
    }
    
    func getImage() -> Image? {
        if let ui = getUIImage() {
            return Image(uiImage: ui)
        }
        return nil
    }
    
    static func addIC(_ add: ICInfo) { // Add a IC to the IC list with nil checks
        if shared.identifiedICs == nil {
            shared.identifiedICs = [add]
        } else {
            shared.identifiedICs!.append(add)
        }
    }

    static func addComp(_ add: ComponentInfo) { // Add component to component list with nil checks
        if shared.identifiedComponents == nil {
            shared.identifiedComponents = [add]
        } else {
            shared.identifiedComponents!.append(add)
        }
    }
}
