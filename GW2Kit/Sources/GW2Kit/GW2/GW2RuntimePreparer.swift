//
//  GW2RuntimePreparer.swift
//  GW2Kit
//
//  Ensures Wine native dylibs (freetype, libpng) are present before launch.
//

import Foundation

public enum GW2RuntimePreparer {
    /// Verify bundled x86_64 dylibs exist; run bundle-native-dylibs.sh when possible.
    public static func ensureNativeDylibsBundled() {
        let native = WineRuntimeInstaller.nativeDylibFolder
        let freetype = native.appending(path: "libfreetype.6.dylib")
        let libpng = native.appending(path: "libpng16.16.dylib")

        if FileManager.default.fileExists(atPath: freetype.path),
           FileManager.default.fileExists(atPath: libpng.path) {
            return
        }

        guard let script = bundleNativeDylibsScriptURL() else { return }

        let wineRoot = WineRuntimeInstaller.libraryFolder.appending(path: "Wine")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path(percentEncoded: false), wineRoot.path(percentEncoded: false)]
        process.environment = ProcessInfo.processInfo.environment
        try? process.run()
        process.waitUntilExit()
    }

    private static func bundleNativeDylibsScriptURL() -> URL? {
        if let bundled = Bundle.main.url(forResource: "bundle-native-dylibs", withExtension: "sh") {
            return bundled
        }

        let devPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Scripts/bundle-native-dylibs.sh")

        if FileManager.default.isExecutableFile(atPath: devPath.path) {
            return devPath
        }
        return nil
    }
}
