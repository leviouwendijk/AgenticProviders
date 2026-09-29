import Agentic
import Foundation

public enum HYAIGatewayError:
    Error,
    Sendable,
    LocalizedError
{
    case invalidEndpoint(String)
    case emptyAPIKey
    case emptyMessages
    case emptyMappedMessages
    case unsupportedContent(MessageRole)
    case unsupportedResponseFormat
    case invalidHTTPResponse
    case model_warming(
        retryAfterSeconds: Int?,
        state: String?,
        estimatedSeconds: Int?
    )
    case httpStatus(
        status: Int,
        body: String?
    )
    case invalidResponse
    case invalidToolCall
    case invalidToolArguments(String)
    case invalidStreamFrame(String)
    case streamEndedWithoutResponse

    public var errorDescription: String? {
        switch self {
        case .invalidEndpoint(let value):
            return "Invalid HostYourAI endpoint: \(value)"

        case .emptyAPIKey:
            return "HostYourAI API key is empty."

        case .emptyMessages:
            return "HostYourAI gateway received a request with no messages."

        case .emptyMappedMessages:
            return "HostYourAI gateway produced no OpenAI-compatible messages."

        case .unsupportedContent(let role):
            return "HostYourAI gateway does not support one or more \(role.rawValue) content blocks in this implementation."

        case .unsupportedResponseFormat:
            return "HostYourAI structured-output lowering has not been implemented yet."

        case .invalidHTTPResponse:
            return "HostYourAI returned a non-HTTP response."

        case .model_warming(
            let retryAfterSeconds,
            let state,
            let estimatedSeconds
        ):
            let retry = retryAfterSeconds.map(String.init)
                ?? "unknown"
            let state = state ?? "unknown"
            let eta = estimatedSeconds.map(String.init)
                ?? "unknown"

            return "HostYourAI model is warming (state: \(state), retry-after: \(retry)s, eta: \(eta)s)."

        case .httpStatus(let status, let body):
            guard let body,
                  !body.isEmpty
            else {
                return "HostYourAI returned HTTP status \(status)."
            }

            return "HostYourAI returned HTTP status \(status): \(body)"

        case .invalidResponse:
            return "HostYourAI returned a response without a usable completion choice."

        case .invalidToolCall:
            return "HostYourAI returned an incomplete tool call."

        case .invalidToolArguments(let value):
            return "HostYourAI returned invalid JSON tool arguments: \(value)"

        case .invalidStreamFrame(let value):
            return "HostYourAI gateway could not decode an SSE frame: \(value)"

        case .streamEndedWithoutResponse:
            return "HostYourAI stream ended without a completed response."
        }
    }
}
