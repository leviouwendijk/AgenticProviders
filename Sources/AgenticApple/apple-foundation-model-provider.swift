import Agentic

public struct AppleFoundationModelProvider:
    AgentModelProvider
{
    public let descriptor = AgentModelProviderDescriptor(
        source: "apple_foundation_models",
        displayName: "Apple Foundation Models",
        metadata: [
            "provider": "apple",
            "privacy": "local_private",
        ]
    )

    public let gatewayIdentifier: AgentModelGatewayIdentifier

    public init(
        gatewayIdentifier: AgentModelGatewayIdentifier = .apple_foundation_models
    ) {
        self.gatewayIdentifier = gatewayIdentifier
    }

    public var gateways: [AgentModelGatewayFactory] {
        let gatewayIdentifier = gatewayIdentifier

        return [
            .init(
                identifier: gatewayIdentifier
            ) {
                AppleFoundationModelGateway(
                    identifier: gatewayIdentifier
                )
            },
        ]
    }

    public var profileProviders: [any AgentModelProfileProvider] {
        [
            AppleFoundationModelProfileProvider(
                gatewayIdentifier: gatewayIdentifier
            ),
        ]
    }
}
