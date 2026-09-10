//
//  AgilePriceWheelApp.swift
//  AgilePriceWheel
//
//  Created by Richard Hine on 10/09/2026.
//

import SwiftUI
import CoreData

@main
struct AgilePriceWheelApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
