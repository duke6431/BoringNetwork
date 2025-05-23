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
    
    /// A list of active clients registered with the session.
    var clients: [BaseClient] { get }
    
    /// Registers a concrete client to be managed by the session.
    ///
    /// - Parameter client: The client to register.
    /// - Returns: Self, to support chaining.
    @discardableResult
    func register(_ client: BaseClient) -> Self
    
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

extension BoringSessioning {
    /// Returns the first existing or newly generated client of the given type.
    public func client<Client: BaseClient>() -> Client? {
        clients.compactMap { $0 as? Client }.first ?? generate()
    }
    
    /// Attempts to instantiate a client using its registered factory.
    @discardableResult
    private func generate<Client: BaseClient>() -> Client? {
        let client = (clientFactories[String(describing: Client.self)]?() as? Client)
        client?._session = self
        return client
    }
    
    /// Default: empty array for clients.
    public var clients: [BaseClient] { [] }
    
    /// Default: empty dictionary for client factories.
    public var clientFactories: [String: () -> BaseClient] { [:] }
}

extension Result where Success == Cancellable, Failure == Error {
    /// Returns the cancellable object if the result is successful.
    var object: Success? {
        switch self {
        case .success(let cancellable): cancellable
        case .failure: nil
        }
    }
    
    /// Returns the error if the result is a failure.
    var error: Failure? {
        switch self {
        case .success: nil
        case .failure(let err): err
        }
    }
}

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
