//
//  GW2onMacApp.swift
//  GW2onMac
//

import SwiftUI
import GW2Kit

@main
struct GW2onMacApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)
    }
}
