import Agentic

public struct HYAIModelProfileProvider:
    AgentModelProfileProvider
{
    public var gatewayIdentifier:
        AgentModelGatewayIdentifier
    public var profileIdentifier:
        AgentModelProfileIdentifier
    public var autoPolicy: HYAIPolicy

    public init(
        gatewayIdentifier: AgentModelGatewayIdentifier = .hyai,
        profileIdentifier: AgentModelProfileIdentifier = .hyai_auto,
        autoPolicy: HYAIPolicy = .balanced
    ) {
        self.gatewayIdentifier = gatewayIdentifier
        self.profileIdentifier = profileIdentifier
        self.autoPolicy = autoPolicy
    }

    public func profiles() throws -> [AgentModelProfile] {
        [
            .init(
                identifier: profileIdentifier,
                gatewayIdentifier: gatewayIdentifier,
                model: "hyai/auto",
                title: "HostYourAI Auto",
                purposes: [
                    .executor,
                    .planner,
                    .researcher,
                    .advisor,
                    .reviewer,
                    .summarizer,
                    .classifier,
                    .extractor,
                    .coder,
                ],
                capabilities: [
                    .text,
                    .tool_use,
                    .streaming,
                ],
                cost: .balanced,
                latency: .medium,
                privacy: .private_cloud,
                limits: .unknown,
                metadata: [
                    "provider": "hostyourai",
                    "gateway": "hyai_chat_completions",
                    "virtual_model": "true",
                    "auto_policy": autoPolicy.rawValue,
                ]
            ),
        ]
    }
}

public extension AgentModelGatewayIdentifier {
    static let hyai: Self = "hyai"
}

public extension AgentModelProfileIdentifier {
    static let hyai_auto: Self = "hyai_auto"
}
