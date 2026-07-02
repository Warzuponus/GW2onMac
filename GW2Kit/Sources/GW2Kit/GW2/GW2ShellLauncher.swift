//
//  GW2ShellLauncher.swift
//  GW2Kit
//
//  Launches Gw2-64.exe via the bundled launch-gw2.sh (same path as manual dev scripts).
//

import Foundation
import os.log

public enum GW2ShellLauncherError: LocalizedError {
    case scriptMissing
    case launchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .scriptMissing:
            return "launch-gw2.sh was not found in the app bundle."
        case .launchFailed(let detail):
            return detail
        }
    }
}

public enum GW2ShellLauncher {
    /// Launch Guild Wars 2 using the bundled shell script (matches `./Scripts/launch-gw2.sh`).
    public static func launch(
        bottle: Bottle,
        arguments: String,
        useD3dMetalBackend: Bool
    ) throws {
        if !WineRuntimeInstaller.isBundledD3DMetalComplete() {
            throw GW2ShellLauncherError.launchFailed(
                "GPTK libraries are incomplete. Re-run Install GPTK — need D3DMetal.framework and libd3dshared.dylib in Wine/lib/external/."
            )
        }

        GW2RuntimePreparer.ensureNativeDylibsBundled()

        guard let script = launchScriptURL() else {
            throw GW2ShellLauncherError.scriptMissing
        }

        let bundleID = applicationSupportBundleID(for: bottle)

        var env = ProcessInfo.processInfo.environment
        env["GW2ONMAC_BUNDLE_ID"] = bundleID
        env["WINEPREFIX"] = bottle.url.path
        env["GW2ONMAC_LIBD3DSHARED"] = "1"
        env["GW2ONMAC_D3DMETAL"] = useD3dMetalBackend ? "1" : "0"

        var args = [script.path(percentEncoded: false)]
        if !arguments.isEmpty {
            args.append(contentsOf: arguments.split { $0.isWhitespace }.map(String.init))
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = args
        process.environment = env

        Logger.gw2Kit.info(
            "Launching GW2 via shell script (bundle=\(bundleID, privacy: .public), d3dmetal=\(useD3dMetalBackend, privacy: .public))"
        )

        try process.run()
    }

    private static func launchScriptURL() -> URL? {
        if let bundled = Bundle.main.url(forResource: "launch-gw2", withExtension: "sh") {
            return bundled
        }

        let devPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Scripts/launch-gw2.sh")

        if FileManager.default.isExecutableFile(atPath: devPath.path) {
            return devPath
        }
        return nil
    }

    /// Resolve which Application Support folder owns the runtime for this bottle.
    private static func applicationSupportBundleID(for bottle: Bottle) -> String {
        let path = bottle.url.path
        if path.contains(AppPaths.legacyBundleIdentifier) {
            return AppPaths.legacyBundleIdentifier
        }
        return AppPaths.bundleIdentifier
    }
}
