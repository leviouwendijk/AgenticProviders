import Agentic

/// Installable Agentic model-provider composition for Ollama.
///
/// Endpoint resolution remains inside `OllamaModelGateway.resolve()`, which
/// reads `AGENTIC_MODEL_OLLAMA_ENDPOINT` through Milieu. Consumers such as the
/// CLI only need to install this provider; they do not need to know Ollama's
/// transport or endpoint configuration details.
public struct OllamaModelProvider: AgentModelProvider {
    public let descriptor = AgentModelProviderDescriptor(
        source: "ollama",
        displayName: "Ollama",
        metadata: [
            "provider": "ollama",
            "privacy": "local_private",
        ]
    )

    public let gatewayIdentifier: AgentModelGatewayIdentifier

    public init(
        gatewayIdentifier: AgentModelGatewayIdentifier = .ollama
    ) {
        self.gatewayIdentifier = gatewayIdentifier
    }

    public var gateways: [AgentModelGatewayFactory] {
        let gatewayIdentifier = gatewayIdentifier

        return [
            .init(
                identifier: gatewayIdentifier
            ) {
                try OllamaModelGateway.resolve(
                    identifier: gatewayIdentifier
                )
            },
        ]
    }

    public var profileProviders: [any AgentModelProfileProvider] {
        [
            OllamaModelProfileProvider(
                gatewayIdentifier: gatewayIdentifier
            ),
        ]
    }
}
