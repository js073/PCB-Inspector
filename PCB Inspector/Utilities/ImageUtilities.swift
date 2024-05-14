//
//  ImageUtilities.swift
//  PCB Inspector
//
//  Created by Jack Smith on 11/12/2023.
//
//  Provides useful utilities for image alteration

import Foundation
import CoreImage
import SwiftUI
import Vision

/// Provides helpful functions to perform operations on images
class ImageUtilities {
    static func blackWhiteFilter(_ input: CGImage, intensity: Double) -> CIImage? { // Converts a colour image to black and white
        let ciImage = CIImage(cgImage: input)
        let bwImage = ciImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 0, "inputContrast": 1])
        return bwImage
    }
    
    static func ciToCG(_ input: CIImage) -> CGImage? { // Converts a CIImage to a CGImage
        let context = CIContext(options: nil)
        if let cgImage = context.createCGImage(input, from: input.extent) {
            return cgImage
        }
        return nil
    }
}

extension CGSize {
    /// One CGSize by the specifed amount
    func multiply(_ amount: CGFloat) -> CGSize {
        var newSize: CGSize = .zero
        newSize.width = self.width * amount
        newSize.height = self.height * amount
        return newSize
    }
    
    /// Minus one CGSize from another
    func minus(_ other: CGSize) -> CGSize {
        var newSize: CGSize = .zero
        newSize.width = self.width - other.width
        newSize.height = self.height - other.height
        return newSize
    }
}

extension CGImage {
    /// Converts a CGImage to an Image object, with the given orientation
    func toImage(_ orientation: CGImagePropertyOrientation) -> Image {
        let imageOrientation = getOrientation(orientation)
        let image = Image(decorative: self, scale: 1.0, orientation: imageOrientation)
        return image
    }
    
    /// Rotates the CGImage to the given orientation
    func changeOrientation(_ orientation: CGImagePropertyOrientation) -> CGImage? {
        guard self.colorSpace != nil else { return nil }
        let currentSize = CGSize(width: self.width, height: self.height)
        if let context = CGContext(data: nil, width: Int(currentSize.width), height: Int(currentSize.height), bitsPerComponent: self.bitsPerComponent, bytesPerRow: self.bytesPerRow, space: self.colorSpace!, bitmapInfo: self.bitmapInfo.rawValue) {
            context.rotate(by: orientation.getRotationRadians())
            context.draw(self, in: CGRect(origin: CGPoint(x: 0, y: 0), size: orientation.getWidthHeight(currentSize)))
            return context.makeImage()
        }
        return nil
    }
}

/// Get the aspect ratio of UIImage, ratio of width to height
extension UIImage {
    func getAspectRatio() -> CGFloat {
        let w = self.size.width
        let h = self.size.height
        return w / h
    }
}

extension UIImage.Orientation {
    /// Converts the UIImage Orientation to CGImage Orientation
    func toCGOrientation() -> CGImagePropertyOrientation {
        switch self {
        case .up: return .up
        case .left: return .left
        case .right: return .right
        case .down: return .down
        case .upMirrored: return .upMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        case .downMirrored: return .downMirrored
        default: return .up
        }
    }
}

extension CGImagePropertyOrientation {
    /// Converts from CG orientation to UI orientation
    func toUIOrientation() -> UIImage.Orientation {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        }
    }
    
    /// Gets the rotation radians from the orientation
    func getRotationRadians() -> CGFloat {
        switch self {
        case .up, .upMirrored: return 0
        case .left, .leftMirrored: return -(CGFloat.pi / 2)
        case .right, .rightMirrored: return (CGFloat.pi / 2)
        case .down, .downMirrored: return CGFloat.pi
        }
    }
    
    /// Converts the current width and height to the related height and widt
    func getWidthHeight(_ input: CGSize) -> CGSize {
        switch self {
        case .up, .upMirrored, .down, .downMirrored: return CGSize(width: input.height, height: input.width)
        case .left, .leftMirrored, .right, .rightMirrored: return CGSize(width: input.width, height: input.height)
        }
    }
}

/// Used to transform CG orientation to Image orientation
func getOrientation(_ orientation: CGImagePropertyOrientation) -> Image.Orientation {
    switch orientation {
    case .up: return .up
    case .down: return .down
    case .left: return .left
    case .right: return .right
    case .upMirrored: return .upMirrored
    case .downMirrored: return .downMirrored
    case .leftMirrored: return .leftMirrored
    case .rightMirrored: return .rightMirrored
    }
}
