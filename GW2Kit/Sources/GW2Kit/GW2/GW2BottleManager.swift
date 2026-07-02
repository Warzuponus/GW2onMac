//
//  GW2BottleManager.swift
//  GW2Kit
//
//  TyriaSilicon — Guild Wars 2 launcher for Apple Silicon Macs.
//

import Foundation
import SemanticVersion
import os.log

/// Manages the single Guild Wars 2 Wine prefix used by TyriaSilicon.
public final class GW2BottleManager: ObservableObject, @unchecked Sendable {
    @MainActor public static let shared = GW2BottleManager()

    public static let bottleDirName = "GW2"

    @Published public private(set) var bottle: Bottle?
    @Published public private(set) var isCreating = false

    public var bottleURL: URL {
        BottleData.containerDir.appending(path: Self.bottleDirName)
    }

    @MainActor
    public func loadBottle() {
        let metadata = bottleURL
            .appending(path: "Metadata")
            .appendingPathExtension("plist")

        if FileManager.default.fileExists(atPath: metadata.path(percentEncoded: false)) {
            bottle = Bottle(bottleUrl: bottleURL, isAvailable: true)
        } else {
            bottle = nil
        }
    }

    @MainActor
    @discardableResult
    public func createBottleIfNeeded() async throws -> Bottle {
        if let bottle, bottle.isAvailable {
            return bottle
        }

        isCreating = true
        defer { isCreating = false }

        try FileManager.default.createDirectory(at: bottleURL, withIntermediateDirectories: true)

        let newBottle = Bottle(bottleUrl: bottleURL, inFlight: true)
        bottle = newBottle

        GW2Profile.apply(to: &newBottle.settings)
        try await Wine.initializePrefix(bottle: newBottle)
        try await Wine.changeWinVersion(bottle: newBottle, win: .win10)
        try await applyPerformanceTuning(for: newBottle)

        let wineVer = try await Wine.wineVersion()
        newBottle.settings.wineVersion = SemanticVersion(wineVer) ?? SemanticVersion(0, 0, 0)
        try newBottle.settings.encode(to: newBottle.url.appending(path: "Metadata").appendingPathExtension("plist"))

        try await GW2FontInstaller.installFonts(into: newBottle)

        newBottle.inFlight = false
        newBottle.isAvailable = true

        loadBottle()
        guard let bottle else {
            throw GW2BottleError.creationFailed
        }
        return bottle
    }

    /// Apply Retina/AVX tuning and GW2 fonts before launching the game.
    @MainActor
    public func prepareForLaunch() async throws {
        guard let bottle, bottle.isAvailable else { return }

        await applyPerformanceTuningIfNeeded()

        if !GW2FontInstaller.areFontsInstalled(in: bottle) {
            try await GW2FontInstaller.installFonts(into: bottle)
        }
    }

    @MainActor
    public func applyPerformanceTuningIfNeeded() async {
        guard let bottle, bottle.isAvailable else { return }

        GW2Profile.applyPerformance(to: &bottle.settings)

        do {
            if try await Wine.retinaMode(bottle: bottle) {
                try await Wine.changeRetinaMode(bottle: bottle, retinaMode: false)
            }
        } catch {
            Logger.gw2Kit.warning("RetinaMode tuning failed: \(error)")
        }
    }

    @MainActor
    private func applyPerformanceTuning(for bottle: Bottle) async throws {
        GW2Profile.applyPerformance(to: &bottle.settings)
        try await Wine.changeRetinaMode(bottle: bottle, retinaMode: false)
    }

    public func launcherProgram() -> Program? {
        guard let bottle else { return nil }
        let launcher = GW2Profile.launcherURL(in: bottle)
        guard FileManager.default.fileExists(atPath: launcher.path(percentEncoded: false)) else {
            return nil
        }
        let program = Program(url: launcher, bottle: bottle)
        if program.settings.arguments.isEmpty {
            program.settings.arguments = GW2Profile.defaultLaunchArguments
        }
        return program
    }

    public func setupProgram() -> Program? {
        guard let bottle else { return nil }
        let setup = GW2Profile.setupURL(in: bottle)
        guard FileManager.default.fileExists(atPath: setup.path(percentEncoded: false)) else {
            return nil
        }
        return Program(url: setup, bottle: bottle)
    }
}

public enum GW2BottleError: LocalizedError {
    case creationFailed
    case runtimeMissing
    case d3dMetalMissing

    public var errorDescription: String? {
        switch self {
        case .creationFailed:
            return "Failed to create the Guild Wars 2 Wine prefix."
        case .runtimeMissing:
            return "GW2onMac Wine runtime is not installed. Complete setup first."
        case .d3dMetalMissing:
            return "Apple Game Porting Toolkit (D3DMetal) was not found. Install GPTK for DirectX 11 support."
        }
    }
}
