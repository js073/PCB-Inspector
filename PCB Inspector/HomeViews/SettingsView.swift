//
//  SettingsView.swift
//  PCB Inspector
//
//  Created by Jack Smith on 22/01/2024.
//
//  A simple settings view to change basic application settings

import SwiftUI

struct SettingsView: View {
    @State fileprivate var developerModeToggle: Bool = false
    @State fileprivate var originalDeveloperMode: Bool = false
    @State fileprivate var searchModeToggle: Bool = false
    @State fileprivate var originalSearchMode: Bool = false
    @State fileprivate var colourSchemeSelection: ColourScheme = .defaultScheme
    @State fileprivate var originalColourScheme: ColourScheme = .defaultScheme
    @State fileprivate var isConfirmingErase: Bool = false
    
    @State fileprivate var showingOctopartSheet: Bool = false
    @State fileprivate var octopartClientID: String = ""
    @State fileprivate var octopartClientSecret: String = ""
    
    @State fileprivate var showingGoogleSheet: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Form {
                    // API option section
                    Section {
                        Toggle("Use API", isOn: $searchModeToggle)
                        
                        // API credential options
                        Group {
                            // Octopart API options
                            Button {
                                showingOctopartSheet.toggle()
                            } label: {
                                LabeledContent("Octopart API Credentials", content: { Image(systemName: "chevron.right") })
                            }
                            .foregroundStyle(.iconColour)
                            .sheet(isPresented: $showingOctopartSheet, content: {
                                OctopartAPIScreen(closingAction: { showingOctopartSheet.toggle() })
                            })
                            
                            // Google API options
                            Button {
                                showingGoogleSheet.toggle()
                            } label: {
                                LabeledContent("Google API Credentials", content: { Image(systemName: "chevron.right") })
                            }
                            .foregroundStyle(.iconColour)
                            .sheet(isPresented: $showingGoogleSheet, content: {
                                GoogleAPIScreen(closingAction: { showingGoogleSheet.toggle() })
                            })
                        }
                        .disabled(!searchModeToggle)
                        .opacity(!searchModeToggle ? 0.5 : 1)
                    } header: {
                        Text("API Options")
                    } footer: {
                        Text("Use API - Determines if the application will use the API to get information.\nCredential Sections - For entry of credentials for the specific APIs. ")
                    }
                    
                    
                    Section {
//                        Toggle("Developer Mode", isOn: $developerModeToggle)
                        Button {
                            isConfirmingErase = true
                        } label: {
                            Text("Reset App")
                        }
                        .confirmationDialog("Are you sure you want to delete all information?", isPresented: $isConfirmingErase, titleVisibility: .visible) {
                            Button(role: .destructive) {
                                DataHandler.handlerShared.deleteAll()
                                saveSettings(false, ColourScheme.defaultScheme.rawValue, true)
                            } label: {
                                Text("Delete")
                            }
                        }
                    } header: {
                        Text("App Reset")
                    } footer: {
                        Text("Will erase all stored model and reset settings")
                    }
                }
                .overlay(alignment: .bottom) { // Save and cancel buttons
                    HStack {
                        Button { // Clear the current selection and reset
                            fetchSettings()
                        } label: {
                            Text("Clear")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SmallMonoButtonStyle())
                        Button { // Save the current options
                            saveSettings()
                        } label: {
                            Text("Save")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SmallAccentButtonStyle())
                    }
                    .padding([.leading, .trailing], 20)
                    .opacity(settingsHasChanges() ? 0.5 : 1)
                    .disabled(settingsHasChanges())
                }
                .task {
                    fetchSettings()
                    print(developerModeToggle, originalDeveloperMode, colourSchemeSelection, originalColourScheme)
                }
            }
        }
    }
    
    /// Get the stored settings from the app storage
    fileprivate func fetchSettings() {
        developerModeToggle = UserDefaults.standard.bool(forKey: "developerModeToggle") ? true : false
        originalDeveloperMode = developerModeToggle
        if let colourSchemeString = UserDefaults.standard.string(forKey: "colourScheme") {
            colourSchemeSelection = ColourScheme(rawValue: colourSchemeString) ?? .defaultScheme
            originalColourScheme = colourSchemeSelection
        }
        
        searchModeToggle = UserDefaults.standard.bool(forKey: "searchModeToggle") ? true : false
        originalSearchMode = searchModeToggle
    }
    
    /// Save the current settings to the app sotrage with the specified values
    fileprivate func saveSettings(_ developerMode: Bool, _ colourScheme: String, _ searchMode: Bool) {
        UserDefaults.standard.setValue(developerMode, forKey: "developerModeToggle")
        originalDeveloperMode = developerMode
        developerModeToggle = developerMode
        UserDefaults.standard.setValue(colourScheme, forKey: "colourScheme")
        originalColourScheme = ColourScheme(rawValue: colourScheme) ?? .defaultScheme
        colourSchemeSelection = ColourScheme(rawValue: colourScheme) ?? .defaultScheme
        UserDefaults.standard.setValue(searchMode, forKey: "searchModeToggle")
        originalSearchMode = searchMode
        searchModeToggle = searchMode
        
    }
    
    /// Convenience wrapper, saves settings with the current values
    fileprivate func saveSettings() {
        saveSettings(developerModeToggle, colourSchemeSelection.rawValue, searchModeToggle)
    }
    
    /// Checks if the user has made any alterations to the settings
    fileprivate func settingsHasChanges() -> Bool {
        return originalDeveloperMode == developerModeToggle && originalColourScheme == colourSchemeSelection && searchModeToggle == originalSearchMode
    }
}

// Used for editing values for Octopart API keys
fileprivate struct OctopartAPIScreen: View {
    @State fileprivate var userID: String = ""
    @State fileprivate var userSecret: String = ""
    var closingAction: () -> ()
    
    var body: some View {
        VStack {
            HStack {
                Button {
                    closingAction()
                } label: {
                    Text("Exit")
                }
                .buttonStyle(SmallMonoButtonStyle())
                Spacer()
                Button { // Save the set values
                    UserDefaults.standard.setValue(userID, forKey: "octopart-user-id")
                    UserDefaults.standard.setValue(userSecret, forKey: "octopart-user-secret")
                    closingAction()
                } label: {
                    Text("Save")
                }
                .buttonStyle(SmallAccentButtonStyle())
            }
            .padding(.all, 20)

            Form { // Text entry section
                Section { // Form for Octopart client id
                    TextField("User ID", text: $userID)
                        .autocorrectionDisabled()
                } header: {
                    Text("Octopart User ID")
                }
                
                Section { // Form input for Octopart client secret
                    TextField("User Secret", text: $userSecret)
                        .autocorrectionDisabled()
                } header: {
                    Text("Octopart User Secret")
                }
            }
        }
        .background(.backgroundColourVariant)
        .task { // Update the values on Shett opening
            userID = UserDefaults.standard.string(forKey: "octopart-user-id") ?? ""
            userSecret = UserDefaults.standard.string(forKey: "octopart-user-secret") ?? ""
        }
    }
}

// Used for editing Google API keys
fileprivate struct GoogleAPIScreen: View {
    @State fileprivate var userID: String = ""
    @State fileprivate var userSecret: String = ""
    var closingAction: () -> ()
    
    var body: some View {
        VStack {
            HStack {
                Button {
                    closingAction()
                } label: {
                    Text("Exit")
                }
                .buttonStyle(SmallMonoButtonStyle())
                Spacer()
                Button { // Save the set values
                    UserDefaults.standard.setValue(userID, forKey: "google-api-key")
                    UserDefaults.standard.setValue(userSecret, forKey: "google-engine-id")
                    closingAction()
                } label: {
                    Text("Save")
                }
                .buttonStyle(SmallAccentButtonStyle())
            }
            .padding(.all, 20)
            Form { // Text entry section
                Section { // Form for Google api key
                    TextField("API Key", text: $userID)
                        .autocorrectionDisabled()
                } header: {
                    Text("Google Custom Search API Key")
                }
                
                Section { // Form input for Google engine ID
                    TextField("Engine ID", text: $userSecret)
                        .autocorrectionDisabled()
                } header: {
                    Text("Google Custom Search Engine ID")
                }
            }
        }
        .background(.backgroundColourVariant)
        .task { // Update the values on Shett opening
            userID = UserDefaults.standard.string(forKey: "google-api-key") ?? ""
            userSecret = UserDefaults.standard.string(forKey: "google-engine-id") ?? ""
        }
    }
}


/// Enum used to denote the current colour scheme options
fileprivate enum ColourScheme: String, Identifiable, CaseIterable {
    case defaultScheme, lightScheme, darkScheme
    var id: Self { self }
}

#Preview {
    SettingsView()
}
