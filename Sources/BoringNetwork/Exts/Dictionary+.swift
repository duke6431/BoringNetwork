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
        /// Preserve the original dictionary's values (ignore incoming keys if already present).
        case origin
        /// Override existing keys with values from the new dictionary.
        case target
    }
    
    /// Merges another dictionary into the current one using a specified strategy.
    ///
    /// - Parameters:
    ///   - dictionary: The dictionary to merge into the current dictionary.
    ///   - strategy: The conflict resolution strategy to use. Defaults to `.origin`.
    /// - Returns: The updated dictionary after the merge.
    @discardableResult
    mutating func merge(with dictionary: Dictionary<Key, Value>, using strategy: MergeStrategy = .origin) -> Self {
        dictionary.reduce(into: self) { partialResult, pair in
            if strategy == .origin, partialResult[pair.key] != nil { return }
            partialResult[pair.key] = pair.value
        }
    }
    
    /// Returns a new dictionary resulting from merging the current dictionary
    /// with another, using a specified conflict resolution strategy.
    ///
    /// - Parameters:
    ///   - dictionary: The dictionary to merge.
    ///   - strategy: The conflict resolution strategy to apply. Defaults to `.origin`.
    /// - Returns: A new merged dictionary.
    func merged(with dictionary: Dictionary<Key, Value>, using strategy: MergeStrategy = .origin) -> Dictionary<Key, Value> {
        var result = self
        return result.merge(with: dictionary, using: strategy)
    }
}
