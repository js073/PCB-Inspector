//
//  Structures.swift
//  PCB Inspector
//
//  Created by Jack Smith on 30/01/2024.
//
//  Contains various structures used in various sections of the application 

import Foundation
import SwiftUI
import OrderedCollections

/// Structure to contain information about components
struct ComponentInfo: Identifiable, Codable {
    var id = UUID()
    var type: ComponentType // The type of the component
    var imageInfo: ComponentImageInfo //
    var internalName: String // A name representation for the component
}

/// Information about the image location and size that the sub-image of this component contains
struct ComponentImageInfo {
    var subImage: UIImage? // A cropped image of the current component
    var imageLocation: (x: CGFloat, y: CGFloat) // The location of the top left of the component in the image
    var imageSize: (x: CGFloat, y: CGFloat) // The size of the component on the image
    
    enum CodingKeys: String, CodingKey { // Used for serialising data
        case subImage
        case imageLocationX
        case imageLocationY
        case imageSizeX
        case imageSizeY
    }
}

/// Provides specific info for identified IC components
struct ICInfo: Codable {
    var baseInfo: ComponentInfo // Base info for this component, an instance of the ComponentInfo class
    var informationDescription: OrderedDictionary<String, String> // A dictionary containing component parameters and their values, i.e. ("Manufacturer": "ABC")
    var rawIdentifiedText: [String]? // The raw text that has been identified on the IC
    var infoState: ICInfoState = .unloaded // State of info being loaded for this component
    var note: String? // Note that the user has added about this IC
    var informationURL: String? // The URL that the user has selected to contain show informatio about this IC from
}

/// Extension to component image info to allow for custom data deserialisation
extension ComponentImageInfo: Decodable {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let rawImage = try values.decode(Data.self, forKey: .subImage) // Get the RAW data for the image
        if rawImage.isEmpty {
            subImage = nil
        } else { // Convert RAW data to UIImage
            subImage = UIImage(data: rawImage)
        }
        // Decode other values in the normal method
        let locationX = try values.decode(CGFloat.self, forKey: .imageLocationX)
        let locationY = try values.decode(CGFloat.self, forKey: .imageLocationY)
        let sizeX = try values.decode(CGFloat.self, forKey: .imageSizeX)
        let sizeY = try values.decode(CGFloat.self, forKey: .imageSizeY)
        imageLocation = (locationX, locationY)
        imageSize = (sizeX, sizeY)
    }
}

/// Extension to component image info to allow for custom data serialisation
extension ComponentImageInfo: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let imgData = if let subImage {
            subImage.pngData() // Get the raw data if there is an image
        } else {
            Data.init() // Get an empty data type
        }
        // Encode the values as normal
        try container.encode(imgData, forKey: .subImage)
        try container.encode(imageLocation.x, forKey: .imageLocationX)
        try container.encode(imageLocation.y, forKey: .imageLocationY)
        try container.encode(imageSize.x, forKey: .imageSizeX)
        try container.encode(imageSize.y, forKey: .imageSizeY)
    }
}
