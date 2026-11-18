import Agentic
import AgenticModels
import AgenticProviderHTTP
import Foundation
import Milieu
import Primitives

public struct AnthropicModelGateway: AgentModelGateway {
    public let identifier: AgentModelGatewayIdentifier
    private let client: ProviderHTTP

    public init(
        identifier: AgentModelGatewayIdentifier = "anthropic_messages", apiKey: String,
        endpoint: String = AnthropicAPI.endpoint
    ) throws {
        self.identifier = identifier
        self.client = try .init(
            endpoint: endpoint, apiKey: apiKey,
            headers: ["x-api-key": apiKey, "anthropic-version": AnthropicAPI.version])
    }

    public var response: AgentModelResponseProviding { AnthropicResponseProvider(client: client) }
}

public struct AnthropicModelProvider: AgentModelProvider {
    public let descriptor = AgentModelProviderDescriptor(
        source: "anthropic", displayName: "Anthropic")
    public let api_key_symbol: String
    public let endpoint: String
    public let gatewayIdentifier: AgentModelGatewayIdentifier

    public init(
        api_key_symbol: String = AnthropicAPI.api_key_symbol,
        endpoint: String = AnthropicAPI.endpoint,
        gatewayIdentifier: AgentModelGatewayIdentifier = "anthropic_messages"
    ) {
        self.api_key_symbol = api_key_symbol
        self.endpoint = endpoint
        self.gatewayIdentifier = gatewayIdentifier
    }

    public var gateways: [AgentModelGatewayFactory] {
        let symbol = api_key_symbol
        let endpoint = endpoint
        let identifier = gatewayIdentifier
        return [
            .init(identifier: identifier) {
                do {
                    let key = try EnvironmentExtractor.value(symbol)
                    return .available(
                        try AnthropicModelGateway(
                            identifier: identifier, apiKey: key, endpoint: endpoint))
                } catch let error as EnvironmentExtractableError {
                    switch error {
                    case .missing, .empty:
                        return .unavailable(
                            .init(
                                kind: .missing_configuration,
                                message: "Anthropic API key unavailable.",
                                metadata: ["symbol": symbol]))
                    case .inferenceRequired: throw error
                    }
                }
            }
        ]
    }

    public var profileProviders: [any AgentModelProfileProvider] {
        [
            SnapshotAgentModelProfileProvider(
                snapshot: .init(
                    source: "anthropic",
                    profiles: [
                        .init(
                            known: KnownModel.claude.fable_5_2,
                            identifier: "anthropic:fable_5_2", gatewayIdentifier: gatewayIdentifier,
                            model: "claude-fable-5-2", title: "Claude Fable 5.2",
                            capabilities: [
                                .text, .tool_use, .streaming, .structured_output, .reasoning,
                            ]),
                        .init(
                            known: KnownModel.claude.opus_5_5,
                            identifier: "anthropic:opus_5_5", gatewayIdentifier: gatewayIdentifier,
                            model: "claude-opus-5-5", title: "Claude Opus 5.5",
                            capabilities: [
                                .text, .tool_use, .streaming, .structured_output, .reasoning,
                            ]),
                        .init(
                            known: KnownModel.claude.sonnet_5_5,
                            identifier: "anthropic:sonnet_5_5", gatewayIdentifier: gatewayIdentifier,
                            model: "claude-sonnet-5-5", title: "Claude Sonnet 5.5",
                            capabilities: [
                                .text, .tool_use, .streaming, .structured_output, .reasoning,
                            ]),
                        .init(
                            known: KnownModel.claude.haiku_5_5,
                            identifier: "anthropic:haiku_5_5", gatewayIdentifier: gatewayIdentifier,
                            model: "claude-haiku-5-5", title: "Claude Haiku 5.5",
                            capabilities: [
                                .text, .tool_use, .streaming, .structured_output, .reasoning,
                            ]),
                        .init(
                            known: KnownModel.claude.opus_5,
                            identifier: "anthropic:opus_5", gatewayIdentifier: gatewayIdentifier,
                            model: "claude-opus-5", title: "Claude Opus 5",
                            capabilities: [
                                .text, .tool_use, .streaming, .structured_output, .reasoning,
                            ]),
                        .init(
                            known: KnownModel.claude.sonnet_5,
                            identifier: "anthropic:sonnet_5", gatewayIdentifier: gatewayIdentifier,
                            model: "claude-sonnet-5", title: "Claude Sonnet 5",
                            capabilities: [
                                .text, .tool_use, .streaming, .structured_output, .reasoning,
                            ]),
                        .init(
                            known: KnownModel.claude.opus_4_8,
                            identifier: "anthropic:opus_4_8", gatewayIdentifier: gatewayIdentifier,
                            model: "claude-opus-4-8", title: "Claude Opus 4.8",
                            capabilities: [
                                .text, .tool_use, .streaming, .structured_output, .reasoning,
                            ]),
                    ]))
        ]
    }
}

struct AnthropicResponseProvider: AgentModelResponseProviding {
    let client: ProviderHTTP

    func countInputTokens(
        request: AgentRequest, route: AgentModelRoute, context _: AgentModelInvocationContext
    ) async throws -> Int? {
        let body = try AnthropicMapper.countRequest(request, model: route.profile.model)
        let data = try await client.post(
            path: "/v1/messages/count_tokens", body: body,
            timeout: request.invocationoptions?.timeoutseconds)
        return try ProviderJSON.inputTokenCount(data)
    }

    func buffered(
        request: AgentRequest, route: AgentModelRoute, context _: AgentModelInvocationContext
    ) async throws -> AgentResponse {
        let body = try AnthropicMapper.request(request, model: route.profile.model, stream: false)
        let data = try await client.post(
            path: "/v1/messages", body: body, timeout: request.invocationoptions?.timeoutseconds)
        return try AnthropicMapper.response(ProviderJSON.object(data))
    }

    func stream(
        request: AgentRequest, route: AgentModelRoute, context _: AgentModelInvocationContext
    )
        -> AsyncThrowingStream<AgentStreamEvent, Error>
    {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let body = try AnthropicMapper.request(
                        request, model: route.profile.model, stream: true)
                    var accumulator = AnthropicStreamAccumulator()
                    for try await event in client.stream(
                        path: "/v1/messages", body: body,
                        timeout: request.invocationoptions?.timeoutseconds)
                    {
                        let outputs = try accumulator.consume(event)
                        for output in outputs { continuation.yield(output) }
                    }
                    guard accumulator.completed else { throw ProviderHTTPError.streamEnded }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

package enum AnthropicMapper {
    package static func request(_ request: AgentRequest, model: String, stream: Bool) throws -> Data {
        var system: [String] = []
        var messages: [[String: Any]] = []
        for message in request.messages {
            if message.role == .system {
                for block in message.content.blocks {
                    guard case .text(let value) = block else { throw ProviderHTTPError.invalidJSON }
                    system.append(value)
                }
                continue
            }
            var blocks: [[String: Any]] = []
            if message.role == .assistant, let raw = message.providerContinuation?["anthropic"],
                let data = raw.data(using: .utf8),
                let saved = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            {
                blocks = saved
            } else {
                for block in message.content.blocks {
                    switch block {
                    case .text(let text): blocks.append(["type": "text", "text": text])
                    case .call(let call):
                        guard message.role == .assistant else {
                            throw ProviderHTTPError.invalidJSON
                        }
                        blocks.append([
                            "type": "tool_use", "id": call.id, "name": call.name,
                            "input": try ProviderJSON.foundation(call.input),
                        ])
                    case .result(let result):
                        guard message.role == .tool else { throw ProviderHTTPError.invalidJSON }
                        blocks.append([
                            "type": "tool_result", "tool_use_id": result.call.id,
                            "content": result.modelText,
                            "is_error": result.isError,
                        ])
                    case .resource:
                        throw ProviderHTTPError.streamError(
                            "Anthropic resource inputs not yet supported")
                    }
                }
            }
            guard !blocks.isEmpty else { continue }
            let role = message.role == .assistant ? "assistant" : "user"
            if let last = messages.indices.last, messages[last]["role"] as? String == role,
                let prior = messages[last]["content"] as? [[String: Any]]
            {
                messages[last]["content"] = prior + blocks
            } else {
                messages.append(["role": role, "content": blocks])
            }
        }
        guard !messages.isEmpty else { throw ProviderHTTPError.invalidJSON }
        let config = request.generationConfiguration
        var payload: [String: Any] = [
            "model": model, "messages": messages, "max_tokens": config.maxOutputTokens ?? 4096,
            "stream": stream,
        ]
        // Prompt caching: a breakpoint on the system block caches tools and
        // system together; the top-level marker moves with the growing
        // conversation, so each request reads the previous one's prefix.
        if !system.isEmpty {
            payload["system"] = [[
                "type": "text", "text": system.joined(separator: "\n\n"),
                "cache_control": ["type": "ephemeral"],
            ]]
        }
        payload["cache_control"] = ["type": "ephemeral"]
        if let temperature = config.temperature { payload["temperature"] = temperature }
        if let topP = config.topP { payload["top_p"] = topP }
        if !config.stopSequences.isEmpty { payload["stop_sequences"] = config.stopSequences }
        if !request.tools.isEmpty {
            payload["tools"] = try request.tools.map { tool -> [String: Any] in
                [
                    "name": tool.name, "description": tool.description,
                    "input_schema": try tool.input.map(ProviderJSON.foundation) ?? [
                        "type": "object", "properties": [:],
                    ],
                ]
            }
        }
        switch request.responseFormat {
        case .text: break
        case .jsonschema(let schema):
            payload["output_config"] = [
                "format": [
                    "type": "json_schema", "schema": try ProviderJSON.foundation(schema.jsonvalue),
                ]
            ]
        }
        return try ProviderJSON.encode(payload)
    }

    /// Preserve the exact native messages, signed thinking and output schema.
    package static func countRequest(_ request: AgentRequest, model: String) throws -> Data {
        let payload = try ProviderJSON.object(Self.request(request, model: model, stream: false))
        let fields: Set<String> = [
            "model", "messages", "system", "tools", "thinking", "tool_choice",
            "output_config",
        ]
        return try ProviderJSON.encode(payload.filter { fields.contains($0.key) })
    }

    package static func call(_ block: [String: Any]) throws -> FunctionCall? {
        guard block["type"] as? String == "tool_use" else { return nil }
        guard let id = block["id"] as? String,
            let name = block["name"] as? String,
            let input = block["input"]
        else { throw ProviderHTTPError.invalidJSON }
        return .init(id: id, name: name, input: try ProviderJSON.value(input))
    }

    package static func response(_ object: [String: Any]) throws -> AgentResponse {
        guard let content = object["content"] as? [[String: Any]] else {
            throw ProviderHTTPError.invalidJSON
        }
        var blocks: [MessageContentBlock] = []
        for block in content {
            switch block["type"] as? String {
            case "text":
                if let value = block["text"] as? String { blocks.append(.text(value)) }
            case "tool_use":
                guard let call = try call(block) else { throw ProviderHTTPError.invalidJSON }
                blocks.append(.call(call))
            default: break
            }
        }
        let usage = object["usage"] as? [String: Any] ?? [:]
        let input = usage["input_tokens"] as? Int
        let cachedRead = usage["cache_read_input_tokens"] as? Int
        let cachedWrite = usage["cache_creation_input_tokens"] as? Int
        let output = usage["output_tokens"] as? Int
        let stop = object["stop_reason"] as? String
        let reason: AgentStopReason
        switch stop {
        case "tool_use": reason = .tool_use
        case "max_tokens": reason = .max_tokens
        case "stop_sequence": reason = .stop_sequence
        case "end_turn", "model_context_window_exceeded", nil: reason = .end_turn
        default: reason = .error
        }
        var message = Message(role: .assistant, content: .init(blocks: blocks))
        message.providerContinuation = ["anthropic": try ProviderJSON.text(content)]
        let counts = [input, cachedRead, cachedWrite, output].compactMap { $0 }
        return .init(
            message: message, stopReason: reason,
            usage: .init(
                inputTokens: input, outputTokens: output,
                totalTokens: counts.isEmpty ? nil : counts.reduce(0, +),
                cachedInputReadTokens: cachedRead, cachedInputWriteTokens: cachedWrite),
            metadata: ["provider": "anthropic", "response_id": object["id"] as? String ?? ""])
    }
}

package struct AnthropicStreamAccumulator {
    private var message: [String: Any] = [:]
    private var blocks: [Int: [String: Any]] = [:]
    private var partialInputs: [Int: String] = [:]
    package private(set) var completed = false

    package init() {}

    package mutating func consume(_ event: ProviderSSEEvent) throws -> [AgentStreamEvent] {
        let json = try ProviderJSON.object(Data(event.data.utf8))
        let type = json["type"] as? String ?? event.name
        switch type {
        case "message_start":
            guard let value = json["message"] as? [String: Any] else {
                throw ProviderHTTPError.invalidJSON
            }
            message = value
        case "content_block_start":
            guard let index = json["index"] as? Int,
                let block = json["content_block"] as? [String: Any]
            else { throw ProviderHTTPError.invalidJSON }
            blocks[index] = block
        case "content_block_delta":
            guard let index = json["index"] as? Int, let delta = json["delta"] as? [String: Any]
            else {
                throw ProviderHTTPError.invalidJSON
            }
            switch delta["type"] as? String {
            case "text_delta":
                let value = delta["text"] as? String ?? ""
                blocks[index, default: [:]]["text"] =
                    (blocks[index]?["text"] as? String ?? "") + value
                return [.messagedelta(.text(value))]
            case "input_json_delta":
                partialInputs[index, default: ""] += delta["partial_json"] as? String ?? ""
            case "thinking_delta":
                let value = delta["thinking"] as? String ?? ""
                blocks[index, default: [:]]["thinking"] =
                    (blocks[index]?["thinking"] as? String ?? "") + value
            case "signature_delta":
                blocks[index, default: [:]]["signature"] = delta["signature"] as? String ?? ""
            default: break
            }
        case "content_block_stop":
            guard let index = json["index"] as? Int else { throw ProviderHTTPError.invalidJSON }
            if let raw = partialInputs.removeValue(forKey: index) {
                guard let data = raw.data(using: .utf8) else { throw ProviderHTTPError.invalidJSON }
                blocks[index, default: [:]]["input"] = try JSONSerialization.jsonObject(
                    with: data, options: [.fragmentsAllowed])
            }
            if let block = blocks[index], let call = try AnthropicMapper.call(block) {
                return [.call(call)]
            }
        case "message_delta":
            if let delta = json["delta"] as? [String: Any], let reason = delta["stop_reason"] {
                message["stop_reason"] = reason
            }
            if let usage = json["usage"] as? [String: Any] {
                var current = message["usage"] as? [String: Any] ?? [:]
                for (key, value) in usage { current[key] = value }
                message["usage"] = current
            }
        case "message_stop":
            message["content"] = blocks.keys.sorted().compactMap { blocks[$0] }
            completed = true
            return [.completed(try AnthropicMapper.response(message))]
        case "error": throw ProviderHTTPError.streamError(event.data)
        default: break
        }
        return []
    }
}
