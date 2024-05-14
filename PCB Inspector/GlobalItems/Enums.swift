//
//  Enums.swift
//  PCB Inspector
//
//  Created by Jack Smith on 30/01/2024.
//
//  File containing definitions for various Enums used throughout the application 

import Foundation

/// Enum storing the different types of identified component
enum ComponentType: CaseIterable, Codable {
    case ic // Integrated circuit
    case cap // Capacitor
    case res // Resistor
    case other // Other
}


enum ICInfoState: Codable { // Enum object to represent the state of info about an identified IC
    case unloaded // Info has not yet been attempted to be extracted
    case loaded // Info has been identified and loaded
    case notAvaliable // Info was attempted to be loaded, but was not avaliable
    case webLoaded // Info has been selected from the web
    case noText // No text was identified on the IC
}

enum LoadingProgress { // ENUM used to show necessary information when loading of information is occuring
    case stopped // Loading has stopped
    case error // Error occured
    case loading // Loading in process
}

enum SceneViews { // Custom enum object to determine the next view to navigate to
    case singleView // View for a single component inspection
    case multiView // View for multiple element inspection
    case notSet // Error case
}

/// Custom enum used to create an either type
enum Either<A, B> {
    case Left(A)
    case Right(B)
    
    // Accessor function for the left object, returned as optional
    func left() -> A? {
        switch self {
        case .Left(let a):
            return a
        case .Right(_):
            return nil
        }
    }
    
    // Accessor function for the right object, returned as optional
    func right() -> B? {
        switch self {
        case .Left(_):
            return nil
        case .Right(let b):
            return b
        }
    }
}
