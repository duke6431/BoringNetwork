//
//  BoringContainer.swift
//  BoringNetwork
//
//  Created by Duc Nguyen on 2025/05/21.
//
//  Description:
//  Defines the `BoringContainer`, a central dependency injection holder for managing
//  public and secure client sessions. It facilitates access and registration of
//  HTTP clients, including those requiring authentication.
//

import Foundation

public extension BoringContainer {
    /// Represents a client registration target for the container.
    enum ClientType {
        /// A public, unauthenticated client.
        case `public`(_ client: BaseClient)
        
        /// A secure, authenticated client.
        case secure(_ client: BaseClient)
    }
}

/// A container responsible for managing public and secure session clients.
/// It supports dynamic registration of clients, including an optional auth client.
public class BoringContainer {
    /// The base URL session shared across all session clients.
    private let session: URLSession
    
    /// The optional authentication client which must conform to both `BaseClient` and `AuthService`.
    public private(set) var authClient: (BaseClient & AuthService)?
    
    /// The session for unauthenticated clients.
    private lazy var publicSession: BoringSession = {
        var session: BoringSession = .init(session: session)
        if let authClient { session = session.register(authClient) }
        return session
    }()
    
    /// The session for authenticated clients.
    private lazy var secureSession: SecureSession = {
        guard let authClient else { fatalError("AuthClient was not configured") }
        return .init(session: session, authClient: authClient)
    }()
    
    /// Initializes the container with a shared session and optional auth client.
    ///
    /// - Parameters:
    ///   - session: The `URLSession` used across all sessions.
    ///   - authClient: An optional client conforming to both `BaseClient` and `AuthService`.
    public init(
        session: URLSession,
        authClient: (BaseClient & AuthService)?
    ) {
        self.session = session
        self.authClient = authClient
    }
    
    /// Registers a client into either the public or secure session based on the type.
    ///
    /// - Parameter client: The `ClientType` indicating where the client should be registered.
    /// - Returns: Self, for chaining.
    @discardableResult
    public func register(_ client: ClientType) -> Self {
        switch client {
        case .public(let client):
            publicSession.register(client)
        case .secure(let client):
            secureSession.register(client)
        }
        return self
    }
    
    /// Registers the `AuthService` client for both secure operations and as a public client.
    ///
    /// - Parameter authClient: The authentication-enabled base client.
    /// - Returns: Self, for chaining.
    @discardableResult
    public func register(_ authClient: BaseClient & AuthService) -> Self {
        publicSession.register(authClient)
        self.authClient = authClient
        return self
    }
    
    /// Retrieves a public client of a specific type.
    ///
    /// - Returns: An optional instance of the requested `BaseClient` type.
    public func `public`<Client: BaseClient>() -> Client? {
        publicSession.client()
    }
    
    /// Retrieves a secure client of a specific type.
    ///
    /// - Returns: An optional instance of the requested `BaseClient` type.
    public func secure<Client: BaseClient>() -> Client? {
        secureSession.client()
    }
}
