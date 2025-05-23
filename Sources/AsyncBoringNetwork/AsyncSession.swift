//
//  AsyncSession.swift
//  AsyncBoringNetwork
//
//  Created by Duc Nguyen on 2025/05/21.
//
//  Description:
//  Defines async-compatible session interfaces and implementations for
//  use with Swift Concurrency. Supports structured async/await-based
//  request execution with optional secure token injection.
//

import Foundation
import BoringNetwork

/// A protocol that extends `BoringSessioning` with Swift Concurrency support.
/// Provides an async/await interface for executing URL requests.
public protocol AsyncSessioning: BoringSessioning {
    /// Executes a URL request asynchronously and returns the result.
    ///
    /// - Parameter request: The request to be executed.
    /// - Returns: A tuple containing the response data and the URL response.
    func execute(request: URLRequest) async throws -> (Data, URLResponse)
}

class AsyncBoringSession: BoringSession, AsyncSessioning {
    /// Executes a URL request asynchronously using Swift Concurrency,
    /// bridging the completion-handler API to async/await.
    ///
    /// - Parameter request: The request to be executed.
    /// - Returns: A tuple containing the response data and the URL response.
    public func execute(request: URLRequest) async throws -> (Data, URLResponse) {
        try await Self.bridgeAsync(request: request) { request, completion in
            self.execute(request: request, completionHandler: completion)
        }
    }
}

class AsyncSecureSession: SecureSession, AsyncSessioning {
    /// Executes a URL request asynchronously, injecting the access token if available.
    /// If a 401 Unauthorized response is received, triggers authentication and throws unauthorized error.
    ///
    /// - Parameter request: The request to be executed.
    /// - Returns: A tuple containing the response data and the URL response.
    public func execute(request: URLRequest) async throws -> (Data, URLResponse) {
        var authenticatedRequest = request
        if let token = authClient.tokenStore.accessToken {
            authenticatedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return try await Self.bridgeAsync(request: authenticatedRequest) { request, completion in
            self.execute(request: request) { data, response, error in
                if let response, let http = response as? HTTPURLResponse, let data {
                    if http.statusCode == 401 {
                        self.authClient.requestAuthentication()
                        completion(nil, response, NetworkError.Network.unauthorized)
                        return
                    }
                    completion(data, response, nil)
                } else {
                    completion(data, response, error)
                }
            }
        }
    }
}

private extension AsyncSessioning {
    static func bridgeAsync(
        request: URLRequest,
        executor: @escaping (_ request: URLRequest, _ completion: @Sendable @escaping (Data?, URLResponse?, Error?) -> Void) -> Void
    ) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            executor(request) { data, response, error in
                if let data, let response {
                    continuation.resume(returning: (data, response))
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: NetworkError.Internal.inconsistent)
                }
            }
        }
    }
}
