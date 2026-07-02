//
//  Bottle.swift
//  GW2Kit
//
//  TyriaSilicon — adapted from Whisky (GPL-3.0).
//

import Foundation
import SwiftUI
import os.log

public final class Bottle: ObservableObject, Equatable, Hashable, Identifiable, Comparable, @unchecked Sendable {
    public let url: URL
    private let metadataURL: URL
    @Published public var settings: BottleSettings {
        didSet { saveSettings() }
    }
    @Published public var inFlight: Bool = false
    public var isAvailable: Bool = false

    public init(bottleUrl: URL, inFlight: Bool = false, isAvailable: Bool = false) {
        let metadataURL = bottleUrl.appending(path: "Metadata").appendingPathExtension("plist")
        self.url = bottleUrl
        self.inFlight = inFlight
        self.isAvailable = isAvailable
        self.metadataURL = metadataURL

        do {
            self.settings = try BottleSettings.decode(from: metadataURL)
        } catch {
            Logger.gw2Kit.error(
                "Failed to load settings for bottle `\(metadataURL.path(percentEncoded: false))`: \(error)"
            )
            self.settings = BottleSettings()
            GW2Profile.apply(to: &self.settings)
        }
    }

    private func saveSettings() {
        do {
            try settings.encode(to: metadataURL)
        } catch {
            Logger.gw2Kit.error(
                "Failed to encode settings for bottle `\(self.metadataURL.path(percentEncoded: false))`: \(error)"
            )
        }
    }

    public static func == (lhs: Bottle, rhs: Bottle) -> Bool {
        lhs.url == rhs.url
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    public var id: URL { url }

    public static func < (lhs: Bottle, rhs: Bottle) -> Bool {
        lhs.settings.name.lowercased() < rhs.settings.name.lowercased()
    }
}
