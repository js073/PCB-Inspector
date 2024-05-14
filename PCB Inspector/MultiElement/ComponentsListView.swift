//
//  ComponentsListView.swift
//  PCB Inspector
//
//  Created by Jack Smith on 14/12/2023.
//
//  List view for all components identified

import SwiftUI

struct ComponentsListView: View {
    @Binding var controller: MultiElementController
    @Binding var components: [ComponentInfo] // List of the components in the current view
    @Binding var integratedComponents: [ICInfo] // List of the ICs in the current view
    @State fileprivate var currentIC: ICInfo? // The current IC
    @State fileprivate var infoOpen = false // Is the info pane open
    
    var body: some View {
        GeometryReader { master in
            ZStack {
                Group {
                    List {
                        ForEach($components) { comp in // Loops through each of the identified components
                            ListComponent(component: comp)
                                .contentShape(Rectangle())
                                .gesture(TapGesture(count: 1)
                                    .onEnded { // Opens the info pane when the IC is tapped
                                        if let ic = getICFromUUID(comp.id, integratedComponents) {
                                            currentIC = ic
                                            withAnimation {
                                                infoOpen = true
                                            }
                                        } else {
                                            print("comp ids: \(components.map { $0.id }), ic ids: \(integratedComponents.map { $0.baseInfo.id })")
                                            print("not ic")
                                        }
                                    })
                        }
                        .listRowBackground(Color.backgroundColourVariant)
                    }
                    .scrollContentBackground(.hidden)
                }
                .disabled(infoOpen)
                .popover(isPresented: $infoOpen) { // Info page overlay
                    ICInfoPopover(component: currentIC, controller: controller, closingAction: {
                        withAnimation {
                            infoOpen = false
                        }
                    })
                }
            }
        }
    }
}

struct ListComponent: View { // Individual list components
    @Binding var component: ComponentInfo
    
    var body: some View {
        GeometryReader { g in
            HStack {
                Circle()
                    .fill(componentColours[component.type] ?? .pink)
                    .frame(width: 15)
                Text(component.internalName)
                    .bold()
                Spacer()
                if component.type == .ic { // displays icon if the item is an iC and therefore can be interacted with
                    Image(systemName: "chevron.right.circle")
                        .frame(alignment: .trailing)
                        .foregroundColor(.accentColor)
                        .bold()
                }
            }.frame(width: g.size.width, height: g.size.height, alignment: .leading)
        }
    }
}

#Preview {
    ComponentsListView(controller: .constant(MultiElementController()), components: .constant([ci, ci2]), integratedComponents: .constant([ic]))
}
