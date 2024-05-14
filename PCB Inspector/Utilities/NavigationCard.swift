//
//  NavigationCard.swift
//  PCB Inspector
//
//  Created by Jack Smith on 08/01/2024.
//
//  Card-style navigation object

import SwiftUI

struct NavigationCard<Content: View>: View {
    var icon: Image? // Image to show in card
    var buttonText: String // Text to show in button
    var descriptionText: String // Description of action to show between image and button
    var nextView: Content // Next view to navigate to
    
    var body: some View {
        GeometryReader { cardGeo in
            VStack {
                if let icon { // Icon used in the navigation card
                    icon
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 50)
                        .padding([.bottom], 10)
                        .padding([.leading, .trailing, .top], 20)
                }
                Text(descriptionText) // Main description of the navigation
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(icon == nil ? [.bottom] : [.top, .bottom], 10)
                    .padding(icon == nil ? [.leading, .trailing, .top] : [.leading, .trailing], 20)
                NavigationLink(destination: nextView) { // Link to the specified next view
                    Text(buttonText)
                        .bold()
                        .frame(width: cardGeo.size.width * 0.7)
                }
                .buttonStyle(SquaredAccentButtonStyle())
                .padding([.top], 10)
                .padding([.leading, .trailing, .bottom], 20)
            }
            .frame(width: cardGeo.size.width * 0.9, alignment: .center)
            .background { // Used to give a rounded rectangle background 
                RoundedRectangle(cornerRadius: 25)
                    .foregroundStyle(.backgroundColourVariant)
            }
            .frame(width: cardGeo.size.width, height: cardGeo.size.height, alignment: .center)
        }
    }
}

#Preview {
    NavigationStack {
        NavigationCard(icon: Image(systemName: "house.circle"), buttonText: "text", descriptionText: "desc", nextView: Text("hello"))
    }
}
