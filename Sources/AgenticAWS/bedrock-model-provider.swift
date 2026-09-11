import Agentic

public struct BedrockModelProvider:
    AgentModelProvider
{
    public let descriptor = AgentModelProviderDescriptor(
        source: "aws_bedrock",
        displayName: "AWS Bedrock",
        metadata: [
            "provider": "aws",
            "privacy": "private_cloud",
        ]
    )

    public let profiles: [AgentModelProfile]
    public let metadata: [String: String]
    public let diagnostics: BedrockDiagnostics

    private let storedGateways: [AgentModelGatewayFactory]

    public init(
        profiles: [AgentModelProfile],
        metadata: [String: String] = [:],
        diagnostics: BedrockDiagnostics = .disabled
    ) {
        let gatewayIdentifier = AgentModelGatewayIdentifier.aws_bedrock

        self.profiles = profiles
        self.metadata = metadata
        self.diagnostics = diagnostics
        self.storedGateways = [
            .init(
                identifier: gatewayIdentifier
            ) {
                try BedrockModelGateway.resolve(
                    identifier: gatewayIdentifier,
                    metadata: metadata,
                    diagnostics: diagnostics
                )
            },
        ]
    }

    public init(
        runtime: any BedrockModelRuntime,
        profiles: [AgentModelProfile],
        metadata: [String: String] = [:],
        diagnostics: BedrockDiagnostics = .disabled
    ) {
        let gatewayIdentifier = AgentModelGatewayIdentifier.aws_bedrock

        self.profiles = profiles
        self.metadata = metadata
        self.diagnostics = diagnostics
        self.storedGateways = [
            .init(
                identifier: gatewayIdentifier
            ) {
                BedrockModelGateway(
                    identifier: gatewayIdentifier,
                    runtime: runtime,
                    metadata: metadata,
                    diagnostics: diagnostics
                )
            },
        ]
    }

    public init(
        gateways: [AgentModelGatewayFactory],
        profiles: [AgentModelProfile]
    ) {
        self.profiles = profiles
        self.metadata = [:]
        self.diagnostics = .disabled
        self.storedGateways = gateways
    }

    public var gateways: [AgentModelGatewayFactory] {
        storedGateways
    }

    public var profileProviders: [any AgentModelProfileProvider] {
        [
            BedrockModelProfileProvider(
                profiles: profiles
            ),
        ]
    }
}
