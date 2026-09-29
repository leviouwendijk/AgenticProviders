import Agentic
import Milieu

public struct HYAIModelProvider: AgentModelProvider {
    public let descriptor = AgentModelProviderDescriptor(
        source: "hyai",
        displayName: "HostYourAI",
        metadata: [
            "provider": "hostyourai",
            "privacy": "private_cloud",
        ]
    )

    public let gatewayIdentifier:
        AgentModelGatewayIdentifier
    public let apiKeySymbol: String
    public let endpoint: String
    public let autoPolicy: HYAIPolicy
    public let autoTask: HYAITask?

    public init(
        gatewayIdentifier: AgentModelGatewayIdentifier = .hyai,
        apiKeySymbol: String = HYAIModelGateway.apiKeySymbol,
        endpoint: String = HYAIModelConfiguration.defaultEndpoint,
        autoPolicy: HYAIPolicy = .balanced,
        autoTask: HYAITask? = nil
    ) {
        self.gatewayIdentifier = gatewayIdentifier
        self.apiKeySymbol = apiKeySymbol
        self.endpoint = endpoint
        self.autoPolicy = autoPolicy
        self.autoTask = autoTask
    }

    public var gateways: [AgentModelGatewayFactory] {
        let gatewayIdentifier = gatewayIdentifier
        let apiKeySymbol = apiKeySymbol
        let endpoint = endpoint
        let autoPolicy = autoPolicy
        let autoTask = autoTask

        return [
            .init(
                identifier: gatewayIdentifier,
                resolve: {
                    do {
                        return .available(
                            try HYAIModelGateway.resolve(
                                identifier: gatewayIdentifier,
                                apiKeySymbol: apiKeySymbol,
                                endpoint: endpoint,
                                autoPolicy: autoPolicy,
                                autoTask: autoTask
                            )
                        )
                    } catch let error as EnvironmentExtractableError {
                        switch error {
                        case .missing(let symbol):
                            return .unavailable(
                                .init(
                                    kind: .missing_configuration,
                                    message: "HostYourAI API key is not configured.",
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
                                    message: "HostYourAI API key configuration is empty.",
                                    metadata: [
                                        "symbol": symbol,
                                        "state": "empty",
                                    ]
                                )
                            )

                        case .inferenceRequired:
                            throw error
                        }
                    } catch let error as HYAIGatewayError {
                        switch error {
                        case .invalidEndpoint(let value):
                            return .unavailable(
                                .init(
                                    kind: .invalid_configuration,
                                    message: "HostYourAI endpoint configuration is invalid.",
                                    metadata: [
                                        "value": value,
                                    ]
                                )
                            )

                        case .emptyAPIKey:
                            return .unavailable(
                                .init(
                                    kind: .missing_configuration,
                                    message: "HostYourAI API key configuration is empty.",
                                    metadata: [
                                        "symbol": apiKeySymbol,
                                        "state": "empty",
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

    public var profileProviders:
        [any AgentModelProfileProvider]
    {
        [
            HYAIModelProfileProvider(
                gatewayIdentifier: gatewayIdentifier,
                autoPolicy: autoPolicy
            ),
        ]
    }
}
