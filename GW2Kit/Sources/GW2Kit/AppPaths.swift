//
//  AppPaths.swift
//  GW2Kit
//
//  GW2onMac — Guild Wars 2 launcher for Apple Silicon Macs.
//

import Foundation

/// Application Support (runtime) and Container (prefix) paths, with legacy TyriaSilicon fallback.
public enum AppPaths {
    public static let bundleIdentifier = "com.gw2onmac.app"
    public static let legacyBundleIdentifier = "com.tyriasilicon.app"

    public static var applicationSupport: URL {
        resolveApplicationSupport()
    }

    public static var container: URL {
        resolveContainer()
    }

    public static var legacyApplicationSupport: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: legacyBundleIdentifier)
    }

    public static var legacyContainer: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Containers")
            .appending(path: legacyBundleIdentifier)
    }

    // Runtime and prefix resolve independently: a migrated TyriaSilicon install can have
    // them under different bundle IDs. Mirrors Scripts/resolve-bundle-id.sh — keep in sync.

    /// New ID if its runtime exists, else legacy if that exists, else new.
    private static func resolveApplicationSupport() -> URL {
        let home = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let newPath = home.appending(path: bundleIdentifier)
        let legacyPath = home.appending(path: legacyBundleIdentifier)

        if hasRuntime(at: newPath) { return newPath }
        if hasRuntime(at: legacyPath) { return legacyPath }
        return newPath
    }

    /// Prefers a prefix with GW2 installed, then any GW2 prefix (new before legacy), else new.
    private static func resolveContainer() -> URL {
        let newPath = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Containers")
            .appending(path: bundleIdentifier)
        let candidates = [newPath, legacyContainer]

        if let installed = candidates.first(where: { hasGW2Installed(in: $0) }) {
            return installed
        }
        if let prefix = candidates.first(where: { hasPrefix(in: $0) }) {
            return prefix
        }
        return newPath
    }

    private static func hasPrefix(in container: URL) -> Bool {
        FileManager.default.fileExists(atPath: container.appending(path: "GW2").path(percentEncoded: false))
    }

    private static func hasGW2Installed(in container: URL) -> Bool {
        let exe = container.appending(path: "GW2/drive_c/Program Files/Guild Wars 2/Gw2-64.exe")
        return FileManager.default.fileExists(atPath: exe.path(percentEncoded: false))
    }

    private static func hasRuntime(at appSupport: URL) -> Bool {
        let wine64 = appSupport
            .appending(path: "Libraries/Wine/bin/wine64")
        return FileManager.default.isExecutableFile(atPath: wine64.path(percentEncoded: false))
    }
}
