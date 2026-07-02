//
//  FileHandle+Extensions.swift
//  GW2Kit
//
//  TyriaSilicon — Guild Wars 2 launcher for Apple Silicon Macs.
//  Adapted from Whisky (GPL-3.0). See NOTICES.md in the repository root.
//

import Foundation
import os.log
import SemanticVersion

extension FileHandle {
    func write(line: String) {
        do {
            guard let data = line.data(using: .utf8) else { return }
            try write(contentsOf: data)
        } catch {
            Logger.gw2Kit.info("Failed to write line: \(error)")
        }
    }

    func writeApplicaitonInfo() {
        let macOSVersion = ProcessInfo.processInfo.operatingSystemVersion
        var header = String()
        header += "GW2onMac Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "")\n"
        header += "Date: \(ISO8601DateFormatter().string(from: Date.now))\n"
        header += "macOS Version: \(macOSVersion.majorVersion).\(macOSVersion.minorVersion).\(macOSVersion.patchVersion)\n\n"
        write(line: header)
    }

    func writeInfo(for process: Process) {
        var header = String()

        if let arguments = process.arguments {
            header += "Arguments: \(arguments.joined(separator: " "))\n\n"
        }

        if let environment = process.environment, !environment.isEmpty {
            header += "Environment:\n\(environment as AnyObject)\n\n"
        }

        write(line: header)
    }

    func writeInfo(for bottle: Bottle) {
        var header = String()
        header += "Bottle Name: \(bottle.settings.name)\n"
        header += "Bottle URL: \(bottle.url.path)\n\n"

        if let version = WineRuntimeInstaller.runtimeVersion() {
            header += "Wine Runtime Version: \(version.major).\(version.minor).\(version.patch)\n"
        }
        header += "Windows Version: \(bottle.settings.windowsVersion)\n"
        header += "Enhanced Sync: \(bottle.settings.enhancedSync)\n\n"
        write(line: header)
    }
}
