//
//  ImageAndComponents.swift
//  PCB Inspector
//
//  Created by Jack Smith on 13/12/2023.
//
//  View showing IC Components and allowing the user to interact with them

import SwiftUI

struct ComponentsImageView: View {
    @Binding var controller: MultiElementController // Controller for logic behind the vuew
    @Binding var components: [ComponentInfo] // List of the components in the current view
    @Binding var integratedComponents: [ICInfo] // List of the ICs in the current view
    @Binding var image: UIImage // Image of PCB to display
    @State private var imageZoom = 1.0 // The current zoom level of the image
    @State private var actionZoom = 0.0 // The zoom level of the current pinch "session"
    @State private var infoPageOpen: Bool = false // If the ICInfo page is currently open
    let maxZoom = 7.5 // Max zoom amount
    @State private var currentIC : ICInfo? // The current IC
    @State private var currentOffset: CGSize = .zero
    @State private var imageAspectRatio: CGFloat? // Aspect ratio of the current image
    
    var body: some View {
        GeometryReader { master in
            ZStack {
                GeometryReader { geometry in
                    VStack {
                        GeometryReader { imageGeo in
                            ZStack { // Background colour for image section
                                Rectangle()
                                    .fill(.backgroundColourVariant)
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
                                    .overlay { // Overlay containing the identified components
                                        ForEach($components) { comp in
                                            ComponentOverlay(
                                                imageInfo: comp,
                                                parentImageActualSize: .constant((imageGeo.size.width, imageGeo.size.width * (1 / image.getAspectRatio()))),
                                                openICInfoAction: .constant({
                                                    self.currentIC = getICFromUUID(comp.id, integratedComponents)
                                                    if self.currentIC != nil {
                                                        withAnimation {
                                                            infoPageOpen = true
                                                        }
                                                    }
                                                }))
                                            .animation(.easeInOut, value: imageZoom + actionZoom)
                                        }
                                    }
                                    .animation(.easeInOut, value: imageZoom + actionZoom)
                                    .animation(.spring, value: currentOffset)
                                    .scaleEffect(imageZoom + actionZoom, anchor: .center)
                                    .offset(currentOffset)
                            }
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
                            .contentShape(RoundedRectangle(cornerRadius: 25.0))
                            .clipShape(RoundedRectangle(cornerRadius: 25.0))
                        }
                        .frame(width: geometry.size.width * 0.95, height: geometry.size.height * 0.75, alignment: .center)
                        .position(x: geometry.frame(in: .local).midX, y: geometry.frame(in: .local).midY)
                    }
                }
                .onTapGesture {
                    print("hello")
                }
                .onChange(of: infoPageOpen) {
                    print("changed to \(infoPageOpen)")
                }
                
                .onChange(of: integratedComponents.count) {
                    print("there has BEEN AN ELTEREFINBOWB")
                }
                
                .disabled(infoPageOpen) // Disable the background view when the view is open
                .popover(isPresented: $infoPageOpen) {
                    ICInfoPopover(component: currentIC, controller: controller, closingAction: {
                        withAnimation {
                            infoPageOpen = false
                        }
                    })
                }
               
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
                        
/// Generate the component overlay
struct ComponentOverlay: View {
    @Binding var imageInfo: ComponentInfo
    @Binding var parentImageActualSize: (x: CGFloat, y: CGFloat)
    @Binding var openICInfoAction: () -> ()
    
    var body: some View {
        Group {
            Rectangle()
                .fill(componentColours[imageInfo.type] ?? .pink)
                .overlay(alignment: .center) {
                    Text(imageInfo.internalName)
                        .bold()
                        .scaledToFit()
                        .minimumScaleFactor(0.001)
                }
        }
        .frame(width: absoluteToRelativeSize(imageInfo.imageInfo.imageSize, parentImageActualSize).x, height: absoluteToRelativeSize(imageInfo.imageInfo.imageSize, parentImageActualSize).y)
        .opacity(0.75)
        .position(x: absoluteToRelativeSize(imageInfo.imageInfo.imageSize, parentImageActualSize).x / 2 + absoluteToRelativeSize(imageInfo.imageInfo.imageLocation, parentImageActualSize).x, y: absoluteToRelativeSize(imageInfo.imageInfo.imageSize, parentImageActualSize).y / 2 + absoluteToRelativeSize(imageInfo.imageInfo.imageLocation, parentImageActualSize).y)
        .gesture(TapGesture(count: 1) // Open information about the component
            .onEnded {
                if imageInfo.type == .ic {
                    openICInfoAction()
                } else {
                    print("Not ic")
                }
            })
    }
}

/// Converts the size of a component to the new size relative to the size of the parent
fileprivate func absoluteToRelativeSize(_ normalSub: (x: CGFloat, y: CGFloat), _ actualParent: (x: CGFloat, y: CGFloat)) -> (x: CGFloat, y: CGFloat) {
    let x = CGFloat(normalSub.x) * CGFloat(actualParent.x)
    let y = CGFloat(normalSub.y) * CGFloat(actualParent.y)
    return (x: x, y: y)
}

/// Iterate through a list of ICInfo types and find one with the given UUID, returns `nil` if none are found
func getICFromUUID(_ uuid: UUID, _ icList: [ICInfo]) -> ICInfo? {
    for ic in icList {
        if ic.baseInfo.id == uuid {
            return ic
        }
    }
    return nil
}

// FOR PREVIEW PURPOSES

let ci = ComponentInfo(type: .ic, imageInfo: ComponentImageInfo(imageLocation: (0.2, 0.2), imageSize: (0.2, 0.2)), internalName: "IC1")
let ic = ICInfo(baseInfo: ci, informationDescription: ["manufacturer": "Broadcom", "description": "this is a description", "informationSource": "inf osourv"], rawIdentifiedText: ["kmfj2005a"], infoState: .loaded)
let ci2 = ComponentInfo(type: .res, imageInfo: ComponentImageInfo(imageLocation: (0.5, 0.5), imageSize: (0.1, 0.1)), internalName: "RES1")
let ci3 = ComponentInfo(type: .ic, imageInfo: ComponentImageInfo(imageLocation: (0.8, 0.8), imageSize: (0.2, 0.2)), internalName: "IC2")
let ic3 = ICInfo(baseInfo: ci3, informationDescription: ["test": "hello"], infoState: .loaded)

#Preview {
    ComponentsImageView(controller: .constant(MultiElementController()), components: .constant([ci, ci2, ci3]), integratedComponents: .constant([ic, ic3]), image: .constant(UIImage(named: "PCB Placeholder")!))
}
