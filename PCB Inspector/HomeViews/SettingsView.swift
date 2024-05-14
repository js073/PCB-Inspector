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
    @State fileprivate var colourSchemeSelection: ColourScheme = .defaultScheme
    @State fileprivate var originalColourScheme: ColourScheme = .defaultScheme
    @State fileprivate var isConfirmingErase: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Form {
//                    Picker("Colour Scheme", selection: $colourSchemeSelection) {
//                        Text("Default").tag(ColourScheme.defaultScheme)
//                        Text("Light").tag(ColourScheme.lightScheme)
//                        Text("Dark").tag(ColourScheme.darkScheme)
//                    }
                    Section {
                        Toggle("Developer Mode", isOn: $developerModeToggle)
                        Button {
                            isConfirmingErase = true
                        } label: {
                            Text("Reset App")
                        }
                        .confirmationDialog("Are you sure you want to delete all information?", isPresented: $isConfirmingErase, titleVisibility: .visible) {
                            Button(role: .destructive) {
                                DataHandler.handlerShared.deleteAll()
                                saveSettings(false, ColourScheme.defaultScheme.rawValue)
                            } label: {
                                Text("Delete")
                            }
                        }
                    } header: {
                        Text("Developer Options")
                    } footer: {
                        Text("Developer Mode - Allows access to a testing view as well as disable all calls to the API. For testing purposes only. \n Reset App - Will erase all stored model and reset settings")
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
                    .opacity(originalDeveloperMode == developerModeToggle && originalColourScheme == colourSchemeSelection ? 0.5 : 1)
                    .disabled(originalDeveloperMode == developerModeToggle && originalColourScheme == colourSchemeSelection)
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
    }
    
    /// Save the current settings to the app sotrage with the specified values
    fileprivate func saveSettings(_ developerMode: Bool, _ colourScheme: String) {
        UserDefaults.standard.setValue(developerMode, forKey: "developerModeToggle")
        originalDeveloperMode = developerMode
        developerModeToggle = developerMode
        UserDefaults.standard.setValue(colourScheme, forKey: "colourScheme")
        originalColourScheme = ColourScheme(rawValue: colourScheme) ?? .defaultScheme
        colourSchemeSelection = ColourScheme(rawValue: colourScheme) ?? .defaultScheme
    }
    
    /// Convenience wrapper, saves settings with the current values
    fileprivate func saveSettings() {
        saveSettings(developerModeToggle, colourSchemeSelection.rawValue)
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
