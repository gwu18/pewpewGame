// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PewPewCore",
    platforms: [
        .visionOS(.v2),
        .macOS(.v14),
    ],
    products: [
        .library(name: "GameCore", targets: ["GameCore"]),
        .library(name: "GestureCore", targets: ["GestureCore"]),
    ],
    targets: [
        .target(name: "GameCore"),
        .target(name: "GestureCore", dependencies: ["GameCore"]),
        .testTarget(name: "GameCoreTests", dependencies: ["GameCore"]),
        .testTarget(name: "GestureCoreTests", dependencies: ["GestureCore"]),
    ]
)
