//
//  GPTKInstaller.swift
//  GW2Kit
//
//  Discovers a user-downloaded Game Porting Toolkit 4.x disk image or mounted
//  volume, installs Metal Shader Converter, and copies D3DMetal into the Wine runtime.
//

import Foundation

public enum GPTKInstallStep: Sendable, Equatable {
    case searching
    case mountingDMG(String)
    case installingShaderConverter
    case mountingEvaluationEnvironment
    case copyingD3DMetal
    case complete
}

public enum GPTKInstallerError: LocalizedError {
    case runtimeNotInstalled
    case sourceNotFound
    case mountFailed(String)
    case evaluationDMGNotFound
    case shaderConverterPackageNotFound
    case shaderConverterInstallFailed(String)
    case d3dMetalNotFound
    case copyFailed(String)

    public var errorDescription: String? {
        switch self {
        case .runtimeNotInstalled:
            return "Install the Wine runtime first — GW2onMac needs a destination folder for D3DMetal."
        case .sourceNotFound:
            return """
            Game Porting Toolkit 4.x was not found. Download it from Apple Developer, open the .dmg \
            (or choose the file below), then try again.
            """
        case .mountFailed(let detail):
            return "Could not mount the GPTK disk image: \(detail)"
        case .evaluationDMGNotFound:
            return "Evaluation environment disk image not found inside the Game Porting Toolkit folder."
        case .shaderConverterPackageNotFound:
            return "Metal Shader Converter installer package not found inside the Game Porting Toolkit folder."
        case .shaderConverterInstallFailed(let detail):
            return "Metal Shader Converter install failed: \(detail)"
        case .d3dMetalNotFound:
            return "D3DMetal.framework was not found inside the evaluation environment."
        case .copyFailed(let detail):
            return "Could not copy D3DMetal.framework: \(detail)"
        }
    }
}

/// Automates GPTK 4.x setup after the user downloads Apple's disk image.
public enum GPTKInstaller {
    public static let appleDownloadPage = URL(string: "https://developer.apple.com/download/all/")!
    public static let appleGPTKPage = URL(string: "https://developer.apple.com/games/game-porting-toolkit/")!

    private static let gptkVolumeNameFragment = "Game Porting Toolkit"
    private static let evaluationVolumeNameFragment = "Evaluation environment"

    /// Whether Apple's shader conversion tool from GPTK is on the system PATH.
    public static func isMetalShaderConverterInstalled() -> Bool {
        FileManager.default.isExecutableFile(atPath: "/usr/local/bin/metal-shaderconverter")
    }

    /// Best-effort discovery of GPTK without user interaction.
    public static func discoverSources() -> [URL] {
        var candidates: [URL] = []
        var seen = Set<String>()

        func append(_ url: URL) {
            let key = url.standardizedFileURL.path
            guard seen.insert(key).inserted else { return }
            candidates.append(url)
        }

        for volume in mountedVolumes() {
            let name = volume.lastPathComponent
            if name.localizedCaseInsensitiveContains(gptkVolumeNameFragment)
                || name.localizedCaseInsensitiveContains(evaluationVolumeNameFragment) {
                append(volume)
            }
        }

        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        if let items = try? FileManager.default.contentsOfDirectory(
            at: downloads,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for item in items where item.pathExtension.lowercased() == "dmg" {
                let name = item.deletingPathExtension().lastPathComponent
                if name.localizedCaseInsensitiveContains("game")
                    && name.localizedCaseInsensitiveContains("porting") {
                    append(item)
                }
            }
        }

        return candidates
    }

    /// Install GPTK components. Pass a specific `.dmg` or mounted volume, or `nil` to auto-discover.
    public static func install(
        from explicitSource: URL? = nil,
        progress: (@Sendable (GPTKInstallStep) -> Void)? = nil
    ) async throws {
        guard WineRuntimeInstaller.isRuntimeInstalled() else {
            throw GPTKInstallerError.runtimeNotInstalled
        }

        progress?(.searching)

        let source = try resolveSource(explicitSource)
        var mountedByUs: [URL] = []
        defer {
            for mount in mountedByUs.reversed() {
                detachVolume(at: mount)
            }
        }

        let gptkRoot: URL
        if source.pathExtension.lowercased() == "dmg" {
            progress?(.mountingDMG(source.lastPathComponent))
            let mount = try mountDiskImage(at: source)
            mountedByUs.append(mount)
            gptkRoot = mount
        } else {
            gptkRoot = source
        }

        let evaluationRoot = try await resolveEvaluationRoot(
            gptkRoot: gptkRoot,
            mountedByUs: &mountedByUs,
            progress: progress
        )

        if !isMetalShaderConverterInstalled() {
            let shaderPkg = try findShaderConverterPackage(in: gptkRoot)
            progress?(.installingShaderConverter)
            try await installPackage(at: shaderPkg)
        }

        guard let d3dMetal = findD3DMetalFramework(in: evaluationRoot) else {
            throw GPTKInstallerError.d3dMetalNotFound
        }

        progress?(.copyingD3DMetal)
        try copyD3DMetal(from: d3dMetal)

        progress?(.complete)
    }

    // MARK: - Discovery

    private static func resolveSource(_ explicit: URL?) throws -> URL {
        if let explicit {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: explicit.path, isDirectory: &isDir) {
                return explicit
            }
            throw GPTKInstallerError.sourceNotFound
        }

        let discovered = discoverSources()
        if let mounted = discovered.first(where: { $0.path.hasPrefix("/Volumes/") }) {
            return mounted
        }
        if let dmg = discovered.first(where: { $0.pathExtension.lowercased() == "dmg" }) {
            return dmg
        }
        throw GPTKInstallerError.sourceNotFound
    }

    private static func mountedVolumes() -> [URL] {
        let volumes = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: volumes,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
    }

    // MARK: - Evaluation environment

    private static func resolveEvaluationRoot(
        gptkRoot: URL,
        mountedByUs: inout [URL],
        progress: (@Sendable (GPTKInstallStep) -> Void)?
    ) async throws -> URL {
        if gptkRoot.lastPathComponent.localizedCaseInsensitiveContains(evaluationVolumeNameFragment) {
            return gptkRoot
        }

        if let existing = mountedVolumes().first(where: {
            $0.lastPathComponent.localizedCaseInsensitiveContains(evaluationVolumeNameFragment)
        }) {
            return existing
        }

        let evaluationDMG = try findEvaluationDMG(in: gptkRoot)
        progress?(.mountingEvaluationEnvironment)
        let mount = try mountDiskImage(at: evaluationDMG)
        mountedByUs.append(mount)
        return mount
    }

    private static func findEvaluationDMG(in gptkRoot: URL) throws -> URL {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: gptkRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            throw GPTKInstallerError.evaluationDMGNotFound
        }

        if let match = items.first(where: {
            $0.pathExtension.lowercased() == "dmg"
                && $0.lastPathComponent.localizedCaseInsensitiveContains("evaluation")
        }) {
            return match
        }
        throw GPTKInstallerError.evaluationDMGNotFound
    }

    private static func findShaderConverterPackage(in gptkRoot: URL) throws -> URL {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: gptkRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            throw GPTKInstallerError.shaderConverterPackageNotFound
        }

        if let match = items.first(where: {
            $0.pathExtension.lowercased() == "pkg"
                && $0.lastPathComponent.localizedCaseInsensitiveContains("metal shader converter")
        }) {
            return match
        }
        throw GPTKInstallerError.shaderConverterPackageNotFound
    }

    private static func findD3DMetalFramework(in root: URL) -> URL? {
        let preferred = root
            .appending(path: "redist/lib/external/D3DMetal.framework")
        if FileManager.default.fileExists(atPath: preferred.path) {
            return preferred
        }

        return findNamedFramework("D3DMetal.framework", under: root)
    }

    private static func findNamedFramework(_ name: String, under root: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let url as URL in enumerator {
            if url.lastPathComponent == name {
                return url
            }
        }
        return nil
    }

    // MARK: - Install actions

    private static func copyD3DMetal(from source: URL) throws {
        let destinationRoot = WineRuntimeInstaller.libraryFolder
            .appending(path: "Wine/lib/external")
        let destination = destinationRoot.appending(path: "D3DMetal.framework")

        try FileManager.default.createDirectory(at: destinationRoot, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        do {
            try FileManager.default.copyItem(at: source, to: destination)
        } catch {
            throw GPTKInstallerError.copyFailed(error.localizedDescription)
        }
    }

    private static let hdiutilURL = URL(fileURLWithPath: "/usr/bin/hdiutil")

    private static func mountDiskImage(at url: URL) throws -> URL {
        let process = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.executableURL = hdiutilURL
        process.arguments = ["attach", "-plist", "-nobrowse", "-readonly", url.path]
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let detail = String(data: errData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw GPTKInstallerError.mountFailed(detail?.isEmpty == false ? detail! : url.lastPathComponent)
        }

        guard let mountPoint = parseMountPoint(from: outData) else {
            throw GPTKInstallerError.mountFailed("Could not read mount point from hdiutil.")
        }

        return URL(fileURLWithPath: mountPoint, isDirectory: true)
    }

    /// `hdiutil attach -plist` returns `{ "system-entities": [...] }` on recent macOS; older releases used a top-level array.
    private static func parseMountPoint(from data: Data) -> String? {
        guard !data.isEmpty,
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) else {
            return nil
        }

        let entities: [[String: Any]]
        if let dict = plist as? [String: Any], let systemEntities = dict["system-entities"] as? [[String: Any]] {
            entities = systemEntities
        } else if let legacy = plist as? [[String: Any]] {
            entities = legacy
        } else {
            return nil
        }

        return entities.compactMap { $0["mount-point"] as? String }.first
    }

    private static func detachVolume(at mountPoint: URL) {
        let process = Process()
        process.executableURL = hdiutilURL
        process.arguments = ["detach", mountPoint.path, "-quiet"]
        try? process.run()
        process.waitUntilExit()
    }

    private static func installPackage(at pkgURL: URL) async throws {
        let shellSafe = pkgURL.path.replacingOccurrences(of: "'", with: "'\\''")
        let script = "do shell script \"installer -pkg '\(shellSafe)' -target /\" with administrator privileges"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]

            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: GPTKInstallerError.shaderConverterInstallFailed(
                        "Installer exited with status \(proc.terminationStatus). You may need to approve the install in System Settings."
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: GPTKInstallerError.shaderConverterInstallFailed(error.localizedDescription))
            }
        }
    }
}
