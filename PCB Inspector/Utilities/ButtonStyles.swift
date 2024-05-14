//
//  InterfaceUtilities.swift
//  PCB Inspector
//
//  Created by Jack Smith on 11/12/2023.
//
//  Provides button styles used throughout the application

import SwiftUI

struct MonoButtonStyle: ButtonStyle { // Button style with grey background
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(.accentColorMono, in: Capsule())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

struct AccentButtonStyle: ButtonStyle { // Button style with accent colour
    var colour: Color = .accent
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(colour, in: Capsule())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

struct RedButtonStyle: ButtonStyle { // Button style with accent colour
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(.red, in: Capsule())
            .opacity(configuration.isPressed ? 0.5 : 1)
            .foregroundStyle(.white)
    }
}

struct SmallAccentButtonStyle: ButtonStyle { // Small button with accent colour
    var colour: Color = .accent
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding([.top, .bottom], 5)
            .padding([.leading, .trailing], 10)
            .background(colour, in: Capsule())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

struct SmallMonoButtonStyle: ButtonStyle { // Small button with accent colour
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding([.top, .bottom], 5)
            .padding([.leading, .trailing], 10)
            .background(.accentColorMono, in: Capsule())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

struct ToggleButtonStyle: ButtonStyle { // Small button with accent colour
    var backgroundColour: Color
    @Binding var isActive: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding([.top, .bottom], 5)
            .padding([.leading, .trailing], 10)
            .bold()
            .background(backgroundColour.opacity(isActive ? 0.4 : 0), in: Capsule())
            .foregroundStyle(backgroundColour)
    }
}

struct SquaredAccentButtonStyle: ButtonStyle { // Button style with accent colour
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(.accent, in: RoundedRectangle(cornerRadius: 15))
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

#Preview {
    VStack {
        Button(action: { print("Pressed") }) {
            Label("Press Me", systemImage: "star")
        }
        .buttonStyle(MonoButtonStyle())
        
        Button(action: { print("Pressed") }) {
            Label("Press Me", systemImage: "star")
        }
        .buttonStyle(AccentButtonStyle())
        
        Button(action: { print("Pressed") }) {
            Label("Press Me", systemImage: "star")
        }
        .buttonStyle(RedButtonStyle())
        
        Button(action: { print("Pressed") }) {
            Label("Press Me", systemImage: "star")
        }
        .buttonStyle(SmallAccentButtonStyle())
        
        Button(action: { print("Pressed") }) {
            Label("Press Me", systemImage: "star")
        }
        .buttonStyle(SmallMonoButtonStyle())
        
        Button(action: { print("Pressed") }) {
            Label("Press Me", systemImage: "star")
        }
        .buttonStyle(ToggleButtonStyle(backgroundColour: .blue, isActive: .constant(true)))
        
        Button(action: { print("Pressed") }) {
            Label("Press Me", systemImage: "star")
        }
        .buttonStyle(SquaredAccentButtonStyle())
    }
    
}
