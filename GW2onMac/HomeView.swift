//
//  HomeView.swift
//  GW2onMac
//

import SwiftUI
import GW2Kit
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var statusMessage = ""
    @State private var isBusy = false
    @State private var launchArguments = GW2Profile.defaultLaunchArguments
    @State private var showImportPicker = false

    private var gw2Installed: Bool { appState.isGameInstalled }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Guild Wars 2")
                    .font(.largeTitle.bold())
                Text("GW2onMac · Apple Silicon")
                    .foregroundStyle(.secondary)
            }

            statusRow("Wine runtime", ok: appState.isRuntimeInstalled)
            statusRow("D3DMetal (GPTK)", ok: appState.isD3DMetalAvailable, hint: "Install Apple Game Porting Toolkit")
            statusRow("GW2 prefix", ok: appState.hasPrefix)
            statusRow("Game installed", ok: gw2Installed, hint: "Install or import Guild Wars 2")

            runtimeActions
            gw2InstallActions

            if let version = WineRuntimeInstaller.runtimeVersion() {
                Text("Runtime v\(version.major).\(version.minor).\(version.patch)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !gw2Installed, appState.hasPrefix {
                incompleteSetupBanner
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

                Button("Create Prefix") {
                    Task { await createPrefix() }
                }
                .disabled(isBusy || appState.hasPrefix)
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
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let folder = urls.first else { return }
                Task { await appState.importExistingInstall(from: folder) }
            case .failure(let error):
                statusMessage = error.localizedDescription
            }
        }
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

    @ViewBuilder
    private var gw2InstallActions: some View {
        if appState.hasPrefix, !gw2Installed {
            HStack {
                Button("Install GW2") {
                    Task { await appState.downloadAndRunGW2Setup() }
                }
                .disabled(appState.isGW2InstallBusy)

                Button("Import Existing…") { showImportPicker = true }
                    .disabled(appState.isGW2InstallBusy)
            }
        }

        switch appState.gw2InstallPhase {
        case .downloading(let fraction):
            ProgressView(value: fraction) { Text("Downloading Gw2Setup…") }
        case .launching, .waitingForGame, .importing:
            ProgressView("Installing Guild Wars 2…")
        case .failed(let message):
            Text(message).font(.caption).foregroundStyle(.secondary)
        default:
            EmptyView()
        }
    }

    private var incompleteSetupBanner: some View {
        Text("Finish installing Guild Wars 2 to enable Play.")
            .font(.callout)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func statusRow(_ title: String, ok: Bool, hint: String = "") -> some View {
        HStack(spacing: 8) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(ok ? .green : .secondary)
            Text(title)
            if !ok, !hint.isEmpty {
                Text("— \(hint)")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
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

    private func createPrefix() async {
        isBusy = true
        defer { isBusy = false }

        do {
            try await appState.createPrefix()
            statusMessage = "GW2 prefix ready."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func repairLauncher() {
        guard let bottle = appState.bottleManager.bottle else { return }
        if GW2Repair.clearLauncherLock(in: bottle) {
            statusMessage = "Removed stale Gw2-64.tmp lock file."
        } else {
            statusMessage = "No empty lock files found — nothing to repair."
        }
    }

    private func play() {
        saveLaunchArguments()
        guard let program = appState.bottleManager.launcherProgram() else {
            statusMessage = "Gw2-64.exe not found. Install Guild Wars 2 first."
            return
        }
        program.settings.arguments = launchArguments
        program.run()
        statusMessage = "Launching Guild Wars 2…"
    }
}
