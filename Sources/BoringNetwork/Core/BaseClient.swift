//
//  BaseClient.swift
//  BoringNetwork
//
//  Created by Duc Nguyen on 2025/05/20.
//
//  Description:
//  Provides a base HTTP client abstraction for constructing typed requests,
//  handling URL encoding, query generation, JSON encoding, and header injection.
//  Designed for subclassing and customization.
//

import Foundation

/// A reusable HTTP client for constructing and executing RESTful requests.
/// Provides support for typed parameters, dynamic headers, and encoding strategies.
open class BaseClient: NSObject {
    /// HTTP methods supported by the client.
    public enum HTTPMethod: String, Codable {
        case get, delete, trace, options, head, post, put, patch
        
        /// Returns the uppercase string value used in `URLRequest.httpMethod`.
        public var value: String { rawValue.uppercased() }
    }
    
    /// The base URL for all requests constructed by this client.
    public let baseUrl: URL
    
    /// Determines the JSON key encoding strategy.
    public let keyCodingStrategy: BaseKeyCodingStrategy = .useDefaultKeys
    
    /// The backing session for executing requests.
    weak var _session: BoringSessioning?
    
    /// The active session, or triggers a fatal error if not set.
    public var session: BoringSessioning {
        guard let _session else {
            fatalError("\(String(describing: self))'s session not configured")
        }
        return _session
    }
    
    /// Additional headers that are applied to every request.
    open var additionalHeaders: [String: String] = [:]
    
    /// Initializes the client with a base URL.
    ///
    /// - Parameter baseUrl: The root URL for all requests.
    public init(baseUrl: URL) {
        self.baseUrl = baseUrl
        super.init()
        self.customConfiguration()
    }
    
    /// Override to customize the client after initialization.
    open func customConfiguration() { }
    
    /// Appends headers to the request.
    ///
    /// - Parameters:
    ///   - request: The request to modify.
    ///   - additionalHeaders: The headers to add.
    fileprivate func attachHeader(_ request: inout URLRequest, _ additionalHeaders: [String: String]?) throws {
        additionalHeaders?.forEach {
            request.addValue($1, forHTTPHeaderField: $0)
        }
    }
    
    /// Constructs a full request using an absolute URL string.
    ///
    /// - Parameters:
    ///   - url: Full URL as a string.
    ///   - method: HTTP method to use.
    ///   - parameters: Encodable body or query parameters.
    ///   - additionalHeaders: Optional headers to merge.
    /// - Returns: A configured URLRequest if successful.
    public func constructRequest<Parameters: Encodable>(
        using url: String,
        method: HTTPMethod,
        parameters: Parameters? = nil,
        additionalHeaders: [String: String]? = nil
    ) throws -> URLRequest? {
        guard let url = URL(string: url) else {
            throw NetworkError.Internal.inconsistent.with(detail: "Base URL or Owner not found")
        }
        let components = NSURLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let componentUrl = components?.url else { return nil }
        
        var request = URLRequest(url: componentUrl)
        try attachHeader(&request, self.additionalHeaders.merged(with: additionalHeaders ?? [:], using: .target))
        request.httpMethod = method.value
        
        let jsonEncoder = JSONEncoder().with(strategy: keyCodingStrategy)
        guard let parameters, let data = try? jsonEncoder.encode(parameters) else {
            return request
        }
        
        if [.get, .delete, .trace, .head, .options].contains(method) {
            guard let params = try? JSONSerialization.jsonObject(with: data) as? [String: Any?], params.count > 0 else {
                return request
            }
            components?.queryItems = params.compactMap {
                guard let value = $0.value else { return nil }
                return URLQueryItem(name: $0.key, value: "\(value)")
            } + (components?.queryItems ?? [])
            
            guard let url = components?.url?.absoluteString,
                  let componentUrl = URL(string: url) else { return request }
            request = URLRequest(url: componentUrl)
            try attachHeader(&request, additionalHeaders)
        } else {
            request.httpBody = data
        }
        
        return request
    }
    
    /// Constructs a full request using a relative path from `baseUrl`.
    ///
    /// - Parameters:
    ///   - path: Relative path to append to `baseUrl`.
    ///   - method: HTTP method to use.
    ///   - parameters: Encodable body or query parameters.
    ///   - additionalHeaders: Optional headers to merge.
    /// - Returns: A configured URLRequest if successful.
    public func constructRequest<Parameters: Encodable>(
        with path: String,
        method: HTTPMethod,
        parameters: Parameters? = nil,
        additionalHeaders: [String: String]? = nil
    ) throws -> URLRequest? {
        var url = baseUrl
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) {
            if !path.isEmpty { url = url.appending(path: path) }
        } else {
            if !path.isEmpty { url = url.appendingPathComponent(path) }
        }
        let components = NSURLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let componentUrl = components?.url else { return nil }
        
        var request = URLRequest(url: componentUrl)
        try attachHeader(&request, self.additionalHeaders.merged(with: additionalHeaders ?? [:], using: .target))
        request.httpMethod = method.value
        
        let jsonEncoder = JSONEncoder().with(strategy: keyCodingStrategy)
        guard let parameters, let data = try? jsonEncoder.encode(parameters) else {
            return request
        }
        
        if [.get, .delete, .trace, .head, .options].contains(method) {
            guard let params = try? JSONSerialization.jsonObject(with: data) as? [String: Any?], params.count > 0 else {
                return request
            }
            components?.queryItems = params.compactMap {
                guard let value = $0.value else { return nil }
                return URLQueryItem(name: $0.key, value: "\(value)")
            } + (components?.queryItems ?? [])
            
            guard let url = components?.url?.absoluteString,
                  let componentUrl = URL(string: url) else { return request }
            request = URLRequest(url: componentUrl)
            try attachHeader(&request, additionalHeaders)
        } else {
            request.httpBody = data
        }
        
        return request
    }
    
    /// Constructs a request using an `Endpoint` definition.
    ///
    /// - Parameter endpoint: The endpoint describing the API request.
    /// - Returns: A configured URLRequest if successful.
    public func constructRequest<Parameter: Encodable>(
        with endpoint: any Endpoint<Parameter>
    ) throws -> URLRequest? {
        var request = try constructRequest(
            with: endpoint.path,
            method: endpoint.method,
            parameters: endpoint.request,
            additionalHeaders: endpoint.headers
        )
        if let timeoutInterval = endpoint.timeoutInterval {
            request?.timeoutInterval = timeoutInterval
        }
        return request
    }
}
