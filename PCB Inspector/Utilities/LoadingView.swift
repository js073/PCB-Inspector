//
//  LoadingView.swift
//  PCB Inspector
//
//  Created by Jack Smith on 21/12/2023.
//
//  Provides a simple loading view with some specified descriptor text

import SwiftUI

struct LoadingView: View {
    @Binding var loadingText: String
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Text(loadingText)
                    .multilineTextAlignment(.center)
                    .font(.title)
                    .bold()
                    .padding(.bottom, 50)
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.accent)
                    .scaleEffect(2)
                    .scaledToFit()
                    .frame(width: geometry.size.width)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
    }
}

#Preview {
    LoadingView(loadingText: .constant("Loading"))
}
