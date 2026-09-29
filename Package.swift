// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "AgenticProviders",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AgenticApple",
            targets: ["AgenticApple"]
        ),
        .library(
            name: "AgenticAWS",
            targets: ["AgenticAWS"]
        ),
        .library(
            name: "AgenticOllama",
            targets: ["AgenticOllama"]
        ),

        // testing
        .executable(
            name: "t_ap_main",
            targets: ["AgenticProvidersTestFlows"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Agentic.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Workspace.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/AgenticModels.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/AWSConnector.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Primitives.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Milieu.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Cryptography.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Schema.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Macros.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/TestFlows.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "AgenticApple",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Schema", package: "Schema"),
            ]
        ),
        .target(
            name: "AgenticAWS",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "Workspace", package: "Workspace"),
                .product(name: "AgenticModels", package: "AgenticModels"),
                .product(name: "AWSConnector", package: "AWSConnector"),
                .product(name: "Schema", package: "Schema"),
                .product(name: "Macros", package: "Macros"),
            ]
        ),
        .target(
            name: "AgenticOllama",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Milieu", package: "Milieu"),
                .product(name: "Cryptography", package: "Cryptography"),
            ]
        ),

        .executableTarget(
            name: "AgenticProvidersTestFlows",
            dependencies: [
                "AgenticApple",
                "AgenticAWS",
                "AgenticOllama",
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticModels", package: "AgenticModels"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "AWSConnector", package: "AWSConnector"),
                .product(name: "Schema", package: "Schema"),
                .product(name: "TestFlows", package: "TestFlows"),
            ],
            path: "Testing/AgenticProvidersTestFlows"
        ),
    ],
    swiftLanguageModes: [.v6]
)
