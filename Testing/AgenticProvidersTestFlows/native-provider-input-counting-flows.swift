import Agentic
import AgenticProviderHTTP
import Foundation
import TestFlows

@testable import AgenticAnthropic
@testable import AgenticOpenAI

extension AgenticProvidersFlowTesting {
    static func runNativeProviderInputCounting() throws -> [TestDiagnostic] {
        // Claude profiles serve every role an agent declares (planner,
        // coder, reviewer…), so an explicit Claude selection is never
        // rejected for its purpose and silently rerouted.
        let claude = try AnthropicModelProvider().profileProviders.flatMap { try $0.profiles() }
        for purpose in AgentModelRoutePurpose.allCases where purpose != .local_private {
            try Expect.true(
                claude.allSatisfy { $0.purposes.contains(purpose) },
                "every Claude profile serves \(purpose.rawValue)"
            )
        }
        let call = FunctionCall(id: "count.call", name: "read_file", input: .object([:]))
        let openai: [[String: Any]] = [
            ["type": "reasoning", "id": "rs_fixture", "summary": [],
             "encrypted_content": "fixture-only-encrypted-reasoning"],
            ["type": "function_call", "call_id": call.id, "name": call.name, "arguments": "{}"],
        ]
        let anthropic: [[String: Any]] = [
            ["type": "thinking", "thinking": "fixture reasoning", "signature": "fixture-only-signature"],
            ["type": "tool_use", "id": call.id, "name": call.name, "input": [:]],
        ]
        let request = AgentRequest(
            messages: [
                .init(id: "count.system", role: .system, content: .init(text: "Review the source.")),
                .init(id: "count.user", role: .user, content: .init(text: "Inspect Layout.swift.")),
                .init(id: "count.assistant", role: .assistant,
                      content: .init(blocks: [.text("Stored duplicate only."), .call(call)]),
                      providerContinuation: [
                        "openai": try ProviderJSON.text(openai),
                        "anthropic": try ProviderJSON.text(anthropic),
                      ]),
                .init(id: "count.tool", role: .tool, content: .init(blocks: [
                    .result(.init(call: call.reference,
                                  output: .object(["archive": .string("not transmitted")]),
                                  text: "Layout.swift:10: wrapping is character-based.")),
                ])),
            ],
            tools: [.init(identifier: "read_file", description: "Read a file.",
                          input: .object(["type": .string("object")]))],
            generationConfiguration: .init(maxOutputTokens: 256),
            responseFormat: .jsonschema(.object(properties: [
                .init(name: "summary", schema: .string()),
            ]))
        )
        let openaiBody = try OpenAIMapper.countRequest(request, model: "fixture-openai")
        let anthropicBody = try AnthropicMapper.countRequest(request, model: "fixture-anthropic")
        let openaiCount = try ProviderJSON.object(openaiBody)
        let anthropicCount = try ProviderJSON.object(anthropicBody)
        let openaiGeneration = try ProviderJSON.object(
            OpenAIMapper.request(request, model: "fixture-openai", stream: false))
        let anthropicGeneration = try ProviderJSON.object(
            AnthropicMapper.request(request, model: "fixture-anthropic", stream: false))

        func match(_ field: String, count: [String: Any], generation: [String: Any]) throws {
            guard let measured = count[field], let sent = generation[field] else {
                throw ProviderHTTPError.invalidJSON
            }
            try Expect.equal(try ProviderJSON.text(measured), try ProviderJSON.text(sent),
                "Counting preserves native field \(field) exactly")
        }
        for field in ["model", "input", "tools", "text"] {
            try match(field, count: openaiCount, generation: openaiGeneration)
        }
        for field in ["model", "messages", "system", "tools", "output_config"] {
            try match(field, count: anthropicCount, generation: anthropicGeneration)
        }
        // Claude routes cache: a breakpoint on the system block (tools and
        // system) plus the top-level marker that follows the conversation.
        try Expect.true(
            (anthropicGeneration["cache_control"] as? [String: Any])?["type"] as? String == "ephemeral",
            "Generation requests cache the growing conversation"
        )
        try Expect.true(
            ((anthropicGeneration["system"] as? [[String: Any]])?.last?["cache_control"] as? [String: Any])?["type"] as? String == "ephemeral",
            "The system block is a cache breakpoint"
        )
        try Expect.true(anthropicCount["cache_control"] == nil, "Counting does not depend on caching")
        try Expect.true(openaiCount["stream"] == nil && openaiCount["max_output_tokens"] == nil,
            "OpenAI count requests exclude generation-only fields")
        try Expect.true(anthropicCount["stream"] == nil && anthropicCount["max_tokens"] == nil,
            "Anthropic count requests exclude generation-only fields")

        var duplicateChanged = request
        duplicateChanged.messages[2].content = .init(text: String(repeating: "duplicate ", count: 2_000))
        try Expect.equal(try OpenAIMapper.countRequest(duplicateChanged, model: "fixture-openai"),
            openaiBody, "Duplicated stored content does not add another OpenAI input copy")
        try Expect.equal(try AnthropicMapper.countRequest(duplicateChanged, model: "fixture-anthropic"),
            anthropicBody, "Duplicated stored content does not add another Anthropic input copy")

        try Expect.equal(try ProviderJSON.inputTokenCount(Data(#"{"input_tokens":0}"#.utf8)), 0,
            "Zero is a valid provider count")
        try Expect.equal(try ProviderJSON.inputTokenCount(Data(#"{"input_tokens":177}"#.utf8)), 177,
            "Provider counts are decoded without another estimate")
        for invalid in [#"{}"#, #"{"input_tokens":-1}"#, #"{"input_tokens":true}"#,
                        #"{"input_tokens":"177"}"#, #"{"input_tokens":null}"#] {
            var rejected = false
            do { _ = try ProviderJSON.inputTokenCount(Data(invalid.utf8)) }
            catch { rejected = true }
            try Expect.true(rejected, "Invalid count data cannot become budget evidence")
        }
        return [.field("provider_counting", "offline native-input contracts")]
    }
}
