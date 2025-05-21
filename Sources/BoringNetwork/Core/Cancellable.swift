//
//  Cancellable.swift
//  BoringNetwork
//
//  Created by Duc Nguyen on 2025/05/20.
//
//  Description:
//  Defines the `Cancellable` protocol, which standardizes cancellation support
//  for asynchronous tasks like network operations. This abstraction allows
//  task management and lifecycle control across different session clients.
//

import Foundation

/// A protocol that represents a cancellable operation, typically associated
/// with asynchronous or long-running tasks such as HTTP requests or timers.
public protocol Cancellable: AnyObject {
    /// Cancels the ongoing operation, if possible.
    func cancel()
    
    /// Indicates whether the operation is in a state where cancellation is allowed.
    var isCancellable: Bool { get }
}

extension URLSessionTask: Cancellable {
    /// Indicates whether the URL session task is currently running and can be cancelled.
    public var isCancellable: Bool { state == .running }
}
