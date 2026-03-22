//
//  MkcalsApp.swift
//  MPlate
//

import SwiftUI

@main
struct MkcalsApp: App {
    @StateObject private var toggleManager = ToggleManager()
    @State private var firstSetupComplete: Int64 = 0

    init() {
        do {
            try DatabaseManager.setup()
            print("Database setup successfully")
        } catch {
            print("Error setting up database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if firstSetupComplete == 0 {
                    ContentView()
                        .environmentObject(toggleManager)
                } else {
                    Homepage()
                        .environmentObject(toggleManager)
                }
            }
            .onAppear {
                firstSetupComplete = DatabaseManager.checkFirstSetupComplete()
            }
        }
    }
}
