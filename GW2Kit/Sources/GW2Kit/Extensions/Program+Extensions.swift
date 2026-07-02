//
//  Program+Extensions.swift
//  GW2Kit
//
//  TyriaSilicon — Guild Wars 2 launcher for Apple Silicon Macs.
//  Adapted from Whisky (GPL-3.0). See NOTICES.md in the repository root.
//

import Foundation
import AppKit
import os.log

extension Program {
    public func run() {
        if NSEvent.modifierFlags.contains(.shift) {
            runInTerminal()
        } else if url.lastPathComponent == GW2Profile.launcherExecutable {
            runViaShellScript()
        } else {
            runInWine()
        }
    }

    func runViaShellScript() {
        let arguments = settings.arguments
        let useBackend = bottle.settings.d3dMetalBackend

        Task.detached(priority: .userInitiated) {
            do {
                try GW2ShellLauncher.launch(
                    bottle: self.bottle,
                    arguments: arguments,
                    useD3dMetalBackend: useBackend
                )
            } catch {
                await MainActor.run {
                    self.showRunError(message: error.localizedDescription)
                }
            }
        }
    }

    func runInWine() {
        let arguments = settings.arguments.split { $0.isWhitespace }.map(String.init)
        let environment = generateEnvironment()

        Task.detached(priority: .userInitiated) {
            do {
                try await Wine.runProgram(
                    at: self.url, args: arguments, bottle: self.bottle, environment: environment
                )
            } catch {
                await MainActor.run {
                    self.showRunError(message: error.localizedDescription)
                }
            }
        }
    }

    public func generateTerminalCommand() -> String {
        Wine.generateRunCommand(
            at: url, bottle: bottle, args: settings.arguments, environment: generateEnvironment()
        )
    }

    public func runInTerminal() {
        let wineCmd = generateTerminalCommand().replacingOccurrences(of: "\\", with: "\\\\")

        let script = """
        tell application "Terminal"
            activate
            do script "\(wineCmd)"
        end tell
        """

        Task.detached(priority: .userInitiated) {
            var error: NSDictionary?
            guard let appleScript = NSAppleScript(source: script) else { return }
            appleScript.executeAndReturnError(&error)

            if let error,
               let description = error["NSAppleScriptErrorMessage"] as? String {
                Logger.gw2Kit.error("Failed to run terminal script \(error)")
                await self.showRunError(message: String(describing: description))
            }
        }
    }

    @MainActor private func showRunError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Failed to launch Guild Wars 2"
        alert.informativeText = "\(url.lastPathComponent): \(message)"
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
