// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ios_tools",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .watchOS(.v6)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ios_tools",
            targets: ["ios_tools"]),
        .executable(
            name: "LarkBotDemo",
            targets: ["LarkBotDemo"]),
        .executable(
            name: "LarkCustomBotDemo",
            targets: ["LarkCustomBotDemo"])
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ios_tools",
            path: "Sources/ios_tools",
            exclude: ["LarkBot/Demo", "LarkCustomBot/Demo"]),
        .executableTarget(
            name: "LarkBotDemo",
            dependencies: ["ios_tools"],
            path: "Sources/ios_tools/LarkBot/Demo"),
        .executableTarget(
            name: "LarkCustomBotDemo",
            dependencies: ["ios_tools"],
            path: "Sources/ios_tools/LarkCustomBot/Demo")
    ]
)
