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

public protocol EndpointConvertible {
    var endpoint: Endpoint { get }
}

/// A protocol that defines a typed HTTP endpoint, including its path, method,
/// headers, request body, and timeout settings. Used to describe API routes
/// in a composable and reusable manner.
open class Endpoint: EndpointConvertible {
    /// The HTTP method for the request (e.g., GET, POST).
    open var method: BaseClient.HTTPMethod
    
    /// The endpoint path to be appended to the base URL.
    open var path: String
    
    /// An optional base URL to override the default session base URL.
    open var baseURL: URL?
    
    /// An optional timeout interval for the request. If `nil`, the session default is used.
    open var timeoutInterval: TimeInterval?
    
    /// Optional headers to be included with the request. Overrides session headers on conflict.
    open var headers: [String: String]?
    
    /// The payload to be encoded into the request body or query.
    open var request: Encodable
    
    public init(method: BaseClient.HTTPMethod, path: String, baseURL: URL? = nil, timeoutInterval: TimeInterval? = nil, headers: [String : String]? = nil, request: Encodable) {
        self.method = method
        self.path = path
        self.baseURL = baseURL
        self.timeoutInterval = timeoutInterval
        self.headers = headers
        self.request = request
    }
    
    public var endpoint: Endpoint { self }
}
