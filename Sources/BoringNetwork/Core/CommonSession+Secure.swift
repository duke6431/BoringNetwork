//
//  CommonSession+Secure.swift
//  BoringNetwork
//
//  Created by Duc Nguyen on 2025/05/20.
//
//  Description:
//  Defines the secure session infrastructure used by BoringNetwork. This includes
//  credential models, token containers, and authentication service abstractions
//  to support bearer-token-based API access and refresh mechanisms.
//

import Foundation

/// A service capable of handling authentication and token refresh flows.
public protocol AuthService: AnyObject {
    /// The token storage associated with this service.
    var tokenStore: TokenStore { get }
    
    /// Initiates an authentication or refresh sequence.
    func requestAuthentication()
}

/// A protocol defining a secure token container for access and refresh tokens.
public protocol TokenStore {
    /// The currently stored access token, if any.
    var accessToken: String? { get }
    
    /// The currently stored refresh token, if any.
    var refreshToken: String? { get }
    
    /// Clears both access and refresh tokens from storage.
    func clear()
}

/// A network session that automatically attaches an authorization token
/// to requests using a provided `TokenStore`. It can be extended to support
/// automatic token refreshing via `AuthService`.
open class SecureSession: BoringSession {
    /// Provides token refresh and authentication operations.
    public let authClient: AuthService
    
    /// Initializes a secure session using the given URL session and auth client.
    ///
    /// - Parameters:
    ///   - session: The `URLSession` instance to use (defaults to `.shared`).
    ///   - authClient: The service used to retrieve and refresh tokens.
    public required init(
        session: URLSession = .shared,
        authClient: AuthService
    ) {
        self.authClient = authClient
        super.init(session: session)
    }
    
    @available(iOS, unavailable)
    public required init(session: URLSession = .shared) {
        fatalError("This function is not ment to be called")
    }
    
    /// Executes the request, injecting the `Authorization` header with a bearer token if available.
    /// Automatically triggers re-authentication on 401 Unauthorized responses.
    ///
    /// - Parameters:
    ///   - request: The URL request to be executed.
    ///   - completionHandler: A closure called with the response, data, and error.
    /// - Returns: A `Cancellable` reference to the in-flight task.
    @discardableResult
    public override func execute(
        request: URLRequest,
        completionHandler: ((Data?, URLResponse?, Error?) -> Void)?
    ) -> Cancellable {
        var authenticatedRequest = request
        if let token = authClient.tokenStore.accessToken {
            authenticatedRequest.setValue(token, forHTTPHeaderField: "Authorization")
        }
        return super.execute(request: authenticatedRequest, completionHandler: { [weak authClient] data, response, error in
            guard let httpResponse = response as? HTTPURLResponse else {
                completionHandler?(data, response, error)
                return
            }
            if httpResponse.statusCode == 401 {
                authClient?.requestAuthentication()
                completionHandler?(nil, nil, NetworkError.Network.unauthorized)
                return
            }
            completionHandler?(data, response, error)
        })
    }
}
