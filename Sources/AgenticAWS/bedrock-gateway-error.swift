import Agentic
import Foundation

public enum BedrockGatewayError: Error, Sendable, LocalizedError {
    case emptyMessages
    case emptyMappedMessages
    case emptyContent(AgentRole)
    case unsupportedContent(AgentRole)
    case unsupportedResource(id: String, modality: AgentModality)
    case invalidToolInput(id: String, input: String)
    case streamError(type: String, message: String?)
    case streamEndedWithoutResponse

    public var errorDescription: String? {
        switch self {
        case .emptyMessages:
            return "Bedrock gateway received a request with no messages."

        case .emptyMappedMessages:
            return "Bedrock gateway produced no Bedrock messages."

        case .emptyContent(let role):
            return "Bedrock gateway produced empty content for \(role.rawValue) message."

        case .unsupportedContent(let role):
            return "Bedrock gateway does not support one or more \(role.rawValue) content blocks."

        case .unsupportedResource(let id, let modality):
            return "Bedrock gateway does not yet support provider lowering for \(modality.rawValue) resource '\(id)'."

        case .invalidToolInput(let id, let input):
            return "Bedrock gateway could not decode streamed tool input for '\(id)': \(input)"

        case .streamError(let type, let message):
            if let message {
                return "Bedrock stream error \(type): \(message)"
            }

            return "Bedrock stream error \(type)."

        case .streamEndedWithoutResponse:
            return "Bedrock stream ended without a completed response."
        }
    }
}
