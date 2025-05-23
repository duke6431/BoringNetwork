//
//  Endpoint.swift
//  BoringNetwork
//
//  Created by Duc Nguyen on 2025/05/20.
//
//  Description:
//  Defines the `Endpoint` protocol for encapsulating network route metadata
//  including HTTP method, path, headers, timeout, and typed request body.
//  Used by HTTP clients to construct and send strongly typed requests.
//

import Foundation

/// A default empty request payload used when no request body is needed.
public struct Empty: Encodable {}

/// A protocol that defines a typed HTTP endpoint, including its path, method,
/// headers, request body, and timeout settings. Used to describe API routes
/// in a composable and reusable manner.
public protocol Endpoint<Query>: Sendable {
    /// The type of the request body or query parameters. Must conform to `Encodable`.
    associatedtype Query: Encodable = Empty
    
    /// The HTTP method for the request (e.g., GET, POST).
    var method: BaseClient.HTTPMethod { get }
    
    /// The endpoint path to be appended to the base URL.
    var path: String { get }
    
    /// An optional base URL to override the default session base URL.
    var baseURL: URL? { get }
    
    /// An optional timeout interval for the request. If `nil`, the session default is used.
    var timeoutInterval: TimeInterval? { get }
    
    /// Optional headers to be included with the request. Overrides session headers on conflict.
    var headers: [String: String]? { get }
    
    /// The payload to be encoded into the request body or query.
    var request: Query { get }
}

public extension Endpoint {
    var timeoutInterval: TimeInterval? { nil }
    var headers: [String: String]? { nil }
    var baseURL: URL? { nil }
}
