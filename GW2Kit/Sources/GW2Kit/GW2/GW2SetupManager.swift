//
//  GW2SetupManager.swift
//  GW2Kit
//
//  GW2onMac — Guild Wars 2 launcher for Apple Silicon Macs.
//

import Foundation

public enum GW2SetupError: LocalizedError {
    case prefixMissing
    case downloadFailed(String)
    case setupNotFound

    public var errorDescription: String? {
        switch self {
        case .prefixMissing:
            return "Create a GW2 prefix before installing the game."
        case .downloadFailed(let detail):
            return "Failed to download Gw2Setup-64.exe: \(detail)"
        case .setupNotFound:
            return "Gw2Setup-64.exe was not found in the prefix."
        }
    }
}

/// Downloads and launches ArenaNet's GW2 installer inside the Wine prefix.
public enum GW2SetupManager {
    /// Primary Gw2Setup download URL (first entry in `setupDownloadURLs`).
    public static var setupDownloadURL: URL { setupDownloadURLs[0] }

    /// ArenaNet CDN URLs for Gw2Setup-64.exe, tried in order until one succeeds.
    public static var setupDownloadURLs: [URL] { ReleaseConfiguration.gw2SetupDownloadURLs }

    /// Path where Gw2Setup is stored inside the prefix (`C:\Gw2Setup-64.exe`).
    public static func setupURL(in bottle: Bottle) -> URL {
        GW2Profile.setupURL(in: bottle)
    }

    public static func hasSetupExecutable(in bottle: Bottle) -> Bool {
        FileManager.default.fileExists(atPath: setupURL(in: bottle).path(percentEncoded: false))
    }

    public static func downloadSetup(
        into bottle: Bottle,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        let destination = setupURL(in: bottle)
        var lastError: String?

        for url in setupDownloadURLs {
            do {
                try await HTTPDownload.download(from: url, to: destination, progress: progress)
                return
            } catch {
                lastError = error.localizedDescription
                if FileManager.default.fileExists(atPath: destination.path) {
                    try? FileManager.default.removeItem(at: destination)
                }
            }
        }

        throw GW2SetupError.downloadFailed(lastError ?? "All download URLs failed.")
    }

    /// Launch Gw2Setup-64.exe (non-blocking).
    @MainActor
    public static func launchSetup(using bottleManager: GW2BottleManager) throws {
        guard let program = bottleManager.setupProgram() else {
            throw GW2SetupError.setupNotFound
        }
        program.run()
    }

    /// Poll until `Gw2-64.exe` appears or timeout elapses.
    public static func waitForInstall(in bottle: Bottle, timeout: TimeInterval = 3600) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if GW2Profile.isInstalled(in: bottle) {
                return true
            }
            try? await Task.sleep(for: .seconds(3))
        }
        return GW2Profile.isInstalled(in: bottle)
    }

    /// Copy an existing Windows GW2 install folder into the prefix.
    public static func importExistingInstall(from sourceFolder: URL, into bottle: Bottle) throws {
        let destination = GW2Profile.installDirectory(in: bottle)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(at: sourceFolder, to: destination)
    }
}
