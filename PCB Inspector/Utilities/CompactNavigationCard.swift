//
//  VerticalNavigationCard.swift
//  PCB Inspector
//
//  Created by Jack Smith on 16/02/2024.
//
//  Card-styled navigation object in more compact space

import SwiftUI

struct CompactNavigationCard<Content: View>: View {
    var icon: Image? // Image to show in card
    var buttonText: String // Text to show in button
    var descriptionText: String // Description of action to show between image and button
    var nextView: Content // Next view to navigate to
    
    var body: some View {
        GeometryReader { cardGeo in
            VStack {
                HStack {
                    if let icon { // Icon used in the navigation card
                        icon
                            .font(.largeTitle)
                            .padding([.leading, .trailing], 10)
                    }
                    HStack {
                        Spacer()
                        Text(descriptionText) // Main description of the navigation
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding([.leading, .trailing], 10)
                }
                .padding([.top, .bottom, .leading, .trailing], 20)
                NavigationLink(destination: nextView) { // Link to the specified next view
                    Text(buttonText)
                        .bold()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SquaredAccentButtonStyle())
//                .padding([.top], 10)
                .padding([.leading, .trailing, .bottom], 20)
            }
            .frame(width: cardGeo.size.width * 0.9, alignment: .center)
            .background { // Used to give a rounded rectangle background
                RoundedRectangle(cornerRadius: 25)
                    .foregroundStyle(.backgroundColourVariant)
            }
            .contentShape(Rectangle())
            .frame(width: cardGeo.size.width, alignment: .center)
        }
    }
}

#Preview {
    NavigationStack {
        CompactNavigationCard(icon: Image(systemName: "house.circle"), buttonText: "text", descriptionText: "desc", nextView: Text("hello"))
    }
}
