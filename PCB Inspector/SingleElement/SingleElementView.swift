//
//  SingleElementView.swift
//  PCB Inspector
//
//  Created by Jack Smith on 23/11/2023.
//
//  View displayed when the user chooses to inspect a single element

import SwiftUI

struct SingleElementView: View {
    @State fileprivate var controller = SingleElementController()
    @State fileprivate var componentURL: String?
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                PreviewImage(image: $controller.elementImage) // Image of component
                    .padding(.all, 20)
                    .background {
                        RoundedRectangle(cornerRadius: 15)
                            .foregroundStyle(.backgroundColourVariant)
                    }
                    .frame(maxHeight: geometry.size.height * 0.25, alignment: .center)
                    .padding(.all, 20)
                switch controller.loadingProgress { // Show different view based on the loading progress
                case .stopped: // Loading completed, show necessary information
                    switch controller.icInfoState { // Shows different information based on the state of the info identification process
                    case .unloaded: // Show the loading view
                        LoadingView(loadingText: .constant("Retrieving IC Info"))
                    case .loaded: // Show component information
                        List {
                            ForEach(controller.identifiedInformation.sorted(by: { a, b in return false}), id: \.key) { item in
                                TitleDescription(title: .constant(item.key), description: .constant(item.value))
                            }
                            .listRowBackground(Color.backgroundColourVariant)
                        }
                        .scrollContentBackground(.hidden)
                    case .notAvaliable: // Show the RAW text if no info could be identified
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
                        
                        Button { // Button to perform Google search option
                            controller.icInfoState = .webLoaded
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
                        
                        List { // List view of the RAW identified markings
                            Section {
                                ForEach((controller.extractedText ?? ["tmp"]).sorted(by: { a, b in return false }), id: \.self) { item in
                                    HStack {
                                        Text(item)
                                        Spacer()
                                        Button { // Copy to clipboard button
                                            let clipboard = UIPasteboard.general
                                            clipboard.string = item
                                        } label: {
                                            HStack {
                                                Text("Copy")
                                                Image(systemName: "doc.on.doc")
                                            }
                                        }
                                        .buttonStyle(SmallAccentButtonStyle())
                                    }
                                }
                                .listRowBackground(Color.backgroundColourVariant)
                            } header: {
                                Text("Identified Markings")
                            }
                        }
                        .scrollContentBackground(.hidden)
                        
                        
                    case .webLoaded: // Using the websearch view, show th eweb view
                        GoogleSearchView(componentID: .constant(UUID()), getResults: controller.performGoogleSearch, closeView: { controller.icInfoState = .notAvaliable }, selectURL: { _ in () })
                        
                    case .noText: // Show error if no text could be identified 
                        Image(systemName: "exclamationmark.triangle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.red)
                            .frame(maxHeight: geometry.size.height * 0.1)
                        Spacer()
                            .frame(height: 25)
                        Text("No be identified on the component")
                            .font(.title)
                            .bold()
                            .padding([.leading, .trailing], 20)
                    }
                case .error: // Error has occured
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.red)
                        .frame(width: 75, height: 75)
                        .padding(.bottom, 20)
                    Text("An error occured when attempting to get information")
                    HStack {
                        Button { // Retry button
                            Task {
                                await controller.getInformation()
                            }
                        } label: {
                            Text("Try Again")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SmallAccentButtonStyle())
                    }
                case .loading: // Currently loading option 
                    LoadingView(loadingText: .constant("Getting information about this component"))
                }
                if GlobalStorage.shared.isInPreview { // Button to force call when using the simulator
                    Button {
                        Task {
                            await controller.getInformation()
                        }
                    } label: {
                        Text("Get information")
                    }
                }
            }.navigationTitle("Single Element")
                .task {
                    await controller.getInfoFromText()
                    #if targetEnvironment(simulator) // Don't allow auto-run in simulator, to prevent unecessary calls when coding
//                    controller.icInfoState = .notAvaliable
                    await controller.getInformation()
                    #else
                    await controller.getInformation()
                    #endif
                }
        }
    }
}

#Preview {
    SingleElementView()
}
