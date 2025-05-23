//
//  Dictionary+.swift
//  BoringNetwork
//
//  Created by Duc Nguyen on 2025/05/20.
//
//  Description:
//  Extends `Dictionary` with convenience methods for merging using a selectable strategy.
//  Supports merging with control over whether existing or new values take precedence.
//

import Foundation

public extension Dictionary {
    /// Strategy used to resolve conflicts when merging dictionaries.
    enum MergeStrategy {
        /// Preserve the current dictionary’s existing values (ignore duplicates from the other dictionary).
        case preserveOriginal
        /// Overwrite existing values with values from the other dictionary.
        case overwriteWithNew
        /// Use a custom closure to resolve conflicts for duplicate keys.
        case custom((_ existing: Value, _ new: Value, _ key: Key) -> Value)
    }
    
    /// Merges another dictionary into the current one using the specified strategy.
    ///
    /// - Parameters:
    ///   - dictionary: The dictionary to merge into `self`.
    ///   - strategy: Strategy to resolve key collisions. Defaults to `.preserveOriginal`.
    /// - Returns: The merged dictionary (self).
    @inlinable
    @discardableResult
    mutating func merge(
        with dictionary: Dictionary<Key, Value>,
        using strategy: MergeStrategy = .preserveOriginal
    ) -> Self {
        dictionary.reduce(into: self) { current, incoming in
            switch strategy {
            case .preserveOriginal:
                if current[incoming.key] == nil {
                    current[incoming.key] = incoming.value
                }
            case .overwriteWithNew:
                current[incoming.key] = incoming.value
            case .custom(let resolver):
                if let existing = current[incoming.key] {
                    current[incoming.key] = resolver(existing, incoming.value, incoming.key)
                } else {
                    current[incoming.key] = incoming.value
                }
            }
        }
    }
    
    /// Returns a new dictionary resulting from merging this dictionary
    /// with another, using a specified merge strategy.
    ///
    /// - Parameters:
    ///   - dictionary: The dictionary to merge into this one.
    ///   - strategy: Strategy to resolve key collisions. Defaults to `.preserveOriginal`.
    /// - Returns: A new dictionary with values merged.
    @inlinable
    func merged(
        with dictionary: Dictionary<Key, Value>,
        using strategy: MergeStrategy = .preserveOriginal
    ) -> Dictionary<Key, Value> {
        var result = self
        result.merge(with: dictionary, using: strategy)
        return result
    }
}
