import Foundation

struct HYAICodec {
    static func encode<Value: Encodable>(
        _ value: Value
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy =
            .convertToSnakeCase
        encoder.outputFormatting = [
            .sortedKeys,
        ]

        return try encoder.encode(
            value
        )
    }

    static func decode<Value: Decodable>(
        _ type: Value.Type,
        from data: Data
    ) throws -> Value {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy =
            .convertFromSnakeCase

        return try decoder.decode(
            type,
            from: data
        )
    }
}
