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

enum GPTKInstallPhase: Equatable {
    case idle
    case working(GPTKInstallStep)
    case complete
    case failed(String)
}

enum RosettaInstallPhase: Equatable {
    case idle
    case installing
    case complete
    case failed(String)
}

@MainActor
final class AppState: ObservableObject {
    @Published var bottleManager = GW2BottleManager.shared
    @Published var runtimeInstallPhase: RuntimeInstallPhase = .idle
    @Published var gw2InstallPhase: GW2InstallPhase = .idle
    @Published var gptkInstallPhase: GPTKInstallPhase = .idle
    @Published var rosettaInstallPhase: RosettaInstallPhase = .idle
    @Published var runtimeUpdateAvailable: SemanticVersion?
    /// When true, show the setup wizard even if the user could use the launcher.
    @Published var showSetupWizard = false
    var isRuntimeInstalled: Bool { WineRuntimeInstaller.isRuntimeInstalled() }
    var isD3DMetalAvailable: Bool { WineRuntimeInstaller.isD3DMetalAvailable() }
    var isRosettaInstalled: Bool { Rosetta2.isInstalled() }
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

    var isGPTKInstallBusy: Bool {
        switch gptkInstallPhase {
        case .working: true
        default: false
        }
    }

    var isRosettaInstallBusy: Bool {
        switch rosettaInstallPhase {
        case .installing: true
        default: false
        }
    }

    /// Show the launcher only after all setup steps are complete.
    var showsHome: Bool { isReadyToPlay && !showSetupWizard }

    var isReadyToPlay: Bool { isRuntimeInstalled && isD3DMetalAvailable && hasPrefix && isGameInstalled }

    var needsSetup: Bool { !isReadyToPlay }

    init() {
        bottleManager.loadBottle()
        Task { await bottleManager.applyPerformanceTuningIfNeeded() }
        Task { await checkRuntimeUpdate() }
    }

    func refresh() {
        bottleManager.loadBottle()
        objectWillChange.send()
        Task { await bottleManager.applyPerformanceTuningIfNeeded() }
    }

    func openSetupWizard() {
        showSetupWizard = true
    }

    func finishSetupWizard() {
        showSetupWizard = false
        refresh()
    }

    func checkRuntimeUpdate() async {
        let (shouldUpdate, remoteVersion) = await WineRuntimeInstaller.shouldUpdateRuntime()
        runtimeUpdateAvailable = shouldUpdate ? remoteVersion : nil
    }

    func downloadAndInstallRuntime() async {
        guard !isRuntimeBusy else { return }

        do {
            try await ensureRosettaInstalled()
        } catch {
            runtimeInstallPhase = .failed(error.localizedDescription)
            return
        }

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
        guard !isRosettaInstallBusy else { return }
        rosettaInstallPhase = .installing
        do {
            try await Rosetta2.ensureInstalled()
            rosettaInstallPhase = .complete
            refresh()
        } catch {
            rosettaInstallPhase = .failed(error.localizedDescription)
        }
    }

    /// Install Rosetta 2 when missing. Called automatically before Wine operations.
    func ensureRosettaInstalled() async throws {
        guard !Rosetta2.isInstalled() else { return }
        rosettaInstallPhase = .installing
        defer {
            if case .installing = rosettaInstallPhase {
                rosettaInstallPhase = .idle
            }
        }
        try await Rosetta2.ensureInstalled()
        rosettaInstallPhase = .complete
        refresh()
    }

    func createPrefix() async throws {
        try await ensureRosettaInstalled()
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

        do {
            try await ensureRosettaInstalled()
        } catch {
            gw2InstallPhase = .failed(error.localizedDescription)
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

        do {
            try await ensureRosettaInstalled()
        } catch {
            gw2InstallPhase = .failed(error.localizedDescription)
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

    func resetGPTKInstallPhase() {
        gptkInstallPhase = .idle
    }

    func resetRosettaInstallPhase() {
        rosettaInstallPhase = .idle
    }

    func installGPTK(from source: URL? = nil) async {
        guard !isGPTKInstallBusy else { return }

        gptkInstallPhase = .working(.searching)

        let accessed = source?.startAccessingSecurityScopedResource() ?? false
        defer {
            if accessed, let source { source.stopAccessingSecurityScopedResource() }
        }

        do {
            try await GPTKInstaller.install(from: source) { [weak self] step in
                Task { @MainActor in
                    self?.gptkInstallPhase = .working(step)
                }
            }
            gptkInstallPhase = .complete
            refresh()
        } catch {
            gptkInstallPhase = .failed(error.localizedDescription)
        }
    }
}
