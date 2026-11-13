import Agentic
import Primitives

struct HYAIChatRequest: Sendable, Codable {
    let model: String
    let messages: [HYAIChatMessage]
    let tools: [HYAITool]?
    let stream: Bool
    let temperature: Double?
    let topP: Double?
    let maxTokens: Int?
    let stop: [String]?
    let hyai: HYAIRouterOptions?
}

struct HYAIRouterOptions: Sendable, Codable {
    let task: HYAITask
    let policy: HYAIPolicy
}

struct HYAIChatMessage: Sendable, Codable {
    let role: String
    let content: String?
    let toolCalls: [HYAIToolCall]?
    let toolCallId: String?
}

struct HYAITool: Sendable, Codable {
    let type: String
    let function: HYAIToolDefinition
}

struct HYAIToolDefinition: Sendable, Codable {
    let name: String
    let description: String
    let parameters: JSONValue
}

struct HYAIToolCall: Sendable, Codable {
    let index: Int?
    let id: String?
    let type: String?
    let function: HYAIFunctionCall?
}

struct HYAIFunctionCall: Sendable, Codable {
    let name: String?
    let arguments: String?
}

struct HYAIChatCompletionResponse: Sendable, Codable {
    let model: String?
    let choices: [HYAIChatCompletionChoice]
    let usage: HYAIUsage?
}

struct HYAIChatCompletionChoice: Sendable, Codable {
    let message: HYAIChatMessage
    let finishReason: String?
}

struct HYAIChatCompletionChunk: Sendable, Codable {
    let model: String?
    let choices: [HYAIChatCompletionChunkChoice]
    let usage: HYAIUsage?
}

struct HYAIChatCompletionChunkChoice: Sendable, Codable {
    let delta: HYAIChatCompletionDelta
    let finishReason: String?
}

struct HYAIChatCompletionDelta: Sendable, Codable {
    let content: String?
    let toolCalls: [HYAIToolCall]?
}

/// OpenAI-shaped usage: promptTokens includes cached and cache-created tokens,
/// completionTokens includes reasoning tokens.
struct HYAIUsage: Sendable, Codable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
    let promptTokensDetails: HYAIPromptTokensDetails?
    let completionTokensDetails: HYAICompletionTokensDetails?
}

struct HYAIPromptTokensDetails: Sendable, Codable {
    let cachedTokens: Int?
    let createdCacheTokens: Int?
}

struct HYAICompletionTokensDetails: Sendable, Codable {
    let reasoningTokens: Int?
}

extension HYAIUsage {
    /// Normalize to AgentUsage, where inputTokens excludes cache reads and writes.
    var agentUsage: AgentUsage {
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
