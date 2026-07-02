//
//  AppState.swift
//  GW2onMac
//

import SwiftUI
import GW2Kit
import SemanticVersion

enum RuntimeInstallPhase: Equatable {
    case idle
    case downloading(Double)
    case extracting
    case complete
    case failed(String)
}

enum GW2InstallPhase: Equatable {
    case idle
    case downloading(Double)
    case launching
    case waitingForGame
    case importing
    case complete
    case failed(String)
}

@MainActor
final class AppState: ObservableObject {
    @Published var bottleManager = GW2BottleManager.shared
    @Published var runtimeInstallPhase: RuntimeInstallPhase = .idle
    @Published var gw2InstallPhase: GW2InstallPhase = .idle
    @Published var runtimeUpdateAvailable: SemanticVersion?

    var isRuntimeInstalled: Bool { WineRuntimeInstaller.isRuntimeInstalled() }
    var isD3DMetalAvailable: Bool { WineRuntimeInstaller.isD3DMetalAvailable() }
    var hasPrefix: Bool { bottleManager.bottle?.isAvailable == true }
    var isGameInstalled: Bool {
        guard let bottle = bottleManager.bottle else { return false }
        return GW2Profile.isInstalled(in: bottle)
    }

    var isRuntimeBusy: Bool {
        switch runtimeInstallPhase {
        case .downloading, .extracting: true
        default: false
        }
    }

    var isGW2InstallBusy: Bool {
        switch gw2InstallPhase {
        case .downloading, .launching, .waitingForGame, .importing: true
        default: false
        }
    }

    /// Show the main launcher once Wine runtime is present.
    var showsHome: Bool { isRuntimeInstalled }

    var isReadyToPlay: Bool { isRuntimeInstalled && isD3DMetalAvailable && hasPrefix && isGameInstalled }

    init() {
        bottleManager.loadBottle()
        Task { await bottleManager.applyPerformanceTuningIfNeeded() }
        Task { await checkRuntimeUpdate() }
    }

    func refresh() {
        bottleManager.loadBottle()
        Task { await bottleManager.applyPerformanceTuningIfNeeded() }
    }

    func checkRuntimeUpdate() async {
        let (shouldUpdate, remoteVersion) = await WineRuntimeInstaller.shouldUpdateRuntime()
        runtimeUpdateAvailable = shouldUpdate ? remoteVersion : nil
    }

    func downloadAndInstallRuntime() async {
        guard !isRuntimeBusy else { return }

        runtimeInstallPhase = .downloading(0)
        do {
            try await WineRuntimeInstaller.downloadAndInstallRuntime { [weak self] fraction in
                Task { @MainActor in
                    if fraction >= 0.95 {
                        self?.runtimeInstallPhase = .extracting
                    } else {
                        self?.runtimeInstallPhase = .downloading(fraction)
                    }
                }
            }
            runtimeInstallPhase = .complete
            runtimeUpdateAvailable = nil
            refresh()
        } catch {
            runtimeInstallPhase = .failed(error.localizedDescription)
        }
    }

    func installRosetta() async {
        do {
            _ = try await Rosetta2.installRosetta()
            refresh()
        } catch {
            runtimeInstallPhase = .failed("Rosetta install failed: \(error.localizedDescription)")
        }
    }

    func createPrefix() async throws {
        guard isRuntimeInstalled else {
            throw GW2BottleError.runtimeMissing
        }
        guard isD3DMetalAvailable else {
            throw GW2BottleError.d3dMetalMissing
        }
        _ = try await bottleManager.createBottleIfNeeded()
        refresh()
    }

    func downloadAndRunGW2Setup() async {
        guard !isGW2InstallBusy else { return }
        guard let bottle = bottleManager.bottle else {
            gw2InstallPhase = .failed(GW2SetupError.prefixMissing.localizedDescription)
            return
        }

        gw2InstallPhase = .downloading(0)
        do {
            if !GW2SetupManager.hasSetupExecutable(in: bottle) {
                try await GW2SetupManager.downloadSetup(into: bottle) { [weak self] fraction in
                    Task { @MainActor in
                        self?.gw2InstallPhase = .downloading(fraction)
                    }
                }
            }

            gw2InstallPhase = .launching
            try GW2SetupManager.launchSetup(using: bottleManager)

            gw2InstallPhase = .waitingForGame
            let installed = await GW2SetupManager.waitForInstall(in: bottle)
            gw2InstallPhase = installed ? .complete : .failed("Game install not detected yet. Finish Gw2Setup, then click Refresh.")
            refresh()
        } catch {
            gw2InstallPhase = .failed(error.localizedDescription)
        }
    }

    func importExistingInstall(from folder: URL) async {
        guard !isGW2InstallBusy else { return }
        guard let bottle = bottleManager.bottle else {
            gw2InstallPhase = .failed(GW2SetupError.prefixMissing.localizedDescription)
            return
        }

        gw2InstallPhase = .importing
        do {
            let accessed = folder.startAccessingSecurityScopedResource()
            defer {
                if accessed { folder.stopAccessingSecurityScopedResource() }
            }
            try GW2SetupManager.importExistingInstall(from: folder, into: bottle)
            refresh()
            gw2InstallPhase = isGameInstalled ? .complete : .failed("Copied files, but Gw2-64.exe was not found in the selected folder.")
        } catch {
            gw2InstallPhase = .failed(error.localizedDescription)
        }
    }

    func resetRuntimeInstallPhase() {
        runtimeInstallPhase = .idle
    }

    func resetGW2InstallPhase() {
        gw2InstallPhase = .idle
    }
}
