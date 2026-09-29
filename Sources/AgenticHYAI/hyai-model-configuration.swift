import Foundation

public enum HYAIPolicy:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case balanced
    case speed
    case cost
    case quality
    case sovereign
}

public enum HYAITask:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case chat
    case code
    case summarize
    case classify
    case extract
    case rag
    case legal
    case reason
}

public struct HYAIModelConfiguration: Sendable {
    public static let defaultEndpoint =
        "https://hostyourai.com/api/v1"

    public let endpoint: URL
    public let apiKey: String
    public let autoPolicy: HYAIPolicy
    public let autoTask: HYAITask?
    public let metadata: [String: String]

    public init(
        endpoint: String = Self.defaultEndpoint,
        apiKey: String,
        autoPolicy: HYAIPolicy = .balanced,
        autoTask: HYAITask? = nil,
        metadata: [String: String] = [:]
    ) throws {
        guard let endpointURL = URL(string: endpoint),
              let scheme = endpointURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              endpointURL.host != nil
        else {
            throw HYAIGatewayError.invalidEndpoint(
                endpoint
            )
        }

        let apiKey = apiKey.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !apiKey.isEmpty else {
            throw HYAIGatewayError.emptyAPIKey
        }

        self.endpoint = endpointURL
        self.apiKey = apiKey
        self.autoPolicy = autoPolicy
        self.autoTask = autoTask
        self.metadata = metadata
    }
}
