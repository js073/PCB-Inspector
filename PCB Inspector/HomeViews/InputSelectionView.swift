//
//  InputSelectionView.swift
//  PCB Inspector
//
//  Created by Jack Smith on 08/01/2024.
//
//  Allows the user to choose their input selection method

import SwiftUI

struct InputSelectionView: View {
    var viewStyle: SceneViews // Used to determine if the open saved option should be shown for multi-element views
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                ScrollView {
                    CompactNavigationCard(icon: Image(systemName: "camera"), buttonText: "Camera", descriptionText: "Take an image using the device camera", nextView: CameraView())
                        .frame(height: 175)
                    CompactNavigationCard(icon: Image(systemName: "photo.on.rectangle"), buttonText: "Library", descriptionText: "Open an existing image from the device library", nextView: LibraryView())
                        .frame(height: 175)
                    if viewStyle == .multiView { // Multi selection view has the extra option of opening a pre-identified PCB
                        CompactNavigationCard(icon: Image(systemName: "list.bullet.rectangle"), buttonText: "Existing", descriptionText: "Open a saved identified PCB", nextView: OpenExistingView())
                            .frame(height: 175)
                        CompactNavigationCard(icon: Image(systemName: "camera.viewfinder"), buttonText: "Live", descriptionText: "Perform live view of PCB", nextView: LiveViewView())
                            .frame(height: 175)
                    }
                }
            }
        }
    }
}

#Preview {
    InputSelectionView(viewStyle: .multiView)
}
