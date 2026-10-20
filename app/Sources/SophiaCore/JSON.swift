import Foundation

/// A JSON value. Records keep fields they don't recognise exactly as written,
/// so the format can grow without migrations (DATA-MODEL.md, "The learning log").
public enum JSON: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSON])
    case object([String: JSON])
    case null

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSON].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSON].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v):
            if v == v.rounded(), abs(v) < 1e15 { try c.encode(Int64(v)) } else { try c.encode(v) }
        case .bool(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }

    public subscript(key: String) -> JSON? {
        if case .object(let o) = self { return o[key] }
        return nil
    }

    public var string: String? { if case .string(let v) = self { return v }; return nil }
    public var array: [JSON]? { if case .array(let v) = self { return v }; return nil }
    public var object: [String: JSON]? { if case .object(let v) = self { return v }; return nil }
    public var bool: Bool? { if case .bool(let v) = self { return v }; return nil }

    public static func parse(_ text: String) -> JSON? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(JSON.self, from: data)
    }

    /// One line of JSON with sorted keys, as stored in the .jsonl files.
    public var line: String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: (try? enc.encode(self)) ?? Data("null".utf8), as: UTF8.self)
    }

    public var pretty: String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
        return String(decoding: (try? enc.encode(self)) ?? Data("null".utf8), as: UTF8.self)
    }
}

public typealias JSONObject = [String: JSON]

extension Dictionary where Key == String, Value == JSON {
    public func str(_ key: String) -> String? { self[key]?.string }
    public var line: String { JSON.object(self).line }
}
