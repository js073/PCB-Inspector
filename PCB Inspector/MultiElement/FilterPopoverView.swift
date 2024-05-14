//
//  FilterPopoverView.swift
//  PCB Inspector
//
//  Created by Jack Smith on 14/12/2023.
//
//  Filter popover view, used in the multi-element view

import SwiftUI

struct FilterPopoverView: View {
    let componentTypes = componentDescriptions.map { $0.key }
    @State var componentFilter: [ComponentType : Bool] = [
        .ic : true,
        .cap : true,
        .res : true
    ]
    
    var body: some View {
        VStack {
            ForEach(componentTypes, id: \.self) { type in
                Button {
                    
                } label: {
                    Text(componentDescriptions[type] ?? "none")
                }
                .buttonStyle(ToggleButtonStyle(backgroundColour: componentColours[type] ?? .pink, isActive: .constant(true)))
            }
        }
    }
}

#Preview {
    FilterPopoverView()
}
