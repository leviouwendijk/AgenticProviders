import Agentic
import AgenticAnthropic
import AgenticHYAI
import Foundation
import Primitives
import TestFlows

/// Live: whether a gateway lets the model call a tool by its own name when
/// that tool is not in the request's definitions, its contract only in the
/// history (as `inspect_capability` leaves it). Two questions, answered
/// apart:
///
/// 1. Does a call to the undeclared name come back from the gateway?
/// 2. Is a request with such a call in its history accepted?
///
/// Both yes: the gateway can take direct calls, and `inspect_capability`
/// can say "call it by its own name" there instead of `call_capability`.
/// Live calls cost money, so it runs only when asked for, with the
/// gateway's key present:
/// `AGENTIC_PROBE_DIRECT_CALLS=1 with_dev_environment .build/release/t_ap_main --tag direct-call-probe`.
extension AgenticProvidersFlowTesting {
    static func runHYAIDirectCallProbe() async throws -> [TestDiagnostic] {
        try skipUnlessProbing()
        let key = ProcessInfo.processInfo.environment[HYAIModelGateway.apiKeySymbol] ?? ""
        try TestFlowSkip.unless(!key.isEmpty, "\(HYAIModelGateway.apiKeySymbol) is unset.")
        let model = ProcessInfo.processInfo.environment["AGENTIC_PROBE_HYAI_MODEL"]
            ?? "deepseek-ai/DeepSeek-V4-Pro"
        return try await directCallProbe(
            gateway: try HYAIModelGateway(apiKey: key),
            model: model
        )
    }

    static func runAnthropicDirectCallProbe() async throws -> [TestDiagnostic] {
        try skipUnlessProbing()
        let key = ProcessInfo.processInfo.environment[AnthropicAPI.api_key_symbol] ?? ""
        try TestFlowSkip.unless(!key.isEmpty, "\(AnthropicAPI.api_key_symbol) is unset.")
        let model = ProcessInfo.processInfo.environment["AGENTIC_PROBE_ANTHROPIC_MODEL"]
            ?? "claude-haiku-5-5"
        return try await directCallProbe(
            gateway: try AnthropicModelGateway(apiKey: key),
            model: model
        )
    }

    private static func skipUnlessProbing() throws {
        try TestFlowSkip.unless(
            ProcessInfo.processInfo.environment["AGENTIC_PROBE_DIRECT_CALLS"] == "1",
            "Live probe: set AGENTIC_PROBE_DIRECT_CALLS=1 to run it."
        )
    }

    private static func directCallProbe(
        gateway: any AgentModelGateway,
        model: String
    ) async throws -> [TestDiagnostic] {
        let route = AgentModelRoute(
            purpose: .executor,
            profile: AgentModelProfile(
                identifier: AgentModelProfileIdentifier("direct-call-probe:\(gateway.identifier.rawValue):\(model)"),
                gatewayIdentifier: gateway.identifier,
                model: model,
                purposes: [.executor],
                capabilities: [.text, .tool_use]
            )
        )
        let lookupSchema: JSONValue = .object([
            "type": .string("object"),
            "properties": .object([
                "key": .object([
                    "type": .string("string"),
                    "description": .string("The key to look up."),
                ]),
            ]),
            "required": .array([.string("key")]),
        ])
        // Declared: the inspector, and an unrelated tool so the definitions
        // are not only the one the model just used.
        let tools = [
            ToolDescriptor(
                name: "inspect_capability",
                description: "Return one available capability's contract.",
                input: .object([
                    "type": .string("object"),
                    "properties": .object(["identifier": .object(["type": .string("string")])]),
                    "required": .array([.string("identifier")]),
                ])
            ),
            ToolDescriptor(
                name: "probe_echo",
                description: "Echo text back. Not needed for lookups.",
                input: .object([
                    "type": .string("object"),
                    "properties": .object(["text": .object(["type": .string("string")])]),
                    "required": .array([.string("text")]),
                ])
            ),
        ]
        // The history as it stands after an inspection: the contract of
        // `probe_lookup`, which is not among the definitions.
        let inspect = FunctionCall(
            id: "probe_inspect_1",
            name: "inspect_capability",
            input: .object(["identifier": .string("probe_lookup")])
        )
        let contract: JSONValue = .object([
            "identifier": .string("probe_lookup"),
            "purpose": .string("Look up the stored value for a key."),
            "input": lookupSchema,
            "callWith": .string("probe_lookup (call it by its own name)"),
        ])
        let opening: [Message] = [
            Message(
                role: .system,
                text: "You run tool calls for a test. A capability you inspected is callable by its own name, even when it is not in your tool list."
            ),
            Message(role: .user, text: "Look up the value stored under the key 'alpha'."),
            Message(role: .assistant, content: .init(blocks: [.call(inspect)])),
            Message(role: .tool, content: .init(blocks: [.result(.init(call: inspect.reference, output: contract))])),
        ]

        // 1. Does a call to the undeclared name come back?
        var returned = "no call"
        var shape = ""
        var directCall: FunctionCall?
        do {
            let response = try await gateway.respond(
                request: AgentRequest(messages: opening, tools: tools),
                route: route
            )
            let calls = response.message.content.blocks.compactMap { block -> FunctionCall? in
                guard case .call(let call) = block else { return nil }
                return call
            }
            directCall = calls.first { $0.name == "probe_lookup" }
            let kinds = response.message.content.blocks.map { block -> String in
                switch block {
                case .text: "text"
                case .call(let call): "call:" + call.name
                default: String(describing: block).prefix(20).description
                }
            }
            shape = "stop \(String(describing: response.stopReason)); finish \(response.metadata["finish_reason"] ?? "-"); blocks [\(kinds.joined(separator: ", "))]"
            returned = directCall != nil
                ? "returned"
                : calls.isEmpty
                    ? "model answered in text: " + String(response.message.content.text.prefix(160))
                    : "model called " + calls.map { $0.name }.joined(separator: ", ")
        } catch {
            returned = "gateway error: \(error)"
        }

        // Control: the same request with `probe_lookup` declared. A call
        // here but not above means the gateway or model needs the
        // definition; no call here either means the setup, not the gateway.
        var control = "no call"
        do {
            let declared = tools + [ToolDescriptor(
                name: "probe_lookup",
                description: "Look up the stored value for a key.",
                input: lookupSchema
            )]
            let response = try await gateway.respond(
                request: AgentRequest(messages: opening, tools: declared),
                route: route
            )
            control = response.message.content.blocks.contains { block in
                guard case .call(let call) = block else { return false }
                return call.name == "probe_lookup"
            } ? "returned" : "no call (finish \(response.metadata["finish_reason"] ?? "-"))"
        } catch {
            control = "gateway error: \(error)"
        }

        // 2. Is a history holding such a call accepted? Uses the returned
        // call, or a constructed one when the model did not make it, so this
        // answer does not depend on the first.
        let call = directCall ?? FunctionCall(
            id: "probe_lookup_1",
            name: "probe_lookup",
            input: .object(["key": .string("alpha")])
        )
        var accepted = "no"
        do {
            let response = try await gateway.respond(
                request: AgentRequest(
                    messages: opening + [
                        Message(role: .assistant, content: .init(blocks: [.call(call)])),
                        Message(role: .tool, content: .init(blocks: [.result(.init(
                            call: call.reference,
                            output: .object(["value": .string("forty-two")])
                        ))])),
                    ],
                    tools: tools
                ),
                route: route
            )
            accepted = "accepted: " + String(response.message.content.text.prefix(120))
        } catch {
            accepted = "rejected: \(error)"
        }

        let diagnostics: [TestDiagnostic] = [
            .field("gateway", gateway.identifier.rawValue),
            .field("model", model),
            .field("undeclared_call", returned),
            .field("response", shape),
            .field("declared_control", control),
            .field("history", accepted),
        ]
        try Expect.true(
            returned == "returned" && accepted.hasPrefix("accepted"),
            "direct calls to undeclared tools: call \(returned) (\(shape)); declared control \(control); history \(accepted)"
        )
        return diagnostics
    }
}
