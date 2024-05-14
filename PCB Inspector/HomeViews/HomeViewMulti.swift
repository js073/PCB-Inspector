//
//  HomeViewMulti.swift
//  PCB Inspector
//
//  Created by Jack Smith on 16/02/2024.
//
//  New home view used for the multi-element view only 

import SwiftUI

struct HomeViewMulti: View {
    @State var devMode: Bool = false
    let titleText = "PCB Inspector Tips"
    let bodyText = "Welcome to PCB Inspector. \n To start, first select either the Camera or Library mode to open a photo, or open a previously saved PCB. "
    
    var body: some View {
        NavigationStack() {
            GeometryReader { homeGeo in
                VStack {

//                        .font(.body)
//                    SimpleNavigationBox(titleText: titleText, nextView: InformationPage())
//                        .frame(maxHeight: 50)
//                        .padding([.top], 20)
//                    Divider()
//                        .padding([.top], 10)
//                        .padding(.bottom, 5)
                    InputSelectionView(viewStyle: .multiView)
                }
                .overlay(alignment: .top) {
//                    if devMode {
//                        NavigationLink {
//                            TestViewSelector()
//                        } label: {
//                            Text("Test Views")
//                        }
//                        .buttonStyle(AccentButtonStyle(colour: .red))
//                    }
                }
            }
            .task {
                // Set global values
                GlobalStorage.shared.nextScene = .multiView
                GlobalStorage.shared.identifiedComponents = nil
                GlobalStorage.shared.identifiedICs = nil
                GlobalStorage.shared.takenImage = nil
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
                
//                ToolbarItem(placement: .principal) {
//                    HStack {
//                        Image("Logo - SVG")
//                            .resizable()
//                            .scaledToFit()
//                        //                        .ignoresSafeArea(false)
//                        //                        .frame(maxWidth: homeGeo.size.width * 0.8)
//                            .frame(height: 75)
//                            .padding(.top, 50)
////                            .border(.red)
//                        Spacer()
//                    }
//                }
            }
        }
    }
}

#Preview {
    HomeViewMulti()
}
