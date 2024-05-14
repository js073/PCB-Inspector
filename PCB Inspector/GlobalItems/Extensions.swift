//
//  Extensions.swift
//  PCB Inspector
//
//  Created by Jack Smith on 13/02/2024.
//
//  Contains various extensions used throughout the application

import Foundation
import CoreGraphics
import UIKit


extension Collection where Element: Equatable {
    /// Function similar to split, however returns both the elements included and not included 
    func splitArray(with: (Element) -> Bool) -> (included: [Element], excluded: [Element]) {
        var include: [Element] = []
        var exclude: [Element] = []
        for item in self { // Iterate through the items of the array
            if with(item) { // Add to included if the passed function returns true
                include.append(item)
            } else { // Else add to exluded items 
                exclude.append(item)
            }
        }
        return (include, exclude)
    }
}

extension Array {
    /// Extension to return nil if the given index is outside of the array range
    func conditionalGet(_ index: Index) -> Element? {
        if index >= 0 && index < self.count {
            return self[index]
        }
        return nil
    }
}

/// Extension to CGImage to perform a adapted from https://stackoverflow.com/questions/10544887/rotating-a-cgimage
extension CGImage {
    func createRotatedImage(orienation: UIImage.Orientation) -> CGImage? {
        var orientedImage: CGImage?
        let imageRef = self
        let originalWidth = imageRef.width
        let originalHeight = imageRef.height
        let bitsPerComponent = imageRef.bitsPerComponent
        let bytesPerRow = imageRef.bytesPerRow

        let colorSpace = imageRef.colorSpace
        let bitmapInfo = imageRef.bitmapInfo

        var degreesToRotate: Double
        var swapWidthHeight: Bool
        var mirrored: Bool
        switch orienation {
        case .up:
            degreesToRotate = 0.0
            swapWidthHeight = false
            mirrored = false
            break
        case .upMirrored:
            degreesToRotate = 0.0
            swapWidthHeight = false
            mirrored = true
            break
        case .right:
            degreesToRotate = -90.0
            swapWidthHeight = true
            mirrored = false
            break
        case .rightMirrored:
            degreesToRotate = -90.0
            swapWidthHeight = true
            mirrored = true
            break
        case .down:
            degreesToRotate = 180.0
            swapWidthHeight = false
            mirrored = false
            break
        case .downMirrored:
            degreesToRotate = 180.0
            swapWidthHeight = false
            mirrored = true
            break
        case .left:
            degreesToRotate = 90.0
            swapWidthHeight = true
            mirrored = false
            break
        case .leftMirrored:
            degreesToRotate = 90.0
            swapWidthHeight = true
            mirrored = true
            break
            
        default:
            degreesToRotate = 0
            swapWidthHeight = false
            mirrored = false
            break
        }
        
        mirrored = false
        
        let radians = degreesToRotate * Double.pi / 180

        var width: Int
        var height: Int
        if swapWidthHeight {
            width = originalHeight
            height = originalWidth
        } else {
            width = originalWidth
            height = originalHeight
        }

        if let contextRef = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace!, bitmapInfo: bitmapInfo.rawValue) {

            contextRef.translateBy(x: CGFloat(width) / 2.0, y: CGFloat(height) / 2.0)
            contextRef.rotate(by: CGFloat(radians))
            if swapWidthHeight {
                contextRef.translateBy(x: -CGFloat(height) / 2.0, y: -CGFloat(width) / 2.0)
            } else {
                contextRef.translateBy(x: -CGFloat(width) / 2.0, y: -CGFloat(height) / 2.0)
            }
            contextRef.draw(imageRef, in: CGRect(x: 0, y: 0, width: originalWidth, height: originalHeight))

            orientedImage = contextRef.makeImage()
        }

        return orientedImage
    }
}

extension CIImage {
    /// Converts a CIImage to CGImage
    func toCGImage() -> CGImage? {
        let context = CIContext(options: nil)
        return context.createCGImage(self, from: self.extent)
    }
}

extension UIDeviceOrientation {
    func toCGOrientation() -> CGImagePropertyOrientation {
        switch self {
        case .portrait:
            return .right
        case .portraitUpsideDown:
            return .left
        case .landscapeLeft:
            return .up
        case .landscapeRight:
            return .down
        default:
            return .right
        }
    }
}
