//
//  CameraController.swift
//  PCB Inspector
//
//  Created by Jack Smith on 22/11/2023.
//
//  Controls the logic of getting images and previews from the camera

import Foundation
import AVFoundation
import CoreImage
import os.log
import UIKit

// Created with help of the documentation found here https://developer.apple.com/documentation/avfoundation/capture_setup/avcam_building_a_camera_app 

class CameraController : NSObject {
    private let session = AVCaptureSession() // Start a new camera session
    private var sessionConfigured = false
    private var sessionRunning: Bool {
        session.isRunning
    } // Boolean for if the current session is running
    
    private var cameraInput: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var inputDevice: AVCaptureDevice?
    
    var previewPaused = false
    var addImagePreview: ((CIImage) -> Void)?
    var addImageCapture: ((AVCapturePhoto) -> Void)?
    
    // If the model the camera should be configured for live capture
    var liveCaptureMode: Bool = false
    
    private let wideAngleDevices: [AVCaptureDevice.DeviceType] = [.builtInTripleCamera, .builtInDualWideCamera] // Types containing a wide angle camera
    
    
    // An image stream containing the current preview images
    lazy var imagePreviews: AsyncStream<CIImage> = AsyncStream { continuation in
        addImagePreview = { img in
            if !self.previewPaused {
                continuation.yield(img)
            }
            
        }
    }
    
    // An image stream containing the image captures
    lazy var imageCaptures: AsyncStream<AVCapturePhoto> = AsyncStream { continuation in
        addImageCapture = { img in
            continuation.yield(img)
            logger.debug("image taken \(img)")
        }
    }
    
    // Contains possible capture devices
    private var backCaptureDevices: [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTripleCamera, .builtInTrueDepthCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInDualWideCamera, .builtInWideAngleCamera, .builtInDualWideCamera], mediaType: .video, position: .back).devices.filter { $0.isConnected && !$0.isSuspended }
    }
    
    override init() {
        super.init()
        self.subInit()
    }
    
    
    // Get the best avaliable capture device
    private func subInit() {
        self.inputDevice = backCaptureDevices.first ?? AVCaptureDevice.default(for: .video)
    }
    
    
    // Configures the camera, returns True on success and False on failure
    private func configueCamera() -> Bool {

        session.beginConfiguration()
        
        guard
            let cameraDevice = inputDevice, // Get camera device
            let cameraInput = try? AVCaptureDeviceInput(device: cameraDevice)
        else {
            return false
        } // Try adding it as the output
        
        let photoOutput = AVCapturePhotoOutput()
        let videoOutput = AVCaptureVideoDataOutput()
        
        if liveCaptureMode { // If we are in live capture mode, then we will disregard late frames 
            videoOutput.alwaysDiscardsLateVideoFrames = true
        }
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoDataOutputQueue"))
        
        session.sessionPreset = AVCaptureSession.Preset.photo
        
        if session.canAddInput(cameraInput) {
            session.addInput(cameraInput)
            logger.debug("camera input added")
        } else {
            return false
        }
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            logger.debug("camera output added")
        } else {
            return false
        }
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            logger.debug("output added \(videoOutput.alwaysDiscardsLateVideoFrames)")
        } else {
            return false
        }
        
        self.cameraInput = cameraInput
        self.photoOutput = photoOutput
        self.videoOutput = videoOutput
        
        photoOutput.maxPhotoQualityPrioritization = .quality

        logger.debug("configured correctly")
        self.sessionConfigured = true
        self.session.commitConfiguration()
        
        if wideAngleDevices.contains(cameraDevice.deviceType) {
            do {
                try cameraDevice.lockForConfiguration()
                cameraDevice.videoZoomFactor = 2
                cameraDevice.unlockForConfiguration()
            } catch {
                pubLogger.warning("error for zoom")
            }
        }
        
        return true
    }
    
    
    // Returns true if camera access is authorised and false otherwise
    private func cameraAuthorised() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            let choice = await AVCaptureDevice.requestAccess(for: .video)
            return choice
        default:
            return false
        }
    }
    
    
    // starts the camera stream
    func start() async {
        let auth = await cameraAuthorised()
        guard auth else {
            return
        }
        if self.sessionConfigured {
            if !self.sessionRunning {
                self.session.startRunning()
            }
            return
        }
        if self.configueCamera() {
            self.session.startRunning()
        }
        return
    }
    
    // stops the camera stream
    func stop() async {
        if self.sessionRunning {
            self.session.stopRunning()
        }
    }
    
    fileprivate func getVideoOrientation() -> CGFloat? { // Gets the current device orientation and returns the correct video orientation angle
        switch UIDevice.current.orientation {
        case .portrait:
            return 180
        case .landscapeLeft:
            return 180
        case .landscapeRight:
            return 0
        case .portraitUpsideDown:
            return 270
        default:
            return nil
        }
    }
    
    
    // called when a photo is taken
    func takePhoto() {
        guard let photo = self.photoOutput else {
            return
        }
        var settings = AVCapturePhotoSettings()
        if photo.availablePhotoCodecTypes.contains(.hevc) { // Take an image as a HEVC
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        }
        settings.flashMode = .off // Don't allow the flash
        settings.photoQualityPrioritization = .quality // Prioritise quality
        
        if let id = inputDevice {
            let rc = AVCaptureDevice.RotationCoordinator(device: id, previewLayer: nil)
            if let connectionOutput = photo.connection(with: .video) {
                let angle = rc.videoRotationAngleForHorizonLevelCapture
                if connectionOutput.isVideoRotationAngleSupported(angle) {
                    connectionOutput.videoRotationAngle = angle
                }
            }
        }
        
        photo.capturePhoto(with: settings, delegate: self)
    }
    
    func setFocusPoint(xCoord: CGFloat, yCoord: CGFloat) { // Takes a point and sets this as the current focus point
        // Adapted from https://gist.github.com/stucarney/2fe0710e772b6ede7d078ce56eef250c
        if let inputDevice = inputDevice {
            if inputDevice.isFocusModeSupported(.autoFocus) && inputDevice.isFocusPointOfInterestSupported {
                do {
                    try inputDevice.lockForConfiguration() // To deal with concurrency, lock config
                    inputDevice.focusMode = .autoFocus
                    inputDevice.focusPointOfInterest = CGPoint(x: xCoord, y: yCoord)
                    inputDevice.unlockForConfiguration() // Unlock condig
                } catch {
                    print("Couldn't lock config")
                }
            }
        }
    }
    
    func setAutoFocus() { // Resets the autofocus mode to general autofocus
        if let inputDevice = inputDevice {
            if inputDevice.isFocusModeSupported(.continuousAutoFocus) {
                do {
                    try inputDevice.lockForConfiguration()
                    inputDevice.focusMode = .continuousAutoFocus
                    inputDevice.unlockForConfiguration()
                } catch {
                    print("Can't lock config")
                }
            }
        }
    }
}


// Performed on photo capture
extension CameraController : AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            logger.error("Error taking photo: \(error)")
            return
        }

        addImageCapture?(photo)
        logger.debug("image captured and added to queue")
    }
}


// Performed on image preview update
extension CameraController : AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = sampleBuffer.imageBuffer else {return}
        
        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        
        addImagePreview?(CIImage(cvPixelBuffer: buffer))
    }
}


fileprivate let logger = Logger()
