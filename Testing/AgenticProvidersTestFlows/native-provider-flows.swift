import Agentic
import AgenticProviderHTTP
import Foundation
import Primitives
import TestFlows

@testable import AgenticAnthropic
@testable import AgenticOpenAI

extension AgenticProvidersFlowTesting {
    static func runNativeProviderWireContracts() throws -> [TestDiagnostic] {
        let call = FunctionCall(
            id: "call_1", name: "read_file", input: .object(["path": .string("README.md")]))
        let messages: [Message] = [
            .init(role: .user, text: "Read the file"),
            .init(role: .assistant, content: .init(blocks: [.call(call)])),
            .init(
                role: .tool,
                content: .init(blocks: [.result(.init(call: call.reference, output: .string("ok")))]
                )),
        ]
        let request = AgentRequest(messages: messages, tools: [])
        let openai = try ProviderJSON.object(
            OpenAIMapper.request(request, model: "gpt-6-astra", stream: false))
        let outputItems = openai["input"] as? [[String: Any]] ?? []
        try Expect.true(
            outputItems.contains { $0["type"] as? String == "function_call" },
            "OpenAI emits native function_call items")
        try Expect.true(
            outputItems.contains { $0["type"] as? String == "function_call_output" },
            "OpenAI emits tool result item")
        let anthropic = try ProviderJSON.object(
            AnthropicMapper.request(request, model: "claude-opus-5", stream: false))
        let messageItems = anthropic["messages"] as? [[String: Any]] ?? []
        let nested = messageItems.flatMap { $0["content"] as? [[String: Any]] ?? [] }
        try Expect.true(
            nested.contains { $0["type"] as? String == "tool_use" },
            "Anthropic emits native tool_use")
        try Expect.true(
            nested.contains { $0["type"] as? String == "tool_result" },
            "Anthropic emits native tool_result")
        return [
            .field("openai_items", String(outputItems.count)),
            .field("anthropic_blocks", String(nested.count)),
        ]
    }

    static func runNativeProviderContinuation() throws -> [TestDiagnostic] {
        let openai: [String: Any] = [
            "id": "resp_test", "status": "completed",
            "output": [
                ["type": "reasoning", "encrypted_content": "opaque"],
                [
                    "type": "function_call", "call_id": "call_1", "name": "read_file",
                    "arguments": "{\"path\":\"README.md\"}",
                ],
            ],
        ]
        let response = try OpenAIMapper.response(openai)
        try Expect.true(
            response.message.providerContinuation?["openai"]?.contains("encrypted_content") == true,
            "OpenAI reasoning continuation retained")
        let serialized = try JSONEncoder().encode(response.message)
        let restored = try JSONDecoder().decode(Message.self, from: serialized)
        try Expect.equal(
            restored.providerContinuation, response.message.providerContinuation,
            "Provider continuation survives persistence")
        let anthropic: [String: Any] = [
            "id": "msg_test", "stop_reason": "tool_use",
            "content": [
                ["type": "thinking", "thinking": "test", "signature": "opaque_signature"],
                [
                    "type": "tool_use", "id": "toolu_1", "name": "read_file",
                    "input": ["path": "README.md"],
                ],
            ],
        ]
        let other = try AnthropicMapper.response(anthropic)
        try Expect.true(
            other.message.providerContinuation?["anthropic"]?.contains("opaque_signature") == true,
            "Anthropic signed thinking retained")
        return [.field("continuation", "roundtrip")]
    }

    static func runAnthropicNativeStream() throws -> [TestDiagnostic] {
        var stream = AnthropicStreamAccumulator()
        let events: [(String, String)] = [
            (
                "message_start",
                #"{"type":"message_start","message":{"id":"msg_test","type":"message","role":"assistant","content":[],"usage":{"input_tokens":10,"output_tokens":0}}}"#
            ),
            (
                "content_block_start",
                #"{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}"#
            ),
            (
                "content_block_delta",
                #"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"hello"}}"#
            ),
            ("content_block_stop", #"{"type":"content_block_stop","index":0}"#),
            (
                "message_delta",
                #"{"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":4}}"#
            ),
            ("message_stop", #"{"type":"message_stop"}"#),
        ]
        var outputs: [AgentStreamEvent] = []
        for (name, data) in events {
            outputs.append(contentsOf: try stream.consume(.init(name: name, data: data)))
        }
        try Expect.true(stream.completed, "Stream reached message_stop")
        try Expect.true(
            outputs.contains {
                if case .messagedelta(.text("hello")) = $0 { return true }
                return false
            }, "Text streaming preserved")
        try Expect.true(
            outputs.contains {
                if case .completed = $0 { return true }
                return false
            }, "Final response emitted")
        return [.field("events", String(outputs.count))]
    }
}
