// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Tico",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(name: "Tico", targets: ["Tico"])
    ],
    targets: [
        .target(
            name: "TicoMultitouchBridge",
            path: "Sources/TicoMultitouchBridge",
            publicHeadersPath: "include"
        ),
        .executableTarget(
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
