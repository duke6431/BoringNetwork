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
    /// Override this property to specify the key used to extract the nested object.
    open var key: String { fatalError("Wrappable key must be overridden") }
    
    /// The decoded value extracted from the nested key.
    open var data: T?
    
    /// Initializes the wrapper and decodes the nested value from the specified key.
    ///
    /// - Parameter decoder: The decoder used to read the data.
    public required init(from decoder: any Decoder) throws {
        data = try (try decoder.container(keyedBy: StringCodingKey.self)).decode(T.self, for: key)
    }
    
    /// Returns the extracted value, if any.
    open func value() -> T? {
        return data
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

public extension Encodable {
    /// Converts the Encodable object into a dictionary, if possible.
    ///
    /// - Returns: A `[String: Any]` representation of the object, or nil on failure.
    var dictionary: [String: Any]? {
        do {
            return try JSONSerialization.jsonObject(
                with: try JSONEncoder().encode(self),
                options: .allowFragments
            ) as? [String: Any]
        } catch {
            print(error.localizedDescription)
            return nil
        }
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
