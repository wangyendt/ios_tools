// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ios_tools",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ios_tools_lib",
            targets: ["ios_tools_lib"]),
        .executable(
            name: "LarkBotDemo",
            targets: ["LarkBotDemo"]),
        .executable(
            name: "LarkCustomBotDemo",
            targets: ["LarkCustomBotDemo"]),
        .executable(
            name: "WaynePrintDemo",
            targets: ["WaynePrintDemo"]),
        .executable(
            name: "AliyunOSSDemo",
            targets: ["AliyunOSSDemo"])
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ios_tools_lib",
            dependencies: [],
            path: "Sources/ios_tools",
            exclude: [
                "AliyunOSS/Demo",
                "LarkBot/Demo",
                "LarkCustomBot/Demo",
                "Tools/Demo"
            ],
            sources: [
                "AliyunOSS/AliyunOSS.swift",
                "Common",
                "LarkBot/LarkBot.swift",
                "LarkCustomBot/LarkCustomBot.swift",
                "Tools/WaynePrint.swift"
            ]),
        .executableTarget(
            name: "LarkBotDemo",
            dependencies: ["ios_tools_lib"],
            path: "Sources/ios_tools/LarkBot/Demo"),
        .executableTarget(
            name: "LarkCustomBotDemo",
            dependencies: ["ios_tools_lib"],
            path: "Sources/ios_tools/LarkCustomBot/Demo"),
        .executableTarget(
            name: "WaynePrintDemo",
            dependencies: ["ios_tools_lib"],
            path: "Sources/ios_tools/Tools/Demo/WaynePrint"),
        .executableTarget(
            name: "AliyunOSSDemo",
            dependencies: ["ios_tools_lib"],
            path: "Sources/ios_tools/AliyunOSS/Demo")
    ]
)
