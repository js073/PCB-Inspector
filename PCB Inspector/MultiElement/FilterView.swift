//
//  FilterView.swift
//  PCB Inspector
//
//  Created by Jack Smith on 22/12/2023.
//
//  Provides the filter sub-view

import SwiftUI

struct FilterView: View {
    @Binding var controller: MultiElementController?
    @State private var selectedToggles: [Bool] = Array(repeating: false, count: ComponentType.allCases.count) // Current filter toggles, with 0 being the all toggle, and the others being the individual class toggles
    @State private var prevToggles: [Bool] = Array(repeating: false, count: ComponentType.allCases.count) // Previous toggle state to find out what has changed
    let componentTypes = ComponentType.allCases.filter { $0 != .other } // All possible component types, apart from other
    
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundStyle(.backgroundColourVariant)
            VStack {
                List {
                    Section { // All button section
                        CustomButton(textLabel: .constant("All"), colour: .constant(.green), isSelected: $selectedToggles[0])
                    }
                    .listRowBackground(Color.backgroundColour)
                    Section { // Individual type section
                        ForEach (Array(zip(componentTypes.indices, componentTypes)), id: \.0) { (i, type) in
                            CustomButton(textLabel: .constant(componentDescriptions[type] ?? "nil"), colour: .constant(componentColours[type] ?? .pink), isSelected: $selectedToggles[i+1])
                        }
                        .listRowBackground(Color.backgroundColour)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .onChange(of: selectedToggles) { // A toggle has been changed
                var currentFilterTypes: [ComponentType] = []
                guard selectedToggles != prevToggles else { return } // Only execute if current and previous are different
                guard let changedIndex = zip(selectedToggles, prevToggles).map({ (a, b) in
                    a == b
                }).firstIndex(of: false) else { return } // Find the element that has changed from previous
                if changedIndex == 0, selectedToggles[0] { // If all has been toggled on
                    for i in 1..<selectedToggles.count { // Set all other toggles to false
                        selectedToggles[i] = false
                    }
                    currentFilterTypes = componentTypes
                } else {
                    if selectedToggles[0] { // Set the all toggle to false if it was toggled on
                       selectedToggles[0] = false
                    }
                    let togglesTypes = zip(componentTypes, selectedToggles[1..<selectedToggles.count]).filter { $0.1 }.map { $0.0 } // Only include the selected toggles in the toggle list 
                    currentFilterTypes = togglesTypes
                }
                prevToggles = selectedToggles
                if let controller { // Apply the filter to the controller
                    controller.applyFilter(currentFilterTypes)
                }
            }
        }
        .task {
            if let controller {
                setCurrentToggles(controller.currentComponentFilter)
            } else {
                prevToggles[0] = true
                selectedToggles[0] = true
            }
        }
    }
    
    func setCurrentToggles(_ filterTypes: [ComponentType]) { // Sets the current toggles based on the current filters
        var temp = Array(repeating: false, count: componentTypes.count + 1)
        if filterTypes.count == componentTypes.count { // Case where all are selected
            temp[0] = true
        } else {
            for f in filterTypes {
                if let index = componentTypes.firstIndex(of: f) {
                    temp[index + 1] = true
                }
            }
        }
        prevToggles = temp
        selectedToggles = temp
    }
    
}

struct CustomButton: View {
    @Binding var textLabel: String
    @Binding var colour: Color
    @Binding var isSelected: Bool
    
    var body: some View {
        Button {
            isSelected.toggle()
        } label: {
            HStack {
                Text(textLabel)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                } else {
                    Image(systemName: "circle")
                }
            }
        }
        .foregroundStyle(colour)
        .listRowBackground(isSelected ? colour.opacity(0.3) : .backgroundColour)
    }
}

#Preview {
    FilterView(controller: .constant(nil))
}
