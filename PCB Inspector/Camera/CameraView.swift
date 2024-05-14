//
//  CameraView.swift
//  PCB Inspector
//
//  Created by Jack Smith on 22/11/2023.
//
//  Contains the view for the camera

import SwiftUI
import os.log

// Created with help of documentation found here https://developer.apple.com/documentation/avfoundation/capture_setup/avcam_building_a_camera_app

struct CameraView: View {
    @StateObject private var dataModel = CameraDataModel()
    @State private var focusSelected = false
    @State private var focusAbsolutePosition: (x: CGFloat, y: CGFloat) = (x: 0, y: 0)
    @State private var iconOrientation: Angle = .zero // Rotation angle for camera icon
    @State var isPhotoTaken = false
    var savePhotoOtherLocation: Bool = false // Flag to save the taken photo to some other location 
    var performOnImageTaken: (() async -> ())? // Function to perform on image taken when the "savePhotoOtherLocation" is set to true
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                if !isPhotoTaken { // Camera preview screen
                    GeometryReader { geometry in
                        Spacer()
                        PreviewImage(image: $dataModel.imagePreview)
                            .overlay(alignment: .bottom) {
                                Button {
                                    dataModel.camera.takePhoto()
                                    self.isPhotoTaken = true
                                    dataModel.camera.previewPaused = true
                                    if dataModel.takenImagePreview == nil {
                                        logger.debug("image is nil")
                                    } else {
                                        logger.debug("image is not nil")
                                    }
                                } label: {
                                    Label {
                                    } icon: {
                                        ZStack {
                                            Circle()
                                                .stroke(.iconColour, lineWidth: 5)
                                            Circle()
                                                .fill(.accent)
                                            Image(systemName: "camera")
                                                .foregroundColor(.iconColour)
                                                .frame(width: geometry.size.width * 0.15, height: geometry.size.height * 0.15)
                                                .rotationEffect(iconOrientation)
                                                .animation(.smooth, value: iconOrientation)
                                                .onReceive(NotificationCenter.Publisher(center: .default, name: UIDevice.orientationDidChangeNotification)) { _ in
                                                    withAnimation {
                                                        switch UIDevice.current.orientation {
                                                        case .landscapeLeft: iconOrientation = .degrees(90)
                                                        case .landscapeRight: iconOrientation = .degrees(-90)
                                                        case .portraitUpsideDown: iconOrientation = .degrees(180)
                                                        default: iconOrientation = .zero
                                                        }
                                                    }
                                                } // Rotate the camera icon based on device orientation
                                        }
                                    }
                                }
                                .frame(width: geometry.size.width * 0.2)
                            }
                            .gesture(SpatialTapGesture() // Tap to focus gesture
                                .onEnded { event in
                                    let location = event.location // Determine the position of the tap in the image
                                    if let img = dataModel.imagePreviewUI {
                                        let aspectRatio = img.getAspectRatio()
                                        let imageWidth = geometry.size.width
                                        let imageHeight = imageWidth * (1 / aspectRatio)
                                        let normalisedY = location.y - (geometry.size.height / 2) + (imageHeight / 2)
                                        if 0 <= normalisedY && normalisedY <= imageHeight {
                                            withAnimation {
                                                focusSelected = true
                                            }
                                            focusAbsolutePosition = (location.x - (geometry.size.width / 2), location.y - (geometry.size.height / 2))
                                            let focusImagePosition = (x: (location.x / imageWidth) * img.size.width, y: (normalisedY / imageHeight) * img.size.height)
                                            dataModel.camera.setFocusPoint(xCoord: focusImagePosition.x, yCoord: focusImagePosition.y)
                                        }
                                    }
                                })
                            .overlay(alignment: .topLeading) { // Show a reset focus button if manual focus is used
                                if focusSelected {
                                    Button {
                                        withAnimation {
                                            focusSelected = false
                                        }
                                        dataModel.camera.setAutoFocus() // Reset focus scheme to normal
                                    } label: {
                                        Text("Reset focus")
                                    }
                                    .buttonStyle(SmallAccentButtonStyle())
                                    .padding()
                                    .animation(.easeInOut, value: 0.5)
                                }
                            }
                            .overlay() { // Show a box where the user has selected focus
                                if focusSelected {
                                    RoundedRectangle(cornerRadius: 25.0)
                                        .foregroundStyle(.clear)
                                        .frame(width: 100, height: 100, alignment: .center)
                                        .border(.yellow, width: 5)
                                        .opacity(0.8)
                                        .offset(x: focusAbsolutePosition.x, y: focusAbsolutePosition.y)
                                        .animation(.easeInOut, value: 0.5)
                                        .foregroundStyle(.yellow)
                                }
                            }
                        Spacer()
                    }
                }
                if isPhotoTaken { // View to show if a photo is taken
                    if dataModel.takenImagePreview != nil {
                        GeometryReader { geometry in
                            VStack {
                                if UserDefaults.standard.bool(forKey: "developerModeToggle"), let takenImage = dataModel.takenImageCG {
                                    Text("\(takenImage.width) x \(takenImage.height)")
                                }
                                
                                // Image blur section 
                                if let blur = dataModel.imageBluriness {
                                    BlurinessView(blurRating: .constant(blur))
                                }
                                
                                PreviewImage(image: $dataModel.takenImagePreview)
                                HStack {
                                    Button {
                                        dataModel.camera.previewPaused = false
                                        self.isPhotoTaken = false
                                    } label: {
                                        Text("Take New")
                                            .foregroundStyle(.iconColour)
                                    }
                                    .buttonStyle(MonoButtonStyle())
                                    
                                    if savePhotoOtherLocation { // If using other option when taking image, perform a different function on click of "use image" button
                                        Button {
                                            Task {
                                                await performOnImageTaken?()
                                            }
                                        } label: {
                                            Text("Use Image")
                                        }
                                        .buttonStyle(AccentButtonStyle())
                                    } else { // Normal behaviour, navigate to next page
                                        NavigationLink {
                                            switch GlobalStorage.shared.nextScene {
                                            case .singleView: SingleElementView()
                                            case .multiView: MultiElementView()
                                            default: Text("This is awkward")
                                            }
                                        } label: {
                                            Text("Use Image")
                                                .foregroundStyle(.iconColour)
                                        }
                                        .buttonStyle(AccentButtonStyle())
                                    }
                                }
                            }
                            .onDisappear { // Remove old preview when going back
                                dataModel.takenImagePreview = nil
                            }
                        }
                    } else { // Show loading screen whilst waiting for image
                        LoadingView(loadingText: .constant("Loading image"))
                    }
                }
            }
        }
        .task {
            dataModel.savePhotoOtherLocation = savePhotoOtherLocation
            await dataModel.camera.start() // Performed on load
        }
        .onDisappear() { // Performed on exit	
            Task {
                await dataModel.camera.stop()
                dataModel.camera.previewPaused = false
                isPhotoTaken = false
            }
        }
        .onAppear() {
            if dataModel.imagePreview != nil {
                logger.debug("is not nil")
            } else {
                logger.debug("is nil")
            }
        }
    }
}

fileprivate var logger = Logger()

#Preview {
    CameraView()
}
