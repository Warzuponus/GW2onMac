//
//  GW2FontInstaller.swift
//  GW2Kit
//
//  Installs Windows fonts required by the GW2 launcher UI (Coherent / CEF).
//

import Foundation

public enum GW2FontInstallerError: LocalizedError {
    case winetricksMissing
    case installFailed(String)

    public var errorDescription: String? {
        switch self {
        case .winetricksMissing:
            return "winetricks was not found in the Wine runtime. Install fonts manually with Scripts/gw2-winetricks.sh."
        case .installFailed(let detail):
            return "GW2 font install failed: \(detail)"
        }
    }
}

public enum GW2FontInstaller {
    private static let markerName = ".gw2onmac/fonts-installed"

    public static func winetricksURL() -> URL? {
        let candidates = [
            WineRuntimeInstaller.libraryFolder.appending(path: "winetricks"),
            WineRuntimeInstaller.libraryFolder.appending(path: "Wine/bin/winetricks"),
            URL(fileURLWithPath: "/usr/local/bin/winetricks"),
            URL(fileURLWithPath: "/opt/homebrew/bin/winetricks")
        ]
        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) {
            return found
        }
        return materializeBundledWinetricksIfNeeded()
    }

    /// Copy bundled `winetricks` from the app into Application Support on first use.
    private static func materializeBundledWinetricksIfNeeded() -> URL? {
        let destination = WineRuntimeInstaller.libraryFolder.appending(path: "winetricks")
        if FileManager.default.isExecutableFile(atPath: destination.path) {
            return destination
        }

        guard let bundled = Bundle.main.url(forResource: "winetricks", withExtension: nil) else {
            return nil
        }

        do {
            try FileManager.default.createDirectory(
                at: WineRuntimeInstaller.libraryFolder,
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: bundled, to: destination)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
            return destination
        } catch {
            return nil
        }
    }

    public static func areFontsInstalled(in bottle: Bottle) -> Bool {
        let marker = bottle.url.appending(path: markerName)
        if FileManager.default.fileExists(atPath: marker.path) {
            return true
        }

        let arial = bottle.url
            .appending(path: "drive_c/windows/Fonts/arial.ttf")
        return FileManager.default.fileExists(atPath: arial.path)
    }

    /// Install corefonts + tahoma into the prefix (required for GW2 launcher text fields).
    public static func installFonts(into bottle: Bottle) async throws {
        if areFontsInstalled(in: bottle) {
            return
        }

        guard let winetricks = winetricksURL() else {
            throw GW2FontInstallerError.winetricksMissing
        }

        for verb in ["corefonts", "tahoma"] {
            try await runWinetricks(verb, winetricks: winetricks, bottle: bottle)
        }

        let markerDir = bottle.url.appending(path: ".gw2onmac")
        try FileManager.default.createDirectory(at: markerDir, withIntermediateDirectories: true)
        let marker = markerDir.appending(path: "fonts-installed")
        FileManager.default.createFile(atPath: marker.path, contents: Data("1".utf8))
    }

    private static func runWinetricks(_ verb: String, winetricks: URL, bottle: Bottle) async throws {
        let environment = Wine.constructLaunchEnvironment(for: bottle)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/arch")
            process.arguments = [
                "-x86_64",
                winetricks.path(percentEncoded: false),
                "-q",
                "fonts",
                verb
            ]
            process.environment = environment

            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: GW2FontInstallerError.installFailed(
                        "winetricks fonts \(verb) exited with status \(proc.terminationStatus)"
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: GW2FontInstallerError.installFailed(error.localizedDescription))
            }
        }
    }
}
