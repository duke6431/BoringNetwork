//
//  CodingKey+.swift
//  BoringNetwork
//
//  Created by Duc Nguyen on 2025/05/20.
//
//  Description:
//  Adds support for dynamic string-based coding keys used in flexible
//  encoding and decoding workflows, especially for JSON wrappers.
//

import Foundation

/// A generic, string-based coding key used for dynamic key access in Codable containers.
/// This enables runtime-based key injection during encoding or decoding.
public struct StringCodingKey: CodingKey, Hashable, ExpressibleByStringLiteral {
    /// The string key value.
    public var stringValue: String
    
    /// Initializes with a given string value.
    public init(stringValue: String) { self.stringValue = stringValue }
    
    /// Convenience initializer.
    public init(_ stringValue: String) { self.init(stringValue: stringValue) }
    
    /// Not supported for string-based keys.
    public var intValue: Int?
    
    /// Not supported for string-based keys.
    public init?(intValue: Int) { return nil }
    
    /// Initializes from a string literal.
    public init(stringLiteral value: String) { self.init(value) }
}

/// Extension to enable encoding with dynamic string keys in a keyed encoding container.
public extension KeyedEncodingContainer where K == StringCodingKey {
    /// Encodes a value using a dynamic string key.
    ///
    /// - Parameters:
    ///   - value: The value to encode.
    ///   - key: The dynamic string key.
    mutating func encode<T>(_ value: T, forKey key: String) throws where T: Encodable {
        try encode(value, forKey: StringCodingKey(key))
    }
}

/// Extension to enable decoding with dynamic string keys in a keyed decoding container.
public extension KeyedDecodingContainer where K == StringCodingKey {
    /// Decodes a value of the specified type using a dynamic string key.
    ///
    /// - Parameters:
    ///   - type: The expected type to decode.
    ///   - key: The dynamic string key.
    /// - Returns: The decoded value.
    func decode<T>(_ type: T.Type, for key: String) throws -> T where T: Decodable {
        try decode(type, forKey: StringCodingKey(key))
    }
    
    /// Decodes an optional value of the specified type using a dynamic string key.
    ///
    /// - Parameters:
    ///   - type: The expected optional type to decode.
    ///   - key: The dynamic string key.
    /// - Returns: The decoded value, or nil if absent.
    func decodeIfPresent<T>(_ type: T.Type, for key: String) throws -> T? where T : Decodable {
        try? decode(type, for: key)
    }
}
