//
//  Constants.swift
//  PCB Inspector
//
//  Created by Jack Smith on 30/01/2024.
//
//  Provides constants and other global declarations used throughout the application

import Foundation
import SwiftUI
import os.log

/// Dictionary relating ComponentType to colour representations
let componentColours: [ComponentType: Color] = [
    .ic: .blue,
    .cap: .orange,
    .res: .red
]

/// Dictionary containing mapping from component type to string representation
let componentDescriptions: [ComponentType: String] = [
    .ic: "Integrated Circuit",
    .cap: "Capacitor",
    .res: "Resistor",
]

// A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
/// 2D array containing a character and other similar looking characters
/// These are characters that the text identification process may confuse with another
let visuallySimilarCharacters: [[Character]] = [
    ["B", "8"],
    ["M", "H", "N"],
    ["D", "0", "O", "Q"],
    ["C", "0", "O"],
    ["7", "Z", "2"],
    ["I", "1", "|"],
    ["S", "5"],
    ["Y", "V", "X", "W"],
]

//{0: 'Capacitor-1', 1: 'Capacitor-2', 2: 'IC', 3: 'Resistor-1'}

let predictionDictionary: [Int : ComponentType] = [ // Dictionary mapping model outputs to ComponentType
    0 : .cap,
    1 : .cap,
    2: .ic,
    3 : .res,
]

// {0: 'Capacitor-N', 1: 'Capacitor-SM', 2: 'IC', 3: 'Resistor-1'}
let smallItemsPredictionDictionary: [Int : ComponentType] = [ // Outputs for "small_items" model
    0 : .cap,
    1 : .res,
]

// {0: 'Capacitor-N', 1: 'IC'}
let largeItemsPredicitionDictionary: [Int : ComponentType] = [ // Outputs for "large_items" model 
    0 : .cap,
    1 : .ic
]


// For testing only
func tempSetComps() {
    let mci = ComponentInfo(type: .ic, imageInfo: ComponentImageInfo(imageLocation: (266, 114), imageSize: (235, 235)), internalName: "IC1")
    let mic = ICInfo(baseInfo: mci, informationDescription: ["Manufacturer": "Broadcom", "Description": "this is a description", "InformationSource": "inf osourv"])
    let mci2 = ComponentInfo(type: .res, imageInfo: ComponentImageInfo(imageLocation: (500, 500), imageSize: (150, 150)), internalName: "RES1")
    GlobalStorage.shared.identifiedComponents = [mci, mci2]
    GlobalStorage.shared.identifiedICs = [mic]
    GlobalStorage.shared.takenImage = UIImage(named: "PCB Placeholder")?.cgImage
    pubLogger.debug("Set temp comp values")
    
}

var pubLogger = Logger()
