import Agentic
import AgenticAWS
import AgenticModels
import AWSConnector
import TestFlows

extension AgenticProvidersFlowTesting {
    static func runBedrockModelProviderCatalogRealization()
        async throws -> [TestFlowDiagnostic]
    {
        let model = "eu.anthropic.claude-sonnet-4-6"
        let profileID: AgentModelProfileIdentifier =
            "aws_bedrock:claude_sonnet_4.6"
        let provider = BedrockModelProvider(
            runtime: BedrockModelProviderFixtureRuntime(),
            profiles: [
                BedrockModelProfiles.advisor(
                    model,
                    modelID: KnownModel.anthropic.`claude_sonnet_4.6`,
                    identifier: profileID,
                    title: "Claude Sonnet 4.6"
                ),
            ]
        )
        let catalogs = try await AgentModelCatalogs(
            modelProviders: [
                provider,
            ]
        )
        let profile = try catalogs.profiles.profile(
            profileID
        )

        _ = try catalogs.gateways.gateway(
            for: .aws_bedrock
        )

        try Expect.equal(
            profile.gatewayIdentifier,
            AgentModelGatewayIdentifier.aws_bedrock,
            "Bedrock provider profile gateway identifier"
        )
        try Expect.equal(
            profile.model,
            model,
            "Bedrock provider concrete model selector"
        )
        try Expect.equal(
            profile.modelID,
            KnownModel.anthropic.`claude_sonnet_4.6`,
            "Bedrock provider semantic model identifier"
        )
        try Expect.equal(
            profile.title,
            "Claude Sonnet 4.6",
            "Bedrock provider profile title"
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
                "model",
                profile.model
            ),
            .field(
                "gateway",
                profile.gatewayIdentifier.rawValue
            ),
        ]
    }

    static func runBedrockMultipleGatewayProviderRealization()
        async throws -> [TestFlowDiagnostic]
    {
        let primaryGatewayIdentifier =
            AgentModelGatewayIdentifier.aws_bedrock_us_east_1
        let secondaryGatewayIdentifier =
            AgentModelGatewayIdentifier.aws_bedrock_us_west_2

        let provider = BedrockModelProvider(
            gateways: [
                .init(
                    identifier: primaryGatewayIdentifier
                ) {
                    BedrockModelGateway(
                        identifier: primaryGatewayIdentifier,
                        runtime: BedrockModelProviderFixtureRuntime()
                    )
                },
                .init(
                    identifier: secondaryGatewayIdentifier
                ) {
                    BedrockModelGateway(
                        identifier: secondaryGatewayIdentifier,
                        runtime: BedrockModelProviderFixtureRuntime()
                    )
                },
            ],
            profiles: [
                BedrockModelProfiles.profile(
                    identifier: "aws_bedrock_us_east_1:fixture",
                    model: "fixture-model",
                    gatewayIdentifier: primaryGatewayIdentifier
                ),
                BedrockModelProfiles.profile(
                    identifier: "aws_bedrock_us_west_2:fixture",
                    model: "fixture-model",
                    gatewayIdentifier: secondaryGatewayIdentifier
                ),
            ]
        )

        let catalogs = try await AgentModelCatalogs(
            modelProviders: [
                provider,
            ]
        )

        let primary = try catalogs.gateways.gateway(
            for: primaryGatewayIdentifier
        )
        let secondary = try catalogs.gateways.gateway(
            for: secondaryGatewayIdentifier
        )

        try Expect.equal(
            primary.identifier,
            primaryGatewayIdentifier,
            "Bedrock provider realizes the primary configured gateway"
        )
        try Expect.equal(
            secondary.identifier,
            secondaryGatewayIdentifier,
            "Bedrock provider realizes the secondary configured gateway"
        )
        try Expect.equal(
            catalogs.gateways.gatewaysByIdentifier.count,
            2,
            "one Bedrock provider can supply multiple configured gateways"
        )

        return [
            .field(
                "primary_gateway",
                primary.identifier.rawValue
            ),
            .field(
                "secondary_gateway",
                secondary.identifier.rawValue
            ),
            .field(
                "gateway_count",
                String(catalogs.gateways.gatewaysByIdentifier.count)
            ),
        ]
    }
}

private struct BedrockModelProviderFixtureRuntime:
    BedrockModelRuntime
{
    func respond(
        _ request: Bedrock.Converse.Request,
        modelIdentifier: String,
        timeoutseconds: Int?
    ) async throws -> Bedrock.Converse.Response {
        .init(
            output: .message(
                .init(
                    role: .assistant,
                    content: [
                        .text("fixture"),
                    ]
                )
            ),
            stopReason: "end_turn"
        )
    }

    func stream(
        _ request: Bedrock.Converse.Request,
        modelIdentifier: String,
        timeoutseconds: Int?
    ) -> AsyncThrowingStream<Bedrock.Converse.StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}
