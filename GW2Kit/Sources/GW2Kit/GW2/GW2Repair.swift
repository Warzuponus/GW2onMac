//
//  GW2Repair.swift
//  GW2Kit
//
//  GW2onMac — common launcher repair helpers.
//

import Foundation

public enum GW2Repair {
    /// Remove stale `Gw2-64.tmp` lock files that block the launcher.
    @discardableResult
    public static func clearLauncherLock(in bottle: Bottle) -> Bool {
        let installDir = bottle.url
            .appending(path: "drive_c")
            .appending(path: "Program Files/Guild Wars 2")

        var removed = false
        for name in ["Gw2-64.tmp", "Gw2.tmp"] {
            let url = installDir.appending(path: name)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
                let size = (attrs[.size] as? NSNumber)?.intValue ?? -1
                if size == 0 {
                    try FileManager.default.removeItem(at: url)
                    removed = true
                }
            } catch {
                continue
            }
        }
        return removed
    }
}
