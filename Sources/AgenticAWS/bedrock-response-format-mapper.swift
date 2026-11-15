import Agentic
import AWSConnector
import Foundation
import Schema

/// Final provider-boundary lowering from Agentic response semantics into
/// Bedrock Converse output configuration.
enum BedrockResponseFormatMapper {
    static func map(
        _ format: AgentResponseFormat
    ) throws -> Bedrock.Converse.OutputConfig? {
        switch format {
        case .text:
            return nil

        case .jsonschema(let schema):
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]

            // `BedrockRequestMapper.prepared` has turned an inexpressible
            // schema into prompted JSON, so this lowering holds.
            let data = try encoder.encode(
                BedrockStructuredSchema(schema).schema.jsonvalue
            )

            return .jsonschema(
                schema: String(
                    decoding: data,
                    as: UTF8.self
                )
            )
        }
    }
}
