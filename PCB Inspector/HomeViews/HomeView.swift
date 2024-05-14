//
//  ContentView.swift
//  PCB Inspector
//
//  Created by Jack Smith on 21/11/2023.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @State var viewPath: NavigationPath = NavigationPath()
    @State var devMode: Bool = false
    
    var body: some View {
        NavigationStack() {
            GeometryReader { homeGeo in
                VStack {
                    NavigationCard(icon: Image(decorative: "MultiElementIcon"), buttonText: "Multi Element", descriptionText: "Take a picture of the whole board and identify all components on it", nextView: InputSelectionView(viewStyle: .multiView).onAppear { GlobalStorage.shared.nextScene = .multiView })
            
                    NavigationCard(icon: Image(decorative: "SingleElementIcon"), buttonText: "Single Element", descriptionText: "Take a picture of a single component and identify it", nextView: InputSelectionView(viewStyle: .singleView).onAppear { GlobalStorage.shared.nextScene = .singleView })
//                    if (devMode) {
//                        NavigationLink {
//                            TestViewSelector()
//                        } label: {
//                            Text("Test Views")
//                        }
//                        .buttonStyle(AccentButtonStyle())
//                    }
                }
                .frame(width: homeGeo.size.width, height: homeGeo.size.height, alignment: .center)
                .task {
                    GlobalStorage.shared.identifiedComponents = nil
                    GlobalStorage.shared.identifiedICs = nil
                    GlobalStorage.shared.takenImage = nil
                    do {
                        print(try FileManager.default.contentsOfDirectory(atPath: FileManager.default.currentDirectoryPath))
                    } catch {
                        print("oh no")
                    }
                }
                .onAppear {
                    devMode = UserDefaults.standard.bool(forKey: "developerModeToggle")
                }
                .navigationTitle("PCB Inspector")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
        }
    }
    
    fileprivate func goToHome() {
        print(viewPath)
        viewPath = NavigationPath()
        print(viewPath)
    }
}

#Preview {
    HomeView()
}
