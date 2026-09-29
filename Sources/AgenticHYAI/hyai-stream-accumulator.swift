import Agentic

struct HYAIStreamAccumulator: Sendable {
    private struct PartialToolCall: Sendable {
        var id: String?
        var name: String?
        var arguments = ""
    }

    private var text = ""
    private var calls:
        [Int: PartialToolCall] = [:]
    private var response: AgentResponse?
    private var resolvedModel: String?
    private var usage: AgentUsage?

    private let requestedModel: String
    private let baseMetadata: [String: String]

    init(
        requestedModel: String,
        metadata: [String: String]
    ) {
        self.requestedModel = requestedModel
        self.baseMetadata = metadata
    }

    mutating func consume(
        _ chunk: HYAIChatCompletionChunk
    ) throws -> [AgentStreamEvent] {
        guard response == nil else {
            return []
        }

        if let model = chunk.model,
           !model.isEmpty
        {
            resolvedModel = model
        }

        if let chunkUsage = chunk.usage {
            usage = .init(
                inputTokens:
                    chunkUsage.promptTokens,
                outputTokens:
                    chunkUsage.completionTokens,
                totalTokens:
                    chunkUsage.totalTokens
            )
        }

        guard let choice = chunk.choices.first else {
            return []
        }

        var events: [AgentStreamEvent] = []

        if let delta = choice.delta.content,
           !delta.isEmpty
        {
            text += delta
            events.append(
                .messagedelta(
                    .text(delta)
                )
            )
        }

        for providerCall
            in choice.delta.toolCalls ?? []
        {
            guard let index = providerCall.index else {
                throw HYAIGatewayError.invalidToolCall
            }

            var partial =
                calls[index]
                ?? PartialToolCall()

            if let id = providerCall.id,
               !id.isEmpty
            {
                partial.id = id
            }

            if let name =
                providerCall.function?.name,
               !name.isEmpty
            {
                partial.name = name
            }

            if let arguments =
                providerCall.function?.arguments
            {
                partial.arguments += arguments
            }

            calls[index] = partial
        }

        guard let finishReason =
            choice.finishReason
        else {
            return events
        }

        let toolCalls = try calls
            .sorted {
                $0.key < $1.key
            }
            .map { _, partial in
                try HYAIResponseMapper.mapToolCall(
                    id: partial.id,
                    name: partial.name,
                    arguments:
                        partial.arguments
                )
            }

        for call in toolCalls {
            events.append(
                .toolcall(call)
            )
        }

        var blocks: [MessageContentBlock] = []

        if !text.isEmpty {
            blocks.append(
                .text(text)
            )
        }

        blocks.append(
            contentsOf: toolCalls.map {
                .tool_call($0)
            }
        )

        let completed = AgentResponse(
            message: .init(
                role: .assistant,
                content: .init(
                    blocks: blocks
                )
            ),
            stopReason:
                HYAIResponseMapper.stopReason(
                    finishReason,
                    hasToolCalls:
                        !toolCalls.isEmpty
                ),
            usage: usage,
            metadata:
                HYAIResponseMapper.baseMetadata(
                    requestedModel:
                        requestedModel,
                    resolvedModel:
                        resolvedModel,
                    finishReason:
                        finishReason,
                    metadata:
                        baseMetadata
                )
        )

        response = completed
        events.append(
            .completed(completed)
        )

        return events
    }

    func requireCompleted() throws {
        guard response != nil else {
            throw HYAIGatewayError
                .streamEndedWithoutResponse
        }
    }
}
