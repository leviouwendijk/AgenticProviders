import Agentic
import Milieu

public struct HYAIModelGateway: AgentModelGateway {
    public let identifier:
        AgentModelGatewayIdentifier

    private let provider:
        HYAIModelResponseProvider

    public init(
        identifier: AgentModelGatewayIdentifier = .hyai,
        configuration: HYAIModelConfiguration
    ) {
        self.identifier = identifier
        self.provider = .init(
            configuration: configuration
        )
    }

    public init(
        identifier: AgentModelGatewayIdentifier = .hyai,
        endpoint: String = HYAIModelConfiguration.defaultEndpoint,
        apiKey: String,
        autoPolicy: HYAIPolicy = .balanced,
        autoTask: HYAITask? = nil,
        metadata: [String: String] = [:]
    ) throws {
        self.init(
            identifier: identifier,
            configuration: try .init(
                endpoint: endpoint,
                apiKey: apiKey,
                autoPolicy: autoPolicy,
                autoTask: autoTask,
                metadata: metadata
            )
        )
    }

    public var response: AgentModelResponseProviding {
        provider
    }

    public static let apiKeySymbol =
        "HYAI_API_KEY"

    public static func resolve(
        identifier: AgentModelGatewayIdentifier = .hyai,
        apiKeySymbol: String = HYAIModelGateway.apiKeySymbol,
        endpoint: String = HYAIModelConfiguration.defaultEndpoint,
        autoPolicy: HYAIPolicy = .balanced,
        autoTask: HYAITask? = nil,
        metadata: [String: String] = [:]
    ) throws -> Self {
        let apiKey = try EnvironmentExtractor.value(
            apiKeySymbol
        )

        return try .init(
            identifier: identifier,
            endpoint: endpoint,
            apiKey: apiKey,
            autoPolicy: autoPolicy,
            autoTask: autoTask,
            metadata: metadata
        )
    }
}

public struct HYAIModelResponseProvider:
    AgentModelResponseProviding
{
    public let configuration:
        HYAIModelConfiguration

    public init(
        configuration: HYAIModelConfiguration
    ) {
        self.configuration = configuration
    }

    public func buffered(
        request: AgentRequest,
        route: AgentModelRoute,
        context _: AgentModelInvocationContext
    ) async throws -> AgentResponse {
        let selectedModel = route.profile.model
        let mapped = try HYAIRequestMapper.map(
            request,
            model: selectedModel,
            purpose: route.purpose,
            configuration: configuration,
            stream: false
        )

        var metadata = configuration.metadata
        metadata["provider"] =
            metadata["provider"]
            ?? "hostyourai"
        metadata["gateway"] =
            metadata["gateway"]
            ?? "hyai_chat_completions"
        metadata["delivery"] = "buffered"

        let runtime = HYAIURLSessionRuntime(
            apiKey: configuration.apiKey,
            timeoutseconds:
                request.invocationoptions?.timeoutseconds
        )
        let response = try await runtime.respond(
            mapped,
            endpoint: configuration.endpoint
        )

        return try HYAIResponseMapper.map(
            response,
            requestedModel: selectedModel,
            metadata: metadata
        )
    }

    public func stream(
        request: AgentRequest,
        route: AgentModelRoute,
        context _: AgentModelInvocationContext
    ) -> AsyncThrowingStream<AgentStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let selectedModel =
                        route.profile.model
                    let mapped = try HYAIRequestMapper.map(
                        request,
                        model: selectedModel,
                        purpose: route.purpose,
                        configuration: configuration,
                        stream: true
                    )

                    var metadata = configuration.metadata
                    metadata["provider"] =
                        metadata["provider"]
                        ?? "hostyourai"
                    metadata["gateway"] =
                        metadata["gateway"]
                        ?? "hyai_chat_completions"
                    metadata["delivery"] = "stream"

                    var accumulator =
                        HYAIStreamAccumulator(
                            requestedModel: selectedModel,
                            metadata: metadata
                        )

                    let runtime = HYAIURLSessionRuntime(
                        apiKey: configuration.apiKey,
                        timeoutseconds:
                            request.invocationoptions?.timeoutseconds
                    )

                    for try await chunk in runtime.stream(
                        mapped,
                        endpoint: configuration.endpoint
                    ) {
                        if Task.isCancelled {
                            throw CancellationError()
                        }

                        for event in try accumulator.consume(
                            chunk
                        ) {
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
