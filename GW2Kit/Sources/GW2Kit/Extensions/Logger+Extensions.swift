//
//  Logger+Extensions.swift
//  GW2Kit
//
//  TyriaSilicon — Guild Wars 2 launcher for Apple Silicon Macs.
//  Adapted from Whisky (GPL-3.0). See NOTICES.md in the repository root.
//

import Foundation
import os.log

public extension Logger {
    static let gw2Kit = Logger(
        subsystem: AppPaths.bundleIdentifier, category: "GW2Kit"
    )
}
