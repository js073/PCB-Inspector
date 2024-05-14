//
//  ICInfoView.swift
//  PCB Inspector
//
//  Created by Jack Smith on 12/12/2023.
//
//  Provides the interface shown when a user chooses to view more info about a component.

import SwiftUI

// Used for testing purposes
var tempComponent: ICInfo = ICInfo(baseInfo: ComponentInfo(type: .ic, imageInfo: ComponentImageInfo(subImage: UIImage(named: "C1"), imageLocation: (0, 0), imageSize: (10, 10)), internalName: "IC1"), informationDescription: ["Manufacturer": "Broadcom", "Most Likely Code": "BCM2837B01FSBG", "informationSource": "https://www.apple.com", "DS": "http://datasheet.octopart.com/PIC18F44J10-I/PT-Microchip-datasheet-8383908.pdf"], infoState: .notAvaliable, note: "tmp", informationURL: "https://www.apple.com")

struct ICInfoPopover: View {
    @State var component: ICInfo? // Info component
    @State var controller: MultiElementController = MultiElementController()
    @State fileprivate var loadingState: LoadingProgress = .stopped // Used to display necessary information if a call to the API failed
    var closingAction: () -> () // Function to perform when pressing the "Close" button
    @State fileprivate var showingImagePreview: Bool = false
    @State fileprivate var showingDeleteConfirmation: Bool = false
    @State fileprivate var showingImageRetakeOption: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                ZStack { // Shows the component name and type
                    HStack {
                        Button { // Button to close view
                            closingAction()
                        } label: {
                            Text("Close")
                        }
                        .buttonStyle(SmallAccentButtonStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer()
                        
                        // Options menu
                        Menu {
                            Button(role: .destructive) { // Delete the IC from the list
                                showingDeleteConfirmation = true
                            } label: {
                                Group {
                                    Image(systemName: "minus.circle")
                                    Text("Remove as IC")
                                }
                            }
                            
                            Button {
                                showingImageRetakeOption = true
                            } label: {
                                Group {
                                    Image(systemName: "camera")
                                    Text("Retake photo")
                                }
                            }
                            
                            Button {
                                Task {
                                    await loadInfo()
                                }
                            } label: {
                                Group {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Reload")
                                }
                            }
                        } label: {
                            Text("Options")
                        }
                        .buttonStyle(SmallMonoButtonStyle())
                        
          
                    }
                    HStack {
                        if let component {
                            Text("\(component.baseInfo.internalName)")
                                .font(.largeTitle)
                                .bold()
                            Circle()
                                .fill(componentColours[component.baseInfo.type] ?? .pink)
                                .frame(width: 25)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.top, 20)
                .padding([.leading, .trailing], 20)
                
                .confirmationDialog("Are you sure you want to delete this item? This action cannot be undone.", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                    Button(role: .destructive) {
                        controller.deleteIC(component?.baseInfo.id)
                        closingAction()
                    } label: {
                        Text("Delete")
                    }
                }
               
                if let component {
                    
                    if let img = component.baseInfo.imageInfo.subImage { // Sub image of the component
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 75, maxHeight: 75, alignment: .center)
                            .padding(.bottom, 20)
                            .onTapGesture {
                                withAnimation {
                                    showingImagePreview = true
                                }
                            }
                        Divider()
                            .padding(.bottom, 10)
                    }
                    switch component.infoState { // Show different views based on the different IC states
                        
                    case .loaded: // Information has been loaded from the API
                        List { // List of aspects of the component
                            ForEach(component.informationDescription.sorted(by: { a, b in return false }), id: \.key) { item in
                                TitleDescription(title: .constant(item.key), description: .constant(item.value))
                            }
                            .listRowBackground(Color.backgroundColour)
                            TitleDescription(title: .constant("Type"), description: .constant(componentDescriptions[component.baseInfo.type]!))
                                .listRowBackground(Color.backgroundColour)
                        }
                        .scrollContentBackground(.hidden)
                        .listStyle(.insetGrouped)
                        // Add notes section
                        NoteSection(component: $component, addNoteAction: controller.addNote, deleteNoteAction: controller.removeNote)
                        Spacer()
                        
                    case .unloaded: // Information is currently being loaded
                        LoadingView(loadingText: .constant("Loading component information"))
                        Spacer()
                        
                    case .notAvaliable: // No inforation avaliable through API
                        Image(systemName: "questionmark.app.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.orange)
                            .frame(maxHeight: geometry.size.height * 0.05)
                        Spacer()
                            .frame(height: 25)
                        Text("No information could be found about this component")
                            .font(.title3)
                            .bold()
                            .padding([.leading, .trailing], 20)
                        
                        Button { // Button the allow the user to search the web instead
                            controller.setComponentURL(component.baseInfo.id, nil)
                            self.component = controller.getICByID(component.baseInfo.id)
                        } label: {
                            HStack {
                                Text("Search with Google")
                                    .bold()
                                    .font(.title3)
                                Image("Google Logo")
                                    .font(.title3)
                            }
                        }
                        .buttonStyle(AccentButtonStyle())
                        
                        List { // List of the raw identified information
                            Section {
                                ForEach((component.informationDescription).sorted(by: { a, b in return false }), id: \.key) { item in
                                    HStack {
                                        TitleDescription(title: .constant(item.key), description: .constant(item.value))
                                        Spacer()
                                        Button { // Copy button
                                            let clipboard = UIPasteboard.general
                                            clipboard.string = item.value
                                        } label: {
                                            HStack {
                                                Text("Copy")
                                                Image(systemName: "doc.on.doc")
                                            }
                                        }
                                        .buttonStyle(SmallAccentButtonStyle())
                                    }
                                }
                                .listRowBackground(Color.backgroundColour)
                            } header: {
                                Text("Identified Markings")
                            }
                        }
                        .scrollContentBackground(.hidden)
                        
                    case .webLoaded: // Web-page view
                        let url = component.informationURL
                        GoogleSearchView(componentID: .constant(component.baseInfo.id), url: url, getResults: controller.performGoogleSearch, closeView: { controller.clearComponentURL(component.baseInfo.id); refeshInfo() }, selectURL: { str in controller.setComponentURL(component.baseInfo.id, str); refeshInfo() })
                        
                    case .noText: // No text on the IC
                        GeometryReader { subGeo in
                            VStack {
                                Text("No information could be found")
                                    .font(.title)
                                    .bold()
                                    .multilineTextAlignment(.center)
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(.red)
                                    .frame(width: subGeo.size.width * 0.25, height: subGeo.size.width * 0.25)
                                //FIXME: Reword this to soumd better
                                Text("This may be because a blurry image of this IC was captured, if this was the case, then you can re-take an Image of this IC")
                                Button {
                                    showingImageRetakeOption = true
                                } label: {
                                    HStack {
                                        Image(systemName: "camera.fill")
                                        Text("Retake Image")
                                    }
                                }
                                .buttonStyle(SmallAccentButtonStyle())
                            }
                            .frame(width: subGeo.size.width * 0.8, height: subGeo.size.height, alignment: .center)
                            .padding(.horizontal, subGeo.size.width * 0.1)
                        }
                    }
                } else { // Otherwise an error has occured
                    Spacer()
                    ErrorScreen()
                        .padding([.leading, .trailing], 20)
                    Spacer()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
            .background(.backgroundColourVariant)
            .disabled(loadingState != .stopped && !showingImagePreview)
            .overlay {
                Group {
                    if loadingState != .stopped { // Black bacground
                        ZStack {
                            Rectangle()
                                .fill(Color.backgroundColour)
//                            Rectangle()
//                                .fill(.black)
//                                .opacity(0.8)
                        }
                    }
                    
                    if loadingState == .error { // An error has occured
                        VStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(.red)
                                .frame(width: 75, height: 75)
                                .padding(.bottom, 20)
                            Text("An error occured when attempting to get information")
                            HStack {
                                Button { // Close the popover
                                    closingAction()
                                } label: {
                                    Text("Close")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(SmallMonoButtonStyle())
                                Button { // Retry button
                                    Task {
                                        await loadInfo()
                                    }
                                } label: {
                                    Text("Try Again")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(SmallAccentButtonStyle())
                            }
                        }
                        .frame(width: geometry.size.width * 0.75)
                        .padding(.all, 20)
                        .background(RoundedRectangle(cornerRadius: 25)
                            .foregroundStyle(.backgroundColour))
                    } else if loadingState == .loading { // If currently loading, show a loading screen
                        LoadingView(loadingText: .constant("Retrieving information"))
                            .frame(width: geometry.size.width * 0.75, height: geometry.size.height * 0.3)
                            .padding(.all, 20)
                            .background(RoundedRectangle(cornerRadius: 25)
                                .foregroundStyle(.backgroundColour))
                    }
                }
                .transition(.opacity)
            }
            .overlay {
                if showingImagePreview, let sImage = component?.baseInfo.imageInfo.subImage {
                    ZStack {
                        Rectangle()
                            .fill(.black)
                            .opacity(0.8)
                        ZStack {
                            RoundedRectangle(cornerRadius: 25)
                            ZoomImage(image: .constant(sImage))
                                .padding(.all, 10)
                                .clipShape(RoundedRectangle(cornerRadius: 25))
                                
                            
                        }
                        .frame(width: geometry.size.width * 0.8, height: geometry.size.width * 0.8 * (1 / sImage.getAspectRatio()), alignment: .center)
                        .overlay(alignment: .topLeading) {
                            Button {
                                withAnimation {
                                    showingImagePreview = false
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                            }
                            .buttonStyle(SmallAccentButtonStyle())
                            .padding(.all, 20)
                        }
                    }
                }
            }
            .popover(isPresented: $showingImageRetakeOption) {
                CameraView(savePhotoOtherLocation: true, performOnImageTaken: {
                    withAnimation {
                        loadingState = .loading
                    }
                    showingImageRetakeOption = false
                    print("starting await funciton")
                    component = await controller.setNewICImage(component?.baseInfo.id)
                    print("stopping await function")
                    withAnimation {
                        loadingState = .stopped
                    }
                })
            }
        }
        .task {
            if !GlobalStorage.shared.isInPreview { // Only load the info if we are not in preview
                await loadInfo()
            }
        }
    }
    
    /// Get info from octopart API
    func loadInfo(performBinarisation: Bool = false) async {
        if component?.infoState == .unloaded {
            withAnimation {
                loadingState = .loading
            }
            component = await controller.retrieveInformation(component?.baseInfo.id, performBinarisation)
            if component == nil {
                withAnimation {
                    loadingState = .error
                }
            } else {
                withAnimation {
                    loadingState = .stopped
                }
            }
        }
    }
    
    /// Refesh the current component from the controller
    private func refeshInfo() {
        self.component = controller.getICByID(self.component?.baseInfo.id)
    }
}

struct TitleDescription: View { // Component to provide a title and description list element
    @Binding var title: String
    @Binding var description: String
    @State var showingWebView: Bool = false
    var isCheckingForURL: Bool = true // Used to determine if a URL should be highlighted in the list
    
    var body: some View {
        VStack {
            Text(title)
                .bold()
                .font(.title3)
                .frame(maxWidth: .infinity, alignment: .leading)
            if description.starts(with: "http") && isCheckingForURL { // If the description is a URL
                Text(description)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .underline()
                    .foregroundStyle(.link)
                    .popover(isPresented: $showingWebView) {
                        WebSearchView(webPageURL: .constant(description.replacingOccurrences(of: "http:", with: "https:")), isShowingCloseButton: true, closingAction: { showingWebView = false })
                            .padding([.leading, .trailing, .bottom], 10)
                    }
                    .onTapGesture {
                        showingWebView = true
                    }
            } else { // If it is not a URL
                Text(description)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview {
    @State var controller = MultiElementController()
    @State var ic: ICInfo? = tempComponent
    Task {
        await controller.getProperties()
    }
    ic = controller.identifiedICs?.first
    return VStack {
        NavigationStack {
            ICInfoPopover(component: ic, controller: controller, closingAction: { print("hello") })
        }
    }
}
