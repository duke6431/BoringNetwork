//
//  RetryInterceptor.swift
//  BoringNetwork
//
//  Created by Duc Nguyen on 24/5/25.
//

import Foundation

final class RetryInterceptor: Interceptor {
    private let maxRetryCount: Int
    private let retryDelay: TimeInterval
    private var retryCounts: [UUID: Int] = [:]
    private let queue = DispatchQueue(label: "RetryInterceptor.Queue")
    
    init(maxRetryCount: Int = 3, retryDelay: TimeInterval = 1.0) {
        self.maxRetryCount = maxRetryCount
        self.retryDelay = retryDelay
    }
    
    func intercept(_ result: (Data?, URLResponse?, Error?), completion: @escaping ((Data?, URLResponse?, Error?)) -> Void) {
        guard let error = result.2 as? URLError else {
            completion(result)
            return
        }
        
        // Use a UUID from userInfo or fallback to retry once
        let id = (error.userInfo["request-id"] as? UUID) ?? UUID()
        queue.sync {
            let currentRetry = retryCounts[id] ?? 0
            if currentRetry < maxRetryCount {
                retryCounts[id] = currentRetry + 1
                DispatchQueue.global().asyncAfter(deadline: .now() + retryDelay) {
                    completion((nil, nil, error))
                }
            } else {
                retryCounts.removeValue(forKey: id)
                completion(result)
            }
        }
    }
}
