//
//  ZoomImage.swift
//  PCB Inspector
//
//  Created by Jack Smith on 12/12/2023.
//
//  Used as the view for an image that can be zoomed

import SwiftUI

struct ZoomImage: View {
    @Binding var image: UIImage
    @State private var imageZoom = 1.0 // The current zoom level of the image
    @State private var actionZoom = 0.0 // The zoom level of the current pinch "session"
    @State private var currentOffset: CGSize = .zero
    @State private var viewportSize: CGSize?
    let maxZoom = 5.0 // Max zoom amount
    @State private var imageAspectRatio: CGFloat? // Aspect ratio of the current image
    
    var body: some View {
        GeometryReader { imageGeo in
            VStack {
                Spacer()
                Image(uiImage: image) // PCB image to display
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageGeo.size.width, height: imageGeo.size.width * (1 / image.getAspectRatio()), alignment: .center)
                    .contentShape(Rectangle())
                    .gesture( // Pinch gesture
                        MagnifyGesture()
                            .onChanged { value in
                                withAnimation {
                                    actionZoom = value.magnification - 1
                                }
                            }
                            .onEnded { value in
                                withAnimation {
                                    if imageZoom + actionZoom >= 1 && imageZoom + actionZoom <= maxZoom { // Updates the zoom of the image with the new value
                                        imageZoom += (actionZoom)
                                    } else if imageZoom + actionZoom < 1 {
                                        imageZoom = 1 // Doesn't allow the zoom to go below 0
                                    } else { // Image is zooming further than max
                                        imageZoom = maxZoom
                                    }
                                    actionZoom = 0
                                    checkPanBounds(imageGeo.size)
                                }
                            }
                    )
                    .gesture( // Doubletap gesture
                        TapGesture(count: 2)
                            .onEnded {
                                withAnimation {
                                    if imageZoom != 1.0 {
                                        imageZoom = 1.0
                                    } else {
                                        imageZoom = 2.0
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture() // Panning gesture
                            .onChanged { gesture in
                                if imageZoom > 1.0 { // Only allow panning when zoomed in
                                    currentOffset.width += gesture.translation.width
                                    currentOffset.height += gesture.translation.height
                                    print(currentOffset, gesture.translation)
                                }
                            }
                            .onEnded { gesture in
                                withAnimation {
                                    print("ended ")
                                    checkPanBounds(imageGeo.size)
                                }
                            }
                    )
                    .animation(.easeInOut, value: imageZoom + actionZoom)
                    .animation(.spring, value: currentOffset)
                    .scaleEffect(imageZoom + actionZoom, anchor: .center)
                    .offset(currentOffset)
                    .onAppear {
                        imageAspectRatio = image.getAspectRatio()
                    }
                    .overlay(alignment: .bottom) { // Control buttons for image preview
                        HStack {
                            Button { // Zoom out
                                withAnimation {
                                    imageZoom -= 0.5
                                    if imageZoom < 1.0 {
                                        imageZoom = 1.0
                                    }
                                    checkPanBounds(imageGeo.size)
                                }
                            } label: {
                                Image(systemName: "minus.magnifyingglass")
                            }
                            .buttonStyle(SmallMonoButtonStyle())
                            Button { // Reset zoom
                                withAnimation {
                                    imageZoom = 1.0
                                    checkPanBounds(imageGeo.size)
                                }
                            } label: {
                                Text("Reset")
                            }
                            .buttonStyle(SmallAccentButtonStyle())
                            Button { // Zoom in
                                withAnimation {
                                    imageZoom += 0.5
                                    if imageZoom > maxZoom {
                                        imageZoom = maxZoom
                                    }
                                    checkPanBounds(imageGeo.size)
                                }
                            } label: {
                                Image(systemName: "plus.magnifyingglass")
                            }
                            .buttonStyle(SmallMonoButtonStyle())
                        }
                        .padding(.bottom, 10)
                    }
                Spacer()
            }
        }
    }
        
        /// Checks the image is in the bounds of the view and sets the values accordingly
    fileprivate func checkPanBounds(_ viewSize: CGSize) {
        if let aspect = imageAspectRatio {
            var imageSize: CGSize = .zero
            imageSize.width = viewSize.width
            imageSize.height = (1 / aspect) * viewSize.width
            let currentZoom = (imageZoom + actionZoom) < 1.0 ? 1.0 : ((imageZoom + actionZoom) > maxZoom ? maxZoom : imageZoom + actionZoom) // Calculate the current zoom level based on the theoretical max and min zoom levels
            let currentImageSize = imageSize.multiply(currentZoom) // Calculate the current image size
            let currentBounds = currentImageSize.minus(viewSize) // Calculate the bounds of panning by taking off the overall view size
            if abs(currentOffset.width) > (currentBounds.width / 2) { // Check horizontal distance is in bounds
                currentOffset.width = (currentBounds.width / 2) * (currentOffset.width.sign == .minus ? -1 : 1) // Otherwise set to extremety
                print("width out of bounds")
            }
            if currentImageSize.height <= viewSize.height { // If the height of the image can fit inside the view, center vertically
                currentOffset.height = 0
                print("height fits in view")
            } else if abs(currentOffset.height) > (currentBounds.height / 2) { // Otherwise check vertical distance is in bounds
                print("height out of bounds")
                currentOffset.height = (currentBounds.height / 2) * (currentOffset.height.sign == .minus ? -1 : 1) // Otherwise set vertical offset to extremity
            }
        }
    }
}

#Preview {
    ZoomImage(image: .constant(UIImage(named: "PCB Placeholder")!))
}
