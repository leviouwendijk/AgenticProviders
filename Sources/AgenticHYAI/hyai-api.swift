import Agentic
import Primitives

package struct HYAIChatRequest: Sendable, Codable {
    package let model: String
    package let messages: [HYAIChatMessage]
    package let tools: [HYAITool]?
    package let stream: Bool
    package let temperature: Double?
    package let topP: Double?
    package let maxTokens: Int?
    package let stop: [String]?
    /// Streams report usage only when asked (`include_usage`).
    package let streamOptions: HYAIStreamOptions?
    package let hyai: HYAIRouterOptions?
}

package struct HYAIStreamOptions: Sendable, Codable {
    package let includeUsage: Bool
}

/// `GET /v1/models`: the catalog with per-model pricing.
package struct HYAIModelList: Sendable, Codable {
    package let data: [HYAIModelListing]
}

package struct HYAIModelListing: Sendable, Codable {
    package let id: String
    package let pricing: HYAIModelPricing?
}

/// EUR (or `currency`) per million tokens; nil when not published.
package struct HYAIModelPricing: Sendable, Codable {
    package let inputPerMillion: Double?
    package let cachedInputPerMillion: Double?
    package let outputPerMillion: Double?
    package let currency: String?
}

package struct HYAIRouterOptions: Sendable, Codable {
    package let task: HYAITask
    package let policy: HYAIPolicy
}

package struct HYAIChatMessage: Sendable, Codable {
    package let role: String
    package let content: String?
    package let toolCalls: [HYAIToolCall]?
    package let toolCallId: String?
}

package struct HYAITool: Sendable, Codable {
    package let type: String
    package let function: HYAIToolDefinition
}

package struct HYAIToolDefinition: Sendable, Codable {
    package let name: String
    package let description: String
    package let parameters: JSONValue
}

package struct HYAIToolCall: Sendable, Codable {
    package let index: Int?
    package let id: String?
    package let type: String?
    package let function: HYAIFunctionCall?
}

package struct HYAIFunctionCall: Sendable, Codable {
    package let name: String?
    package let arguments: String?
}

package struct HYAIChatCompletionResponse: Sendable, Codable {
    package let model: String?
    package let choices: [HYAIChatCompletionChoice]
    package let usage: HYAIUsage?
}

package struct HYAIChatCompletionChoice: Sendable, Codable {
    package let message: HYAIChatMessage
    package let finishReason: String?
}

package struct HYAIChatCompletionChunk: Sendable, Codable {
    package let model: String?
    package let choices: [HYAIChatCompletionChunkChoice]
    package let usage: HYAIUsage?
}

package struct HYAIChatCompletionChunkChoice: Sendable, Codable {
    package let delta: HYAIChatCompletionDelta
    package let finishReason: String?
}

package struct HYAIChatCompletionDelta: Sendable, Codable {
    package let content: String?
    package let toolCalls: [HYAIToolCall]?
}

/// OpenAI-shaped usage: promptTokens includes cached and cache-created tokens,
/// completionTokens includes reasoning tokens.
package struct HYAIUsage: Sendable, Codable {
    package let promptTokens: Int?
    package let completionTokens: Int?
    package let totalTokens: Int?
    package let promptTokensDetails: HYAIPromptTokensDetails?
    package let completionTokensDetails: HYAICompletionTokensDetails?
}

package struct HYAIPromptTokensDetails: Sendable, Codable {
    package let cachedTokens: Int?
    package let createdCacheTokens: Int?
}

package struct HYAICompletionTokensDetails: Sendable, Codable {
    package let reasoningTokens: Int?
}

extension HYAIUsage {
    /// Normalize to AgentUsage, where inputTokens excludes cache reads and writes.
    package var agentUsage: AgentUsage {
        let cachedRead = promptTokensDetails?.cachedTokens
        let cachedWrite = promptTokensDetails?.createdCacheTokens
        let input = promptTokens.map {
            max(0, $0 - (cachedRead ?? 0) - (cachedWrite ?? 0))
        }

        return .init(
            inputTokens: input,
            outputTokens: completionTokens,
            totalTokens: totalTokens,
            cachedInputReadTokens: cachedRead,
            cachedInputWriteTokens: cachedWrite,
            reasoningOutputTokens: completionTokensDetails?.reasoningTokens
        )
    }
}
