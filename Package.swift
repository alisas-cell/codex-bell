// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexBell",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodexBellCore", targets: ["CodexBellCore"]),
        .executable(name: "codex-bell-hook", targets: ["CodexBellHook"]),
        .executable(name: "CodexBell", targets: ["CodexBellApp"]),
    ],
    targets: [
        .target(name: "CodexBellCore"),
        .executableTarget(name: "CodexBellHook", dependencies: ["CodexBellCore"]),
        .executableTarget(
            name: "CodexBellApp",
            dependencies: ["CodexBellCore"],
            exclude: ["Resources"]
        ),
        .testTarget(name: "CodexBellCoreTests", dependencies: ["CodexBellCore"]),
    ]
)
