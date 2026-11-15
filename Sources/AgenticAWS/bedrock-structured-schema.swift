import Agentic
import Foundation
import Primitives
import Schema

/// A schema in the subset Bedrock structured output accepts: every object
/// closed with `additionalProperties: false`.
///
/// A record (an object with declared properties and the default open
/// policy) is closed: its decoder reads only its declared fields, so extra
/// keys could never be used. A dictionary (a schema-valued policy) or a
/// property-less open object has no closed equivalent; it is refused with
/// its path rather than silently narrowed.
struct BedrockStructuredSchema: Invariant, Sendable, Hashable {
    let schema: JSONSchema

    init(
        _ raw: JSONSchema
    ) throws(BedrockSchemaUnsupported) {
        schema = try Self.lowered(raw, path: "$")
    }

    private static func lowered(
        _ schema: JSONSchema,
        path: String
    ) throws(BedrockSchemaUnsupported) -> JSONSchema {
        var definitions: [String: JSONSchema] = [:]
        for (name, definition) in schema.definitions {
            definitions[name] = try lowered(definition, path: "\(path).$defs.\(name)")
        }
        let form: JSONSchema.Form
        switch schema.form {
        case .object(let properties, let additional):
            switch additional {
            case .disallowed:
                break
            case .allowed where !properties.isEmpty:
                break
            case .allowed:
                throw .init(path: path, reason: "an object without declared properties")
            case .schema:
                throw .init(path: path, reason: "a dictionary with arbitrary keys")
            }
            var closed: [JSONSchema.Property] = []
            for property in properties {
                closed.append(.init(
                    name: property.name,
                    schema: try lowered(property.schema, path: "\(path).\(property.name)"),
                    required: property.required,
                    description: property.description
                ))
            }
            form = .object(properties: closed, additionalProperties: .disallowed)
        case .array(let items, let minItems, let maxItems, let uniqueItems):
            form = .array(
                items: try lowered(items, path: "\(path)[]"),
                minItems: minItems,
                maxItems: maxItems,
                uniqueItems: uniqueItems
            )
        case .oneOf(let variants):
            var lowered: [JSONSchema] = []
            for (index, variant) in variants.enumerated() {
                lowered.append(try Self.lowered(variant, path: "\(path).oneOf[\(index)]"))
            }
            form = .oneOf(lowered)
        case .anyOf(let variants):
            var lowered: [JSONSchema] = []
            for (index, variant) in variants.enumerated() {
                lowered.append(try Self.lowered(variant, path: "\(path).anyOf[\(index)]"))
            }
            form = .anyOf(lowered)
        case .any:
            throw .init(path: path, reason: "an unconstrained value")
        default:
            form = schema.form
        }
        return JSONSchema(
            form: form,
            description: schema.description,
            definitions: definitions,
            stringFormat: schema.stringFormat,
            caseDescriptions: schema.caseDescriptions
        )
    }
}

struct BedrockSchemaUnsupported: Error, Sendable, Hashable, CustomStringConvertible {
    let path: String
    let reason: String

    var description: String {
        "\(path): \(reason) has no closed form in Bedrock structured output"
    }
}

extension BedrockRequestMapper {
    /// The request as Bedrock will receive it. A schema Bedrock cannot
    /// express natively is asked for as prompted JSON instead, so the
    /// contract is kept rather than narrowed; the metadata says why.
    static func prepared(
        _ request: AgentRequest
    ) throws -> (request: AgentRequest, metadata: [String: String]) {
        guard case .jsonschema(let schema) = request.responseFormat else {
            return (request, [:])
        }
        do {
            _ = try BedrockStructuredSchema(schema)
            return (request, [:])
        } catch {
            let prompted = try AgentOutputContract(schema: schema)
                .requesting(request, as: .prompted_json)
            return (prompted, [
                "output_representation": AgentOutputRepresentation.prompted_json.rawValue,
                "output_lowering": error.description,
            ])
        }
    }
}
