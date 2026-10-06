import Agentic

import Foundation
import Schema
import Macros

@JSONSchema
public struct BedrockListModelHandlesToolInput: Sendable, Codable, Hashable {
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

@JSONSchema
public struct BedrockListModelHandlesToolOutput: Sendable, Codable, Hashable {
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

@JSONSchema
public struct BedrockListDiscoveredProfilesToolInput: Sendable, Codable, Hashable {
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

public struct BedrockListDiscoveredProfilesToolOutput: Sendable, Codable, Hashable, JSONSchemaProviding {
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

@JSONSchema
public struct BedrockResolveModelHandleToolInput: Sendable, Codable, Hashable {
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

@JSONSchema
public struct BedrockResolveModelHandleToolOutput: Sendable, Codable, Hashable {
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

public struct BedrockModelDiscoveryToolSet: Sendable {
    public var discovery: BedrockModelDiscovery

    public init(
        discovery: BedrockModelDiscovery
    ) {
        self.discovery = discovery
    }

    public static func resolve() throws -> Self {
        try .init(
            discovery: .resolve()
        )
    }

    public var listModelHandles: BedrockListModelHandlesTool {
        .init(
            discovery: discovery
        )
    }

    public var listDiscoveredProfiles: BedrockListDiscoveredProfilesTool {
        .init(
            discovery: discovery
        )
    }

    public var resolveModelHandle: BedrockResolveModelHandleTool {
        .init(
            discovery: discovery
        )
    }

    public var definitions: [ToolDefinition] {
        [
            BedrockListModelHandlesTool.definition,
            BedrockListDiscoveredProfilesTool.definition,
            BedrockResolveModelHandleTool.definition,
        ]
    }
}

public struct BedrockListModelHandlesTool: Tool {
    public typealias Input = BedrockListModelHandlesToolInput
    public typealias Output = BedrockListModelHandlesToolOutput

    public static let definition = ToolDefinition(
        identifier: "bedrock_list_model_handles",
        purpose: "List available AWS Bedrock model invocation handles from foundation models and inference profiles.",
        risk: .observe
    )

    public let discovery: BedrockModelDiscovery

    public init(
        discovery: BedrockModelDiscovery
    ) {
        self.discovery = discovery
    }

    public func call(
        _ input: Input,
        in _: ToolContext
    ) async throws -> Output {
        let handles = try await discovery.handles(
            options: input.options
        )

        return BedrockListModelHandlesToolOutput(
            region: discovery.control.region,
            count: handles.count,
            handles: handles
        )
    }
}

public struct BedrockListDiscoveredProfilesTool: Tool {
    public typealias Input = BedrockListDiscoveredProfilesToolInput
    public typealias Output = BedrockListDiscoveredProfilesToolOutput

    public static let definition = ToolDefinition(
        identifier: "bedrock_list_discovered_profiles",
        purpose: "List Agentic model profiles synthesized from AWS Bedrock model discovery.",
        risk: .observe
    )

    public let discovery: BedrockModelDiscovery

    public init(
        discovery: BedrockModelDiscovery
    ) {
        self.discovery = discovery
    }

    public func call(
        _ input: Input,
        in _: ToolContext
    ) async throws -> Output {
        let handles = try await discovery.handles(
            options: input.options
        )
        let profiles = discovery.profiles(
            from: handles
        )

        return BedrockListDiscoveredProfilesToolOutput(
            region: discovery.control.region,
            handleCount: handles.count,
            profileCount: profiles.count,
            handles: handles,
            profiles: profiles
        )
    }
}

public struct BedrockResolveModelHandleTool: Tool {
    public typealias Input = BedrockResolveModelHandleToolInput
    public typealias Output = BedrockResolveModelHandleToolOutput

    public static let definition = ToolDefinition(
        identifier: "bedrock_resolve_model_handle",
        purpose: "Find Bedrock model handles matching an invocation id, title, provider, source model id, or ARN substring.",
        risk: .observe
    )

    public let discovery: BedrockModelDiscovery

    public init(
        discovery: BedrockModelDiscovery
    ) {
        self.discovery = discovery
    }

    public func call(
        _ input: Input,
        in _: ToolContext
    ) async throws -> Output {
        let query = input.query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let handles = try await discovery.handles(
            options: input.options
        )

        let matches = handles.filter { handle in
            guard !query.isEmpty else {
                return true
            }

            return handle.matches(
                query
            )
        }

        return BedrockResolveModelHandleToolOutput(
            query: query,
            matchCount: matches.count,
            matches: matches
        )
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
