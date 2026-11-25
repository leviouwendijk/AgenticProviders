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
        .library(
            name: "AgenticHYAI",
            targets: ["AgenticHYAI"]
        ),

        .library(
            name: "AgenticOpenAI",
            targets: ["AgenticOpenAI"]
        ),
        .library(
            name: "AgenticAnthropic",
            targets: ["AgenticAnthropic"]
        ),
        .library(name: "AgenticProviderHTTP", targets: ["AgenticProviderHTTP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-agentic/Agentic.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Workspace.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/AWSConnector.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Primitives.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Milieu.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Cryptography.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Schema.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Macros.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "AgenticApple",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticModels", package: "Agentic"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Schema", package: "Schema"),
            ]
        ),
        .target(
            name: "AgenticAWS",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "Workspace", package: "Workspace"),
                .product(name: "AgenticModels", package: "Agentic"),
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
        .target(
            name: "AgenticHYAI",
            dependencies: [
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticModels", package: "Agentic"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Milieu", package: "Milieu"),
            ]
        ),

        .target(
            name: "AgenticProviderHTTP",
            dependencies: [
                .product(name: "Primitives", package: "Primitives"),
            ]
        ),
        .target(
            name: "AgenticOpenAI",
            dependencies: [
                "AgenticProviderHTTP",
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticModels", package: "Agentic"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Milieu", package: "Milieu"),
                .product(name: "Schema", package: "Schema"),
            ]
        ),
        .target(
            name: "AgenticAnthropic",
            dependencies: [
                "AgenticProviderHTTP",
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticModels", package: "Agentic"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Milieu", package: "Milieu"),
                .product(name: "Schema", package: "Schema"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets {
    switch target.type {
    case .regular, .executable, .test, .macro:
        var settings = target.swiftSettings ?? []

        settings.append(
            .treatAllWarnings(as: .error)
        )

        settings.append(
            .unsafeFlags(
                [
                    "-continue-building-after-errors"
                ]
            )
        )

        target.swiftSettings = settings

    case .plugin, .system, .binary:
        break

    @unknown default:
        break
    }
}
