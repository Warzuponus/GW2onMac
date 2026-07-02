//
//  AppPaths.swift
//  GW2Kit
//
//  GW2onMac — Guild Wars 2 launcher for Apple Silicon Macs.
//

import Foundation

/// Application Support and Container paths, with legacy TyriaSilicon migration.
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

    private static func resolveApplicationSupport() -> URL {
        let home = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let newPath = home.appending(path: bundleIdentifier)
        let legacyPath = home.appending(path: legacyBundleIdentifier)

        if hasRuntime(at: newPath) { return newPath }
        if hasRuntime(at: legacyPath) { return legacyPath }
        return newPath
    }

    private static func resolveContainer() -> URL {
        let newPath = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Containers")
            .appending(path: bundleIdentifier)
        let legacyPath = legacyContainer

        if FileManager.default.fileExists(atPath: legacyPath.appending(path: "GW2").path) {
            return legacyPath
        }
        if FileManager.default.fileExists(atPath: newPath.appending(path: "GW2").path) {
            return newPath
        }
        if FileManager.default.fileExists(atPath: legacyPath.path) {
            return legacyPath
        }
        return newPath
    }

    private static func hasRuntime(at appSupport: URL) -> Bool {
        let wine64 = appSupport
            .appending(path: "Libraries/Wine/bin/wine64")
        return FileManager.default.fileExists(atPath: wine64.path)
    }
}
