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
    public var interceptors: [Interceptor] = []
    
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
    public required init(session: URLSession = .shared) {
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
        completionHandler: (@Sendable (Data?, URLResponse?, Error?) -> Void)?
    ) -> Cancellable {
        let request = interceptors.reduce(request) { result, interceptor in interceptor.adapt(result) }
        let task = session.dataTask(with: request) { data, response, error in
            let interceptors = self.interceptors
            @Sendable func applyInterceptors(
                index: Int,
                result: (Data?, URLResponse?, Error?),
                completion: @escaping ((Data?, URLResponse?, Error?)) -> Void
            ) {
                guard index < interceptors.count else {
                    completion(result)
                    return
                }
                interceptors[index].intercept(result) { newResult in
                    applyInterceptors(index: index + 1, result: newResult, completion: completion)
                }
            }
            
            applyInterceptors(index: 0, result: (data, response, error)) { finalData, finalResponse, finalError in
                if (finalError as? URLError)?.code == .notConnectedToInternet {
                    completionHandler?(nil, nil, NetworkError.Network.networkLost)
                    return
                }
                
                guard let httpResponse = finalResponse as? HTTPURLResponse else {
                    completionHandler?(finalData, finalResponse, finalError)
                    return
                }
                
                if !(200..<300).contains(httpResponse.statusCode) {
                    let failure = self.makeHTTPFailure(request, finalResponse, finalData, finalError)
                    completionHandler?(finalData, finalResponse, failure)
                    return
                }
                
                completionHandler?(finalData, finalResponse, finalError)
            }
        }
        
        defer { task.resume() }
        return task
    }
    
    /// Constructs a failure error for HTTP responses with non-2xx status codes.
    private func makeHTTPFailure(
        _ request: URLRequest,
        _ response: URLResponse?,
        _ data: Data?,
        _ error: Error?
    ) -> Error {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        return NetworkError.Network.failure(
            request: request,
            response: response,
            data: data,
            underlying: error,
            comment: "Received status code \(status): \(HTTPURLResponse.localizedString(forStatusCode: status))"
        )
    }
}
