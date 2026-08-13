// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Tico",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(name: "TicoApplication", targets: ["Tico"]),
        .executable(name: "Tico", targets: ["TicoLauncher"])
    ],
    targets: [
        .target(
            name: "TicoMultitouchBridge",
            path: "Sources/TicoMultitouchBridge",
            publicHeadersPath: "include"
        ),
        .target(
            name: "Tico",
            dependencies: ["TicoMultitouchBridge"],
            path: "Sources/Tico",
            exclude: [
                "AGENTS.md",
                "Services/AGENTS.md",
                "Stores/AGENTS.md",
                "Views/AGENTS.md"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "TicoLauncher",
            dependencies: ["Tico"],
            path: "Sources/TicoLauncher"
        ),
        .testTarget(
            name: "TicoTests",
            dependencies: ["Tico"],
            path: "Tests/TicoTests",
            exclude: ["AGENTS.md"],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
