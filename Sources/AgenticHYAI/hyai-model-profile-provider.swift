import Agentic
import AgenticModels

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
                identifier: .hyai_glm_v5_3_flash,
                gatewayIdentifier: gatewayIdentifier,
                model: "zai-org/GLM-5.3-Flash",
                modelID: KnownModel.glm.v5_3_flash,
                title: "HostYourAI GLM 5.3 Flash",
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
                    "virtual_model": "false",
                    "hostyourai_model": "zai-org/GLM-5.3-Flash",
                ]
            ),
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
    static let hyai_glm_v5_3_flash: Self = "hyai_glm_v5_3_flash"
}
