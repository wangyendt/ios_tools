// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ios_tools",
    platforms: [
        .macOS(.v10_15),      // 支持 macOS 10.15+，与代码标注一致
        .iOS(.v13),           // 支持 iOS 13+，与代码标注一致（iPadOS会自动跟随iOS支持）
        .watchOS(.v6)         // 支持 watchOS 6.0+，与代码标注一致
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
            targets: ["AliyunOSSDemo"]),
        .executable(
            name: "OpenAIDemo",
            targets: ["OpenAIDemo"]),
        .executable(
            name: "CrossCommDemo",
            targets: ["CrossCommDemo"])
    ],
    targets: [
        // 核心库目标，只包含实际的功能代码
        .target(
            name: "ios_tools_lib",
            dependencies: [],
            path: "Sources/ios_tools",
            exclude: [
                "AliyunOSS/Demo",
                "LarkBot/Demo",
                "LarkCustomBot/Demo",
                "Tools/Demo",
                "OpenAI/Demo",
                "CrossComm/Demo",
                // 排除所有可能包含 @main 的文件
                "AliyunOSS/Demo/main.swift",
                "LarkBot/Demo/main.swift",
                "LarkCustomBot/Demo/main.swift",
                "Tools/Demo/WaynePrint/main.swift",
                "OpenAI/Demo/main.swift",
                "CrossComm/Demo/main.swift"
            ],
            sources: [
                "AliyunOSS/AliyunOSS.swift",
                "LarkBot/LarkBot.swift",
                "LarkCustomBot/LarkCustomBot.swift",
                "Tools/WaynePrint.swift",
                "OpenAI/OpenAI.swift",
                "CrossComm/CrossComm.swift",
                "Common"
            ]),
        
        // Demo 目标，分开管理
        .executableTarget(
            name: "AliyunOSSDemo",
            dependencies: ["ios_tools_lib"],
            path: "Sources/ios_tools/AliyunOSS/Demo",
            sources: ["main.swift"]),
        .executableTarget(
            name: "LarkBotDemo",
            dependencies: ["ios_tools_lib"],
            path: "Sources/ios_tools/LarkBot/Demo",
            sources: ["main.swift"]),
        .executableTarget(
            name: "LarkCustomBotDemo",
            dependencies: ["ios_tools_lib"],
            path: "Sources/ios_tools/LarkCustomBot/Demo",
            sources: ["main.swift"]),
        .executableTarget(
            name: "WaynePrintDemo",
            dependencies: ["ios_tools_lib"],
            path: "Sources/ios_tools/Tools/Demo/WaynePrint",
            sources: ["main.swift"]),
        .executableTarget(
            name: "OpenAIDemo",
            dependencies: ["ios_tools_lib"],
            path: "Sources/ios_tools/OpenAI/Demo",
            sources: ["main.swift"]),
        .executableTarget(
            name: "CrossCommDemo",
            dependencies: ["ios_tools_lib"],
            path: "Sources/ios_tools/CrossComm/Demo",
            sources: ["main.swift"])
    ]
)
