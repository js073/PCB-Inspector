//
//  ImageBinarisation.swift
//  PCB Inspector
//
//  Created by Jack Smith on 22/01/2024.
//
//  Class to perform the binarisation process on a specificed image

import Foundation
import CoreImage
import SwiftImage // Third part package to allow easier access to raw pixel data, found at https://github.com/koher/swift-image
import Accelerate

class ImageOperations {
    /// Function to split a specified image array into specified window sizes, and apply a function on each of these windows
    static fileprivate func splitImageAndPerform(_ windowSize: Int, _ image: Image<RGBA<UInt8>>, _ function: ([RGBA<UInt8>]) -> ([RGBA<UInt8>])) -> Image<RGBA<UInt8>> {
        var rawImage = image
        let width = rawImage.width
        let height = rawImage.height
        let width_iterations = Int(ceil(Double(width) / Double(windowSize))) // Number of iterations across the width, upperbounded
        let height_iterations = Int(ceil(Double(height) / Double(windowSize))) // Number of iterations across the height, upperbounded
        
        for w in 0..<width_iterations {
            for h in 0..<height_iterations { // Iterate over windows of the image
                let (width_start, width_end) = (windowSize * w, min(windowSize * (w + 1), width))
                let (height_start, height_end) = (windowSize * h, min(windowSize * (h + 1), height))
                let subsection = rawImage[width_start..<width_end, height_start..<height_end] // Current "window"
                let pixelArray = [RGBA<UInt8>](subsection)
                var resultArray: [RGBA<UInt8>] = []
                if standardDeviationCalc(pixelArray) < 0 {
                    resultArray = Array(repeating: RGBA(gray: UInt8(averageValueCalc(pixelArray) < 255 / 2 ? 0 : 255), alpha: UInt8(255)), count: pixelArray.count)
                } else {
                    resultArray = function(pixelArray) // Perform specified operation on current window
                }
                for width_it in 0..<(width_end - width_start) {
                    for height_it in 0..<(height_end - height_start) { // Update the current window based on the result of the operation on the window
                        rawImage[width_start + width_it, height_start + height_it] = resultArray[(height_it * (width_end - width_start)) + width_it]
                    }
                }
            }
        }
        
        return rawImage
    }
    
    /// Convenience wrapper for the above function to pass and return a CGImage
    static fileprivate func splitImageAndPerform(_ windowSize: Int, _ image: CGImage, _ function: ([RGBA<UInt8>]) -> ([RGBA<UInt8>])) -> CGImage {
        let rawImage = cgToPixelArray(image)
        return splitImageAndPerform(windowSize, rawImage, function).cgImage
    }
    
    /// Takes an array of pixels and performs binarisation on them
    static fileprivate func binariseSubImage(_ pixels: [RGBA<UInt8>], constant: UInt8 = 6) -> [RGBA<UInt8>] {
        let avg = averageValueCalc(pixels)
        let thresh = constant > avg ? 0 : avg - constant
        return pixels.map { ($0.gray >= thresh) ? RGBA(gray: 255, alpha: 255) : RGBA(gray: 0, alpha: 255) }
    }
    
    /// Takes the average grey value of an image and if it is too low, inverts the image
    static fileprivate func darkImageToLight(_ image: CGImage) -> CGImage {
        let pixelArray = cgToPixelArray(image)
        let averageValue = averageValueCalc([RGBA<UInt8>](pixelArray))
        if averageValue < 255 / 2 {
            return pixelArray.map { RGBA(gray: 255 - $0.gray, alpha: $0.alpha) }.cgImage
        }
        return pixelArray.cgImage
    }
    
    /// Convencience function to quickly convert a CGImage to an RGBA pixel array
    static fileprivate func cgToPixelArray(_ image: CGImage) -> Image<RGBA<UInt8>> {
        return Image<RGBA<UInt8>>(cgImage: image)
    }
    
    /// Calculates the average value of the gray value of the image
    static fileprivate func averageValueCalc(_ values: [RGBA<UInt8>]) -> UInt8 {
        return UInt8(values.reduce(0) { $0 + Int($1.gray) } / values.count)
    }
    
    /// Calculates the standard deviation of the gray values of the image
    static func standardDeviationCalc(_ values: [RGBA<UInt8>]) -> Double {
        let mean = Double(averageValueCalc(values))
        let std = values.reduce(0) { $0 + pow((Double($1.gray) - mean), 2) }
        return sqrt(std / (Double(values.count) - 1))
    }
    
    /// Pefroms a 3x3 Gaussian Blur on the image
    static func gaussianBlur3x3(_ image: Image<RGBA<UInt8>>) -> Image<RGBA<UInt8>> {
        let kernel = Image<Float>(width: 3, height: 3, pixels: [
            1, 2, 1,
            2, 4, 2,
            1, 2, 1
        ]).map { $0 / 16.0 }
        return image.convoluted(with: kernel)
    }
    
    /// Convenience wrapper to use above function with CGImage
    static func gaussianBlur3x3(_ image: CGImage) -> CGImage {
        let array = cgToPixelArray(image)
        return gaussianBlur3x3(array).cgImage
    }
    
    /// Performs a 5x5 Gaussian Blur on the image
    static func gaussianBlur5x5(_ image: Image<RGBA<UInt8>>) -> Image<RGBA<UInt8>> {
        let kernel = Image<Float>(width: 5, height: 5, pixels: [
            1, 4, 6, 4, 1,
            4, 16, 24, 16, 4,
            6, 24, 36, 24, 6,
            4, 16, 24, 16, 4,
            1, 4, 6, 4, 1
        ]).map { $0 / 256.0 }
        return image.convoluted(with: kernel)
    }
    
    /// Convenience wrapper to use above function with CGImage
    static func gaussianBlur5x5(_ image: CGImage) -> CGImage {
        let array = cgToPixelArray(image)
        return gaussianBlur5x5(array).cgImage
    }
    
    /// Performs a Laplacian operation on the image
    static func laplacianConvolution(_ image: Image<RGBA<Int>>) -> Image<RGBA<Int>> {
        let kernel = Image<Float>(width: 3, height: 3, pixels: [
            0, 1, 0,
            1, -4, 1,
            0, 1, 0
        ])
        return image.convoluted(with: kernel)
    }
    
    /// Old thresholding method which doesn't work properly
    static func brokenThreshold(_ image: CGImage, windowSize: Int = 10, constant: Int = 0) -> CGImage {
        let correctedImage = darkImageToLight(image) // If the image is light on dark, convert it to dark on light
        return splitImageAndPerform(windowSize, correctedImage, { inp in binariseSubImage(inp, constant: UInt8(constant)) })
    }
    
    /// Function to perform mean adaptive threshold on an image with a given window size and addative constant
    static func meanAdaptiveThreshold(_ image: CGImage, windowSize: Int = 10, constant: Int = 0) -> CGImage? {
        let windowSize = div(Int32(windowSize), 2).rem == 0 ? windowSize + 1 : windowSize // Make sure the window size is odd
        
        guard let (originalBuffer, format) = cgImageToBuffer(image) else { return nil }
        
        let averageValue = originalBuffer.array.map { Int($0) }.reduce(0, +) / originalBuffer.count
        print("average value", averageValue)
        
        let convolutionResult = accellerateConvolution1D(originalBuffer, Array(repeating: 1, count: windowSize)) // Perform a convolution to get the mean value for each pixel
        
        // Get arrays for both original and new versions of the image
        let originalImageArray = averageValue < (255 / 2) ? originalBuffer.array.map { 255 - $0 } : originalBuffer.array
        let averageImageArray = averageValue < (255 / 2) ? convolutionResult.array.map { 255 - $0 } : convolutionResult.array
        
        // Iterate through the image and perform the thresholding process
        let binarisedImageArray: [vImage.Planar8.ComponentType] = zip(originalImageArray, averageImageArray).map { Int($0.0) < (Int($0.1) - constant) ? 0 : 255 }
        
        // Convert to a buffer and then a CGImage
        let resultImageBuffer = vImage.PixelBuffer<vImage.Planar8>(pixelValues: binarisedImageArray, size: convolutionResult.size)
        return resultImageBuffer.makeCGImage(cgImageFormat: format)
    }
    
    /// Wrapper function for the above function which allows the binarisation window to depend on the size of the input image
    //TODO: Tune parameters for this function
    static func meanAdaptiveThresholdWindowNumbers(_ image: CGImage, windowNumbers: Int = 7, constant: Int = 5) -> CGImage? {
        let windowSize = max(image.width, image.height) / windowNumbers
        return meanAdaptiveThreshold(image, windowSize: windowSize, constant: constant)
    }
    
    /// Perform binary thresholding, if no threshold is given, then the image average is used 
    static func binaryThreshold(_ image: CGImage, threshold: UInt8? = nil, constant: Int = 0) -> CGImage {
        let pixelArray = cgToPixelArray(image)
        let thresh: UInt8 = threshold == nil ? averageValueCalc([RGBA<UInt8>](pixelArray)) : threshold!
        return pixelArray.map { ($0.gray >= thresh) ? RGBA(gray: 255, alpha: 255) : RGBA(gray: 0, alpha: 255) }.cgImage
    }
    
    /// Perform Niblack threshold, implementation translated into Swift from https://craftofcoding.wordpress.com/2021/09/30/thresholding-algorithms-niblack-local/
    static func niblackThreshold(_ image: CGImage, windowSize: Int = 10, k: Float = -0.2) -> CGImage {
        let correctedImage = darkImageToLight(image)
        var pixelArray = cgToPixelArray(correctedImage)
        
        let (width, height) = (pixelArray.width, pixelArray.height)
        let radius = (windowSize - 1) / 2 // div operation
        for w in radius..<(width - radius) {
            for h in radius..<(height - radius) {
                let subsection = [RGBA<UInt8>](pixelArray[(w - radius)..<(w + radius), (h - radius)..<(h + radius)])
                let mean = averageValueCalc(subsection)
                let std = standardDeviationCalc(subsection)
                let thresh = (Double(mean) + (Double(k) * std))
                
                pixelArray[w, h] = RGBA(gray: UInt8(Double(pixelArray[w, h].gray) > thresh ? 255 : 0), alpha: UInt8(255))
            }
        }
        return pixelArray.cgImage
    }
    
    /// Converts a CGImage to a B&W pixel buffer, returning the format
    static func cgImageToBuffer(_ image: CGImage) -> (buffer: vImage.PixelBuffer<vImage.Planar8>, format: vImage_CGImageFormat)? {
        guard var format = vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: 8, colorSpace: CGColorSpace(name: CGColorSpace.extendedGray)!, bitmapInfo: .init(rawValue: CGImageAlphaInfo.none.rawValue)) else { return nil } // Format for pixel buffer
        // Create the image buffer
        guard let imageBuffer = try? vImage.PixelBuffer(cgImage: image, cgImageFormat: &format, pixelFormat: vImage.Planar8.self) else { return nil }
        return (imageBuffer, format)
    }
    
    /// Provides a 1D image kernel and produces a convolution with the passed B&W Image, returning the original image as a buffer, the new image as a buffer and the format of both of them
    static func accellerateConvolution1D(_ buffer: vImage.PixelBuffer<vImage.Planar8>, _ kernel: [Float]) -> vImage.PixelBuffer<vImage.Planar8> {
        let divisor = kernel.reduce(0, +) // Value to divise the kernel by
        let normalisedKernel = kernel.map { $0 / divisor } // Normalise the kernel
        
        // Output buffer
        let destinationBuffer = vImage.PixelBuffer<vImage.Planar8>(size: buffer.size)
        
        // Convolve the image
        buffer.separableConvolve(horizontalKernel: normalisedKernel, verticalKernel: normalisedKernel, edgeMode: .extend, destination: destinationBuffer)
        return destinationBuffer
    }
    
    /// Convenience wrapper for the above function to allow direct usage with CGImage
    static func accellerateConvolution1D(_ image: CGImage, _ kernel: [Float]) -> CGImage? {
        guard let convertedImage = cgImageToBuffer(image) else { return nil }
        
        return accellerateConvolution1D(convertedImage.buffer, kernel).makeCGImage(cgImageFormat: convertedImage.format)
    }
    
    /// Performs a convolution with a given kernel, given the number of rows and columns
    static func accellerateConvolution2D(_ buffer: vImage.PixelBuffer<vImage.PlanarF>, _ kernel: [Float], kernelRows: Int, kernelCols: Int) -> vImage.PixelBuffer<vImage.PlanarF> {
        let width = buffer.width
        let height = buffer.height
        
        var buffer = buffer
        
        // Perform the convolution
        vDSP.convolve(buffer, rowCount: height, columnCount: width, withKernel: kernel, kernelRowCount: kernelRows, kernelColumnCount: kernelCols, result: &buffer)
        
        return buffer
    }
    
    /// Converts a UInt8 pixel buffer into a Float image, returns a function to deallocte the backing data to prevent memory leak
    static func planar8ToPlanarF(_ buffer: vImage.PixelBuffer<vImage.Planar8>) -> (vImage.PixelBuffer<vImage.PlanarF>, () -> ()) {
        let width = buffer.width
        let height = buffer.height
        
        // Perform the conversion
        let resultStorage = UnsafeMutableBufferPointer<Float>.allocate(capacity: width * height)
        let resultBuffer = vImage.PixelBuffer(data: resultStorage.baseAddress!, width: width, height: height, byteCountPerRow: width * MemoryLayout<Float>.stride, pixelFormat: vImage.PlanarF.self)

        buffer.convert(to: resultBuffer)
        
        return (resultBuffer, resultStorage.deallocate)
    }
    
    /// Converts a Float image to a UInt8 buffer
    static func planarFToPlanar8(_ buffer: vImage.PixelBuffer<vImage.PlanarF>) -> vImage.PixelBuffer<vImage.Planar8> {
        let width = buffer.width
        let height = buffer.height
        
        let destinationBuffer = vImage.PixelBuffer<vImage.Planar8>(width: width, height: height)
        
        buffer.convert(to: destinationBuffer)
        return destinationBuffer
    }
    
    /// Converts a float image into a CGImage
    static func planarFtoCGImage(_ buffer: vImage.PixelBuffer<vImage.PlanarF>) -> CGImage? {
        guard let imageFormat = vImage_CGImageFormat(bitsPerComponent: 32, bitsPerPixel: 32, colorSpace: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: kCGBitmapByteOrder32Host.rawValue | CGBitmapInfo.floatComponents.rawValue | CGImageAlphaInfo.none.rawValue)) else { return nil }
        
        return buffer.makeCGImage(cgImageFormat: imageFormat)
    }
    
    /// Calculates statistics about a given Float image buffer
    static func calculateBufferStatistics(_ buffer: vImage.PixelBuffer<vImage.PlanarF>) -> (mean: Float, std: Float, variance: Float) {
        var mean = Float.nan
        var std = Float.nan
        
        vDSP_normalize(buffer.array, 1, nil, 1, &mean, &std, vDSP_Length(buffer.count))
        
        return (mean, std, std * std)
    }
    
    static func increaseVImageBrightness(_ buffer: vImage.PixelBuffer<vImage.Planar8>) -> vImage.PixelBuffer<vImage.Planar8> {
        let buffer = buffer
        buffer.applyGamma(.nineOverFiveHalfPrecision, destination: buffer)
        return buffer
    }
    
    /// Gaussian blur using Accellerate
    static func fastGaussian3x3(_ image: CGImage) -> CGImage? {
        guard let (buffer, _) = cgImageToBuffer(image) else { return nil }
        let kernel: [Float] = [
            1, 2, 1,
            2, 4, 2,
            1, 2, 1
        ].map { $0 / 16 }
        
        // Convert image to float buffer
        let (floatBuffer, deallocation) = planar8ToPlanarF(buffer)
        // Perform convolution
        let convolved = accellerateConvolution2D(floatBuffer, kernel, kernelRows: 3, kernelCols: 3)
        // Convert back to CGImage
        let img = planarFtoCGImage(convolved)
        // Deallocate buffr
        deallocation()
        return img
    }
    
    /// Performs a Laplacian convolution on the image
    static func laplacianConvolve(_ image: CGImage) -> (CGImage?, Float)? {
        // Convert CGImage to buffer
        guard let (buffer, _) = cgImageToBuffer(image) else { return nil }
        
        // Kernel for convolution
        let kernel: [Float] = [
             -1, -1, -1,
             -1, 8, -1,
             -1, -1, -1,
        ]
        // Convert the buffer type
        let (floatBuffer, deallocation) = planar8ToPlanarF(buffer)
        // Perform convolution
        let convolved = accellerateConvolution2D(floatBuffer, kernel, kernelRows: 3, kernelCols: 3)
        
        let statistics = calculateBufferStatistics(convolved)
        
        // Convert back to CGImage
        let img = planarFtoCGImage(floatBuffer)
        // Deallocate the backing data to prevent data leak
        deallocation()
        return (img, statistics.std)
    }
    
    /// Takes a image a returns an integer value, with a lower value meaning the image is less blurred
    static func determineImageBluriness(_ image: CGImage) -> Int? {
        // Perform laplacian convolution
        guard let (_, varience) = laplacianConvolve(image) else { return nil }
        
        // Set the tresholds for the different levels of bluriness 
        let (highLevel, midLevel): (Float, Float) = (0.1, 0.05)
        
        if varience > highLevel {
            return 0
        } else if varience > midLevel {
            return 1
        } else {
            return 2
        }
    }
    
    /// Rotates an image by a specified number of degrees
    static func rotateImage(_ image: CGImage, degrees: CGFloat) -> CGImage {
        let rawImage = cgToPixelArray(image)
        return rawImage.rotated(byDegrees: degrees).cgImage
    }
    
    /// Helper function to procide radian rotatation 
    static func rotateImage(_ image: CGImage, radians: CGFloat) -> CGImage {
        let degrees = (radians / CGFloat.pi) * 180
        return rotateImage(image, degrees: degrees)
    }
    
    /// Function to take an Image and crop it into the specified number of sections, e.g. a call to 4 will split into a total of 16 (4x4) windows
    static func sectionImage(_ image: CGImage, _ windowNumbers: Int) -> [[CGImage]] {
        let rawImage = cgToPixelArray(image)
        var outputArray: [[CGImage]] = []
        var currentArray: [CGImage] = []
        
        // Calc the size of the image strides
        let widthStride = rawImage.width / windowNumbers
        let heightStride = rawImage.height / windowNumbers
        
        for height in 0..<windowNumbers { // Iterate over widths
            currentArray = []
            for width in 0..<windowNumbers { // Iterate over heights
                let (widthLowerBound, widthUpperBound) = (width * widthStride, (width + 1) * widthStride)
                let (heightLowerBound, heightUpperBound) = (height * heightStride, (height + 1) * heightStride)
                let currentSection = rawImage[widthLowerBound..<widthUpperBound, heightLowerBound..<heightUpperBound]
                currentArray.append(currentSection.cgImage)
            }
            outputArray.append(currentArray)
        }
        return outputArray
    }
    
    /// Function to take an Image and crop it into the specified number of sections, e.g. a call to 4 will split into a total of 16 (4x4) windows
    static func sectionImageFaster(_ image: CGImage, _ windowNumbers: Int) -> [[CGImage]] {
        var outputArray: [[CGImage]] = []
        var currentArray: [CGImage] = []
        
        guard windowNumbers > 0 else { return [] }
        
        // Calc the size of the image strides
        let widthStride = image.width / windowNumbers
        let heightStride = image.height / windowNumbers
        
        for height in 0..<windowNumbers { // Iterate over widths
            currentArray = []
            for width in 0..<windowNumbers { // Iterate over heights
                let widthLowerBound = width * widthStride
                let heightLowerBound = height * heightStride
                let cropSection = CGRect(x: widthLowerBound, y: heightLowerBound, width: widthStride, height: heightStride)
                guard let croppedImage = image.cropping(to: cropSection) else { continue }
                currentArray.append(croppedImage)
            }
            outputArray.append(currentArray)
        }
        return outputArray
    }
    
    static func sectionImageCrossover(_ image: CGImage, _ windowNumbers: Int) -> [[CGImage]] {
        // Calc the size of the image strides
        let widthStride = image.width / windowNumbers
        let heightStride = image.height / windowNumbers
        
        let newWidth = image.width - widthStride
        let newHeight = image.height - heightStride
        
        let cropSection = CGRect(x: widthStride / 2, y: heightStride / 2, width: newWidth, height: newHeight)
        guard let croppedImage = image.cropping(to: cropSection) else { return [] }
        guard windowNumbers - 1 > 1 else { return [] }
        return sectionImageFaster(croppedImage, windowNumbers - 1)
    }
    
    /// Takes an image and divides it into an array of sub-images of a set dimensions, returning the width and height of the array
    static func sectionImageIntoSize(_ image: CGImage, _ size: Int) -> (images: [[CGImage]], width: Int, height: Int) {
        var outputArray: [[CGImage]] = []
        var currentArray: [CGImage] = []
        
        let widthIterations = Int(floor(Double(image.width) / Double(size))) + 1
        let heightIterations = Int(floor(Double (image.height) / Double(size))) + 1
        
        for height in 0..<heightIterations {
            currentArray = []
            for width in 0..<widthIterations {
                let widthLowerBound = width * size
                let heightLowerBound = height * size
                
                let cropSection = CGRect(x: widthLowerBound, y: heightLowerBound, width: size, height: size)
                guard let croppedImage = image.cropping(to: cropSection) else { continue }
                currentArray.append(croppedImage)
            }
            outputArray.append(currentArray)
        }
        
        return (outputArray, widthIterations, heightIterations)
        
    }
    
    /// Apply Unsharp filter to a give CGImage 
    static func unsharpFilter(_ image: CGImage) -> CGImage? {
        let ciImage = CIImage(cgImage: image)
        ciImage.applyingFilter("unsharpMaskFilter")
        return ciImage.toCGImage()
    }
    
    /// Performs the neccessary operations to prepare an image for text extraction
    static func textExtractionImage(_ image: CGImage) -> CGImage {
        let blurredImage = fastGaussian3x3(image) ?? image
//        let sharpenedImage = unsharpFilter(blurredImage) ?? blurredImage
        let binarisedImage = meanAdaptiveThresholdWindowNumbers(blurredImage)
        return binarisedImage ?? image
    }
    
    static func testFunc(_ image: CGImage, windowSize: Int, const: Int) -> CGImage {
//        return laplacianConvolution(Image<RGBA<UInt8>>(cgImage: image)).cgImage
        let correctedImage = darkImageToLight(image)
        _ = gaussianBlur3x3(cgToPixelArray(correctedImage)).cgImage
//        return niblackThreshold(correctedImage, windowSize: windowSize)
        return splitImageAndPerform(windowSize, correctedImage, { inp in binariseSubImage(inp, constant: UInt8(const)) })
    }
}
