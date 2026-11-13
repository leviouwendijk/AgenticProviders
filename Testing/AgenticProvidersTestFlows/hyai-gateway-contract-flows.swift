import Agentic
@testable import AgenticHYAI
import Foundation
import Primitives
import TestFlows

/// HostYourAI speaks the OpenAI wire format. Agentic's own naming
/// (FunctionCall) must never leak into it: the wire field is `tool_calls`.
extension AgenticProvidersFlowTesting {
    static func runHYAIOutgoingToolCalls() throws -> [TestDiagnostic] {
        let call = FunctionCall(
            id: "call_1",
            name: "read_file",
            input: .object(["path": .string("README.md")])
        )
        let request = AgentRequest(messages: [
            .init(id: "u0", role: .user, content: .init(text: "Read the readme.")),
            .init(id: "a0", role: .assistant, content: .init(blocks: [.call(call)])),
            .init(id: "t0", role: .tool, content: .init(blocks: [
                .result(.init(call: call.reference, output: .string("# Readme"))),
            ])),
        ])
        let mapped = try HYAIRequestMapper.map(
            request,
            model: "hyai/auto",
            purpose: .executor,
            configuration: try .init(apiKey: "offline"),
            stream: true
        )
        let json = String(decoding: try HYAICodec.encode(mapped), as: UTF8.self)

        try Expect.true(json.contains(#""tool_calls""#), "Assistant calls encode as tool_calls")
        try Expect.true(!json.contains("function_calls"), "Internal naming never reaches the wire")
        try Expect.true(json.contains(#""tool_call_id":"call_1""#), "Results keep their call id")

        let assistant = mapped.messages[1]
        try Expect.equal(assistant.toolCalls?.first?.id, "call_1", "Call id is preserved")
        try Expect.equal(assistant.toolCalls?.first?.function?.name, "read_file", "Function name is preserved")
        try Expect.equal(
            try JSONValue.decodeJSON(assistant.toolCalls?.first?.function?.arguments),
            call.input,
            "Arguments are preserved"
        )
        return [.field("bytes", String(json.utf8.count))]
    }

    static func runHYAIBufferedToolCalls() throws -> [TestDiagnostic] {
        let response = try HYAICodec.decode(
            HYAIChatCompletionResponse.self,
            from: Data(#"""
            {"model":"qwen/qwen3.8-27b","choices":[{"finish_reason":"tool_calls","message":{"role":"assistant","content":null,"tool_calls":[{"id":"call_1","type":"function","function":{"name":"list_directory","arguments":"{\"path\":\".\"}"}}]}}]}
            """#.utf8)
        )
        let mapped = try HYAIResponseMapper.map(response, requestedModel: "hyai/auto", metadata: [:])

        try Expect.equal(mapped.stopReason, .tool_use, "Tool calls stop for tool use")
        try Expect.equal(
            mapped.message.content.blocks,
            [.call(.init(id: "call_1", name: "list_directory", input: .object(["path": .string(".")])))],
            "A tool-only message carries its call"
        )

        let empty = try HYAICodec.decode(
            HYAIChatCompletionResponse.self,
            from: Data(#"{"choices":[{"finish_reason":"tool_calls","message":{"role":"assistant","content":"\n\n"}}]}"#.utf8)
        )
        try expectMissingToolCalls {
            _ = try HYAIResponseMapper.map(empty, requestedModel: "hyai/auto", metadata: [:])
        }
        return []
    }

    static func runHYAIStreamedToolCalls() throws -> [TestDiagnostic] {
        // Two calls, interleaved; the name arrives once, arguments in fragments.
        let frames = [
            #"{"model":"qwen/qwen3.8-27b","choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_a","type":"function","function":{"name":"read_file","arguments":""}}]}}]}"#,
            #"{"choices":[{"delta":{"tool_calls":[{"index":1,"id":"call_b","type":"function","function":{"name":"list_directory","arguments":"{\"pa"}}]}}]}"#,
            #"{"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\"path\":"}}]}}]}"#,
            #"{"choices":[{"delta":{"tool_calls":[{"index":1,"function":{"arguments":"th\":\".\"}"}}]}}]}"#,
            #"{"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\"README.md\"}"}}]}}]}"#,
            #"{"choices":[{"delta":{},"finish_reason":"tool_calls"}]}"#,
        ]
        let response = try stream(frames)

        try Expect.equal(response.stopReason, .tool_use, "Streamed tool calls stop for tool use")
        try Expect.equal(
            response.message.content.blocks,
            [
                .call(.init(id: "call_a", name: "read_file", input: .object(["path": .string("README.md")]))),
                .call(.init(id: "call_b", name: "list_directory", input: .object(["path": .string(".")]))),
            ],
            "Fragments reassemble per index without mixing"
        )

        try expectMissingToolCalls {
            _ = try stream([
                #"{"choices":[{"delta":{"content":"\n\n"}}]}"#,
                #"{"choices":[{"delta":{},"finish_reason":"tool_calls"}]}"#,
            ])
        }
        return [.field("calls", "2")]
    }

    private static func stream(
        _ frames: [String]
    ) throws -> AgentResponse {
        var accumulator = HYAIStreamAccumulator(requestedModel: "hyai/auto", metadata: [:])
        var completed: AgentResponse?
        for frame in frames {
            let chunk = try HYAICodec.decode(HYAIChatCompletionChunk.self, from: Data(frame.utf8))
            for event in try accumulator.consume(chunk) {
                if case .completed(let response) = event {
                    completed = response
                }
            }
        }
        guard let completed else {
            throw HYAIContractFixtureError.noResponse
        }
        return completed
    }

    private static func expectMissingToolCalls(
        _ body: () throws -> Void
    ) throws {
        do {
            try body()
        } catch HYAIGatewayError.missingToolCalls {
            return
        }
        throw HYAIContractFixtureError.expectedMissingToolCalls
    }
}

private extension JSONValue {
    static func decodeJSON(_ text: String?) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data((text ?? "").utf8))
    }
}

private enum HYAIContractFixtureError: Error {
    case noResponse
    case expectedMissingToolCalls
}
