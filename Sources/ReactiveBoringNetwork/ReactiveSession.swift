//
//  ReactiveSession.swift
//  ReactiveBoringNetwork
//
//  Created by Duc Nguyen on 2025/05/21.
//
//  Description:
//  Defines reactive session interfaces and implementations for RxSwift-based
//  request execution. Supports both public and authenticated sessions that
//  emit `Single<RawResponse>` types with automatic error handling.
//

import Foundation
import BoringNetwork
import RxSwift

/// A container for raw response data and URL response, used with reactive clients.
@objc public final class RawResponse: NSObject {
    /// The response data returned from the request.
    let data: Data
    
    /// The URL response associated with the data.
    let response: URLResponse
    
    /// Initializes a new raw response wrapper.
    ///
    /// - Parameters:
    ///   - data: The body data.
    ///   - response: The associated URL response.
    public init(_ data: Data, _ response: URLResponse) {
        self.data = data
        self.response = response
    }
}

/// A protocol for sessions that support RxSwift-compatible request execution.
public protocol ReactiveSessioning: BoringSessioning {
    /// Executes a request and returns the result wrapped in a `Single`.
    ///
    /// - Parameter request: The URL request to be executed.
    /// - Returns: A single-emission stream containing a `RawResponse` or an error.
    func execute(request: URLRequest) -> Single<RawResponse>
}

/// A default reactive session that wraps a `BoringSession` and emits responses via RxSwift.
public class ReactiveBoringSession: BoringSession, ReactiveSessioning {
    public func execute(request: URLRequest) -> Single<RawResponse> {
        .create { [weak self] single in
            let request = self?.execute(request: request, completionHandler: { data, response, error in
                if let error {
                    single(.failure(error))
                    return
                }
                guard let response, let data else {
                    single(.failure(NetworkError.Internal.inconsistent))
                    return
                }
                single(.success(.init(data, response)))
            })
            return Disposables.create {
                if request?.isCancellable ?? false { request?.cancel() }
            }
        }
    }
}

/// A secure reactive session that injects bearer tokens and handles 401 errors.
/// Emits responses as RxSwift `Single` streams.
open class ReactiveSecureSession: SecureSession, ReactiveSessioning  {
    open func execute(request: URLRequest) -> Single<RawResponse> {
        var authenticatedRequest = request
        if let token = authClient.tokenStore.accessToken {
            authenticatedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return .create { [weak self] single in
            let task = self?.execute(request: authenticatedRequest) { data, response, error in
                self?.handleSecureResponse(data: data, response: response, error: error, single: single)
            }
            return Disposables.create {
                if task?.isCancellable ?? false { task?.cancel() }
            }
        }
    }
    
    private func handleSecureResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        single: @escaping (SingleEvent<RawResponse>) -> Void
    ) {
        if let error = error {
            single(.failure(error))
            return
        }
        guard let data = data, let response = response else {
            single(.failure(NetworkError.Internal.inconsistent))
            return
        }
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            authClient.requestAuthentication()
            single(.failure(NetworkError.Network.unauthorized))
            return
        }
        single(.success(.init(data, response)))
    }
}
