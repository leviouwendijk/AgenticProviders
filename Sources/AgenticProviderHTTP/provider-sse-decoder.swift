import Foundation

/// Incremental SSE event framing over raw UTF-8 bytes.
/// `AsyncBytes.lines` is intentionally avoided because it may discard
/// the empty line that terminates each server-sent event.
public struct ProviderSSEDecoder: Sendable {
    private static let maximumLineBytes = 8 * 1024 * 1024
    private static let maximumEventBytes = 8 * 1024 * 1024

    private var lineBytes: [UInt8] = []
    private var eventName = "message"
    private var dataLines: [String] = []
    private var dataBytes = 0
    private var previousWasCR = false
    private var firstLine = true

    public init() {}

    /// Returns at most one completed event for each consumed byte.
    public mutating func receive(_ byte: UInt8) throws -> ProviderSSEEvent? {
        if previousWasCR {
            previousWasCR = false
            if byte == 0x0A { return nil }
        }

        switch byte {
        case 0x0D:
            previousWasCR = true
            return try completeLine()
        case 0x0A:
            return try completeLine()
        default:
            guard lineBytes.count < Self.maximumLineBytes else {
                throw ProviderHTTPError.streamError("SSE line exceeds 8 MiB")
            }
            lineBytes.append(byte)
            return nil
        }
    }

    /// Preserve the existing transport's trailing-event behavior at EOF.
    public mutating func finish() throws -> ProviderSSEEvent? {
        if !lineBytes.isEmpty, let event = try completeLine() {
            return event
        }
        return dispatch()
    }

    private mutating func completeLine() throws -> ProviderSSEEvent? {
        guard var line = String(bytes: lineBytes, encoding: .utf8) else {
            throw ProviderHTTPError.streamError("Invalid UTF-8 in SSE line")
        }
        lineBytes.removeAll(keepingCapacity: true)

        if firstLine {
            firstLine = false
            if line.first == "\u{FEFF}" { line.removeFirst() }
        }
        if line.isEmpty { return dispatch() }
        if line.first == ":" { return nil }

        let fields = line.split(
            separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let field = fields[0]
        var value = fields.count > 1 ? String(fields[1]) : ""
        if value.first == " " { value.removeFirst() }

        switch field {
        case "event":
            eventName = value
        case "data":
            let count = value.utf8.count
            guard count <= Self.maximumEventBytes - dataBytes else {
                throw ProviderHTTPError.streamError("SSE event exceeds 8 MiB")
            }
            dataBytes += count
            dataLines.append(value)
        default:
            break
        }
        return nil
    }

    private mutating func dispatch() -> ProviderSSEEvent? {
        let name = eventName
        let lines = dataLines
        eventName = "message"
        dataLines.removeAll(keepingCapacity: true)
        dataBytes = 0
        guard !lines.isEmpty else { return nil }
        return .init(
            name: name.isEmpty ? "message" : name,
            data: lines.joined(separator: "\n")
        )
    }
}
