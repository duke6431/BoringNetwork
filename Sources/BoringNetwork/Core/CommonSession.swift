//
//  CommonSession.swift
//  BoringNetwork
//
//  Created by Duke Nguyen on 2024/06/01.
//  Copyright © 2024 Duke Nguyen. All rights reserved.
//
//  Description:
//  Defines the `BoringSessioning` protocol, which abstracts network session
//  behavior into a cancellable-execution model. It supports client registration
//  and lookup mechanisms, allowing dependency injection and reuse across
//  session-based networking clients.
//

import Foundation

// MARK: - URLSessionConfiguration Convenience

public extension URLSessionConfiguration {
    /// A preconfigured ephemeral `URLSessionConfiguration` with secure defaults
    /// tailored for the BoringNetwork framework. This includes restricted cookie
    /// acceptance, shared cookie storage, and enforced TLS 1.2.
    static var boring: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .onlyFromMainDocumentDomain
        configuration.httpShouldSetCookies = true
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        return configuration
    }
}

// MARK: - BoringSessioning Protocol

/// A protocol representing a simplified, abstract network session
/// capable of executing URL requests and returning cancellable tasks.
/// It also supports registration and retrieval of associated clients.
public protocol BoringSessioning: AnyObject {
    /// Executes the given URL request and returns a cancellable handle.
    ///
    /// - Parameters:
    ///   - request: The URL request to be executed.
    ///   - completionHandler: An optional closure to be invoked upon completion.
    /// - Returns: A `Cancellable` representing the task, if created.
    @discardableResult
    func execute(
        request: URLRequest,
        completionHandler: (@Sendable (Data?, URLResponse?, Error?) -> Void)?
    ) -> Cancellable
    
    /// An array of interceptors to be applied to requests.
    var interceptors: [Interceptor] { get set }
    
    /// A list of active clients registered with the session.
    var clients: [BaseClient] { get }
    
    /// Registers a concrete client to be managed by the session.
    ///
    /// - Parameter client: The client to register.
    /// - Returns: Self, to support chaining.
    @discardableResult
    func register(_ client: BaseClient) -> Self
    
    /// Registers an interceptor to be used for requests and responses.
    ///
    /// - Parameter interceptor: The interceptor to register.
    /// - Returns: Self, to allow chaining.
    @discardableResult
    func register(_ interceptor: Interceptor) -> Self
    
    /// A dictionary of factories for lazily instantiating clients.
    var clientFactories: [String: () -> BaseClient] { get }
    
    /// Registers a factory closure that produces a client of the given type.
    ///
    /// - Parameters:
    ///   - clientFactory: The factory to create a client.
    ///   - type: The client type to associate the factory with.
    /// - Returns: Self, to support chaining.
    @discardableResult
    func register<Client: BaseClient>(_ clientFactory: @escaping () -> BaseClient, for type: Client.Type) -> Self
    
    /// Retrieves a client of the specified type if registered.
    ///
    /// - Returns: The client instance if available.
    func client<Client: BaseClient>() -> Client?
}

// MARK: - Default Client Retrieval

extension BoringSessioning {
    public func client<Client: BaseClient>() -> Client? {
        clients.compactMap { $0 as? Client }.first ?? generate()
    }
    
    @discardableResult
    private func generate<Client: BaseClient>() -> Client? {
        let client = (clientFactories[String(describing: Client.self)]?() as? Client)
        client?._session = self
        return client
    }
}

// MARK: - Interceptor Registration

public extension BoringSessioning {
    @discardableResult
    func register(_ interceptor: Interceptor) -> Self {
        interceptors.append(interceptor)
        return self
    }
}
