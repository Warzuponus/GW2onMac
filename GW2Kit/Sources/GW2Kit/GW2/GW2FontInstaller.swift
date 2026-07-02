//
//  GW2FontInstaller.swift
//  GW2Kit
//
//  Installs Windows fonts required by the GW2 launcher UI (Coherent / CEF).
//

import Foundation
import os.log

public enum GW2FontInstallerError: LocalizedError {
    case winetricksMissing
    case cabextractMissing
    case installFailed(String)

    public var errorDescription: String? {
        switch self {
        case .winetricksMissing:
            return "winetricks was not found. Update GW2onMac or run Scripts/gw2-winetricks.sh from the repo."
        case .cabextractMissing:
            return """
            cabextract is required to install GW2 launcher fonts. \
            Update to the latest GW2onMac build, or run: brew install cabextract
            """
        case .installFailed(let detail):
            return "GW2 font install failed: \(detail)"
        }
    }
}

public enum GW2FontInstaller {
    private static let markerName = ".gw2onmac/fonts-installed"
    private static let toolsFolder = WineRuntimeInstaller.libraryFolder.appending(path: "tools")

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
        return materializeBundledTool(named: "winetricks")
    }

    public static func cabextractURL() -> URL? {
        let candidates = [
            toolsFolder.appending(path: "cabextract"),
            URL(fileURLWithPath: "/usr/local/bin/cabextract"),
            URL(fileURLWithPath: "/opt/homebrew/bin/cabextract")
        ]
        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) {
            return found
        }
        return materializeBundledTool(named: "cabextract", into: toolsFolder)
    }

    /// Copy bundled helper tools from the app into Application Support on first use.
    private static func materializeBundledTool(
        named name: String,
        into folder: URL = WineRuntimeInstaller.libraryFolder
    ) -> URL? {
        let destination = folder.appending(path: name)
        if FileManager.default.isExecutableFile(atPath: destination.path) {
            return destination
        }

        guard let bundled = Bundle.main.url(forResource: name, withExtension: nil) else {
            return nil
        }

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
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

        let fontsDir = bottle.url.appending(path: "drive_c/windows/Fonts")
        guard FileManager.default.fileExists(atPath: fontsDir.path) else {
            return false
        }

        let fontFiles = Set(
            (try? FileManager.default.contentsOfDirectory(atPath: fontsDir.path))?
                .map { $0.lowercased() } ?? []
        )

        // Do not use a font count heuristic — stock Wine ships many fonts but not CEF UI fonts.
        let required = ["arial.ttf", "tahoma.ttf"]
        return required.allSatisfy { fontFiles.contains($0) }
    }

    /// Remove the font marker so the next repair/play reinstalls corefonts + tahoma.
    public static func resetFontInstallMarker(in bottle: Bottle) {
        let marker = bottle.url.appending(path: markerName)
        try? FileManager.default.removeItem(at: marker)
    }

    /// Force corefonts + tahoma even when a partial font set exists.
    public static func reinstallFonts(into bottle: Bottle) async throws {
        resetFontInstallMarker(in: bottle)
        try await installFonts(into: bottle)
    }

    /// Best-effort font install. Returns a user-visible warning when install fails or is skipped.
    public static func installFontsIfNeeded(into bottle: Bottle) async -> String? {
        guard !areFontsInstalled(in: bottle) else { return nil }

        do {
            try await installFonts(into: bottle)
            return nil
        } catch {
            Logger.gw2Kit.warning("Optional GW2 font install failed: \(error.localizedDescription, privacy: .public)")
            return error.localizedDescription
        }
    }

    /// Install corefonts + tahoma into the prefix (optional; launcher may already have fonts).
    public static func installFonts(into bottle: Bottle) async throws {
        if areFontsInstalled(in: bottle) {
            return
        }

        guard winetricksURL() != nil else {
            throw GW2FontInstallerError.winetricksMissing
        }
        guard cabextractURL() != nil else {
            throw GW2FontInstallerError.cabextractMissing
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

    private static func winetricksEnvironment(for bottle: Bottle) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment.merge(Wine.constructLaunchEnvironment(for: bottle)) { _, new in new }

        let wineBin = WineRuntimeInstaller.binFolder.path(percentEncoded: false)
        let wine64 = Wine.wineBinary.path(percentEncoded: false)
        environment["WINE"] = wine64
        environment["WINEARCH"] = "win64"

        var pathEntries = [toolsFolder.path(percentEncoded: false), wineBin]
        if let cabextract = cabextractURL() {
            pathEntries.insert(cabextract.deletingLastPathComponent().path(percentEncoded: false), at: 0)
        }
        pathEntries.append(contentsOf: ["/usr/local/bin", "/opt/homebrew/bin"])
        if let existingPath = environment["PATH"], !existingPath.isEmpty {
            pathEntries.append(existingPath)
        }
        environment["PATH"] = pathEntries.joined(separator: ":")

        return environment
    }

    private static func runWinetricks(_ verb: String, winetricks: URL, bottle: Bottle) async throws {
        let environment = winetricksEnvironment(for: bottle)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            let errorPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/arch")
            process.arguments = [
                "-x86_64",
                "/bin/bash",
                winetricks.path(percentEncoded: false),
                "-q",
                verb
            ]
            process.environment = environment
            process.standardError = errorPipe

            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                    return
                }

                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorText = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                let detail = Self.summarizeWinetricksFailure(errorText, verb: verb, status: proc.terminationStatus)
                continuation.resume(throwing: GW2FontInstallerError.installFailed(detail))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: GW2FontInstallerError.installFailed(error.localizedDescription))
            }
        }
    }

    private static func summarizeWinetricksFailure(_ output: String, verb: String, status: Int32) -> String {
        if output.localizedCaseInsensitiveContains("cannot find cabextract") {
            return "cabextract is missing (required for \(verb)). Update GW2onMac or run: brew install cabextract"
        }

        let lines = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("Executing ") }

        if let last = lines.last {
            return "winetricks \(verb) exited with status \(status): \(last)"
        }

        return "winetricks \(verb) exited with status \(status)"
    }
}
