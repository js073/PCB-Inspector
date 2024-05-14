//
//  LibraryController.swift
//  PCB Inspector
//
//  Created by Jack Smith on 11/12/2023.
//
//  Provides the logic for a user selecting a photo from their library

import Foundation
import _PhotosUI_SwiftUI
import SwiftUI

@Observable class LibraryController {
    var selectedPhoto: Image? // Photo selected by the user
    var selectedPhotoSuccess: Bool = true // User has selected photo successfully
    var imageLoading: Bool = false // Loading image from the library
    var imageSize: CGSize? // Size of the image 
    var imageBlur: Int? // Bluriness rating of the image
    
    var chosenPickerPhoto: PhotosPickerItem? = nil {
        didSet {
            if let chosenPickerPhoto {
                imageLoading = true
                loadPhoto(from: chosenPickerPhoto)
                pubLogger.debug("chosen photo")
                imageLoading = false
            }
        }
    }
    
    func loadPhoto(from imageSelection: PhotosPickerItem) { // Loads the selected photo
        imageSelection.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                guard imageSelection == self.chosenPickerPhoto else { return }
                switch result {
                case .success(let data?):
                    pubLogger.debug("success")
                    if let uiImage = UIImage(data: data) {
                        self.selectedPhoto = Image(uiImage: uiImage)
                        self.imageSize = uiImage.size
                        GlobalStorage.shared.takenImage = uiImage.cgImage
                        GlobalStorage.shared.imageOrientation = uiImage.imageOrientation.toCGOrientation()
                        if let cgImage = uiImage.cgImage {
                            self.imageBlur = ImageOperations.determineImageBluriness(cgImage)
                        }
                        self.selectedPhotoSuccess = true
                    }
                case .success(nil): self.selectedPhotoSuccess = false
                    pubLogger.debug("success but no image")
                case .failure(_): self.selectedPhotoSuccess = false
                    pubLogger.debug("no image")
                }
                
            }
        }
    }

}

extension View { // Extension to allow the conversion between Image and CGImage
    @MainActor func toCG() -> CGImage? {
        let renderer = ImageRenderer(content: self)
        
        return renderer.cgImage
    }
}
