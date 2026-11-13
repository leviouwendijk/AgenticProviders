import Agentic

import Foundation
import Schema
import Macros

/// Bedrock model discovery as observe-only Tools.
///
/// Tools resolve `BedrockModelDiscovery` from the invocation's services
/// (see `AgenticAWS.models.discovery()`), so credentials stay host-owned.
@Domain
public enum BedrockModels {
    /// Discovery filter shared by the listing Tools.
    @JSONSchema
    public struct Filter: Sendable, Codable, Hashable {
        public var modelProvider: String?
        public var modelOutputModality: String?
        public var profileType: String?
        public var includeInactiveProfiles: Bool
        public var includeLegacy: Bool
        public var maxProfileResults: Int?

        public init(
            modelProvider: String? = nil,
            modelOutputModality: String? = "TEXT",
            profileType: String? = nil,
            includeInactiveProfiles: Bool = false,
            includeLegacy: Bool = false,
            maxProfileResults: Int? = 100
        ) {
            self.modelProvider = modelProvider
            self.modelOutputModality = modelOutputModality
            self.profileType = profileType
            self.includeInactiveProfiles = includeInactiveProfiles
            self.includeLegacy = includeLegacy
            self.maxProfileResults = maxProfileResults
        }

        public var options: BedrockModelDiscoveryOptions {
            .init(
                modelProvider: modelProvider,
                modelOutputModality: modelOutputModality,
                profileType: profileType,
                includeInactiveProfiles: includeInactiveProfiles,
                includeLegacy: includeLegacy,
                maxProfileResults: maxProfileResults
            )
        }
    }
}

public extension BedrockModels.Tools {
    @Tool("bedrock_list_model_handles")
    struct Handles: Tool {
        public typealias Input = BedrockModels.Filter

        @JSONSchema
        public struct Output: Sendable, Codable, Hashable {
            public var region: String
            public var count: Int
            public var handles: [BedrockModelHandle]

            public init(
                region: String,
                count: Int,
                handles: [BedrockModelHandle]
            ) {
                self.region = region
                self.count = count
                self.handles = handles
            }
        }

        public static let purpose = "List available AWS Bedrock model invocation handles from foundation models and inference profiles."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(
            _ input: Input,
            in context: ToolContext
        ) async throws -> Output {
            let discovery = try context.require(BedrockModelDiscovery.self)
            let handles = try await discovery.handles(
                options: input.options
            )

            return Output(
                region: discovery.control.region,
                count: handles.count,
                handles: handles
            )
        }
    }

    @Tool("bedrock_list_discovered_profiles")
    struct Profiles: Tool {
        public typealias Input = BedrockModels.Filter

        public struct Output: Sendable, Codable, Hashable, JSONSchemaProviding {
            public var region: String
            public var handleCount: Int
            public var profileCount: Int
            public var handles: [BedrockModelHandle]
            public var profiles: [AgentModelProfile]

            public init(
                region: String,
                handleCount: Int,
                profileCount: Int,
                handles: [BedrockModelHandle],
                profiles: [AgentModelProfile]
            ) {
                self.region = region
                self.handleCount = handleCount
                self.profileCount = profileCount
                self.handles = handles
                self.profiles = profiles
            }

            public static var jsonschema: JSONSchema {
                .object(
                    properties: [
                        .init(
                            name: "region",
                            schema: .string(),
                            required: true
                        ),
                        .init(
                            name: "handleCount",
                            schema: .integer(),
                            required: true
                        ),
                        .init(
                            name: "profileCount",
                            schema: .integer(),
                            required: true
                        ),
                        .init(
                            name: "handles",
                            schema: .array(
                                items: BedrockModelHandle.jsonschema
                            ),
                            required: true
                        ),
                        .init(
                            name: "profiles",
                            schema: .array(
                                items: .object(
                                    additionalProperties: .allowed
                                )
                            ),
                            required: true
                        ),
                    ],
                    additionalProperties: .disallowed
                )
            }
        }

        public static let purpose = "List Agentic model profiles synthesized from AWS Bedrock model discovery."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(
            _ input: Input,
            in context: ToolContext
        ) async throws -> Output {
            let discovery = try context.require(BedrockModelDiscovery.self)
            let handles = try await discovery.handles(
                options: input.options
            )
            let profiles = discovery.profiles(
                from: handles
            )

            return Output(
                region: discovery.control.region,
                handleCount: handles.count,
                profileCount: profiles.count,
                handles: handles,
                profiles: profiles
            )
        }
    }

    @Tool("bedrock_resolve_model_handle")
    struct Resolve: Tool {
        @JSONSchema
        public struct Input: Sendable, Codable, Hashable {
            public var query: String
            public var modelProvider: String?
            public var modelOutputModality: String?
            public var profileType: String?
            public var includeInactiveProfiles: Bool
            public var includeLegacy: Bool
            public var maxProfileResults: Int?

            public init(
                query: String,
                modelProvider: String? = nil,
                modelOutputModality: String? = "TEXT",
                profileType: String? = nil,
                includeInactiveProfiles: Bool = false,
                includeLegacy: Bool = false,
                maxProfileResults: Int? = 100
            ) {
                self.query = query
                self.modelProvider = modelProvider
                self.modelOutputModality = modelOutputModality
                self.profileType = profileType
                self.includeInactiveProfiles = includeInactiveProfiles
                self.includeLegacy = includeLegacy
                self.maxProfileResults = maxProfileResults
            }

            public var filter: BedrockModels.Filter {
                .init(
                    modelProvider: modelProvider,
                    modelOutputModality: modelOutputModality,
                    profileType: profileType,
                    includeInactiveProfiles: includeInactiveProfiles,
                    includeLegacy: includeLegacy,
                    maxProfileResults: maxProfileResults
                )
            }
        }

        @JSONSchema
        public struct Output: Sendable, Codable, Hashable {
            public var query: String
            public var matchCount: Int
            public var matches: [BedrockModelHandle]

            public init(
                query: String,
                matchCount: Int,
                matches: [BedrockModelHandle]
            ) {
                self.query = query
                self.matchCount = matchCount
                self.matches = matches
            }
        }

        public static let purpose = "Find Bedrock model handles matching an invocation id, title, provider, source model id, or ARN substring."
        public static let risk: ActionRisk = .observe

        public init() {}

        public func call(
            _ input: Input,
            in context: ToolContext
        ) async throws -> Output {
            let discovery = try context.require(BedrockModelDiscovery.self)
            let query = input.query.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let handles = try await discovery.handles(
                options: input.filter.options
            )
            let matches = query.isEmpty
                ? handles
                : handles.filter { $0.matches(query) }

            return Output(
                query: query,
                matchCount: matches.count,
                matches: matches
            )
        }
    }
}

private extension BedrockModelHandle {
    func matches(
        _ query: String
    ) -> Bool {
        let normalizedQuery = query.lowercased()

        return searchableText.contains(
            normalizedQuery
        )
    }

    var searchableText: String {
        [
            invokeIdentifier,
            kind.rawValue,
            region,
            title ?? "",
            provider ?? "",
            status ?? "",
            type ?? "",
            sourceModelIdentifiers.joined(
                separator: " "
            ),
            sourceModelArns.joined(
                separator: " "
            ),
            inputModalities.joined(
                separator: " "
            ),
            outputModalities.joined(
                separator: " "
            )
        ].joined(
            separator: " "
        ).lowercased()
    }
}
