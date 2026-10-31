import Agentic
import AgenticModels

/// Curated HostYourAI models and manually captured EUR pricing snapshots.
public enum HYAIModelCatalog {
    private struct Listing: Sendable {
        let identifier: AgentModelProfileIdentifier
        let model: String
        let modelID: AgentModelID
        let title: String
        let cost: AgentModelCostClass
        let inputMicros: Int64
        let outputMicros: Int64
    }

    private static let listings: [Listing] = [
        .init(
            identifier: "hyai_deepseek_v4_flash",
            model: "deepseek-ai/DeepSeek-V4-Flash",
            modelID: KnownModel.deepseek.v4_flash,
            title: "DeepSeek V4 Flash",
            cost: .cheap,
            inputMicros: 290000,
            outputMicros: 350000
        ),
        .init(
            identifier: "hyai_deepseek_v4_1_flash",
            model: "deepseek-ai/DeepSeek-V4.1-Flash",
            modelID: "deepseek:v4-1-flash",
            title: "DeepSeek V4.1 Flash",
            cost: .balanced,
            inputMicros: 580000,
            outputMicros: 1720000
        ),
        .init(
            identifier: "hyai_deepseek_v4_1_flash_1017",
            model: "deepseek-ai/DeepSeek-V4.1-Flash-1017",
            modelID: "deepseek:v4-1-flash-1017",
            title: "DeepSeek V4.1 Flash 1017",
            cost: .balanced,
            inputMicros: 580000,
            outputMicros: 1720000
        ),
        .init(
            identifier: "hyai_deepseek_v4_pro",
            model: "deepseek-ai/DeepSeek-V4-Pro",
            modelID: KnownModel.deepseek.v4_pro,
            title: "DeepSeek V4 Pro",
            cost: .balanced,
            inputMicros: 2010000,
            outputMicros: 4020000
        ),
        .init(
            identifier: "hyai_deepseek_v4_pro_0813",
            model: "deepseek-ai/DeepSeek-V4-Pro-0813",
            modelID: "deepseek:v4-pro-0813",
            title: "DeepSeek V4 Pro 0813",
            cost: .balanced,
            inputMicros: 2300000,
            outputMicros: 4600000
        ),
        .init(
            identifier: "hyai_qwen3_8_27b",
            model: "Qwen/Qwen3.8-27B",
            modelID: "qwen:qwen3-8-27b",
            title: "Qwen3.8 27B",
            cost: .balanced,
            inputMicros: 460000,
            outputMicros: 2760000
        ),
        .init(
            identifier: "hyai_qwen3_8_flash_next",
            model: "Qwen/Qwen3.8-Flash-Next",
            modelID: "qwen:qwen3-8-flash-next",
            title: "Qwen3.8 Flash Next",
            cost: .cheap,
            inputMicros: 230000,
            outputMicros: 580000
        ),
        .init(
            identifier: "hyai_qwen3_235b_a22b_instruct",
            model: "qwen3-235b-a22b-instruct-2507",
            modelID: "qwen:qwen3-235b-a22b-instruct-2507",
            title: "Qwen3 235B A22B Instruct",
            cost: .cheap,
            inputMicros: 80000,
            outputMicros: 530000
        ),
        .init(
            identifier: "hyai_qwen3_5_397b_a17b",
            model: "qwen3.5-397b-a17b",
            modelID: KnownModel.qwen.v3_5_397b_a17b,
            title: "Qwen3.5 397B A17B",
            cost: .balanced,
            inputMicros: 690000,
            outputMicros: 4140000
        ),
        .init(
            identifier: "hyai_kimi_k3",
            model: "moonshotai/Kimi-K3",
            modelID: KnownModel.kimi.k3,
            title: "Kimi K3",
            cost: .premium,
            inputMicros: 3450000,
            outputMicros: 17250000
        ),
        .init(
            identifier: "hyai_kimi_k2_5",
            model: "moonshotai/Kimi-K2.5",
            modelID: KnownModel.kimi.k2_5,
            title: "Kimi K2.5",
            cost: .balanced,
            inputMicros: 580000,
            outputMicros: 3220000
        ),
        .init(
            identifier: "hyai_kimi_k2_6",
            model: "moonshotai/Kimi-K2.6",
            modelID: "moonshot:kimi-k2-6",
            title: "Kimi K2.6",
            cost: .balanced,
            inputMicros: 1150000,
            outputMicros: 4600000
        ),
        .init(
            identifier: "hyai_kimi_k2_7_code",
            model: "moonshotai/Kimi-K2.7-Code",
            modelID: "moonshot:kimi-k2-7-code",
            title: "Kimi K2.7 Code",
            cost: .expensive,
            inputMicros: 1440000,
            outputMicros: 5180000
        ),
        .init(
            identifier: "hyai_glm_v5_3",
            model: "zai-org/GLM-5.3",
            modelID: "zai:glm-5-3",
            title: "GLM 5.3",
            cost: .expensive,
            inputMicros: 1610000,
            outputMicros: 5060000
        ),
        .init(
            identifier: "hyai_glm_v5_1",
            model: "zai-org/GLM-5.1",
            modelID: "zai:glm-5-1",
            title: "GLM 5.1",
            cost: .balanced,
            inputMicros: 1480000,
            outputMicros: 4660000
        ),
        .init(
            identifier: "hyai_glm_v5_3_flash",
            model: "zai-org/GLM-5.3-Flash",
            modelID: KnownModel.glm.v5_3_flash,
            title: "HostYourAI GLM 5.3 Flash",
            cost: .balanced,
            inputMicros: 230000,
            outputMicros: 580000
        ),
    ]

    static func profiles(
        gatewayIdentifier: AgentModelGatewayIdentifier
    ) -> [AgentModelProfile] {
        listings.map { listing in
            .init(
                identifier: listing.identifier,
                gatewayIdentifier: gatewayIdentifier,
                model: listing.model,
                modelID: listing.modelID,
                title: listing.title,
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
                cost: listing.cost,
                latency: .medium,
                privacy: .private_cloud,
                limits: .unknown,
                metadata: [
                    "provider": "hostyourai",
                    "gateway": "hyai_chat_completions",
                    "virtual_model": "false",
                    "hostyourai_model": listing.model,
                ]
            )
        }
    }

    /// Manually quoted EUR prices per million tokens from 2026-11-01.
    /// These snapshots are not automatically installed in AgentHome.
    public static func pricingSnapshots() throws -> [ModelPricingSnapshot] {
        try listings.map { listing in
            try ModelPricingSnapshot.tokenPricing(
                provider: "hostyourai",
                model: listing.model,
                source: .manual,
                sourceVersion: "hostyourai-ui-2026-11-01",
                currencyCode: "EUR",
                inputMicrosPerMillionTokens: listing.inputMicros,
                outputMicrosPerMillionTokens: listing.outputMicros,
                metadata: [
                    "price_origin": "user_supplied_hostyourai_catalog",
                ]
            )
        }
    }
}
