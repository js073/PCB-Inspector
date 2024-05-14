//
//  LiveViewView.swift
//  PCB Inspector
//
//  Created by Jack Smith on 19/02/2024.
//
//  Provides a view for a live view feature

import SwiftUI
import OrderedCollections

struct LiveViewView: View {
    @StateObject fileprivate var controller = LiveViewController()
    @State var isShowingInfo: Bool = false
    @State var currentType: ComponentType = .other
    @State var currentLocation: CGRect = CGRectNull
    @State var wasPaused = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                if !controller.loading { // Loading section
                    LoadingView(loadingText: .constant("Preparing Model"))
                }
//                if let uiImage = UIImage(named: "PCB Placeholder") {
//                    let image = Image("PCB Placeholder")
                if let uiImage = controller.liveImageUI, let image = controller.liveImage {
                    image // PCB image to display
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.width * (1 / uiImage.getAspectRatio()), alignment: .center)
                        .contentShape(Rectangle())
                        .overlay {
                            ForEach($controller.currentIdentifiedObjects, id: \.self.1.minX) { object in // Objects overlay
                                ObjectOverlay(componentType: object.0, componentLocation: object.1, actualImageSize: ((geometry.size.width, geometry.size.width * (1 / (controller.liveImageUI?.getAspectRatio() ?? 1)))), tapFunction: {
                                    controller.inferencePaused = true
                                    currentType = object.wrappedValue.0
                                    currentLocation = object.wrappedValue.1
                                    isShowingInfo = true
                                })
                            }
                        }
                        .popover(isPresented: $isShowingInfo) { // Showing detailed information about a component
                            InformationView(type: $currentType, location: $currentLocation, controller: controller, closingAction: { controller.inferencePaused = false; isShowingInfo = false })
                        }
                    HStack {
                        Button { // Pause live view
                            print(controller.currentIdentifiedObjects)
                            withAnimation {
                                controller.inferencePaused.toggle()
                                wasPaused.toggle()
                            }
                        } label: {
                            Image(systemName: (controller.inferencePaused ? "play.fill" : "pause.fill"))
                                .padding(.all, 20)
                                .transition(.slide)
                        }
                        .buttonStyle(SmallAccentButtonStyle())
                        .clipShape(Circle())
                        
//                        Button {
//                            controller.isBinarisig.toggle()
//                        } label: {
//                            Text(controller.isBinarisig ? "Binning" : "Not")
//                        }
                    }
                }
            }
            .task {
                await controller.camera.start()
            }
            .onDisappear {
                Task {
                    await controller.camera.stop()
                }
            }
            .onChange(of: isShowingInfo) {
                if !wasPaused {
                    if !isShowingInfo {
                        controller.inferencePaused = false
                    } else {
                        controller.inferencePaused = true
                    }
                }
            }
        }
    }
}

struct ObjectOverlay: View { // Object overlay 
    @Binding var componentType: ComponentType
    @Binding var componentLocation: CGRect
    var actualImageSize: (width: CGFloat, height: CGFloat)
    var tapFunction: () -> ()
    
    var body: some View {
        Group {
            Group {
                Rectangle()
                    .foregroundStyle(componentColours[componentType] ?? .pink)
            }
            .frame(width: componentLocation.width * actualImageSize.width, height: componentLocation.height * actualImageSize.height)
            .opacity(0.5)
            .position(x: componentLocation.minX * actualImageSize.width, y: componentLocation.minY * actualImageSize.height)
            .gesture(LongPressGesture(minimumDuration: 0) // On tap run the function
                .onEnded { _ in
                    tapFunction()
                })
        }
    }
    
    func tmp(_ p: String) {
        print(p, componentLocation)
    }
}

/// View to show detailed information about component
struct InformationView: View {
    @State var compInfo: LiveCompInfo?
    @State var isLoading: Bool = false
    @Binding var type: ComponentType
    @Binding var location: CGRect
    var controller: LiveViewController
    var closingAction: () -> ()
    
    var body: some View {
        VStack {
            if isLoading { // Loading view
                LoadingView(loadingText: .constant("Getting Information"))
            } else {
                HStack {
                    Button { // Close button
                        closingAction()
                    } label: {
                        Text("Close")
                    }
                    .padding(.all, 10)
                    Spacer()
                }
                .buttonStyle(SmallAccentButtonStyle())
                switch compInfo?.hasPerformedLookup ?? true {
                case false : // Loading view
                    LoadingView(loadingText: .constant("Getting Information"))
                case true : // Loaded section
                    if let componentImage = compInfo?.componentImage { // Image section
                        PreviewImageUI(image: .constant(UIImage(cgImage: componentImage)))
                            .frame(maxHeight: 300)
                    }
                    if let identifiedInfo = compInfo?.identifiedInfo { // Info found on API
                        Text(((compInfo?.hasGotResult) ?? false) ? "Octopart Results" : "Identified Information")
                            .bold()
                            .font(.title3)
                        if !(compInfo?.hasGotResult ?? false) {
                            
                        }
                        List {
                            Section {
                                ForEach(identifiedInfo.sorted(by: { _ , _ in return false }), id: \.self.key) { info in
                                    TitleDescription(title: .constant(info.key), description: .constant(info.value))
                                }
                            }
                        }
                        .listStyle(.inset)
                    } else if let rawText = compInfo?.rawText { // No info found, show raw text
                        if rawText.isEmpty {
                            Text("No text could be identified")
                                .bold()
                        } else {
                            Text("Raw Text")
                                .bold()
                                .font(.title3)
                            List {
                                Section {
                                    ForEach(rawText, id: \.self) { item in
                                        HStack {
                                            Text(item)
                                            
                                        }
                                    }
                                }
                                .listStyle(.inset)
                            }
                        }
                    } else { // Error text
                        ErrorScreen()
                    }
                }
            }
        }
        .task {
            isLoading = true
            compInfo = await controller.inspectComponent((type, location))
            isLoading = false
        }
        
    }
}

#Preview {
    LiveViewView()
}
