//
//  Codable+.swift
//  BoringNetwork
//
//  Created by Duc Nguyen on 2025/05/20.
//
//  Description:
//  Provides helpers for working with Codable in the BoringNetwork framework.
//  Includes key strategy transformations, JSON conversion, and a wrapper pattern
//  to extract nested data from API responses.
//

import Foundation

/// A generic wrapper to extract a nested value from a keyed container.
/// Intended for use when APIs nest payloads under a specific key (e.g., "data").
open class Wrappable<T: Decodable>: Decodable {
    public let key: String
    public var data: T?
    
    public required init(key: String) {
        self.key = key
    }
    
    public required convenience init(from decoder: any Decoder) throws {
        self.init(key: Self.keyName)
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        data = try container.decode(T.self, forKey: StringCodingKey(stringValue: key))
    }
    
    open class var keyName: String {
        fatalError("Subclasses must override `keyName`.")
    }
    
    open func value() -> T? {
        data
    }
}

/// A unified representation of key coding strategies used during encoding and decoding.
public enum BaseKeyCodingStrategy {
    /// Use the keys specified by each type. This is the default strategy.
    case useDefaultKeys
    
    /// Converts snake_case_keys to camelCaseKeys during decoding and vice versa during encoding.
    ///
    /// Preserves underscores at the beginning and end of keys.
    case convertFromSnakeCase
    
    /// Returns the appropriate `JSONDecoder.KeyDecodingStrategy` for this strategy.
    func decode() -> JSONDecoder.KeyDecodingStrategy {
        switch self {
        case .useDefaultKeys:
            return .useDefaultKeys
        case .convertFromSnakeCase:
            return .convertFromSnakeCase
        }
    }
    
    /// Returns the appropriate `JSONEncoder.KeyEncodingStrategy` for this strategy.
    func encode() -> JSONEncoder.KeyEncodingStrategy {
        switch self {
        case .useDefaultKeys:
            return .useDefaultKeys
        case .convertFromSnakeCase:
            return .convertToSnakeCase
        }
    }
}

extension BaseKeyCodingStrategy: Codable {}

public extension Encodable {
    func tryDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        let object = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
        guard let dict = object as? [String: Any] else {
            throw EncodingError.invalidValue(self, .init(codingPath: [], debugDescription: "Encoded object is not a dictionary"))
        }
        return dict
    }
    
    var dictionary: [String: Any]? {
        try? tryDictionary()
    }
}

public extension JSONDecoder {
    /// Applies a custom key decoding strategy to the decoder.
    ///
    /// - Parameter strategy: The key decoding strategy to apply.
    /// - Returns: The decoder with the applied strategy.
    func with(strategy: BaseKeyCodingStrategy?) -> Self {
        keyDecodingStrategy = strategy?.decode() ?? keyDecodingStrategy
        return self
    }
}

public extension JSONEncoder {
    /// Applies a custom key encoding strategy to the encoder.
    ///
    /// - Parameter strategy: The key encoding strategy to apply.
    /// - Returns: The encoder with the applied strategy.
    func with(strategy: BaseKeyCodingStrategy?) -> Self {
        keyEncodingStrategy = strategy?.encode() ?? keyEncodingStrategy
        return self
    }
}
