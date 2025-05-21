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

/// A default async-enabled session based on `BoringSession`.
/// Uses continuation to bridge completion-handler-based execution.
class AsyncBoringSession: BoringSession, AsyncSessioning {
    /// Executes a URL request asynchronously using Swift Concurrency.
    ///
    /// - Parameter request: The request to be executed.
    /// - Returns: A tuple containing the response data and the URL response.
    public func execute(request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, URLResponse), Error>) in
            execute(request: request) { data, response, error in
                if let response, let data {
                    continuation.resume(with: .success((data, response)))
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: NetworkError.Internal.inconsistent)
                }
            }
        }
    }
}

/// An async-compatible secure session that injects authorization headers.
/// Automatically requests authentication on 401 responses.
class AsyncSecureSession: SecureSession, AsyncSessioning {
    /// Executes a URL request asynchronously, injecting the access token if available.
    /// If a 401 Unauthorized response is received, triggers authentication.
    ///
    /// - Parameter request: The request to be executed.
    /// - Returns: A tuple containing the response data and the URL response.
    public func execute(request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, URLResponse), Error>) in
            var authenticatedRequest = request
            if let token = authClient.tokenStore.accessToken {
                authenticatedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            execute(request: authenticatedRequest) { [authClient] data, response, error in
                if let response, let httpResponse = response as? HTTPURLResponse, let data {
                    if httpResponse.statusCode == 401 {
                        authClient.requestAuthentication()
                        continuation.resume(throwing: NetworkError.Network.unauthorized)
                    }
                    continuation.resume(with: .success((data, response)))
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: NetworkError.Internal.inconsistent)
                }
            }
        }
    }
}
