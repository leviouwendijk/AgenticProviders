import Agentic
import AgenticModels
import AgenticProviderHTTP
import Foundation
import Milieu
import Primitives

public struct OpenAIModelGateway: AgentModelGateway {
    public let identifier: AgentModelGatewayIdentifier
    private let client: ProviderHTTP

    public init(
        identifier: AgentModelGatewayIdentifier = "openai_responses", apiKey: String,
        endpoint: String = OpenAIAPI.endpoint
    ) throws {
        self.identifier = identifier
        self.client = try .init(
            endpoint: endpoint, apiKey: apiKey, headers: ["Authorization": "Bearer \(apiKey)"])
    }

    public var response: AgentModelResponseProviding { OpenAIResponseProvider(client: client) }
}

public struct OpenAIModelProvider: AgentModelProvider {
    public let descriptor = AgentModelProviderDescriptor(source: "openai", displayName: "OpenAI")
    public let api_key_symbol: String
    public let endpoint: String
    public let gatewayIdentifier: AgentModelGatewayIdentifier

    public init(
        api_key_symbol: String = OpenAIAPI.api_key_symbol, endpoint: String = OpenAIAPI.endpoint,
        gatewayIdentifier: AgentModelGatewayIdentifier = "openai_responses"
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
                        try OpenAIModelGateway(
                            identifier: identifier, apiKey: key, endpoint: endpoint))
                } catch let error as EnvironmentExtractableError {
                    switch error {
                    case .missing, .empty:
                        return .unavailable(
                            .init(
                                kind: .missing_configuration,
                                message: "OpenAI API key unavailable.",
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
                    source: "openai",
                    profiles: [
                        .init(
                            known: KnownModel.gpt.astra_6,
                            identifier: "openai:astra_6", gatewayIdentifier: gatewayIdentifier,
                            model: "gpt-6-astra", title: "GPT-6 Astra",
                            capabilities: [
                                .text, .tool_use, .streaming, .structured_output, .reasoning,
                            ]),
                        .init(
                            known: KnownModel.gpt.sol_6_1,
                            identifier: "openai:sol_6_1", gatewayIdentifier: gatewayIdentifier,
                            model: "gpt-6.1-sol", title: "GPT-6.1 Sol",
                            capabilities: [
                                .text, .tool_use, .streaming, .structured_output, .reasoning,
                            ]),
                        .init(
                            known: KnownModel.gpt.terra_6_1,
                            identifier: "openai:terra_6_1", gatewayIdentifier: gatewayIdentifier,
                            model: "gpt-6.1-terra", title: "GPT-6.1 Terra",
                            capabilities: [
                                .text, .tool_use, .streaming, .structured_output, .reasoning,
                            ]),
                        .init(
                            known: KnownModel.gpt.luna_6,
                            identifier: "openai:luna_6", gatewayIdentifier: gatewayIdentifier,
                            model: "gpt-6-luna", title: "GPT-6 Luna",
                            capabilities: [
                                .text, .tool_use, .streaming, .structured_output, .reasoning,
                            ]),
                    ]))
        ]
    }
}

struct OpenAIResponseProvider: AgentModelResponseProviding {
    let client: ProviderHTTP

    func countInputTokens(
        request: AgentRequest, route: AgentModelRoute, context _: AgentModelInvocationContext
    ) async throws -> Int? {
        let body = try OpenAIMapper.countRequest(request, model: route.profile.model)
        let data = try await client.post(
            path: "/responses/input_tokens", body: body,
            timeout: request.invocationoptions?.timeoutseconds)
        return try ProviderJSON.inputTokenCount(data)
    }

    func buffered(
        request: AgentRequest, route: AgentModelRoute, context _: AgentModelInvocationContext
    ) async throws -> AgentResponse {
        let body = try OpenAIMapper.request(request, model: route.profile.model, stream: false)
        return try OpenAIMapper.response(
            ProviderJSON.object(
                await client.post(
                    path: "/responses", body: body,
                    timeout: request.invocationoptions?.timeoutseconds)))
    }

    func stream(
        request: AgentRequest, route: AgentModelRoute, context _: AgentModelInvocationContext
    )
        -> AsyncThrowingStream<AgentStreamEvent, Error>
    {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let body = try OpenAIMapper.request(
                        request, model: route.profile.model, stream: true)
                    var completed = false
                    for try await event in client.stream(
                        path: "/responses", body: body,
                        timeout: request.invocationoptions?.timeoutseconds)
                    {
                        if event.data == "[DONE]" { continue }
                        let item = try ProviderJSON.object(Data(event.data.utf8))
                        let type = item["type"] as? String ?? event.name
                        switch type {
                        case "response.output_text.delta":
                            if let text = item["delta"] as? String {
                                continuation.yield(.messagedelta(.text(text)))
                            }
                        case "response.output_item.done":
                            if let output = item["item"] as? [String: Any],
                                let call = try OpenAIMapper.call(output)
                            {
                                continuation.yield(.call(call))
                            }
                        case "response.completed", "response.incomplete":
                            guard let response = item["response"] as? [String: Any] else {
                                throw ProviderHTTPError.invalidJSON
                            }
                            continuation.yield(.completed(try OpenAIMapper.response(response)))
                            completed = true
                        case "response.failed", "error":
                            throw ProviderHTTPError.streamError(event.data)
                        default: break
                        }
                    }
                    guard completed else { throw ProviderHTTPError.streamEnded }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

enum OpenAIMapper {
    static func request(_ request: AgentRequest, model: String, stream: Bool) throws -> Data {
        guard !request.messages.isEmpty else { throw ProviderHTTPError.invalidJSON }
        var input: [[String: Any]] = []
        for message in request.messages {
            if message.role == .assistant, let raw = message.providerContinuation?["openai"],
                let data = raw.data(using: .utf8),
                let saved = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            {
                input.append(contentsOf: saved)
                continue
            }
            var texts: [String] = []
            for block in message.content.blocks {
                switch block {
                case .text(let value): texts.append(value)
                case .call(let call):
                    guard message.role == .assistant else { throw ProviderHTTPError.invalidJSON }
                    if !texts.isEmpty {
                        input.append(["role": "assistant", "content": texts.joined()])
                        texts.removeAll()
                    }
                    input.append([
                        "type": "function_call", "call_id": call.id, "name": call.name,
                        "arguments": try ProviderJSON.text(call.input),
                    ])
                case .result(let result):
                    guard message.role == .tool else { throw ProviderHTTPError.invalidJSON }
                    input.append([
                        "type": "function_call_output", "call_id": result.call.id,
                        "output": result.modelText,
                    ])
                case .resource:
                    throw ProviderHTTPError.streamError("OpenAI resource inputs not yet supported")
                }
            }
            if !texts.isEmpty {
                let role = message.role == .tool ? "user" : message.role.rawValue
                input.append(["role": role, "content": texts.joined()])
            }
        }
        var payload: [String: Any] = [
            "model": model, "input": input, "stream": stream, "store": false,
            "include": ["reasoning.encrypted_content"],
        ]
        let config = request.generationConfiguration
        if let max = config.maxOutputTokens { payload["max_output_tokens"] = max }
        if let temperature = config.temperature { payload["temperature"] = temperature }
        if let topP = config.topP { payload["top_p"] = topP }
        if !config.stopSequences.isEmpty {
            throw ProviderHTTPError.streamError("OpenAI Responses stop sequences not implemented")
        }
        if !request.tools.isEmpty {
            payload["tools"] = try request.tools.map { tool -> [String: Any] in
                [
                    "type": "function", "name": tool.name, "description": tool.description,
                    "parameters": try tool.input.map(ProviderJSON.foundation) ?? [
                        "type": "object", "properties": [:],
                    ], "strict": false,
                ]
            }
        }
        switch request.responseFormat {
        case .text: break
        case .jsonschema(let schema):
            payload["text"] = [
                "format": [
                    "type": "json_schema", "name": "agentic_response",
                    "schema": try ProviderJSON.foundation(schema.jsonvalue), "strict": false,
                ]
            ]
        }
        return try ProviderJSON.encode(payload)
    }

    /// Use the generation mapper so native replay and schemas occur once.
    /// The count endpoint does not accept response-generation parameters.
    static func countRequest(_ request: AgentRequest, model: String) throws -> Data {
        let payload = try ProviderJSON.object(Self.request(request, model: model, stream: false))
        let fields: Set<String> = [
            "model", "input", "instructions", "tools", "text", "reasoning",
            "tool_choice", "parallel_tool_calls", "conversation", "previous_response_id",
        ]
        return try ProviderJSON.encode(payload.filter { fields.contains($0.key) })
    }

    static func call(_ item: [String: Any]) throws -> FunctionCall? {
        guard item["type"] as? String == "function_call" else { return nil }
        guard let id = item["call_id"] as? String,
            let name = item["name"] as? String,
            let raw = item["arguments"] as? String
        else { throw ProviderHTTPError.invalidJSON }
        let input = try JSONDecoder().decode(JSONValue.self, from: Data(raw.utf8))
        return .init(id: id, name: name, input: input)
    }

    static func response(_ object: [String: Any]) throws -> AgentResponse {
        guard let output = object["output"] as? [[String: Any]] else {
            throw ProviderHTTPError.invalidJSON
        }
        if object["status"] as? String == "failed" {
            throw ProviderHTTPError.streamError(try ProviderJSON.text(object))
        }
        var blocks: [MessageContentBlock] = []
        for item in output {
            switch item["type"] as? String {
            case "message":
                for content in item["content"] as? [[String: Any]] ?? [] {
                    if content["type"] as? String == "output_text",
                        let text = content["text"] as? String
                    {
                        blocks.append(.text(text))
                    }
                }
            case "function_call":
                guard let call = try call(item) else { throw ProviderHTTPError.invalidJSON }
                blocks.append(.call(call))
            default: break
            }
        }
        let usage = object["usage"] as? [String: Any] ?? [:]
        let input = usage["input_tokens"] as? Int
        let cached = (usage["input_tokens_details"] as? [String: Any])?["cached_tokens"] as? Int
        let outputTokens = usage["output_tokens"] as? Int
        let reasoning =
            (usage["output_tokens_details"] as? [String: Any])?["reasoning_tokens"] as? Int
        let incomplete = object["status"] as? String == "incomplete"
        let reason: AgentStopReason =
            incomplete
            ? .max_tokens
            : (blocks.contains {
                if case .call = $0 { return true }
                return false
            } ? .tool_use : .end_turn)
        var message = Message(role: .assistant, content: .init(blocks: blocks))
        message.providerContinuation = ["openai": try ProviderJSON.text(output)]
        return .init(
            message: message, stopReason: reason,
            usage: .init(
                inputTokens: input.map { $0 - (cached ?? 0) }, outputTokens: outputTokens,
                totalTokens: usage["total_tokens"] as? Int,
                cachedInputReadTokens: cached, reasoningOutputTokens: reasoning),
            metadata: ["provider": "openai", "response_id": object["id"] as? String ?? ""])
    }
}
