//
//  ReleaseConfiguration.swift
//  GW2Kit
//
//  GW2onMac — Guild Wars 2 launcher for Apple Silicon Macs.
//

import Foundation

/// GitHub release URLs for the self-built Wine runtime.
public enum ReleaseConfiguration {
    /// Wine runtime release tag on GitHub (not the app `v*` tag). Bump when publishing `runtime-v*`.
    public static let runtimeReleaseTag = "runtime-v0.1.1"

    /// Override with `GW2ONMAC_GITHUB_REPO` (e.g. `yourname/GW2onMac`).
    public static var githubRepository: String {
        if let repo = ProcessInfo.processInfo.environment["GW2ONMAC_GITHUB_REPO"], !repo.isEmpty {
            return repo
        }
        return "Warzuponus/GW2onMac"
    }

    public static var runtimeDownloadURL: URL {
        if let override = ProcessInfo.processInfo.environment["GW2ONMAC_WINE_RUNTIME_URL"]
            ?? ProcessInfo.processInfo.environment["TYRIA_WINE_RUNTIME_URL"],
           let url = URL(string: override) {
            return url
        }
        return URL(string: "https://github.com/\(githubRepository)/releases/download/\(runtimeReleaseTag)/Libraries.tar.gz")!
    }

    public static var versionPlistURL: URL {
        if let override = ProcessInfo.processInfo.environment["GW2ONMAC_WINE_VERSION_URL"]
            ?? ProcessInfo.processInfo.environment["TYRIA_WINE_VERSION_URL"],
           let url = URL(string: override) {
            return url
        }
        return URL(string: "https://github.com/\(githubRepository)/releases/download/\(runtimeReleaseTag)/GW2onMacWineVersion.plist")!
    }

    /// ArenaNet Gw2Setup-64.exe download URLs (tried in order). Override with `GW2ONMAC_GW2_SETUP_URL`.
    public static var gw2SetupDownloadURLs: [URL] {
        if let override = ProcessInfo.processInfo.environment["GW2ONMAC_GW2_SETUP_URL"],
           let url = URL(string: override) {
            return [url]
        }
        return [
            // `download.guildwars2.com` returns 404 as of 2026; Lutris/PlayOnLinux use the S3 CDN.
            URL(string: "https://s3.amazonaws.com/gw2cdn/client/branches/Gw2Setup-64.exe")!,
            URL(string: "https://gw2cdn.s3.amazonaws.com/client/branches/Gw2Setup-64.exe")!
        ]
    }
}
