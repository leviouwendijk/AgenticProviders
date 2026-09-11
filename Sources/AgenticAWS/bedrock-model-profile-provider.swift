import Agentic

public struct BedrockModelProfileProvider: AgentModelProfileProvider {
    public var gatewayIdentifier: AgentModelGatewayIdentifier

    private let storedProfiles: [AgentModelProfile]

    public init(
        gatewayIdentifier: AgentModelGatewayIdentifier = .aws_bedrock,
        profiles: [AgentModelProfile]
    ) {
        self.gatewayIdentifier = gatewayIdentifier
        self.storedProfiles = profiles
    }

    public init(
        gatewayIdentifier: AgentModelGatewayIdentifier = .aws_bedrock,
        models: [String],
        defaultPurposes: Set<AgentModelRoutePurpose> = [
            .executor,
            .planner,
            .researcher,
            .advisor,
            .reviewer,
            .summarizer,
            .classifier,
            .extractor,
            .coder
        ],
        defaultCapabilities: Set<AgentModelCapability> = [
            .text,
            .tool_use,
            .streaming,
            .structured_output,
            .reasoning
        ],
        cost: AgentModelCostClass = .balanced,
        latency: AgentModelLatencyClass = .medium,
        privacy: AgentModelPrivacyClass = .private_cloud
    ) {
        self.gatewayIdentifier = gatewayIdentifier
        self.storedProfiles = models.map { model in
            BedrockModelProfiles.profile(
                model: model,
                gatewayIdentifier: gatewayIdentifier,
                purposes: defaultPurposes,
                capabilities: defaultCapabilities,
                cost: cost,
                latency: latency,
                privacy: privacy
            )
        }
    }

    public init(
        gatewayIdentifier: AgentModelGatewayIdentifier = .aws_bedrock,
        handles: [BedrockModelHandle],
        defaultPurposes: Set<AgentModelRoutePurpose> = [
            .executor,
            .planner,
            .researcher,
            .advisor,
            .reviewer,
            .summarizer,
            .classifier,
            .extractor,
            .coder
        ],
        defaultCapabilities: Set<AgentModelCapability> = [
            .text,
            .tool_use,
            .streaming,
            .structured_output,
            .reasoning
        ],
        cost: AgentModelCostClass = .balanced,
        latency: AgentModelLatencyClass = .medium,
        privacy: AgentModelPrivacyClass = .private_cloud
    ) {
        self.gatewayIdentifier = gatewayIdentifier
        self.storedProfiles = handles.map { handle in
            BedrockModelProfiles.profile(
                handle: handle,
                gatewayIdentifier: gatewayIdentifier,
                purposes: defaultPurposes,
                capabilities: defaultCapabilities,
                cost: cost,
                latency: latency,
                privacy: privacy
            )
        }
    }

    public func profiles() throws -> [AgentModelProfile] {
        storedProfiles
    }
}

public enum BedrockModelProfiles {
    public static func profile(
        identifier: AgentModelProfileIdentifier? = nil,
        model: String,
        modelID: AgentModelID? = nil,
        title: String? = nil,
        gatewayIdentifier: AgentModelGatewayIdentifier = .aws_bedrock,
        purposes: Set<AgentModelRoutePurpose> = [
            .executor
        ],
        capabilities: Set<AgentModelCapability> = [
            .text,
            .tool_use,
            .streaming
        ],
        cost: AgentModelCostClass = .balanced,
        latency: AgentModelLatencyClass = .medium,
        privacy: AgentModelPrivacyClass = .private_cloud,
        limits: AgentModelLimits = .unknown,
        metadata: [String: String] = [:]
    ) -> AgentModelProfile {
        var metadata = metadata
        metadata["provider"] = metadata["provider"] ?? "aws"
        metadata["gateway"] = metadata["gateway"] ?? "bedrock_converse"

        if let modelID {
            metadata["model_id"] = metadata["model_id"] ?? modelID.rawValue
            metadata["model_provider"] = metadata["model_provider"] ?? modelID.provider.rawValue
            metadata["model_name"] = metadata["model_name"] ?? modelID.name
        }

        return .init(
            identifier: identifier ?? fallbackIdentifier(
                model: model
            ),
            gatewayIdentifier: gatewayIdentifier,
            model: model,
            modelID: modelID,
            title: title ?? model,
            purposes: purposes,
            capabilities: capabilities,
            cost: cost,
            latency: latency,
            privacy: privacy,
            limits: limits,
            metadata: metadata
        )
    }

    public static func profile(
        handle: BedrockModelHandle,
        gatewayIdentifier: AgentModelGatewayIdentifier = .aws_bedrock,
        purposes: Set<AgentModelRoutePurpose> = [
            .executor
        ],
        capabilities: Set<AgentModelCapability> = [
            .text,
            .tool_use,
            .streaming
        ],
        cost: AgentModelCostClass = .balanced,
        latency: AgentModelLatencyClass = .medium,
        privacy: AgentModelPrivacyClass = .private_cloud,
        limits: AgentModelLimits = .unknown,
        metadata: [String: String] = [:]
    ) -> AgentModelProfile {
        profile(
            identifier: generatedIdentifier(
                for: handle
            ),
            model: handle.invokeIdentifier,
            modelID: nil,
            title: handle.title,
            gatewayIdentifier: gatewayIdentifier,
            purposes: purposes,
            capabilities: effectiveCapabilities(
                capabilities,
                handle: handle
            ),
            cost: cost,
            latency: latency,
            privacy: privacy,
            limits: limits,
            metadata: handle.metadata(
                merging: metadata
            )
        )
    }

    public static func novaMicro(
        _ model: String = "eu.amazon.nova-micro-v1:0"
    ) -> AgentModelProfile {
        profile(
            identifier: .init(
                "aws_bedrock:nova_micro"
            ),
            model: model,
            modelID: KnownModel.amazon.nova_micro,
            title: "AWS Bedrock Nova Micro",
            purposes: [
                .executor,
                .summarizer,
                .classifier,
                .extractor
            ],
            capabilities: [
                .text,
                .tool_use,
                .streaming,
                .structured_output
            ],
            cost: .cheap,
            latency: .low,
            privacy: .private_cloud
        )
    }

    public static func advisor(
        _ model: String,
        modelID: AgentModelID? = nil,
        identifier: AgentModelProfileIdentifier? = nil,
        title: String? = nil
    ) -> AgentModelProfile {
        profile(
            identifier: identifier,
            model: model,
            modelID: modelID,
            title: title,
            purposes: [
                .planner,
                .researcher,
                .advisor,
                .reviewer,
                .coder
            ],
            capabilities: [
                .text,
                .tool_use,
                .streaming,
                .structured_output,
                .reasoning
            ],
            cost: .premium,
            latency: .medium,
            privacy: .private_cloud
        )
    }
}

private extension BedrockModelProfiles {
    static func fallbackIdentifier(
        model: String
    ) -> AgentModelProfileIdentifier {
        .init(
            "aws_bedrock:\(model)"
        )
    }

    static func generatedIdentifier(
        for handle: BedrockModelHandle
    ) -> AgentModelProfileIdentifier {
        .init(
            [
                "aws_bedrock",
                handle.kind.rawValue,
                safeIdentifierComponent(
                    handle.invokeIdentifier
                )
            ].joined(
                separator: ":"
            )
        )
    }

    static func safeIdentifierComponent(
        _ value: String
    ) -> String {
        value.map { character in
            if character.isLetter
                || character.isNumber
                || character == "-"
                || character == "_"
                || character == "." {
                return String(
                    character
                )
            }

            return "_"
        }.joined()
    }

    static func effectiveCapabilities(
        _ capabilities: Set<AgentModelCapability>,
        handle: BedrockModelHandle
    ) -> Set<AgentModelCapability> {
        guard handle.streaming == false else {
            return capabilities
        }

        var capabilities = capabilities
        capabilities.remove(
            .streaming
        )

        return capabilities
    }
}

public extension AgentModelGatewayIdentifier {
    static let aws_bedrock: Self = "aws_bedrock"
}
