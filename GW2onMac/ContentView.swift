//
//  ContentView.swift
//  GW2onMac
//

import SwiftUI
import GW2Kit

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.showsHome {
                HomeView()
            } else {
                SetupWizardView()
            }
        }
        .onAppear { appState.refresh() }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
