import Foundation
import Primitives

public enum ProviderHTTPError: Error, Sendable, LocalizedError {
    case invalidEndpoint(String)
    case httpStatus(Int, String)
    case invalidJSON
    case streamEnded
    case streamError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidEndpoint(let value): "Invalid provider endpoint: \(value)"
        case .httpStatus(let status, let detail): "Provider HTTP \(status): \(detail)"
        case .invalidJSON: "Invalid provider JSON response."
        case .streamEnded: "Provider stream ended without a final response."
        case .streamError(let detail): "Provider stream error: \(detail)"
        }
    }
}

public enum ProviderJSON {
    /// Both native counting APIs return input_tokens. Missing, malformed and
    /// negative counts are errors, never a successful zero-token measurement.
    public static func inputTokenCount(_ data: Data) throws -> Int {
        struct Count: Decodable {
            let input_tokens: Int
        }
        let count = try JSONDecoder().decode(Count.self, from: data).input_tokens
        guard count >= 0 else { throw ProviderHTTPError.invalidJSON }
        return count
    }

    public static func object(_ data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderHTTPError.invalidJSON
        }
        return object
    }

    public static func encode(_ value: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }

    public static func foundation(_ value: JSONValue) throws -> Any {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    public static func value(_ object: Any) throws -> JSONValue {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed])
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }

    public static func text(_ value: JSONValue) throws -> String {
        String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
    }

    public static func text(_ object: Any) throws -> String {
        String(
            decoding: try JSONSerialization.data(
                withJSONObject: object, options: [.fragmentsAllowed, .sortedKeys]), as: UTF8.self)
    }
}

public struct ProviderSSEEvent: Sendable {
    public let name: String
    public let data: String

    public init(name: String, data: String) {
        self.name = name
        self.data = data
    }
}

public struct ProviderHTTP: Sendable {
    public let endpoint: String
    public let apiKey: String
    public let headers: [String: String]

    public init(endpoint: String, apiKey: String, headers: [String: String]) throws {
        guard let components = URLComponents(string: endpoint),
            components.scheme == "https", components.host != nil,
            !apiKey.isEmpty
        else {
            throw ProviderHTTPError.invalidEndpoint(endpoint)
        }
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.headers = headers
    }

    private func request(path: String, body: Data, timeout: Int?) throws -> URLRequest {
        guard let url = URL(string: endpoint + path) else {
            throw ProviderHTTPError.invalidEndpoint(endpoint + path)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if let timeout { request.timeoutInterval = TimeInterval(timeout) }
        return request
    }

    private func validate(_ response: URLResponse, body: Data = Data()) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ProviderHTTPError.invalidJSON
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = String(decoding: body.prefix(4096), as: UTF8.self)
            throw ProviderHTTPError.httpStatus(http.statusCode, detail)
        }
    }

    public func post(path: String, body: Data, timeout: Int?) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(
            for: request(path: path, body: body, timeout: timeout))
        try validate(response, body: data)
        return data
    }

    public func stream(path: String, body: Data, timeout: Int?) -> AsyncThrowingStream<
        ProviderSSEEvent, Error
    > {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try request(path: path, body: body, timeout: timeout)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    try validate(response)

                    var decoder = ProviderSSEDecoder()
                    for try await byte in bytes {
                        try Task.checkCancellation()
                        if let event = try decoder.receive(byte) {
                            continuation.yield(event)
                        }
                    }
                    if let event = try decoder.finish() {
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
