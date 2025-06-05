//
//  CompletionClient.swift
//  BoringNetwork
//
//  Created by Duc Nguyen on 2025/05/21.
//
//  Description:
//  Defines a concrete networking client using completion handlers for asynchronous operations.
//  Supports raw requests, decoded objects, and wrapped response parsing with flexible error handling.
//

import Foundation

/// A networking client that uses completion handlers for executing requests.
/// It provides typed decoding, custom error mapping, and response validation.
open class CompletionClient: BaseClient {
    /// Performs a raw data request and passes through the result or error.
    ///
    /// - Parameters:
    ///   - request: The URL request to perform.
    ///   - errorHandler: Optional custom error handler for status code failures.
    ///   - completion: Completion handler with raw data or error.
    /// - Returns: A `Cancellable` task reference, or nil if request was invalid.
    @discardableResult
    public func raw(from request: URLRequest?, errorHandler: NetworkError.NetHandler? = nil, completion: @escaping (Result<Data, Error>) -> Void) -> Cancellable? {
        guard let request = request else {
            completion(.failure(NetworkError.Invalid.request))
            return nil
        }
        return session.execute(request: request, completionHandler: { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let response = response as? HTTPURLResponse else {
                completion(.failure(NetworkError.Invalid.response))
                return
            }
            guard 200 ..< 300 ~= response.statusCode else {
                completion(.failure(errorHandler?(response, data) ?? NetworkError.Internal.notImplemented.with(detail: "Default error handler not found")))
                return
            }
            guard let data = data else {
                completion(.failure(NetworkError.Invalid.data))
                return
            }
            completion(.success(data))
        })
    }
    
    /// Performs a request and decodes the response into a `Decodable` object.
    ///
    /// - Parameters:
    ///   - request: The URL request to perform.
    ///   - errorHandler: Optional custom error handler.
    ///   - completion: Completion handler with decoded object or error.
    /// - Returns: A `Cancellable` reference, or nil if request was invalid.
    @discardableResult
    public func object<T: Decodable>(from request: URLRequest?, errorHandler: NetworkError.NetHandler? = nil, completion: @escaping (Result<T, Error>) -> Void) -> Cancellable? {
        guard let request = request else {
            completion(.failure(NetworkError.Invalid.request))
            return nil
        }
        return session.execute(request: request, completionHandler: { [weak self] data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let response = response as? HTTPURLResponse else {
                completion(.failure(NetworkError.Invalid.response))
                return
            }
            guard 200 ..< 300 ~= response.statusCode else {
                completion(.failure(errorHandler?(response, data) ?? NetworkError.Internal.notImplemented.with(detail: "Default error handler not found")))
                return
            }
            guard let data = data else {
                completion(.failure(NetworkError.Invalid.data))
                return
            }
            do {
                let item = try self?.decode(T.self, from: data) ?? {
                    throw NetworkError.Internal.inconsistent.with(detail: "Key coding strategy not available")
                }()
                completion(.success(item))
            } catch {
                completion(.failure(NetworkError.Invalid.data.with(underlying: error)))
            }
        })
    }
    
    /// Performs a request and decodes an array of `Decodable` items.
    @discardableResult
    public func array<T: Decodable>(from request: URLRequest?, errorHandler: NetworkError.NetHandler? = nil, completion: @escaping (Result<[T], Error>) -> Void) -> Cancellable? {
        object(from: request, errorHandler: errorHandler, completion: completion)
    }
    
    /// Performs a request and unwraps a single object from a `Wrappable` container.
    @discardableResult
    public func wrappedResponse<T: Decodable, W: Wrappable<T>>(from request: URLRequest?, errorHandler: NetworkError.NetHandler? = nil, using: W.Type, completion: @escaping (Result<T, Error>) -> Void) -> Cancellable? {
        object(from: request, errorHandler: errorHandler, completion: { (result: Result<W, Error>) in
            switch result {
            case .success(let success):
                guard let value = success.value() else {
                    completion(.failure(NetworkError.Invalid.response.with(detail: "Wrapped value is nil for \(W.self)")))
                    return
                }
                completion(.success(value))
            case .failure(let failure):
                completion(.failure(failure))
            }
        })
    }
    
    /// Performs a request and unwraps an array of objects from `Wrappable` containers.
    @discardableResult
    public func wrappedArrayResponse<T: Decodable, W: Wrappable<T>>(from request: URLRequest?, errorHandler: NetworkError.NetHandler? = nil, using: W.Type, completion: @escaping (Result<[T], Error>) -> Void) -> Cancellable? {
        array(from: request, errorHandler: errorHandler, completion: { (result: Result<[W], Error>) in
            switch result {
            case .success(let success):
                completion(.success(success.compactMap { $0.value() }))
            case .failure(let failure):
                completion(.failure(failure))
            }
        })
    }
    
    // MARK: - Private Decoding Helper
    
    /// Decodes data into the specified `Decodable` type using the configured key coding strategy.
    ///
    /// - Parameters:
    ///   - type: The type to decode.
    ///   - data: The raw data to decode from.
    /// - Returns: The decoded instance of the specified type.
    /// - Throws: An error if decoding fails.
    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().with(strategy: keyCodingStrategy).decode(type, from: data)
    }
}

extension CompletionClient {
    /// Performs a typed request using an `Endpoint` and decodes a single object.
    @discardableResult
    public func object<Response: Decodable>(from endpoint: EndpointConvertible, errorHandler: NetworkError.NetHandler? = nil, completion: @escaping (Result<Response, Error>) -> Void) -> Cancellable? {
        object(from: try? constructRequest(with: endpoint), errorHandler: errorHandler, completion: completion)
    }
    
    /// Performs a typed request using an `Endpoint` and decodes an array of objects.
    @discardableResult
    public func array<Response: Decodable>(from endpoint: EndpointConvertible, errorHandler: NetworkError.NetHandler? = nil, completion: @escaping (Result<[Response], Error>) -> Void) -> Cancellable? {
        array(from: try? constructRequest(with: endpoint), errorHandler: errorHandler, completion: completion)
    }
    
    /// Performs a typed request and decodes a wrapped response.
    @discardableResult
    public func wrappedResponse<Response: Decodable, Wrapper: Wrappable<Response>>(from endpoint: EndpointConvertible, errorHandler: NetworkError.NetHandler? = nil, using: Wrapper.Type, completion: @escaping (Result<Response, Error>) -> Void) -> Cancellable? {
        wrappedResponse(from: try? constructRequest(with: endpoint), errorHandler: errorHandler, using: Wrapper.self, completion: completion)
    }
    
    /// Performs a typed request and decodes a wrapped array response.
    @discardableResult
    public func wrappedArrayResponse<Response: Decodable, Wrapper: Wrappable<Response>>(from endpoint: EndpointConvertible, errorHandler: NetworkError.NetHandler? = nil, using: Wrapper.Type, completion: @escaping (Result<[Response], Error>) -> Void) -> Cancellable? {
        wrappedArrayResponse(from: try? constructRequest(with: endpoint), errorHandler: errorHandler, using: Wrapper.self, completion: completion)
    }
}
