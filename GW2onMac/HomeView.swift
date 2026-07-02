//
//  HomeView.swift
//  GW2onMac
//

import SwiftUI
import GW2Kit

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var statusMessage = ""
    @State private var isBusy = false
    @State private var launchArguments = GW2Profile.defaultLaunchArguments

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Guild Wars 2")
                    .font(.largeTitle.bold())
                Text("GW2onMac · Apple Silicon")
                    .foregroundStyle(.secondary)
            }

            runtimeActions

            if let version = WineRuntimeInstaller.runtimeVersion() {
                Text("Runtime v\(version.major).\(version.minor).\(version.patch)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Launch arguments")
                    .font(.headline)
                TextField("Optional flags (e.g. -mapLoadinfo)", text: $launchArguments)
                    .textFieldStyle(.roundedBorder)
                Menu("Troubleshooting presets") {
                    ForEach(GW2Profile.troubleshootingFlags, id: \.label) { flag in
                        Button(flag.label) { launchArguments = flag.args }
                    }
                    Button("Clear") { launchArguments = "" }
                }
                .font(.caption)
            }

            HStack {
                Button("Play") { play() }
                    .disabled(isBusy || !appState.isReadyToPlay || appState.isGW2InstallBusy)
                    .keyboardShortcut(.defaultAction)

                Button("Repair launcher") { repairLauncher() }
                    .disabled(isBusy || !appState.hasPrefix)

                Button("Setup…") { appState.openSetupWizard() }
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text("Unsupported by ArenaNet. Use at your own risk.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 480)
        .onAppear { loadLaunchArguments() }
    }

    @ViewBuilder
    private var runtimeActions: some View {
        if appState.runtimeUpdateAvailable != nil {
            HStack {
                Button("Update Wine Runtime") {
                    Task { await appState.downloadAndInstallRuntime() }
                }
                .disabled(appState.isRuntimeBusy)
            }
        }

        switch appState.runtimeInstallPhase {
        case .downloading(let fraction):
            ProgressView(value: fraction) { Text("Downloading runtime…") }
        case .extracting:
            ProgressView("Extracting runtime…")
        case .failed(let message):
            Text(message).font(.caption).foregroundStyle(.secondary)
        default:
            EmptyView()
        }
    }

    private func loadLaunchArguments() {
        guard let program = appState.bottleManager.launcherProgram() else { return }
        launchArguments = program.settings.arguments
    }

    private func saveLaunchArguments() {
        guard var program = appState.bottleManager.launcherProgram() else { return }
        program.settings.arguments = launchArguments
    }

    private func repairLauncher() {
        Task {
            isBusy = true
            defer { isBusy = false }
            guard let bottle = appState.bottleManager.bottle else { return }

            await appState.bottleManager.applyPerformanceTuningIfNeeded()
            let fontWarning = await GW2FontInstaller.installFontsIfNeeded(into: bottle)

            if GW2Repair.clearLauncherLock(in: bottle) {
                statusMessage = "Removed stale lock file."
            } else {
                statusMessage = "Display settings refreshed."
            }

            if let fontWarning {
                statusMessage += " Font install skipped: \(fontWarning)"
            }
        }
    }

    private func play() {
        saveLaunchArguments()
        Task {
            isBusy = true
            defer { isBusy = false }

            let preparation = await appState.bottleManager.prepareForLaunch()

            guard let program = appState.bottleManager.launcherProgram() else {
                statusMessage = "Gw2-64.exe not found. Install Guild Wars 2 first."
                return
            }

            program.settings.arguments = launchArguments
            program.run()

            if let fontWarning = preparation.fontInstallWarning {
                statusMessage = "Launching Guild Wars 2… (font install skipped: \(fontWarning))"
            } else {
                statusMessage = "Launching Guild Wars 2…"
            }
        }
    }
}
