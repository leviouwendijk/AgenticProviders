import Agentic
import Foundation
import Milieu

public struct OllamaModelGateway: AgentModelGateway {
    public let identifier: AgentModelGatewayIdentifier

    private let provider: OllamaModelResponseProvider

    public init(
        identifier: AgentModelGatewayIdentifier = .ollama,
        configuration: OllamaModelConfiguration
    ) throws {
        self.init(
            identifier: identifier,
            configuration: configuration,
            trust: try OllamaURLSessionTrust.resolve(
                for: configuration.endpoint
            )
        )
    }

    private init(
        identifier: AgentModelGatewayIdentifier,
        configuration: OllamaModelConfiguration,
        trust: OllamaURLSessionTrust
    ) {
        self.identifier = identifier
        self.provider = .init(
            configuration: configuration,
            trust: trust
        )
    }

    public init(
        identifier: AgentModelGatewayIdentifier = .ollama,
        endpoint: URL,
        contextWindow: Int = 32_768,
        thinking: Bool = false,
        metadata: [String: String] = [:]
    ) throws {
        let configuration = try OllamaModelConfiguration(
            endpoint: endpoint,
            contextWindow: contextWindow,
            thinking: thinking,
            metadata: metadata
        )

        try self.init(
            identifier: identifier,
            configuration: configuration
        )
    }

    public var response: AgentModelResponseProviding {
        provider
    }

    public static let endpointSymbol =
        "AGENTIC_MODEL_OLLAMA_ENDPOINT"

    public static func resolve(
        identifier: AgentModelGatewayIdentifier = .ollama,
        endpointSymbol: String = OllamaModelGateway.endpointSymbol,
        contextWindow: Int = 32_768,
        thinking: Bool = false,
        metadata: [String: String] = [:]
    ) throws -> Self {
        let rawEndpoint = try EnvironmentExtractor.value(
            endpointSymbol
        )
        guard let endpoint = URL(string: rawEndpoint) else {
            throw OllamaGatewayError.invalidEndpoint(rawEndpoint)
        }

        let configuration = try OllamaModelConfiguration(
            endpoint: endpoint,
            contextWindow: contextWindow,
            thinking: thinking,
            metadata: metadata
        )

        return try .init(
            identifier: identifier,
            configuration: configuration
        )
    }
}

public struct OllamaModelResponseProvider:
    AgentModelResponseProviding
{
    public let configuration: OllamaModelConfiguration
    let trust: OllamaURLSessionTrust

    public init(
        configuration: OllamaModelConfiguration
    ) throws {
        self.configuration = configuration
        self.trust = try OllamaURLSessionTrust.resolve(
            for: configuration.endpoint
        )
    }

    init(
        configuration: OllamaModelConfiguration,
        trust: OllamaURLSessionTrust
    ) {
        self.configuration = configuration
        self.trust = trust
    }

    public func buffered(
        request: AgentRequest,
        route: AgentModelRoute,
        context _: AgentModelInvocationContext
    ) async throws -> AgentResponse {
        let selectedModel = route.profile.model
        let mapped = try OllamaRequestMapper.map(
            request,
            model: selectedModel,
            configuration: configuration,
            stream: false
        )

        var metadata = configuration.metadata
        metadata["provider"] =
            metadata["provider"] ?? "ollama"
        metadata["gateway"] =
            metadata["gateway"] ?? "ollama_chat"
        metadata["model"] = selectedModel
        metadata["delivery"] = "buffered"

        let runtime = OllamaURLSessionRuntime(
            trust: trust,
            timeoutseconds: request.invocationoptions?.timeoutseconds
        )
        let response = try await runtime.respond(
            mapped,
            endpoint: configuration.endpoint
        )

        var accumulator = OllamaStreamAccumulator(
            metadata: metadata
        )
        _ = accumulator.consume(response)

        return try accumulator.completedResponse()
    }

    public func stream(
        request: AgentRequest,
        route: AgentModelRoute,
        context _: AgentModelInvocationContext
    ) -> AsyncThrowingStream<AgentStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let selectedModel = route.profile.model
                    let mapped = try OllamaRequestMapper.map(
                        request,
                        model: selectedModel,
                        configuration: configuration,
                        stream: true
                    )

                    var metadata = configuration.metadata
                    metadata["provider"] =
                        metadata["provider"] ?? "ollama"
                    metadata["gateway"] =
                        metadata["gateway"] ?? "ollama_chat"
                    metadata["model"] = selectedModel
                    metadata["delivery"] = "stream"

                    var accumulator =
                        OllamaStreamAccumulator(
                            metadata: metadata
                        )

                    let runtime = OllamaURLSessionRuntime(
                        trust: trust,
                        timeoutseconds: request.invocationoptions?.timeoutseconds
                    )

                    for try await chunk in runtime.stream(
                        mapped,
                        endpoint: configuration.endpoint
                    ) {
                        if Task.isCancelled {
                            throw CancellationError()
                        }

                        for event in accumulator.consume(chunk) {
                            continuation.yield(event)
                        }
                    }

                    try accumulator.requireCompleted()
                    continuation.finish()
                } catch {
                    continuation.finish(
                        throwing: error
                    )
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
