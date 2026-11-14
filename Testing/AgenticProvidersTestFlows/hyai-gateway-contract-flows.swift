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
            .init(id: "t1", role: .tool, content: .init(blocks: [
                .result(
                    FunctionCall.Response(
                        call: call.reference,
                        output: .object(["entries": .array([.string("Sources/a.swift")])])
                    ).rendered("Sources/\n    a.swift")
                ),
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
        try Expect.true(
            json.contains(#""stream_options":{"include_usage":true}"#),
            "Streams ask for usage"
        )

        try Expect.equal(mapped.messages[2].content, ##""# Readme""##, "Unrendered results stay JSON")
        try Expect.equal(
            mapped.messages[3].content,
            "Sources/\n    a.swift",
            "A rendered result is sent as its text, not as a JSON string"
        )

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

        let broken = try HYAIResponseMapper.mapToolCall(id: "call_2", name: "ask_user", arguments: #"{"input": {"#)
        try Expect.equal(
            broken.malformedArguments,
            #"{"input": {"#,
            "Unparseable arguments keep the call, marked, for the run to answer"
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
            // include_usage: usage follows finish_reason in its own chunk.
            #"{"choices":[],"usage":{"prompt_tokens":12000,"completion_tokens":80,"total_tokens":12080,"prompt_tokens_details":{"cached_tokens":10240}}}"#,
        ]
        let response = try stream(frames)
        try Expect.equal(response.usage?.cachedInputReadTokens, 10240, "Usage after finish_reason is kept")
        try Expect.equal(response.usage?.inputTokens, 1760, "Uncached input excludes cache reads")

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

    static func runHYAILivePricing() throws -> [TestDiagnostic] {
        let list = try HYAICodec.decode(HYAIModelList.self, from: Data(#"""
        {"data":[
          {"id":"hyai/auto","pricing":{"input_per_million":null,"output_per_million":null,"currency":"EUR"}},
          {"id":"deepseek-ai/DeepSeek-V4-Flash","pricing":{"input_per_million":0.29,"cached_input_per_million":0.07,"output_per_million":0.35,"currency":"EUR"}},
          {"id":"google/gemma-3-27b-it","pricing":{"input_per_million":0.1,"output_per_million":0.32,"currency":"EUR"}},
          {"id":"BAAI/bge-m3","pricing":{"currency":"EUR"}}
        ]}
        """#.utf8))
        let snapshots = try HYAIModelCatalog.liveSnapshots(list, fetchedAt: Date())
        try Expect.equal(
            snapshots.map(\.model),
            ["deepseek-ai/DeepSeek-V4-Flash", "google/gemma-3-27b-it"],
            "Only models with input and output prices are priced"
        )
        let flash = snapshots[0]
        try Expect.equal(flash.source, .live, "Live snapshots are marked live")
        try Expect.equal(
            flash.components.first { $0.kind == .cachedInputReadTokens }?.priceMicros,
            70000,
            "Cached input price is kept"
        )
        try Expect.equal(
            flash.components.first { $0.kind == .inputTokens }?.priceMicros,
            290000,
            "Input price converts to micros"
        )
        try Expect.true(
            !snapshots[1].components.contains { $0.kind == .cachedInputReadTokens },
            "No cached price is invented"
        )

        // Billed names differ from catalog IDs: deepseek/deepseek-v4-flash.
        let catalog = StaticModelPricingCatalog(snapshots: snapshots)
        let billed = try catalog.pricing(for: .init(
            provider: "hostyourai", model: "deepseek/deepseek-v4-flash", region: nil
        ))
        try Expect.equal(billed.model, flash.model, "Billed names resolve to the catalog entry")
        return [.field("priced", String(snapshots.count))]
    }

    private static func stream(
        _ frames: [String]
    ) throws -> AgentResponse {
        var accumulator = HYAIStreamAccumulator(requestedModel: "hyai/auto", metadata: [:])
        for frame in frames {
            let chunk = try HYAICodec.decode(HYAIChatCompletionChunk.self, from: Data(frame.utf8))
            for event in try accumulator.consume(chunk) {
                if case .completed = event {
                    // Completion waits for the end of the stream.
                    throw HYAIContractFixtureError.noResponse
                }
            }
        }
        guard case .completed(let completed) = try accumulator.finish() else {
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
