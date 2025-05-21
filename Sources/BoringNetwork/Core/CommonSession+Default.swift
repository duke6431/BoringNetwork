//
//  CommonSession+Default.swift
//  BoringNetwork
//
//  Created by Duc Nguyen on 2025/05/20.
//
//  Description:
//  Implements `BoringSession`, the default session that conforms to `BoringSessioning`
//  and wraps a `URLSession`. It supports registration of typed clients and executes
//  URL requests with basic error handling for network failure, authorization issues,
//  and non-success status codes.
//

import Foundation

/// A default implementation of `BoringSessioning` using `URLSession`.
/// Manages registration of typed clients and provides standardized request execution.
open class BoringSession: BoringSessioning {
    /// The list of registered client instances.
    public private(set) var clients: [BaseClient] = []
    
    /// A map of factory closures for lazily instantiating client instances by type.
    public private(set) var clientFactories: [String : () -> BaseClient] = [:]
    
    /// Registers a specific client instance with the session.
    ///
    /// - Parameter client: The client to register.
    /// - Returns: Self, for method chaining.
    @discardableResult
    public func register(_ client: BaseClient) -> Self {
        client._session = self
        clients.append(client)
        return self
    }
    
    /// Registers a client factory closure for a specific type.
    ///
    /// - Parameters:
    ///   - clientFactory: A closure that returns a `BaseClient` instance.
    ///   - type: The client type being registered.
    /// - Returns: Self, for method chaining.
    @discardableResult
    public func register<Client: BaseClient>(_ clientFactory: @escaping () -> BaseClient, for type: Client.Type) -> Self {
        clientFactories[String(describing: Client.self)] = clientFactory
        return self
    }
    
    /// The underlying `URLSession` used for executing requests.
    private let session: URLSession
    
    /// Initializes the session with a given `URLSession`.
    ///
    /// - Parameter session: The `URLSession` to use. Defaults to `.shared`.
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Executes a `URLRequest` and returns a cancellable task.
    /// Handles common error cases such as offline state and non-2xx responses.
    ///
    /// - Parameters:
    ///   - request: The request to perform.
    ///   - completionHandler: A closure called with the result of the request.
    /// - Returns: A cancellable task.
    @discardableResult
    open func execute(
        request: URLRequest,
        completionHandler: ((Data?, URLResponse?, Error?) -> Void)?
    ) -> Cancellable {
        let task = session.dataTask(with: request) { data, response, error in
            if (error as? URLError)?.code == .notConnectedToInternet {
                completionHandler?(nil, nil, NetworkError.Network.networkLost)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completionHandler?(data, response, error)
                return
            }
            
            if !(200..<300).contains(httpResponse.statusCode) {
                let failure = NetworkError.Network.failure(
                    request: request,
                    response: response,
                    data: data,
                    underlying: error,
                    comment: "Non-2xx status code received."
                )
                completionHandler?(data, response, failure)
                return
            }
            
            completionHandler?(data, response, error)
        }
        
        defer { task.resume() }
        return task
    }
}
