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

/// A protocol that defines a typed HTTP endpoint, including its path, method,
/// headers, request body, and timeout settings. Used to describe API routes
/// in a composable and reusable manner.
public protocol Endpoint<Query> {
    /// The type of the request body or query parameters. Must conform to `Encodable`.
    associatedtype Query: Encodable
    
    /// The HTTP method for the request (e.g., GET, POST).
    var method: BaseClient.HTTPMethod { get }
    
    /// The endpoint path to be appended to the base URL.
    var path: String { get }
    
    /// An optional timeout interval for the request.
    var timeoutInterval: TimeInterval? { get }
    
    /// Optional headers to be included with the request.
    var headers: [String: String]? { get }
    
    /// The payload to be encoded into the request body or query.
    var request: Query { get }
}

public extension Endpoint {
    /// The default timeout interval is `nil`, indicating no override.
    var timeoutInterval: TimeInterval? { nil }
    
    /// The default headers are `nil`, indicating no additional headers.
    var headers: [String: String]? { nil }
}
