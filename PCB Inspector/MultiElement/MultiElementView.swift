//
//  MultiElementView.swift
//  PCB Inspector
//
//  Created by Jack Smith on 13/12/2023.
//
//  View for multiple element identification

import SwiftUI

struct MultiElementView: View {
    @State fileprivate var controller = MultiElementController() // Controller for view
    @State fileprivate var currentPage = 0 // Determine image view or list view
    @State fileprivate var showingFilterSubpage: Bool = false // Toggle for filter subpage
    @State fileprivate var showingSaveOverlay: Bool = false // Toggle for save overlay
    @State fileprivate var loadingPageText: String = "Identifying Components" // Text to show on the loading page
    @State var isOpeningExisiting: Bool = false // Used to signify if an existing board is being opened
    @State var existingPCB: IdentifiedPCBStorage? = nil // Used to pass the existing board if the view is opened in that mode
    @State fileprivate var isShowingExitConfirmation: Bool = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        GeometryReader { g in
            ZStack {
                VStack {
                    Group {
                        if controller.isSet, let ics = Binding<[ICInfo]>($controller.identifiedICs), let comps = Binding<[ComponentInfo]>($controller.identifiedComponents), let uiImage = Binding<UIImage>($controller.uiImage) {
                            VStack {
                                Picker("Picker title", selection: $currentPage) { // Top picker
                                    Text("Image View").tag(0)
                                    Text("List View").tag(1)
                                }.pickerStyle(.segmented)
                                    .padding()
                                    .zIndex(100)
                                Spacer()
                                if currentPage == 0 { // Image view
                                    ComponentsImageView(controller: $controller, components: comps, integratedComponents: ics, image: uiImage)
                                } else { // lIst view
                                    ComponentsListView(controller: $controller, components: comps, integratedComponents: ics)
                                }
                                Spacer()
                                
                            }
                            .disabled(showingFilterSubpage || showingSaveOverlay) // Disable background if overlays are being shown
                            .navigationTitle(controller.hasSaved ? (controller.savedName ?? "Multi Component") : "Multi Component")
                            .overlay(alignment: .center) { // Darkened page to show for overlays
                                if showingFilterSubpage || showingSaveOverlay {
                                    Rectangle()
                                        .fill(.black)
                                        .opacity(0.5)
                                        .ignoresSafeArea()
                                        .onTapGesture { // If the inactive area is tapped, hide popovers
                                            withAnimation {
                                                showingSaveOverlay = false
                                                showingFilterSubpage = false
                                            }
                                        }
                                }
                            }
                            .overlay(alignment: .bottomLeading) { // Filter view if being shown
                                if showingFilterSubpage {
                                    FilterView(controller: Binding<MultiElementController?>($controller))
                                        .frame(maxWidth: g.size.width * 0.75, maxHeight: g.size.width * 0.75)
                                        .clipShape(RoundedRectangle(cornerRadius: 25))
                                        .padding([.leading, .bottom], 10)
                                        .transition(.offset(x: 0, y: g.size.width))
                                        .zIndex(2)
                                }
                            }
                            .overlay(alignment: .center) {
                                if showingSaveOverlay { // Save PCB overlay if it is being shown
                                    SavingPopover(controller: $controller, closeWindowAction: .constant {
                                        showingSaveOverlay = false
                                    })
                                    .transition(.opacity)
                                    .padding(.all, 20)
                                    .frame(width: g.size.width * 0.9)
                                    .background(.backgroundColourVariant)
                                    .clipShape(RoundedRectangle(cornerRadius: 25))
                                }
                            }
                            HStack { // Bottom control buttons
                                Button { // Filter toggle
                                    withAnimation {
                                        showingFilterSubpage.toggle()
                                    }
                                } label: {
                                    if !showingFilterSubpage {
                                        Text("Filters")
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 25)
                                    } else {
                                        Image(systemName: "xmark")
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 25)
                                    }
                                }
                                .buttonStyle(SmallMonoButtonStyle())
                                Button { // Save button
                                    withAnimation {
                                        showingSaveOverlay.toggle()
                                    }
                                } label: {
                                    if !showingSaveOverlay {
                                        Text("Save")
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 25)
                                    } else {
                                        Image(systemName: "xmark")
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 25)
                                    }
                                }
                                .buttonStyle(SmallAccentButtonStyle())
                                //                            .frame(width: g.size.width * 0.45)
                            }
                            .padding([.top, .bottom], 10)
                            .background {
                                Rectangle()
                                    .fill(.background)
                                    .frame(width: g.size.width)
                            }
                            .frame(width: g.size.width * 0.9)
                        } else if !controller.isError { // Show the loading screen when data is loading
                            LoadingView(loadingText: $loadingPageText)
                        } else { // Show the error screen if the error occurs
                            ErrorScreen()
                        }
                    }
                }
            }
        }
        .task { // Task to be performed before the view is presented
            if !isOpeningExisiting { // New image is being processed
                loadingPageText = "Identifying Components"
                await controller.getProperties() // Process image
            } else { // Exisiting PCB is being loaded
                if let existingPCB { // Exisitng PCB has been successfully passed
                    loadingPageText = "Loading existing"
                    await controller.setPropertiesFromExisting(existingPCB) // Load existing into controller
                } else { // Errror case
                    controller.isError = true
                }
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { // Custom nav bar to allow exit confirmation
                Button {
                    if !controller.hasSaved { // Show confirmation if there has not been a save
                        isShowingExitConfirmation = true
                    } else { // Exit normally if the user has saved
                        dismiss()
                    }
                    print("hello")
                } label: { // Button label
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }
        .confirmationDialog("You have not saved, exiting will delete all unsaved information, are you sure you want to exit?", isPresented: $isShowingExitConfirmation, titleVisibility: .visible) { // Connfirmation dialog for exiting without saving
            Button(role: .destructive) { // Exit button 
                dismiss()
            } label: {
                Text("Exit")
            }
        }
    }
}

#Preview {
    NavigationStack {
        MultiElementView()
    }
}
