//
//  GW2LaunchPreparation.swift
//  GW2Kit
//
//  Result of optional pre-launch steps (fonts, Retina tuning, etc.).
//

import Foundation

public struct GW2LaunchPreparation: Sendable {
    /// Non-fatal warning from optional font installation (launch proceeds anyway).
    public var fontInstallWarning: String?

    public init(fontInstallWarning: String? = nil) {
        self.fontInstallWarning = fontInstallWarning
    }
}
