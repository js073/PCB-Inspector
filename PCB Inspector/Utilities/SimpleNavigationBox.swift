//
//  ExpandingBox.swift
//  PCB Inspector
//
//  Created by Jack Smith on 16/02/2024.
//

import SwiftUI

struct SimpleNavigationBox<Content: View>: View {
    var titleText: String // Text to show in closed view
    var nextView: Content
    
    var body: some View {
        GeometryReader { cardGeo in
            NavigationLink(destination: nextView) {
                HStack {
                    Text(titleText)
                        .bold()
                    Spacer()
                        .border(.red)
                    Image(systemName: "chevron.right")
                }
                .contentShape(Rectangle())
            }
            
            .buttonStyle(.plain)
            .padding([.top, .leading, .trailing, .bottom], 20)
            .frame(width: cardGeo.size.width * 0.9, alignment: .center)
            .background {
                RoundedRectangle(cornerRadius: 25)
                    .foregroundStyle(.backgroundColourVariant)
            }
            .frame(width: cardGeo.size.width, alignment: .center)
            .frame(maxHeight: 50)
        }
    }
}

#Preview {
    NavigationStack {
        SimpleNavigationBox(titleText: "title", nextView: Text("tmp"))
    }
}
