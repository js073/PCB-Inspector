//
//  LibraryView.swift
//  PCB Inspector
//
//  Created by Jack Smith on 11/12/2023.
//
//  View showed when the user chooses to select an image from their photo library

import SwiftUI
import _PhotosUI_SwiftUI

struct LibraryView: View {
    @State var libController = LibraryController()
    let navTitle = "Select Existing"
    
    var body: some View {
        if libController.selectedPhoto == nil && libController.imageLoading == false && libController.selectedPhotoSuccess {
            PhotosPicker(selection: $libController.chosenPickerPhoto, matching: .images) {
                Text("Select a photo from library")
            }
            .buttonStyle(AccentButtonStyle())
            .navigationTitle(navTitle)
        } else if libController.imageLoading && libController.selectedPhotoSuccess {
            LoadingView(loadingText: .constant("Loading Photo"))
        } else if !libController.selectedPhotoSuccess {
            ErrorScreen()
        } else {
            VStack {
                if UserDefaults.standard.bool(forKey: "developerModeToggle"), let imageSize = libController.imageSize {
                    Text("\(imageSize.width) x \(imageSize.height)")
                }
                if let blur = libController.imageBlur {
                    BlurinessView(blurRating: .constant(blur))
                }
                PreviewImage(image: $libController.selectedPhoto)
                HStack {
                    Button {
                        libController.selectedPhoto = nil
                    } label: {
                        Text("Choose new photo")
                    }
                    .buttonStyle(MonoButtonStyle())
                    NavigationLink {
                        switch GlobalStorage.shared.nextScene {
                        case .singleView: SingleElementView()
                        case .multiView: MultiElementView()
                        default: Text("This is awkward")
                        }
                    } label: {
                        Text("Use this photo")
                    }
                    .buttonStyle(AccentButtonStyle())
                }
                
            }
            .navigationTitle(navTitle)
        }
    }
}

#Preview {
    LibraryView()
}
