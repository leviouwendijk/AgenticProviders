import Foundation

struct HYAIURLSessionRuntime: Sendable {
    private static let requestTimeoutInterval:
        TimeInterval = 30 * 60

    let apiKey: String
    let timeoutseconds: Int?

    init(
        apiKey: String,
        timeoutseconds: Int? = nil
    ) {
        self.apiKey = apiKey
        self.timeoutseconds = timeoutseconds
    }

    func respond(
        _ request: HYAIChatRequest,
        endpoint: URL
    ) async throws -> HYAIChatCompletionResponse {
        let urlRequest = try makeRequest(
            request,
            endpoint: endpoint,
            accept: "application/json"
        )

        let data: Data
        let response: URLResponse

        do {
            (data, response) =
                try await URLSession.shared.data(
                    for: urlRequest
                )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw transportFailure(
                error,
                endpoint: endpoint,
                delivery: "buffered"
            )
        }

        guard let response =
            response as? HTTPURLResponse
        else {
            throw HYAIGatewayError
                .invalidHTTPResponse
        }

        try validate(
            response,
            body: data
        )

        return try HYAICodec.decode(
            HYAIChatCompletionResponse.self,
            from: data
        )
    }

    func stream(
        _ request: HYAIChatRequest,
        endpoint: URL
    ) -> AsyncThrowingStream<
        HYAIChatCompletionChunk,
        Error
    > {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let urlRequest = try makeRequest(
                        request,
                        endpoint: endpoint,
                        accept: "text/event-stream"
                    )

                    let bytes: URLSession.AsyncBytes
                    let response: URLResponse

                    do {
                        (bytes, response) =
                            try await URLSession.shared.bytes(
                                for: urlRequest
                            )
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        throw transportFailure(
                            error,
                            endpoint: endpoint,
                            delivery: "stream"
                        )
                    }

                    guard let response =
                        response as? HTTPURLResponse
                    else {
                        throw HYAIGatewayError
                            .invalidHTTPResponse
                    }

                    try validate(
                        response,
                        body: nil
                    )

                    for try await line in bytes.lines {
                        if Task.isCancelled {
                            throw CancellationError()
                        }

                        let line = line.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )

                        guard line.hasPrefix("data:") else {
                            continue
                        }

                        let payload = String(
                            line.dropFirst(5)
                        ).trimmingCharacters(
                            in: .whitespaces
                        )

                        guard !payload.isEmpty else {
                            continue
                        }

                        if payload == "[DONE]" {
                            break
                        }

                        guard let data = payload.data(
                            using: .utf8
                        ) else {
                            throw HYAIGatewayError
                                .invalidStreamFrame(
                                    payload
                                )
                        }

                        do {
                            continuation.yield(
                                try HYAICodec.decode(
                                    HYAIChatCompletionChunk.self,
                                    from: data
                                )
                            )
                        } catch {
                            throw HYAIGatewayError
                                .invalidStreamFrame(
                                    payload
                                )
                        }
                    }

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

private extension HYAIURLSessionRuntime {
    func makeRequest(
        _ request: HYAIChatRequest,
        endpoint: URL,
        accept: String
    ) throws -> URLRequest {
        let url = endpoint
            .appendingPathComponent("chat")
            .appendingPathComponent("completions")

        var urlRequest = URLRequest(
            url: url
        )
        urlRequest.timeoutInterval =
            timeoutseconds.map {
                TimeInterval($0)
            }
            ?? Self.requestTimeoutInterval
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(
            "Bearer \(apiKey)",
            forHTTPHeaderField:
                "Authorization"
        )
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField:
                "Content-Type"
        )
        urlRequest.setValue(
            accept,
            forHTTPHeaderField:
                "Accept"
        )
        urlRequest.httpBody =
            try HYAICodec.encode(
                request
            )

        return urlRequest
    }

    func validate(
        _ response: HTTPURLResponse,
        body: Data?
    ) throws {
        if response.statusCode == 503 {
            throw HYAIGatewayError.model_warming(
                retryAfterSeconds: intHeader(
                    "Retry-After",
                    response: response
                ),
                state: response.value(
                    forHTTPHeaderField:
                        "X-HYAI-Model-State"
                ),
                estimatedSeconds: intHeader(
                    "X-HYAI-Eta-Seconds",
                    response: response
                )
            )
        }

        guard (200..<300).contains(
            response.statusCode
        ) else {
            throw HYAIGatewayError.httpStatus(
                status: response.statusCode,
                body: body.flatMap {
                    String(
                        data: $0,
                        encoding: .utf8
                    )
                }
            )
        }
    }

    func intHeader(
        _ name: String,
        response: HTTPURLResponse
    ) -> Int? {
        response.value(
            forHTTPHeaderField: name
        ).flatMap(Int.init)
    }

    func transportFailure(
        _ error: Error,
        endpoint: URL,
        delivery: String
    ) -> NSError {
        let underlying = error as NSError
        let endpointValue =
            endpoint.absoluteString

        return NSError(
            domain: underlying.domain,
            code: underlying.code,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "HostYourAI \(delivery) invocation to '\(endpointValue)' failed: \(error.localizedDescription)",
                NSUnderlyingErrorKey:
                    underlying,
                "agentic_provider":
                    "hostyourai",
                "agentic_endpoint":
                    endpointValue,
                "agentic_delivery":
                    delivery,
            ]
        )
    }
}
