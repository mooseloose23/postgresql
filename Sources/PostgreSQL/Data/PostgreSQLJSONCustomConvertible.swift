import COperatingSystem
import Foundation

/// Representable by a `JSONB` column on the PostgreSQL database.
public protocol PostgreSQLJSONCustomConvertible: PostgreSQLDataConvertible { }

extension PostgreSQLJSONCustomConvertible {
    /// See `PostgreSQLDataConvertible`.
    public static var postgreSQLDataType: PostgreSQLDataType { return .jsonb }

    /// See `PostgreSQLDataConvertible`.
    public static var postgreSQLDataArrayType: PostgreSQLDataType { return ._jsonb }

    /// See `PostgreSQLDataConvertible`.
    public static func convertFromPostgreSQLData(_ data: PostgreSQLData) throws -> Self {
        guard let value = data.data else {
            throw PostgreSQLError(identifier: "data", reason: "Unable to decode PostgreSQL JSON from `null` data.", source: .capture())
        }

        guard let decodable = Self.self as? Decodable.Type else {
            fatalError("`\(Self.self)` is not `Decodable`.")
        }

        switch data.type {
        case .jsonb:
            switch data.format {
            case .text:
                let decoder = try JSONDecoder().decode(DecoderUnwrapper.self, from: value).decoder
                return try decodable.init(from: decoder) as! Self
            case .binary:
                assert(value[0] == 0x01)
                let decoder = try JSONDecoder().decode(DecoderUnwrapper.self, from: value[value.index(after: value.startIndex)...]).decoder
                return try decodable.init(from: decoder) as! Self
            }
        default: throw PostgreSQLError(identifier: "json", reason: "Could not decode \(Self.self) from data type: \(data.type).", source: .capture())
        }
    }

    /// See `PostgreSQLDataConvertible`.
    public func convertToPostgreSQLData() throws -> PostgreSQLData {
        guard let encodable = self as? Encodable else {
            fatalError("`\(Self.self)` is not `Encodable`.")
        }
        
        return try PostgreSQLData(
            type: .jsonb,
            format: .binary,
            data: [0x01] + JSONEncoder().encode(EncoderWrapper(encodable)) // JSONB requires version number in a first byte
        )
    }
}

// MARK: Private

extension Dictionary: PostgreSQLJSONCustomConvertible { }

private struct DecoderUnwrapper: Decodable {
    let decoder: Decoder
    init(from decoder: Decoder) {
        self.decoder = decoder
    }
}

private struct EncoderWrapper: Encodable {
    var encodable: Encodable
    init(_ encodable: Encodable) {
        self.encodable = encodable
    }
    func encode(to encoder: Encoder) throws {
        try encodable.encode(to: encoder)
    }
}

