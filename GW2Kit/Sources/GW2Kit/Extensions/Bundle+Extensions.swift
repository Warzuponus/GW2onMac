//
//  Bundle+Extensions.swift
//  GW2Kit
//

import Foundation

public extension Bundle {
    static var gw2onMacBundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? AppPaths.bundleIdentifier
    }

    /// Legacy name used during TyriaSilicon development.
    static var tyriaSiliconBundleIdentifier: String {
        gw2onMacBundleIdentifier
    }
}
