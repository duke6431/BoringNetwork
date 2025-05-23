//
//  ReactiveClient.swift
//  ReactiveBoringNetwork
//
//  Created by Duc Nguyen on 2025/05/21.
//
//  Description:
//  Defines a reactive client using RxSwift for declarative networking in the
//  BoringNetwork framework. Supports composing request builders, raw response,
//  object decoding, and wrapped payload extraction using `Single` streams.
//

import Foundation
import RxSwift
import BoringNetwork

/// A client that supports reactive networking operations using RxSwift.
/// Provides methods for constructing requests and decoding responses
/// using `Single` streams for completion-style reactive APIs.
open class ReactiveClient: BaseClient {
    
    /// Constructs a request from a path and method, returning a `Single`.
    public func constructRequest<Parameters>(
        with path: String,
        method: BaseClient.HTTPMethod,
        parameters: Parameters? = nil,
        additionalHeaders: [String: String]? = nil
    ) -> Single<URLRequest> where Parameters: Encodable {
        .create { [weak self] single in
            do {
                if let request = try self?.constructRequest(with: path, method: method, parameters: parameters, additionalHeaders: additionalHeaders) {
                    single(.success(request))
                }
                single(.failure(NetworkError.Invalid.request))
            } catch {
                single(.failure(error))
            }
            return Disposables.create()
        }
    }
    
    /// Constructs a request from a full URL string and method, returning a `Single`.
    public func constructRequest<Parameters>(
        using url: String,
        method: BaseClient.HTTPMethod,
        parameters: Parameters? = nil,
        additionalHeaders: [String: String]? = nil
    ) -> Single<URLRequest> where Parameters: Encodable {
        .create { [weak self] single in
            do {
                if let request = try self?.constructRequest(using: url, method: method, parameters: parameters, additionalHeaders: additionalHeaders) {
                    single(.success(request))
                }
                single(.failure(NetworkError.Invalid.request))
            } catch {
                single(.failure(error))
            }
            return Disposables.create()
        }
    }
    
    /// Constructs a request from a strongly typed `Endpoint` definition.
    public func constructRequest<Parameter>(
        with endpoint: any Endpoint<Parameter>
    ) -> Single<URLRequest> where Parameter: Encodable {
        .create { [weak self] single in
            do {
                if let request = try self?.constructRequest(with: endpoint) {
                    single(.success(request))
                }
                single(.failure(NetworkError.Invalid.request))
            } catch {
                single(.failure(error))
            }
            return Disposables.create()
        }
    }
    
    /// Executes a raw request and returns unparsed data.
    public func raw(
        from request: URLRequest?,
        errorHandler: NetworkError.NetHandler? = nil
    ) -> Single<Data> {
        guard let request = request, let dataProvider = session as? ReactiveSessioning else {
            return .error(NetworkError.Invalid.request)
        }
        return dataProvider.execute(request: request).map { raw in
            guard let response = raw.response as? HTTPURLResponse else {
                throw NetworkError.Invalid.response
            }
            guard 200 ..< 300 ~= response.statusCode else {
                throw errorHandler?(response, raw.data) ?? NetworkError.Internal.notImplemented.with(detail: "Default error handler not found")
            }
            return raw.data
        }
    }
    
    /// Executes a request and decodes the response into a single object.
    public func object<T: Decodable>(
        from request: URLRequest?,
        errorHandler: NetworkError.NetHandler? = nil
    ) -> Single<T> {
        guard let request = request, let dataProvider = session as? ReactiveSessioning else {
            return .error(NetworkError.Invalid.request)
        }
        return dataProvider.execute(request: request).map { raw in
            guard let response = raw.response as? HTTPURLResponse else {
                throw NetworkError.Invalid.response
            }
            guard 200 ..< 300 ~= response.statusCode else {
                throw errorHandler?(response, raw.data) ?? NetworkError.Internal.notImplemented.with(detail: "Default error handler not found")
            }
            return raw.data
        }.map { [weak self] in
            guard let self else { throw NetworkError.Internal.inconsistent }
            return try self.decode(T.self, from: $0)
        }
    }
    
    /// Executes a request and decodes the response into an array.
    public func array<T: Decodable>(
        from request: URLRequest?,
        errorHandler: NetworkError.NetHandler? = nil
    ) -> Single<[T]> {
        object(from: request, errorHandler: errorHandler)
    }
    
    /// Executes a request and decodes a wrapped single object.
    public func wrapped<T: Decodable, W: Wrappable<T>>(
        from request: URLRequest?,
        errorHandler: NetworkError.NetHandler? = nil,
        using wrapper: W.Type
    ) -> Single<T> {
        object(from: request, errorHandler: errorHandler).map { [weak self] (wrapped: W) in
            guard let value = wrapped.value() else {
                throw NetworkError.Invalid.response.with(detail: "Wrapped value is nil for \(W.self)")
            }
            return value
        }
    }
    
    /// Executes a request and decodes a wrapped array of objects.
    public func wrappedArray<T: Decodable, W: Wrappable<T>>(
        from request: URLRequest?,
        errorHandler: NetworkError.NetHandler? = nil,
        using: W.Type
    ) -> Single<[T]> {
        array(from: request, errorHandler: errorHandler).map { (wrapped: [W]) in
            wrapped.compactMap { $0.value() }
        }
    }
}

extension ReactiveClient {
    /// Executes a typed `Endpoint` request and decodes a single object.
    public func object<Request: Encodable, Response: Decodable>(
        from endpoint: any Endpoint<Request>,
        errorHandler: NetworkError.NetHandler? = nil
    ) -> Single<Response> {
        constructRequest(with: endpoint).flatMap { self.object(from: $0, errorHandler: errorHandler) }
    }
    
    /// Executes a typed `Endpoint` request and decodes an array of objects.
    public func array<Request: Encodable, Response: Decodable>(
        from endpoint: any Endpoint<Request>,
        errorHandler: NetworkError.NetHandler? = nil
    ) -> Single<[Response]> {
        constructRequest(with: endpoint).flatMap { self.array(from: $0, errorHandler: errorHandler) }
    }
    
    /// Executes a typed `Endpoint` request and decodes a wrapped single object.
    public func wrapped<Request: Encodable, Response: Decodable, Wrapper: Wrappable<Response>>(
        from endpoint: any Endpoint<Request>,
        errorHandler: NetworkError.NetHandler? = nil,
        using wrapper: Wrapper.Type
    ) -> Single<Response> {
        constructRequest(with: endpoint).flatMap { self.wrapped(from: $0, errorHandler: errorHandler, using: wrapper) }
    }
    
    /// Executes a typed `Endpoint` request and decodes a wrapped array of objects.
    public func wrappedArray<Request: Encodable, Response: Decodable, Wrapper: Wrappable<Response>>(
        from endpoint: any Endpoint<Request>,
        errorHandler: NetworkError.NetHandler? = nil,
        using wrapper: Wrapper.Type
    ) -> Single<[Response]> {
        constructRequest(with: endpoint).flatMap { self.wrappedArray(from: $0, errorHandler: errorHandler, using: wrapper) }
    }
}

private extension ReactiveClient {
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().with(strategy: keyCodingStrategy).decode(type, from: data)
    }
}
