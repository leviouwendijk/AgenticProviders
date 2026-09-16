import Agentic
import AWSConnector
import Foundation

public struct BedrockModelGateway: AgentModelGateway {
    public let identifier: AgentModelGatewayIdentifier

    private let provider: BedrockModelResponseProvider

    public init(
        identifier: AgentModelGatewayIdentifier = .aws_bedrock,
        runtime: any BedrockModelRuntime,
        metadata: [String: String] = [:],
        diagnostics: BedrockDiagnostics = .disabled
    ) {
        self.identifier = identifier
        self.provider = .init(
            configuration: .init(
                runtime: runtime,
                metadata: metadata,
                diagnostics: diagnostics
            )
        )
    }

    public init(
        identifier: AgentModelGatewayIdentifier = .aws_bedrock,
        runtime: BedrockRuntimeClient,
        metadata: [String: String] = [:],
        diagnostics: BedrockDiagnostics = .disabled
    ) {
        self.init(
            identifier: identifier,
            runtime: runtime as any BedrockModelRuntime,
            metadata: metadata,
            diagnostics: diagnostics
        )
    }

    public init(
        identifier: AgentModelGatewayIdentifier = .aws_bedrock,
        configuration: BedrockModelConfiguration
    ) {
        self.identifier = identifier
        self.provider = .init(
            configuration: configuration
        )
    }

    public var response: AgentModelResponseProviding {
        provider
    }

    public static func resolve(
        identifier: AgentModelGatewayIdentifier = .aws_bedrock,
        metadata: [String: String] = [:],
        diagnostics: BedrockDiagnostics = .disabled
    ) throws -> Self {
        try .init(
            identifier: identifier,
            runtime: BedrockRuntimeClient.resolve(),
            metadata: metadata,
            diagnostics: diagnostics
        )
    }

    public static func resolve(
        identifier: AgentModelGatewayIdentifier = .aws_bedrock,
        region: String,
        metadata: [String: String] = [:],
        diagnostics: BedrockDiagnostics = .disabled
    ) throws -> Self {
        try .init(
            identifier: identifier,
            runtime: BedrockRuntimeClient(
                region: region,
                credentials: try AWSCredentials.resolve()
            ),
            metadata: metadata,
            diagnostics: diagnostics
        )
    }
}

public struct BedrockModelResponseProvider: AgentModelResponseProviding {
    public let configuration: BedrockModelConfiguration

    public init(
        configuration: BedrockModelConfiguration
    ) {
        self.configuration = configuration
    }

    public func buffered(
        request: AgentRequest,
        route: AgentModelRoute,
        context _: AgentModelInvocationContext
    ) async throws -> AgentResponse {
        let model = route.profile.model
        let bedrock = try BedrockRequestMapper.map(
            request
        )

        if configuration.diagnostics.raw {
            try dumpBedrockRequest(
                bedrock
            )
        }

        let metadata = BedrockMetadata.base(
            configuration.metadata,
            model: model
        )
        let response = try await configuration.runtime.respond(
            bedrock,
            modelIdentifier: model,
            timeoutseconds: request.invocationoptions?.timeoutseconds
        )

        return try BedrockResponseMapper.map(
            response,
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
                    let model = route.profile.model
                    let bedrock = try BedrockRequestMapper.map(
                        request
                    )

                    if configuration.diagnostics.raw {
                        try dumpBedrockRequest(
                            bedrock
                        )
                    }

                    let metadata = BedrockMetadata.base(
                        configuration.metadata,
                        model: model
                    )
                    var stream = BedrockStreamAccumulator(
                        metadata: metadata
                    )

                    for try await event in configuration.runtime.stream(
                        bedrock,
                        modelIdentifier: model,
                        timeoutseconds: request.invocationoptions?.timeoutseconds
                    ) {
                        if Task.isCancelled {
                            continuation.finish(
                                throwing: CancellationError()
                            )
                            return
                        }

                        let outputs = try stream.consume(
                            event
                        )

                        for output in outputs {
                            continuation.yield(
                                output
                            )
                        }
                    }

                    try stream.requireCompleted()
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

    private func dumpBedrockRequest(
        _ request: Bedrock.Converse.Request
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
        ]

        let data = try encoder.encode(
            request
        )

        guard let text = String(
            data: data,
            encoding: .utf8
        ) else {
            return
        }

        fputs(
            "\n--- Bedrock Converse Request ---\n\(text)\n--- End Bedrock Converse Request ---\n",
            stderr
        )
    }
}

private enum BedrockMetadata {
    static func base(
        _ values: [String: String],
        model: String
    ) -> [String: String] {
        var metadata = values
        metadata["provider"] = metadata["provider"] ?? "aws"
        metadata["gateway"] = metadata["gateway"] ?? "bedrock_converse"
        metadata["model"] = model

        return metadata
    }
}
