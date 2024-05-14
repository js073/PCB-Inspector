//
//  DataHandler.swift
//  PCB Inspector
//
//  Created by Jack Smith on 04/01/2024.
//
//  Contains all logic for using SwiftData for persistent storage

import Foundation
import SwiftData
import UIKit

@Model
class IdentifiedPCBStorage { // Model stored in data to represent the identified PCBs
    @Attribute(.unique) var boardName: String // Name given to the board by the user, must be unique
    @Attribute(.externalStorage) var boardImage: Data // Image of the board as PNG data
    var identifiedComponents: [ComponentInfo] // Component list
    var identifiedICs: [ICInfo] // IC list
    var creationDate: Date // Creation date of the PCB
    
    init(boardName: String, boardImage: Data, identifiedComponents: [ComponentInfo], identifiedICs: [ICInfo], creationDate: Date = .now) { // Initialisation function, with the creation date having a default value of the current date 
        self.boardName = boardName
        self.boardImage = boardImage
        self.identifiedComponents = identifiedComponents
        self.identifiedICs = identifiedICs
        self.creationDate = creationDate
    }
}


class DataHandler { // Class to handle interfacing with data model
    static var handlerShared = DataHandler() // Global model of the data handler to be shared
    private var dataContext: ModelContext?
    var tmpURL: String = "none"
    
    init() { // Initialisation function to get the model
        Task { @MainActor in
            let container = try ModelContainer(for: IdentifiedPCBStorage.self)
            self.dataContext = container.mainContext
        }
    }
    
    func getSavedNames() -> [String]? { // Gets names of all current saved models, returns nil on failure
        if let results = getAllSavedPCBs() {
            return results.map { $0.boardName }
        }
        return nil
    }
    
    func getAllSavedPCBs() -> [IdentifiedPCBStorage]? { // Get all stored PCBs
        do {
            if let dataContext {
                var savedNamesDescriptor = FetchDescriptor<IdentifiedPCBStorage>()
                savedNamesDescriptor.includePendingChanges = true
                
                return try dataContext.fetch(savedNamesDescriptor) // Get all stored identified PCBs
            }
        } catch {
            return nil
        }
        return nil
    }
    
    func saveCurrentPCB(_ item: IdentifiedPCBStorage) -> Bool { // Save to the current model, returns boolean for success
        if let dataContext {
            pubLogger.warning("instered")
            dataContext.insert(item)
            do { try dataContext.save() } catch { return false }
            pubLogger.warning("saved")
            return true
        }
        return false
    }
    
    func deletePCB(_ name: String) -> Bool { // Deletes the item with the passed name, returns boolean for success
        do {
            if let dataContext {
                let descriptor = FetchDescriptor<IdentifiedPCBStorage>(predicate: #Predicate { $0.boardName == name })
                let results = try dataContext.fetch(descriptor)
                guard !results.isEmpty else { return false } // If there are none with the given name
                dataContext.delete(results.first!)
                return true
            }
            return false
        } catch {
            return false
        }
    }
    
    func deleteAll() {
        do {
            if let dataContext {
                try dataContext.delete(model: IdentifiedPCBStorage.self)
            }
        } catch {
            pubLogger.debug("An error occured")
        }
    }
}
