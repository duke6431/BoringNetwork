//
//  NetworkError.swift
//  BoringNetwork
//
//  Created by Duc Nguyen on 2025/05/20.
//
//  Description:
//  Defines a flexible, diagnostic-rich error system used in the BoringNetwork
//  framework. Supports invalid input, internal consistency issues, and
//  network-layer errors with optional context such as HTTP details.
//

import Foundation

/// Base protocol that all custom BoringNetwork errors conform to.
public protocol BaseError: AnyObject, Error, Equatable {
    /// Identifier used to distinguish specific error cases.
    var id: Int8 { get set }
    
    /// The underlying error, if one caused this error.
    var underlyingError: Error? { get set }
    
    /// A human-readable detail string for debugging or UI display.
    var detail: String? { get set }
}

public extension BaseError {
    /// Returns a copy of the current error with the detail set.
    func with(detail: String?) -> Self {
        self.detail = detail
        return self
    }
    
    /// Returns a copy of the current error with an underlying error attached.
    func with(underlying error: Error?) -> Self {
        self.underlyingError = error
        return self
    }
}

/// Base implementation of `BaseError` to support inheritance.
public class BaseErrorImpl: BaseError {
    public var id: Int8
    public var underlyingError: Error?
    public var detail: String?
    
    /// Initializes an error with a given identifier.
    ///
    /// - Parameter id: Numeric identifier for the error case.
    init(id: Int8) { self.id = id }
    
    public static func == (lhs: BaseErrorImpl, rhs: BaseErrorImpl) -> Bool {
        lhs.id == rhs.id
    }
}

/// Contains typed categories of network-related error types used throughout the framework.
public enum NetworkError {
    /// Alias for a handler closure that maps HTTP response and data into an error.
    public typealias NetHandler = ((HTTPURLResponse, Data?) -> Error)
    
    /// Error cases related to invalid request or response data.
    public class Invalid: BaseErrorImpl {
        public static let url = Invalid(id: 1)
        public static let request = Invalid(id: 2)
        public static let response = Invalid(id: 3)
        public static let data = Invalid(id: 4)
    }
    
    /// Internal error types used to represent framework-level issues.
    public class Internal: BaseErrorImpl {
        public static let notImplemented = Internal(id: 1)
        public static let inconsistent = Internal(id: 2)
    }
    
    /// Runtime network-related errors such as unreachable hosts or auth failures.
    public class Network: BaseErrorImpl {
        public static let networkLost = Network(id: 1)
        public static let unauthorized = Network(id: 2)
        
        /// Factory method to create a contextual network failure error.
        ///
        /// - Parameters:
        ///   - request: The originating request.
        ///   - response: The received response, if any.
        ///   - data: The body data returned with the response, if any.
        ///   - underlying: Any lower-level error that caused this one.
        ///   - comment: Optional custom message to include in diagnostics.
        /// - Returns: A fully described `Network` error.
        public static func failure(
            request: URLRequest,
            response: URLResponse?,
            data: Data?,
            underlying: Error?,
            comment: String? = nil
        ) -> Network {
            let error = Network(id: -1)
            error.underlyingError = underlying
            
            var detail = "[NetworkError] Request failed\n"
            detail += "→ URL: \(request.url?.absoluteString ?? "nil")\n"
            detail += "→ Method: \(request.httpMethod ?? "nil")\n"
            
            if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
                detail += "→ Headers:\n"
                for (key, value) in headers {
                    detail += "   • \(key): \(value)\n"
                }
            }
            
            if let body = request.httpBody {
                if let bodyString = String(data: body, encoding: .utf8) {
                    detail += "→ Body: \(bodyString)\n"
                } else {
                    detail += "→ Body (base64): \(body.base64EncodedString())\n"
                }
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                detail += "→ Status Code: \(httpResponse.statusCode)\n"
                if !httpResponse.allHeaderFields.isEmpty {
                    detail += "→ Response Headers:\n"
                    for (key, value) in httpResponse.allHeaderFields {
                        detail += "   • \(key): \(value)\n"
                    }
                }
            } else if let response = response {
                detail += "→ Response: \(response)\n"
            }
            
            if let data = data {
                if let text = String(data: data, encoding: .utf8) {
                    detail += "→ Response Body: \(text)\n"
                } else {
                    detail += "→ Response Body (base64): \(data.base64EncodedString())\n"
                }
            }
            
            if let comment = comment {
                detail += "→ Comment: \(comment)\n"
            }
            
            error.detail = detail
            return error
        }
    }
}

extension NetworkError.Invalid: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .url:
            return "NetworkError - Invalid URL - \(detail ?? "Empty")"
        case .request:
            return "NetworkError - Invalid request - \(detail ?? "Empty")"
        case .response:
            return "NetworkError - Invalid response - \(detail ?? "Empty")"
        case .data:
            return "NetworkError - Invalid data - \(detail ?? "Empty")"
        default:
            return "NetworkError - Invalid error id \(id) - \(detail ?? "Empty")"
        }
    }
}

extension NetworkError.Internal: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "NetworkError - Not implemented - \(detail ?? "Empty")"
        case .inconsistent:
            return "NetworkError - Internal Inconsistent - \(detail ?? "Empty")"
        default:
            return "NetworkError - Internal error id \(id) - \(detail ?? "Empty")"
        }
    }
}

extension NetworkError.Network: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .networkLost:
            return "NetworkError - Network lost - \(detail ?? "Empty")"
        case .unauthorized:
            return "NetworkError - Unauthorized - \(detail ?? "Empty")"
        default:
            return "NetworkError - Network error id \(id) - \(detail ?? "Empty")"
        }
    }
}
