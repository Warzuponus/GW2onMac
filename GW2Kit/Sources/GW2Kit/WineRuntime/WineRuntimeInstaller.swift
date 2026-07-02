//
//  WineRuntimeInstaller.swift
//  GW2Kit
//
//  GW2onMac — Guild Wars 2 launcher for Apple Silicon Macs.
//  Adapted from Whisky (GPL-3.0). See NOTICES.md in the repository root.
//

import Foundation
import SemanticVersion

public class WineRuntimeInstaller {
    /// Application support folder for GW2onMac runtime files (falls back to legacy TyriaSilicon path).
    public static let applicationFolder = AppPaths.applicationSupport

    /// Root folder for Wine libraries, DXVK overlays, and bundled scripts.
    public static let libraryFolder = applicationFolder.appending(path: "Libraries")

    /// Installed `wine64` binary directory.
    public static let binFolder: URL = libraryFolder.appending(path: "Wine").appending(path: "bin")

    /// x86_64 dylibs bundled for Wine (`libfreetype`, etc.).
    public static let nativeDylibFolder: URL = libraryFolder.appending(path: "Wine").appending(path: "lib/native")

    /// `DYLD_LIBRARY_PATH` entries required when launching Wine on Apple Silicon.
    public static var nativeDyldLibraryPath: String {
        var paths: [String] = []
        if FileManager.default.fileExists(atPath: nativeDylibFolder.path) {
            paths.append(nativeDylibFolder.path)
        }
        for fallback in ["/usr/local/lib", "/usr/local/opt/libpng/lib"] {
            if FileManager.default.fileExists(atPath: fallback) {
                paths.append(fallback)
            }
        }
        return paths.joined(separator: ":")
    }

    /// Default URL for the self-built runtime tarball (override via env for local testing).
    public static var runtimeDownloadURL: URL {
        ReleaseConfiguration.runtimeDownloadURL
    }

    public static var versionPlistURL: URL {
        ReleaseConfiguration.versionPlistURL
    }

    /// Application Support folder for fresh runtime installs (always the new bundle ID).
    public static var installTargetFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: AppPaths.bundleIdentifier)
    }

    public static func isRuntimeInstalled() -> Bool {
        runtimeVersion() != nil && FileManager.default.fileExists(atPath: wine64Binary.path)
    }

    public static var wine64Binary: URL {
        binFolder.appending(path: "wine64")
    }

    public static func install(from tarball: URL) throws {
        let target = installTargetFolder
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

        let libraries = target.appending(path: "Libraries")
        if FileManager.default.fileExists(atPath: libraries.path) {
            try FileManager.default.removeItem(at: libraries)
        }

        try Tar.untar(tarBall: tarball, toURL: target)
    }

    /// Download the runtime tarball and install it into Application Support.
    public static func downloadAndInstallRuntime(
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appending(path: "GW2onMac-runtime-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let tarball = tempDir.appending(path: "Libraries.tar.gz")

        try await HTTPDownload.download(
            from: runtimeDownloadURL,
            to: tarball,
            progress: { fraction in
                progress?(fraction * 0.9)
            }
        )

        progress?(0.95)
        try install(from: tarball)
        progress?(1.0)
    }

    public static func uninstall() {
        try? FileManager.default.removeItem(at: libraryFolder)
    }

    public static func shouldUpdateRuntime() async -> (Bool, SemanticVersion) {
        let localVersion = runtimeVersion()
        let remoteVersion = await fetchRemoteVersion()

        if let localVersion, let remoteVersion, localVersion < remoteVersion {
            return (true, remoteVersion)
        }

        return (false, SemanticVersion(0, 0, 0))
    }

    private static func fetchRemoteVersion() async -> SemanticVersion? {
        await withCheckedContinuation { continuation in
            URLSession(configuration: .ephemeral).dataTask(with: URLRequest(url: versionPlistURL)) { data, _, error in
                guard error == nil, let data else {
                    continuation.resume(returning: nil)
                    return
                }

                do {
                    let remoteInfo = try PropertyListDecoder().decode(WineRuntimeVersion.self, from: data)
                    continuation.resume(returning: remoteInfo.version)
                } catch {
                    continuation.resume(returning: nil)
                }
            }.resume()
        }
    }

    public static func runtimeVersion() -> SemanticVersion? {
        for name in ["GW2onMacWineVersion", "TyriaWineVersion"] {
            let versionPlist = libraryFolder
                .appending(path: name)
                .appendingPathExtension("plist")

            guard FileManager.default.fileExists(atPath: versionPlist.path) else { continue }

            do {
                let data = try Data(contentsOf: versionPlist)
                let info = try PropertyListDecoder().decode(WineRuntimeVersion.self, from: data)
                return info.version
            } catch {
                continue
            }
        }
        return nil
    }

    /// Folder where GPTK copies D3DMetal.framework and libd3dshared.dylib.
    public static var d3dMetalExternalFolder: URL {
        libraryFolder.appending(path: "Wine/lib/external")
    }

    /// Detect whether Apple Game Porting Toolkit / D3DMetal is available for DirectX 11 (GW2 default).
    public static func isD3DMetalAvailable() -> Bool {
        if isBundledD3DMetalComplete() {
            return true
        }

        let legacyPaths = [
            "/usr/local/lib/d3dmetal",
            "/opt/homebrew/lib/d3dmetal",
            libraryFolder.appending(path: "D3DMetal").path
        ]
        return legacyPaths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    /// Bundled GPTK layout requires both D3DMetal.framework and libd3dshared.dylib.
    public static func isBundledD3DMetalComplete() -> Bool {
        let external = d3dMetalExternalFolder
        let framework = external.appending(path: "D3DMetal.framework").path
        let libd3dshared = external.appending(path: "libd3dshared.dylib").path
        return FileManager.default.fileExists(atPath: framework)
            && FileManager.default.fileExists(atPath: libd3dshared)
    }

    /// Path to bundled `libd3dshared.dylib` (always safe to set when GPTK is installed).
    public static func d3dMetalLibraryOverrides() -> [String: String] {
        let libd3dshared = d3dMetalExternalFolder.appending(path: "libd3dshared.dylib")
        guard FileManager.default.fileExists(atPath: libd3dshared.path) else {
            return [:]
        }

        return [
            "CX_APPLEGPTK_LIBD3DSHARED_PATH": libd3dshared.path
        ]
    }

    /// Forces all Wine rendering through D3DMetal. Required for in-game DirectX 11 but breaks CEF launcher UI.
    public static func d3dMetalBackendOverrides() -> [String: String] {
        guard isBundledD3DMetalComplete() else {
            return [:]
        }

        return [
            "CX_ACTIVE_GRAPHICS_BACKEND": "d3dmetal"
        ]
    }

    /// Library path + optional backend override (v0.1.6 applied both unconditionally and broke the launcher).
    public static func d3dMetalEnvironmentOverrides(enableBackend: Bool) -> [String: String] {
        var result = d3dMetalLibraryOverrides()
        if enableBackend {
            result.merge(d3dMetalBackendOverrides()) { _, new in new }
        }
        return result
    }
}

public struct WineRuntimeVersion: Codable {
    public var version: SemanticVersion
    public var crossoverSourceVersion: String?
    public var wineVersion: String?

    public init(version: SemanticVersion = SemanticVersion(0, 0, 0)) {
        self.version = version
    }
}

// MARK: - Legacy aliases (TyriaSilicon / TyriaWine)

public typealias TyriaWineInstaller = WineRuntimeInstaller
public typealias TyriaWineVersion = WineRuntimeVersion

public extension WineRuntimeInstaller {
    static func isTyriaWineInstalled() -> Bool { isRuntimeInstalled() }
    static func tyriaWineVersion() -> SemanticVersion? { runtimeVersion() }
    static func shouldUpdateTyriaWine() async -> (Bool, SemanticVersion) { await shouldUpdateRuntime() }
}
