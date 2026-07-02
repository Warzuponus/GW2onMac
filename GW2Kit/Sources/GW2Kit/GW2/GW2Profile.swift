//
//  GW2Profile.swift
//  GW2Kit
//
//  TyriaSilicon — Guild Wars 2 launcher for Apple Silicon Macs.
//  Adapted from Whisky (GPL-3.0). See NOTICES.md in the repository root.
//

import Foundation

/// Hard-coded configuration for the single Guild Wars 2 Wine prefix.
public enum GW2Profile {
    public static let bottleName = "Guild Wars 2"
    public static let installFolderName = "Guild Wars 2"
    public static let launcherExecutable = "Gw2-64.exe"
    public static let setupExecutable = "Gw2Setup-64.exe"

    /// Windows install path inside the prefix.
    public static let windowsInstallPath = "C:\\Program Files\\Guild Wars 2"

    /// Relative path from `drive_c` to the 64-bit launcher.
    public static let launcherRelativePath =
        "Program Files/Guild Wars 2/\(launcherExecutable)"

    /// Default launch arguments (empty unless troubleshooting).
    public static let defaultLaunchArguments = ""

    /// Troubleshooting flags documented on the GW2 Wiki Wine page.
    public static let troubleshootingFlags: [(label: String, args: String)] = [
        ("DirectX 9 (single-threaded)", "-dx9single"),
        ("DirectX 9", "-dx9"),
        ("Repair / image mode", "-image")
    ]

    /// Environment variables tuned for GW2 on Apple Silicon + D3DMetal.
    public static func environmentOverrides() -> [String: String] {
        [
            // GW2 Wiki: fixme spam causes memory leaks; silence all Wine debug output.
            "WINEDEBUG": "-all",
            "WINEARCH": "win64"
        ]
    }

    /// Apply GW2-specific defaults onto a fresh bottle configuration.
    public static func apply(to settings: inout BottleSettings) {
        settings.name = bottleName
        settings.windowsVersion = .win10
        settings.enhancedSync = .msync
        settings.dxvk = false
        settings.dxvkAsync = false
        settings.metalHud = false
        settings.avxEnabled = true
    }

    /// Registry and bottle flags that improve FPS on Apple Silicon Macs.
    public static func applyPerformance(to settings: inout BottleSettings) {
        settings.avxEnabled = true
        settings.enhancedSync = .msync
        settings.dxvk = false
        settings.metalHud = false
        settings.metalTrace = false
    }

    public static func launcherURL(in bottle: Bottle) -> URL {
        bottle.url
            .appending(path: "drive_c")
            .appending(path: launcherRelativePath)
    }

    public static func setupURL(in bottle: Bottle) -> URL {
        bottle.url
            .appending(path: "drive_c")
            .appending(path: setupExecutable)
    }

    public static func installDirectory(in bottle: Bottle) -> URL {
        bottle.url
            .appending(path: "drive_c")
            .appending(path: "Program Files")
            .appending(path: installFolderName)
    }

    public static func isInstalled(in bottle: Bottle) -> Bool {
        FileManager.default.fileExists(atPath: launcherURL(in: bottle).path(percentEncoded: false))
    }
}
