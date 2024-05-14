//
//  PreviewImage.swift
//  PCB Inspector
//
//  Created by Jack Smith on 10/12/2023.
//
//  Gives a simple image preview, bounded to the given frame

import SwiftUI

/// Simple image preview, takes an Image type as input
struct PreviewImage: View {
    @Binding var image: Image?
    var body: some View {
        GeometryReader { geometry in
            if let image = image {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
            }
        }
    }
}

/// Simple image preview, takes UIImage type as input 
struct PreviewImageUI: View {
    @Binding var image: UIImage?
    var body: some View {
        GeometryReader { geometry in
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
            }
        }
    }
}

#Preview {
    PreviewImageUI(image: .constant(UIImage(named: "PCB Placeholder")))
}
