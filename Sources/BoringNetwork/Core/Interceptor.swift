//
//  Interceptor.swift
//  BoringNetwork
//
//  Created by Duc Nguyen on 2025/05/23.
//
//  Description:
//  Declares the `Interceptor` protocol for adapting requests and intercepting
//  responses in the BoringNetwork framework. This enables behaviors like logging,
//  header injection, and custom error inspection without modifying session internals.
//

import Foundation

/// A protocol for intercepting requests and responses in a network session.
/// Useful for adding headers, logging, and handling custom side effects.
public protocol Interceptor {
    /// Modifies or inspects the URL request before it is sent.
    ///
    /// This method is called synchronously and should return the modified or original request.
    ///
    /// - Parameter request: The original `URLRequest`.
    /// - Returns: A modified or original `URLRequest`.
    func adapt(_ request: URLRequest) -> URLRequest
    
    /// Called after a network response is received. Allows inspection, logging, or modification.
    ///
    /// This method is asynchronous and uses a completion closure to forward the possibly modified result.
    ///
    /// - Parameters:
    ///   - result: A tuple containing data, response, and error from the network layer.
    ///   - completion: A closure to forward the possibly modified result.
    func intercept(_ result: (Data?, URLResponse?, Error?), completion: @Sendable @escaping ((Data?, URLResponse?, Error?)) -> Void)
}

public extension Interceptor {
    func adapt(_ request: URLRequest) -> URLRequest { request }
    
    func intercept(_ result: (Data?, URLResponse?, Error?), completion: @Sendable @escaping ((Data?, URLResponse?, Error?)) -> Void) {
        completion(result)
    }
}
