import Agentic
import Milieu

/// Installable Agentic model-provider composition for Ollama.
///
/// Endpoint resolution remains inside `OllamaModelGateway.resolve()`, which
/// reads the configured environment symbol through Milieu. Consumers such as
/// the CLI only need to install this provider; they do not need to know Ollama's
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
    public let endpointSymbol: String

    public init(
        gatewayIdentifier: AgentModelGatewayIdentifier = .ollama,
        endpointSymbol: String = OllamaModelGateway.endpointSymbol
    ) {
        self.gatewayIdentifier = gatewayIdentifier
        self.endpointSymbol = endpointSymbol
    }

    public var gateways: [AgentModelGatewayFactory] {
        let gatewayIdentifier = gatewayIdentifier
        let endpointSymbol = endpointSymbol

        return [
            .init(
                identifier: gatewayIdentifier,
                resolve: {
                    do {
                        return .available(
                            try OllamaModelGateway.resolve(
                                identifier: gatewayIdentifier,
                                endpointSymbol: endpointSymbol
                            )
                        )
                    } catch let error as EnvironmentExtractableError {
                        switch error {
                        case .missing(let symbol):
                            return .unavailable(
                                .init(
                                    kind: .missing_configuration,
                                    message: "Ollama endpoint is not configured.",
                                    metadata: [
                                        "symbol": symbol,
                                        "state": "missing",
                                    ]
                                )
                            )

                        case .empty(let symbol):
                            return .unavailable(
                                .init(
                                    kind: .missing_configuration,
                                    message: "Ollama endpoint configuration is empty.",
                                    metadata: [
                                        "symbol": symbol,
                                        "state": "empty",
                                    ]
                                )
                            )

                        case .inferenceRequired:
                            throw error
                        }
                    } catch let error as OllamaGatewayError {
                        switch error {
                        case .invalidEndpoint(let value):
                            return .unavailable(
                                .init(
                                    kind: .invalid_configuration,
                                    message: "Ollama endpoint configuration is invalid.",
                                    metadata: [
                                        "value": value,
                                    ]
                                )
                            )

                        case .missingTLSCACertificateConfiguration(
                            let symbol
                        ):
                            return .unavailable(
                                .init(
                                    kind: .missing_configuration,
                                    message: "Ollama TLS CA certificate configuration is missing.",
                                    metadata: [
                                        "symbol": symbol,
                                        "state": "missing",
                                    ]
                                )
                            )

                        default:
                            throw error
                        }
                    }
                }
            ),
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
