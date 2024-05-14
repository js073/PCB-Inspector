//
//  GoogleSearchView.swift
//  PCB Inspector
//
//  Created by Jack Smith on 02/02/2024.
//
//  Provides a web view allowing the user to choose the website to use for info

import SwiftUI

struct GoogleSearchView: View {
    @State var searchTerm: String = "" // Terms used for search
    @Binding var componentID: UUID // ID of component
    @State var url: String? = nil // If there is already a URL, display it
    @State private var showingList: Bool = true // Showing list of options
//    @State var results: [(String, String)] = [("a", "https://www.apple.com"), ("C", "d")]
    @State private var results: [(String, String)] = [] // Results of search
    @State private var error: Bool = false // If an error occured
    @State private var showingOverlay: Bool = false // If showing selection overlay
    @State private var overlayURL: String = "" // URL for overlay to display
    @State private var loading: Bool = true // If the contents is loading
    @State fileprivate var isConfirmingErase: Bool = false // If the confirmation pop-up is showing
    var getResults: (UUID?) async -> ((String, [(String, String)])?) // Get results for search of component
    var closeView: () -> () // Close view
    var selectURL: (String?) -> () // Set the URL as seldcted
    
    var body: some View {
        GeometryReader { geo in
            VStack {
                HStack {
                    Button { // Close view button
                        isConfirmingErase = true
                    } label: {
                        Text("Clear")
                    }
                    .confirmationDialog("Are you sure you want to remove this page as the saved one?", isPresented: $isConfirmingErase, titleVisibility: .visible) {
                        Button(role: .destructive) {
                            closeView()
                        } label: {
                            Text("Delete")
                        }
                    }
                    .buttonStyle(SmallAccentButtonStyle())
                    .padding(.bottom, 5)
                }
                if loading { // Loading screen
                    LoadingView(loadingText: .constant("Getting components"))
                } else {
                    if error { // Error screen
                        ErrorScreen()
                        Button {
                            Task {
                                await getInfo()
                            }
                        } label: {
                            Text("Retry")
                                .bold()
                        }
                        .buttonStyle(AccentButtonStyle(colour: .red))
                        .padding(.top, 20)
                        .onAppear {
                            print("WEB : An error occured during loading")
                        }
                    } else {
                        if let url { // If the URL exists, then show the contents
                            WebSearchView(webPageURL: .constant(url))
                                .padding([.leading, .trailing], 20)
                        } else {
                            if !results.isEmpty { // If there are results
                                VStack {
                                    List { // Show list of results and URLs
                                        Text("Search results for: \(searchTerm)")
                                            .font(.title2)
                                            .bold()
                                        ForEach($results, id: \.0) { item in
                                            HStack {
                                                TitleDescription(title: item.0, description: item.1, isCheckingForURL: false)
                                                Spacer()
                                                Image(systemName: "chevron.right.circle")
                                                    .font(.title2)
                                                    .foregroundStyle(.accent)
                                            }
                                            .contentShape(Rectangle())
                                            .onTapGesture { // Open a preview of the page on tap
                                                overlayURL = item.wrappedValue.1
                                                withAnimation {
                                                    showingOverlay = true
                                                }
                                            }
                                        }
                                    }
//                                    .border(.red)
                                }
                                .overlay { // Preview overlay
                                    if showingOverlay {
                                        WebPageSelectionView(url: $overlayURL, closingAction: { withAnimation { showingOverlay = false }}, selectingAction: { withAnimation { url = overlayURL; selectURL(url) }})
                                            .transition(.move(edge: .trailing))
                                            .background {
                                                Rectangle()
                                                    .foregroundStyle(.backgroundColourVariant)
                                            }
                                    }
                                }
                                .transition(.opacity)
                            } else { // No results, error screen
                                ErrorScreen()
                                Button {
                                    Task {
                                        await getInfo()
                                    }
                                } label: {
                                    Text("Retry")
                                        .bold()
                                }
                                .buttonStyle(AccentButtonStyle(colour: .red))
                                .padding(.top, 20)
                                .onAppear {
                                    print("WEB : No results ")
                                }
                            }
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background {
                Rectangle()
                    .fill(.backgroundColourVariant)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
            }
            .task {
                await getInfo()
            }
        }
    }
    
    private func getInfo() async { // Gets the info on page load or retry
        loading = true
        if url == nil {
            if let searchResults = await getResults(componentID) {
                results = searchResults.1
                searchTerm = searchResults.0
            } else {
                error = true
            }
        }
        loading = false
    }
}

/// Shows a preview of the given page and allows the user to choose the page as the one for this component
struct WebPageSelectionView: View {
    @Binding var url: String // URL
    var closingAction: () -> () // Close the preview
    var selectingAction: () -> () // Choose this URL as the selected one
    
    var body: some View {
        VStack {
            HStack {
                Button { // Close button
                    closingAction()
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(SmallAccentButtonStyle())
                Spacer()
                Button { // Select button
                    selectingAction()
                } label: {
                    Text("Select this Page")
                }
                .buttonStyle(SmallAccentButtonStyle())
            }
            WebSearchView(webPageURL: $url) // Web view 
        }
        .padding([.leading, .trailing], 20)
        .background {
            Rectangle()
                .fill(.backgroundColourVariant)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

#Preview {
    let controller = MultiElementController()
    
    return GoogleSearchView(componentID: .constant(UUID()), url: nil, getResults: controller.performGoogleSearch, closeView: { print("hello") }, selectURL: { s in print(s ?? "none") })
}
