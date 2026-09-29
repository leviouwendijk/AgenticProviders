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

struct HYAIUsage: Sendable, Codable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
}
