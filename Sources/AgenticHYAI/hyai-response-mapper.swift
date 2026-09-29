import Agentic
import Foundation
import Primitives

struct HYAIResponseMapper {
    static func map(
        _ response: HYAIChatCompletionResponse,
        requestedModel: String,
        metadata: [String: String]
    ) throws -> AgentResponse {
        guard let choice = response.choices.first else {
            throw HYAIGatewayError.invalidResponse
        }

        var blocks: [MessageContentBlock] = []

        if let text = choice.message.content,
           !text.isEmpty
        {
            blocks.append(
                .text(text)
            )
        }

        let calls = try mapToolCalls(
            choice.message.toolCalls ?? []
        )
        blocks.append(
            contentsOf: calls.map {
                .tool_call($0)
            }
        )

        return .init(
            message: .init(
                role: .assistant,
                content: .init(
                    blocks: blocks
                )
            ),
            stopReason: stopReason(
                choice.finishReason,
                hasToolCalls: !calls.isEmpty
            ),
            usage: response.usage.map {
                .init(
                    inputTokens:
                        $0.promptTokens,
                    outputTokens:
                        $0.completionTokens,
                    totalTokens:
                        $0.totalTokens
                )
            },
            metadata: baseMetadata(
                requestedModel: requestedModel,
                resolvedModel: response.model,
                finishReason: choice.finishReason,
                metadata: metadata
            )
        )
    }

    static func mapToolCall(
        id: String?,
        name: String?,
        arguments: String?
    ) throws -> ToolCall {
        guard let id,
              !id.isEmpty,
              let name,
              !name.isEmpty
        else {
            throw HYAIGatewayError.invalidToolCall
        }

        return .init(
            id: id,
            tool: .init(
                rawValue: name
            ),
            input: try decodeArguments(
                arguments
            )
        )
    }

    static func baseMetadata(
        requestedModel: String,
        resolvedModel: String?,
        finishReason: String?,
        metadata: [String: String]
    ) -> [String: String] {
        var result = metadata
        result["provider"] =
            result["provider"]
            ?? "hostyourai"
        result["gateway"] =
            result["gateway"]
            ?? "hyai_chat_completions"
        result["requested_model"] =
            requestedModel
        result["model"] =
            resolvedModel.flatMap {
                $0.isEmpty ? nil : $0
            }
            ?? requestedModel

        if let finishReason,
           !finishReason.isEmpty
        {
            result["finish_reason"] =
                finishReason
        }

        return result
    }

    static func stopReason(
        _ value: String?,
        hasToolCalls: Bool
    ) -> AgentStopReason {
        if hasToolCalls {
            return .tool_use
        }

        switch value {
        case "stop", nil:
            return .end_turn

        case "length":
            return .max_tokens

        case "tool_calls",
             "function_call":
            return .tool_use

        default:
            return .error
        }
    }

    private static func mapToolCalls(
        _ calls: [HYAIToolCall]
    ) throws -> [ToolCall] {
        try calls.map { call in
            try mapToolCall(
                id: call.id,
                name: call.function?.name,
                arguments:
                    call.function?.arguments
            )
        }
    }

    private static func decodeArguments(
        _ value: String?
    ) throws -> JSONValue {
        guard let value,
              !value.isEmpty
        else {
            return .object([:])
        }

        guard let data = value.data(
            using: .utf8
        ) else {
            throw HYAIGatewayError
                .invalidToolArguments(
                    value
                )
        }

        do {
            return try JSONDecoder().decode(
                JSONValue.self,
                from: data
            )
        } catch {
            throw HYAIGatewayError
                .invalidToolArguments(
                    value
                )
        }
    }
}
