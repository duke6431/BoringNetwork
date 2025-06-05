//
//  AsyncClient.swift
//  AsyncBoringNetwork
//
//  Created by Duc Nguyen on 2025/05/21.
//
//  Description:
//  Defines an async-enabled networking client built on Swift Concurrency.
//  Provides support for executing requests, decoding JSON responses, and handling
//  wrapped API payloads using async/await.
//

import Foundation
import BoringNetwork

/// A network client that supports asynchronous operations using Swift Concurrency.
/// Provides helpers to fetch raw data, decoded objects, or wrapped payloads.
open class AsyncClient: BaseClient {
    /// Performs a request and returns raw data if successful.
    ///
    /// - Parameters:
    ///   - request: The URL request to execute.
    ///   - errorHandler: Optional handler for customizing error conversion.
    /// - Returns: The raw response data.
    @inlinable
    public func raw(from request: URLRequest?, errorHandler: NetworkError.NetHandler? = nil) async throws -> Data {
        guard let request = request, let dataProvider = session as? AsyncSessioning else { throw NetworkError.Invalid.request }
        let (data, response) = try await dataProvider.execute(request: request)
        guard let response = response as? HTTPURLResponse else {
            throw NetworkError.Invalid.response
        }
        guard 200 ..< 300 ~= response.statusCode else {
            throw errorHandler?(response, data) ?? NetworkError.Internal.notImplemented.with(detail: "Default error handler not found")
        }
        return data
    }
    
    /// Performs a request and decodes the response into a `Decodable` object.
    ///
    /// - Parameters:
    ///   - request: The URL request to execute.
    ///   - errorHandler: Optional handler for customizing error conversion.
    /// - Returns: A decoded object of type `T`.
    @inlinable
    public func object<T: Decodable>(from request: URLRequest?, errorHandler: NetworkError.NetHandler? = nil) async throws -> T {
        let data = try await raw(from: request, errorHandler: errorHandler)
        return try decode(T.self, from: data)
    }
    
    /// Performs a request and decodes an array of `Decodable` objects.
    ///
    /// - Parameters:
    ///   - request: The URL request to execute.
    ///   - errorHandler: Optional handler for customizing error conversion.
    /// - Returns: An array of decoded objects of type `T`.
    @inlinable
    public func array<T: Decodable>(from request: URLRequest?, errorHandler: NetworkError.NetHandler? = nil) async throws -> [T] {
        try await object(from: request, errorHandler: errorHandler)
    }
    
    /// Performs a request and unwraps a single value from a wrapped payload.
    ///
    /// - Parameters:
    ///   - request: The URL request to execute.
    ///   - errorHandler: Optional handler for customizing error conversion.
    ///   - using: The wrapper type that conforms to `Wrappable`.
    /// - Returns: The unwrapped value of type `T`.
    @inlinable
    public func wrapped<T: Decodable, W: Wrappable<T>>(from request: URLRequest?, errorHandler: NetworkError.NetHandler? = nil, using: W.Type) async throws -> T {
        let wrapped: W = try await object(from: request, errorHandler: errorHandler)
        guard let value = wrapped.value() else {
            throw NetworkError.Invalid.response.with(detail: "Wrapped value is nil for \(W.self)")
        }
        return value
    }
    
    /// Performs a request and unwraps an array of values from wrapped payloads.
    ///
    /// - Parameters:
    ///   - request: The URL request to execute.
    ///   - errorHandler: Optional handler for customizing error conversion.
    ///   - using: The wrapper type that conforms to `Wrappable`.
    /// - Returns: An array of unwrapped values of type `T`.
    @inlinable
    public func wrappedArray<T: Decodable, W: Wrappable<T>>(from request: URLRequest?, errorHandler: NetworkError.NetHandler? = nil, using: W.Type) async throws -> [T] {
        let wrapped: [W] = try await array(from: request, errorHandler: errorHandler)
        return wrapped.compactMap { $0.value() }
    }
}

extension AsyncClient {
    @inlinable
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().with(strategy: keyCodingStrategy).decode(type, from: data)
    }
}

extension AsyncClient {
    /// Performs a typed request using an `Endpoint` and decodes a single object.
    ///
    /// - Parameters:
    ///   - endpoint: The endpoint describing the request.
    ///   - errorHandler: Optional handler for customizing error conversion.
    /// - Returns: A decoded object of type `Response`.
    @inlinable
    public func object<Response: Decodable>(from endpoint: EndpointConvertible, errorHandler: NetworkError.NetHandler? = nil) async throws -> Response {
        try await object(from: try constructRequest(with: endpoint), errorHandler: errorHandler)
    }
    
    /// Performs a typed request using an `Endpoint` and decodes an array of objects.
    ///
    /// - Parameters:
    ///   - endpoint: The endpoint describing the request.
    ///   - errorHandler: Optional handler for customizing error conversion.
    /// - Returns: An array of decoded objects of type `Response`.
    @inlinable
    public func array<Response: Decodable>(from endpoint: EndpointConvertible, errorHandler: NetworkError.NetHandler? = nil) async throws -> [Response] {
        try await array(from: try constructRequest(with: endpoint), errorHandler: errorHandler)
    }
    
    /// Performs a typed request and decodes a wrapped single object.
    ///
    /// - Parameters:
    ///   - endpoint: The endpoint describing the request.
    ///   - errorHandler: Optional handler for customizing error conversion.
    ///   - using: The wrapper type that conforms to `Wrappable`.
    /// - Returns: The unwrapped value of type `Response`.
    @inlinable
    public func wrapped<Response: Decodable, Wrapper: Wrappable<Response>>(from endpoint: EndpointConvertible, errorHandler: NetworkError.NetHandler? = nil, using: Wrapper.Type) async throws -> Response {
        try await wrapped(from: try constructRequest(with: endpoint), errorHandler: errorHandler, using: Wrapper.self)
    }
    
    /// Performs a typed request and decodes a wrapped array of objects.
    ///
    /// - Parameters:
    ///   - endpoint: The endpoint describing the request.
    ///   - errorHandler: Optional handler for customizing error conversion.
    ///   - using: The wrapper type that conforms to `Wrappable`.
    /// - Returns: An array of unwrapped values of type `Response`.
    @inlinable
    public func wrappedArray<Response: Decodable, Wrapper: Wrappable<Response>>(from endpoint: EndpointConvertible, errorHandler: NetworkError.NetHandler? = nil, using: Wrapper.Type) async throws -> [Response] {
        try await  wrappedArray(from: try constructRequest(with: endpoint), errorHandler: errorHandler, using: Wrapper.self)
    }
}
