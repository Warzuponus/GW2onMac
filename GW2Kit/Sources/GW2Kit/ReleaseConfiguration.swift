//
//  ReleaseConfiguration.swift
//  GW2Kit
//
//  GW2onMac — Guild Wars 2 launcher for Apple Silicon Macs.
//

import Foundation

/// GitHub release URLs for the self-built Wine runtime.
public enum ReleaseConfiguration {
    /// Override with `GW2ONMAC_GITHUB_REPO` (e.g. `yourname/GW2onMac`).
    public static var githubRepository: String {
        if let repo = ProcessInfo.processInfo.environment["GW2ONMAC_GITHUB_REPO"], !repo.isEmpty {
            return repo
        }
        return "PLACEHOLDER/GW2onMac"
    }

    public static var runtimeDownloadURL: URL {
        if let override = ProcessInfo.processInfo.environment["GW2ONMAC_WINE_RUNTIME_URL"]
            ?? ProcessInfo.processInfo.environment["TYRIA_WINE_RUNTIME_URL"],
           let url = URL(string: override) {
            return url
        }
        return URL(string: "https://github.com/\(githubRepository)/releases/latest/download/Libraries.tar.gz")!
    }

    public static var versionPlistURL: URL {
        if let override = ProcessInfo.processInfo.environment["GW2ONMAC_WINE_VERSION_URL"]
            ?? ProcessInfo.processInfo.environment["TYRIA_WINE_VERSION_URL"],
           let url = URL(string: override) {
            return url
        }
        return URL(string: "https://github.com/\(githubRepository)/releases/latest/download/GW2onMacWineVersion.plist")!
    }
}
