import Agentic
import Foundation
import Primitives

struct HYAIRequestMapper {
    static func map(
        _ request: AgentRequest,
        model: String,
        purpose: AgentModelRoutePurpose,
        configuration: HYAIModelConfiguration,
        stream: Bool
    ) throws -> HYAIChatRequest {
        guard !request.messages.isEmpty else {
            throw HYAIGatewayError.emptyMessages
        }

        guard case .text = request.responseFormat else {
            throw HYAIGatewayError
                .unsupportedResponseFormat
        }

        let messages = try HYAIMessageMapper.map(
            request.messages
        )
        guard !messages.isEmpty else {
            throw HYAIGatewayError.emptyMappedMessages
        }

        return .init(
            model: model,
            messages: messages,
            tools: HYAIToolMapper.map(
                request.tools
            ),
            stream: stream,
            temperature:
                request.generationConfiguration.temperature,
            topP:
                request.generationConfiguration.topP,
            maxTokens:
                request.generationConfiguration.maxOutputTokens,
            stop:
                request.generationConfiguration.stopSequences.isEmpty
                    ? nil
                    : request.generationConfiguration.stopSequences,
            hyai:
                model == "hyai/auto"
                    ? .init(
                        task:
                            configuration.autoTask
                            ?? task(for: purpose),
                        policy: configuration.autoPolicy
                    )
                    : nil
        )
    }

    private static func task(
        for purpose: AgentModelRoutePurpose
    ) -> HYAITask {
        switch purpose {
        case .coder:
            return .code

        case .summarizer:
            return .summarize

        case .classifier:
            return .classify

        case .extractor:
            return .extract

        case .planner,
             .researcher,
             .advisor,
             .reviewer:
            return .reason

        case .executor,
             .local_private:
            return .chat
        }
    }
}

private struct HYAIMessageMapper {
    static func map(
        _ messages: [Message]
    ) throws -> [HYAIChatMessage] {
        var mapped: [HYAIChatMessage] = []

        for message in messages {
            switch message.role {
            case .system, .user:
                mapped.append(
                    .init(
                        role: message.role.rawValue,
                        content: try textOnly(message),
                        toolCalls: nil,
                        toolCallId: nil
                    )
                )

            case .assistant:
                var text = ""
                var calls: [HYAIToolCall] = []

                for block in message.content.blocks {
                    switch block {
                    case .text(let value):
                        text += value

                    case .tool_call(let call):
                        calls.append(
                            .init(
                                index: nil,
                                id: call.id,
                                type: "function",
                                function: .init(
                                    name: call.tool.rawValue,
                                    arguments: try jsonString(
                                        call.input
                                    )
                                )
                            )
                        )

                    case .resource,
                         .tool_result:
                        throw HYAIGatewayError
                            .unsupportedContent(
                                message.role
                            )
                    }
                }

                guard !text.isEmpty || !calls.isEmpty else {
                    throw HYAIGatewayError
                        .unsupportedContent(
                            message.role
                        )
                }

                mapped.append(
                    .init(
                        role: "assistant",
                        content:
                            text.isEmpty ? nil : text,
                        toolCalls:
                            calls.isEmpty ? nil : calls,
                        toolCallId: nil
                    )
                )

            case .tool:
                for block in message.content.blocks {
                    guard case .tool_result(let result) = block else {
                        throw HYAIGatewayError
                            .unsupportedContent(
                                message.role
                            )
                    }

                    mapped.append(
                        .init(
                            role: "tool",
                            content: try jsonString(
                                result.output
                            ),
                            toolCalls: nil,
                            toolCallId:
                                result.call.id
                        )
                    )
                }
            }
        }

        return mapped
    }

    private static func textOnly(
        _ message: Message
    ) throws -> String {
        var text = ""

        for block in message.content.blocks {
            guard case .text(let value) = block else {
                throw HYAIGatewayError
                    .unsupportedContent(
                        message.role
                    )
            }

            text += value
        }

        guard !text.isEmpty else {
            throw HYAIGatewayError
                .unsupportedContent(
                    message.role
                )
        }

        return text
    }

    private static func jsonString(
        _ value: JSONValue
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys,
        ]

        let data = try encoder.encode(
            value
        )

        guard let text = String(
            data: data,
            encoding: .utf8
        ) else {
            throw HYAIGatewayError.invalidResponse
        }

        return text
    }
}

private struct HYAIToolMapper {
    static func map(
        _ tools: [ToolDescriptor]
    ) -> [HYAITool]? {
        guard !tools.isEmpty else {
            return nil
        }

        return tools.map { definition in
            .init(
                type: "function",
                function: .init(
                    name: definition.name,
                    description:
                        definition.description,
                    parameters:
                        definition.input
                        ?? defaultSchema
                )
            )
        }
    }

    private static let defaultSchema:
        JSONValue = .object([
            "type": .string("object"),
            "properties": .object([:]),
        ])
}
