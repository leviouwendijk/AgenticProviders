import Agentic
import AWSConnector
import Foundation

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
                identifier: gatewayIdentifier,
                resolve: {
                    // Missing or unusable AWS configuration leaves Bedrock
                    // unavailable; it does not stop the runtime.
                    do {
                        return .available(
                            try BedrockModelGateway.resolve(
                                identifier: gatewayIdentifier,
                                metadata: metadata,
                                diagnostics: diagnostics
                            )
                        )
                    } catch let error as AWSRegionError {
                        switch error {
                        case .missingConfigFile:
                            return .unavailable(
                                .bedrock(.missing_configuration, error)
                            )

                        case .unreadableConfigFile,
                             .missingConfigProfile,
                             .missingRegion:
                            return .unavailable(
                                .bedrock(.invalid_configuration, error)
                            )
                        }
                    } catch let error as AWSCredentialsError {
                        switch error {
                        case .missingSharedCredentialsFile:
                            return .unavailable(
                                .bedrock(.missing_configuration, error)
                            )

                        case .unreadableSharedCredentialsFile,
                             .missingSharedCredentialsProfile,
                             .missingProfileValue:
                            return .unavailable(
                                .bedrock(.invalid_configuration, error)
                            )
                        }
                    }
                }
            ),
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

private extension AgentModelGatewayUnavailability {
    static func bedrock(
        _ kind: Kind,
        _ error: any LocalizedError
    ) -> Self {
        .init(
            kind: kind,
            message: error.errorDescription ?? "AWS configuration for Bedrock is unavailable.",
            metadata: [
                "provider": "aws",
                "configuration": "AWS_REGION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY or ~/.aws",
            ]
        )
    }
}
