//
//  PCB_InspectorApp.swift
//  PCB Inspector
//
//  Created by Jack Smith on 21/11/2023.
//

import SwiftUI
import SwiftData

@main
struct PCB_InspectorApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            IdentifiedPCBStorage.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            HomeViewMulti()
        }
        .modelContainer(sharedModelContainer)
    }
}
