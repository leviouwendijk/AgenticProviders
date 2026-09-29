import Agentic
import AWSConnector

enum BedrockResponseMapper {
    static func map(
        _ response: Bedrock.Converse.Response,
        metadata baseMetadata: [String: String]
    ) throws -> AgentResponse {
        let message: Bedrock.Converse.Message

        switch response.output {
        case .message(let value):
            message = value
        }

        let role: MessageRole
        switch message.role {
        case .user:
            role = .user
        case .assistant:
            role = .assistant
        }

        let blocks = try message.content.map { block in
            try map(
                block,
                role: role
            )
        }

        var metadata = baseMetadata

        if let stopReason = response.stopReason {
            metadata["bedrock_stop_reason"] = stopReason
        }

        return AgentResponse(
            message: .init(
                role: role,
                content: .init(
                    blocks: blocks
                )
            ),
            stopReason: BedrockStopReasonMapper.map(
                response.stopReason
            ),
            usage: BedrockUsageMapper.map(
                response.usage
            ),
            metadata: metadata
        )
    }
}

private extension BedrockResponseMapper {
    static func map(
        _ block: Bedrock.Converse.ContentBlock,
        role: MessageRole
    ) throws -> MessageContentBlock {
        switch block {
        case .text(let text):
            return .text(text)

        case .toolUse(let toolUse):
            return .tool_call(
                ToolCall(
                    id: toolUse.toolUseId,
                    tool: ToolIdentifier(
                        rawValue: toolUse.name
                    ),
                    input: toolUse.input
                )
            )

        case .toolResult:
            throw BedrockGatewayError.unsupportedContent(
                role
            )
        }
    }
}
