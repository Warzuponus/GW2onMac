// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "GW2Kit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "GW2Kit",
            targets: ["GW2Kit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftPackageIndex/SemanticVersion.git", from: "0.3.0")
    ],
    targets: [
        .target(
            name: "GW2Kit",
            dependencies: ["SemanticVersion"]
        )
    ],
    swiftLanguageVersions: [.version("6")]
)
