import Agentic
import AgenticModels
import Foundation

/// Curated HostYourAI models with offline EUR pricing snapshots.
public enum HYAIModelCatalog {
    private struct Listing: Sendable {
        let identifier: AgentModelProfileIdentifier
        let model: String
        let modelID: AgentModelID
        let title: String
        let cost: AgentModelCostClass
        let inputMicros: Int64
        let outputMicros: Int64
        let cachedInputMicros: Int64?
    }

    private static let listings: [Listing] = [
        .init(
            identifier: "hyai_deepseek_v4_flash",
            model: "deepseek-ai/DeepSeek-V4-Flash",
            modelID: KnownModel.deepseek.v4_flash,
            title: "DeepSeek V4 Flash",
            cost: .cheap,
            inputMicros: 290000,
            outputMicros: 350000,
            cachedInputMicros: 70000
        ),
        .init(
            identifier: "hyai_deepseek_v4_1_flash",
            model: "deepseek-ai/DeepSeek-V4.1-Flash",
            modelID: KnownModel.deepseek.v4_1_flash,
            title: "DeepSeek V4.1 Flash",
            cost: .balanced,
            inputMicros: 580000,
            outputMicros: 1720000,
            cachedInputMicros: 150000
        ),
        .init(
            identifier: "hyai_deepseek_v4_1_flash_1017",
            model: "deepseek-ai/DeepSeek-V4.1-Flash-1017",
            modelID: KnownModel.deepseek.v4_1_flash_1017,
            title: "DeepSeek V4.1 Flash 1017",
            cost: .balanced,
            inputMicros: 690000,
            outputMicros: 2070000,
            cachedInputMicros: 140000
        ),
        .init(
            identifier: "hyai_deepseek_v4_pro",
            model: "deepseek-ai/DeepSeek-V4-Pro",
            modelID: KnownModel.deepseek.v4_pro,
            title: "DeepSeek V4 Pro",
            cost: .balanced,
            inputMicros: 2010000,
            outputMicros: 4020000,
            cachedInputMicros: 510000
        ),
        .init(
            identifier: "hyai_deepseek_v4_pro_0813",
            model: "deepseek-ai/DeepSeek-V4-Pro-0813",
            modelID: KnownModel.deepseek.v4_pro_0813,
            title: "DeepSeek V4 Pro 0813",
            cost: .balanced,
            inputMicros: 2300000,
            outputMicros: 4600000,
            cachedInputMicros: 580000
        ),
        .init(
            identifier: "hyai_qwen3_8_27b",
            model: "Qwen/Qwen3.8-27B",
            modelID: KnownModel.qwen.v3_8_27b,
            title: "Qwen3.8 27B",
            cost: .balanced,
            inputMicros: 690000,
            outputMicros: 3790000,
            cachedInputMicros: 140000
        ),
        .init(
            identifier: "hyai_qwen3_8_flash_next",
            model: "Qwen/Qwen3.8-Flash-Next",
            modelID: KnownModel.qwen.v3_8_flash_next,
            title: "Qwen3.8 Flash Next",
            cost: .cheap,
            inputMicros: 230000,
            outputMicros: 580000,
            cachedInputMicros: 60000
        ),
        .init(
            identifier: "hyai_qwen3_235b_a22b_instruct",
            model: "qwen3-235b-a22b-instruct-2507",
            modelID: KnownModel.qwen.v3_235b_a22b_instruct_2507,
            title: "Qwen3 235B A22B Instruct",
            cost: .cheap,
            inputMicros: 80000,
            outputMicros: 530000,
            cachedInputMicros: 20000
        ),
        .init(
            identifier: "hyai_qwen3_5_397b_a17b",
            model: "qwen3.5-397b-a17b",
            modelID: KnownModel.qwen.v3_5_397b_a17b,
            title: "Qwen3.5 397B A17B",
            cost: .balanced,
            inputMicros: 690000,
            outputMicros: 4140000,
            cachedInputMicros: nil
        ),
        .init(
            identifier: "hyai_kimi_k3",
            model: "moonshotai/Kimi-K3",
            modelID: KnownModel.kimi.k3,
            title: "Kimi K3",
            cost: .premium,
            inputMicros: 3450000,
            outputMicros: 17250000,
            cachedInputMicros: 860000
        ),
        .init(
            identifier: "hyai_kimi_k2_5",
            model: "moonshotai/Kimi-K2.5",
            modelID: KnownModel.kimi.k2_5,
            title: "Kimi K2.5",
            cost: .balanced,
            inputMicros: 580000,
            outputMicros: 3220000,
            cachedInputMicros: 150000
        ),
        .init(
            identifier: "hyai_kimi_k2_6",
            model: "moonshotai/Kimi-K2.6",
            modelID: KnownModel.kimi.k2_6,
            title: "Kimi K2.6",
            cost: .balanced,
            inputMicros: 1150000,
            outputMicros: 4600000,
            cachedInputMicros: 290000
        ),
        .init(
            identifier: "hyai_kimi_k2_7_code",
            model: "moonshotai/Kimi-K2.7-Code",
            modelID: KnownModel.kimi.k2_7_code,
            title: "Kimi K2.7 Code",
            cost: .balanced,
            inputMicros: 860000,
            outputMicros: 4020000,
            cachedInputMicros: 230000
        ),
        .init(
            identifier: "hyai_glm_v5_3",
            model: "zai-org/GLM-5.3",
            modelID: KnownModel.glm.v5_3,
            title: "GLM 5.3",
            cost: .balanced,
            inputMicros: 1150000,
            outputMicros: 4020000,
            cachedInputMicros: 290000
        ),
        .init(
            identifier: "hyai_glm_v5_1",
            model: "zai-org/GLM-5.1",
            modelID: KnownModel.glm.v5_1,
            title: "GLM 5.1",
            cost: .balanced,
            inputMicros: 1610000,
            outputMicros: 5060000,
            cachedInputMicros: 400000
        ),
        .init(
            identifier: "hyai_glm_v5_3_flash",
            model: "zai-org/GLM-5.3-Flash",
            modelID: KnownModel.glm.v5_3_flash,
            title: "HostYourAI GLM 5.3 Flash",
            cost: .cheap,
            inputMicros: 150000,
            outputMicros: 580000,
            cachedInputMicros: 80000
        ),
    ]

    static func profiles(
        gatewayIdentifier: AgentModelGatewayIdentifier
    ) -> [AgentModelProfile] {
        listings.map { listing in
            .init(
                known: listing.modelID,
                identifier: listing.identifier,
                gatewayIdentifier: gatewayIdentifier,
                model: listing.model,
                title: listing.title,
                capabilities: [
                    .text,
                    .tool_use,
                    .streaming,
                ],
                cost: listing.cost,
                privacy: .private_cloud,
                metadata: [
                    "provider": "hostyourai",
                    "gateway": "hyai_chat_completions",
                    "virtual_model": "false",
                    "hostyourai_model": listing.model,
                ]
            )
        }
    }

    /// Snapshots for every listed model with both an input and an output
    /// price; a cached-input price is included when published.
    static func liveSnapshots(
        _ list: HYAIModelList,
        fetchedAt: Date
    ) throws -> [ModelPricingSnapshot] {
        try list.data.compactMap { model in
            guard let pricing = model.pricing,
                  let input = pricing.inputPerMillion,
                  let output = pricing.outputPerMillion
            else { return nil }
            return try ModelPricingSnapshot.tokenPricing(
                provider: "hostyourai",
                model: model.id,
                source: .live,
                sourceVersion: "hostyourai-models",
                currencyCode: pricing.currency ?? "EUR",
                inputMicrosPerMillionTokens: micros(input),
                outputMicrosPerMillionTokens: micros(output),
                cachedInputReadMicrosPerMillionTokens: pricing.cachedInputPerMillion.map(micros),
                fetchedAt: fetchedAt,
                metadata: [
                    "price_origin": "hostyourai_models_endpoint",
                ]
            )
        }
    }

    private static func micros(_ perMillion: Double) -> Int64 {
        Int64((perMillion * 1_000_000).rounded())
    }

    /// EUR prices per million tokens as published by `/v1/models` on
    /// 2026-11-14. The offline fallback: live prices replace these.
    public static func pricingSnapshots() throws -> [ModelPricingSnapshot] {
        try listings.map { listing in
            try ModelPricingSnapshot.tokenPricing(
                provider: "hostyourai",
                model: listing.model,
                source: .manual,
                sourceVersion: "hostyourai-models-2026-11-14",
                currencyCode: "EUR",
                inputMicrosPerMillionTokens: listing.inputMicros,
                outputMicrosPerMillionTokens: listing.outputMicros,
                cachedInputReadMicrosPerMillionTokens: listing.cachedInputMicros,
                metadata: [
                    "price_origin": "user_supplied_hostyourai_catalog",
                ]
            )
        }
    }
}
