import Agentic
import Foundation
import Primitives

struct OllamaRequestMapper {
    static func map(
        _ request: AgentRequest,
        model: String,
        configuration: OllamaModelConfiguration,
        stream: Bool
    ) throws -> OllamaChatRequest {
        guard !request.messages.isEmpty else {
            throw OllamaGatewayError.emptyMessages
        }

        let messages = try OllamaMessageMapper.map(request.messages)
        guard !messages.isEmpty else {
            throw OllamaGatewayError.emptyMappedMessages
        }

        return .init(
            model: model,
            messages: messages,
            tools: OllamaToolMapper.map(request.tools),
            stream: stream,
            think: configuration.thinking,
            format: OllamaResponseFormatMapper.map(
                request.responseFormat
            ),
            options: .init(
                numCtx: configuration.contextWindow,
                numPredict: request.generationConfiguration.maxOutputTokens,
                temperature: request.generationConfiguration.temperature,
                topP: request.generationConfiguration.topP,
                stop: request.generationConfiguration.stopSequences.isEmpty
                    ? nil
                    : request.generationConfiguration.stopSequences
            )
        )
    }

}

private struct OllamaMessageMapper {
    static func map(_ messages: [AgentMessage]) throws -> [OllamaChatMessage] {
        var callsByID: [String: AgentToolCall] = [:]
        for message in messages {
            for block in message.content.blocks {
                if case .tool_call(let call) = block {
                    callsByID[call.id] = call
                }
            }
        }

        var mapped: [OllamaChatMessage] = []
        for message in messages {
            switch message.role {
            case .system, .user:
                mapped.append(
                    .init(
                        role: message.role.rawValue,
                        content: try textOnly(message)
                    )
                )

            case .assistant:
                var text = ""
                var calls: [OllamaToolCall] = []

                for block in message.content.blocks {
                    switch block {
                    case .text(let value):
                        text += value
                    case .tool_call(let call):
                        calls.append(
                            .init(
                                id: call.id,
                                function: .init(
                                    index: calls.count,
                                    name: call.name,
                                    arguments: call.input
                                )
                            )
                        )
                    case .resource, .tool_result:
                        throw OllamaGatewayError.unsupportedContent(message.role)
                    }
                }

                guard !text.isEmpty || !calls.isEmpty else {
                    throw OllamaGatewayError.unsupportedContent(message.role)
                }

                mapped.append(
                    .init(
                        role: "assistant",
                        content: text,
                        toolCalls: calls.isEmpty ? nil : calls
                    )
                )

            case .tool:
                for block in message.content.blocks {
                    guard case .tool_result(let result) = block else {
                        throw OllamaGatewayError.unsupportedContent(message.role)
                    }

                    let name = result.name ?? callsByID[result.toolCallID]?.name
                    guard let name, !name.isEmpty else {
                        throw OllamaGatewayError.missingToolName(result.toolCallID)
                    }

                    mapped.append(
                        .init(
                            role: "tool",
                            content: toolResultText(result),
                            toolName: name
                        )
                    )
                }
            }
        }

        return mapped
    }

    private static func textOnly(_ message: AgentMessage) throws -> String {
        var text = ""
        for block in message.content.blocks {
            guard case .text(let value) = block else {
                throw OllamaGatewayError.unsupportedContent(message.role)
            }
            text += value
        }
        guard !text.isEmpty else {
            throw OllamaGatewayError.unsupportedContent(message.role)
        }
        return text
    }

    private static func toolResultText(_ result: AgentToolResult) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let rendered: String
        if let data = try? encoder.encode(result.output),
           let text = String(data: data, encoding: .utf8) {
            rendered = text
        } else {
            rendered = String(describing: result.output)
        }
        return result.isError ? "Tool execution failed: \(rendered)" : rendered
    }
}

private struct OllamaToolMapper {
    static func map(_ tools: [AgentToolDefinition]) -> [OllamaTool]? {
        guard !tools.isEmpty else { return nil }
        return tools.map { definition in
            .init(
                type: "function",
                function: .init(
                    name: definition.name,
                    description: definition.description,
                    parameters: definition.inputSchema ?? defaultSchema
                )
            )
        }
    }

    private static let defaultSchema: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([:])
    ])
}
