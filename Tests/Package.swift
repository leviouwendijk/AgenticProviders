// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "AgenticProvidersTests",
    platforms: [
        .macOS(.v13)
    ],
    products: [

        // PACKAGES TO DO:
        // ....AgenticGoogle
        // ....AgenticMeta

        // testing
        .executable(
            name: "t_ap_main",
            targets: ["AgenticProvidersTestFlows"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-agentic/Agentic.git", branch: "master"),
        .package(url: "https://github.com/swift-sdk/AWSConnector.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Primitives.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Schema.git", branch: "master"),
        .package(url: "https://github.com/swift-tooling/TestFlows.git", branch: "master"),
        .package(path: ".."),
    ],
    targets: [

        .executableTarget(
            name: "AgenticProvidersTestFlows",
            dependencies: [
                .product(name: "AgenticApple", package: "AgenticProviders"),
                .product(name: "AgenticAWS", package: "AgenticProviders"),
                .product(name: "AgenticOllama", package: "AgenticProviders"),
                .product(name: "AgenticHYAI", package: "AgenticProviders"),
                .product(name: "AgenticOpenAI", package: "AgenticProviders"),
                .product(name: "AgenticAnthropic", package: "AgenticProviders"),
                .product(name: "AgenticProviderHTTP", package: "AgenticProviders"),
                .product(name: "Agentic", package: "Agentic"),
                .product(name: "AgenticModels", package: "Agentic"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "AWSConnector", package: "AWSConnector"),
                .product(name: "Schema", package: "Schema"),
                .product(name: "TestFlows", package: "TestFlows"),
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
