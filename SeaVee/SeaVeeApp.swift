//
//  SeaVeeApp.swift
//  SeaVee
//
//  Created by Jessi Draper on 02.12.25.
//

import SwiftUI
import SwiftData

@main
struct SeaVeeApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Cruise.self, CruiseStop.self])
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                CruiseListView()
            }
            .modelContainer(sharedModelContainer)
        }
    }
}
