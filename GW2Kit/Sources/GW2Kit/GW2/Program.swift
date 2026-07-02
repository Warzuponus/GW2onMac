//
//  Program.swift
//  GW2Kit
//
//  TyriaSilicon — Guild Wars 2 launcher for Apple Silicon Macs.
//  Adapted from Whisky (GPL-3.0). See NOTICES.md in the repository root.
//

import Foundation
import SwiftUI
import os.log

public final class Program: ObservableObject, Equatable, Hashable, Identifiable, @unchecked Sendable {
    public let bottle: Bottle
    public let url: URL
    public let settingsURL: URL

    public var name: String {
        url.lastPathComponent
    }

    @Published public var settings: ProgramSettings {
        didSet { saveSettings() }
    }

    public init(url: URL, bottle: Bottle) {
        self.bottle = bottle
        self.url = url

        let settingsFolder = bottle.url.appending(path: "Program Settings")
        let settingsUrl = settingsFolder.appending(path: url.lastPathComponent).appendingPathExtension("plist")
        self.settingsURL = settingsUrl

        do {
            if !FileManager.default.fileExists(atPath: settingsFolder.path(percentEncoded: false)) {
                try FileManager.default.createDirectory(at: settingsFolder, withIntermediateDirectories: true)
            }
            self.settings = try ProgramSettings.decode(from: settingsUrl)
        } catch {
            Logger.gw2Kit.error("Failed to load settings for `\(url.lastPathComponent)`: \(error)")
            self.settings = ProgramSettings()
        }
    }

    public func generateEnvironment() -> [String: String] {
        var environment = settings.environment
        environment.merge(GW2Profile.environmentOverrides()) { _, new in new }

        if settings.locale != .auto {
            environment["LC_ALL"] = settings.locale.rawValue
        }
        return environment
    }

    private func saveSettings() {
        do {
            try settings.encode(to: settingsURL)
        } catch {
            Logger.gw2Kit.error("Failed to save settings for `\(self.name)`: \(error)")
        }
    }

    public static func == (lhs: Program, rhs: Program) -> Bool {
        lhs.url == rhs.url
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    public var id: URL { url }
}
