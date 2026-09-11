import Agentic
import AgenticApple
import AgenticModels
import TestFlows

extension AgenticProvidersFlowTesting {
    static func runAppleModelProviderCatalogRealization()
        async throws -> [TestFlowDiagnostic]
    {
        let provider = AppleFoundationModelProvider()
        let catalogs = try await AgentModelCatalogs(
            modelProviders: [
                provider,
            ]
        )
        let profile = try catalogs.profiles.profile(
            .apple_foundation_models
        )

        _ = try catalogs.gateways.gateway(
            for: .apple_foundation_models
        )

        try Expect.equal(
            profile.gatewayIdentifier,
            AgentModelGatewayIdentifier.apple_foundation_models,
            "Apple provider profile gateway identifier"
        )
        try Expect.equal(
            profile.title,
            "Apple Foundation Models",
            "Apple provider profile title"
        )
        try Expect.true(
            profile.capabilities.contains(
                .tool_use
            ),
            "Apple provider advertises native tool use"
        )
        try Expect.true(
            profile.capabilities.contains(
                .structured_output
            ),
            "Apple provider advertises structured output"
        )

        return [
            .field(
                "provider",
                provider.descriptor.displayName
            ),
            .field(
                "profile",
                profile.identifier.rawValue
            ),
            .field(
                "gateway",
                profile.gatewayIdentifier.rawValue
            ),
        ]
    }
}
