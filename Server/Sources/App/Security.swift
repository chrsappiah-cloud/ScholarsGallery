import Foundation
import NIOCore
import Vapor

private struct GenerationAuthTokenStorageKey: StorageKey {
    typealias Value = String
}

private struct GenerationRateLimiterStorageKey: StorageKey {
    typealias Value = GenerationRateLimiter
}

extension Application {
    var generationAuthToken: String? {
        get { storage[GenerationAuthTokenStorageKey.self] }
        set { storage[GenerationAuthTokenStorageKey.self] = newValue }
    }

    var generationRateLimiter: GenerationRateLimiter? {
        get { storage[GenerationRateLimiterStorageKey.self] }
        set { storage[GenerationRateLimiterStorageKey.self] = newValue }
    }
}

actor GenerationRateLimiter {
    private var requestTimesByClient: [String: [Date]] = [:]
    private let maxRequests: Int
    private let interval: TimeInterval

    init(maxRequests: Int, intervalSeconds: TimeInterval) {
        self.maxRequests = maxRequests
        self.interval = intervalSeconds
    }

    func allow(clientKey: String, now: Date = Date()) -> Bool {
        let cutoff = now.addingTimeInterval(-interval)
        var times = requestTimesByClient[clientKey, default: []].filter { $0 >= cutoff }
        guard times.count < maxRequests else {
            requestTimesByClient[clientKey] = times
            return false
        }
        times.append(now)
        requestTimesByClient[clientKey] = times
        return true
    }
}

private func clientKey(for request: Request) -> String {
    if let forwarded = request.headers.first(name: .xForwardedFor)?.split(separator: ",").first {
        return String(forwarded).trimmingCharacters(in: .whitespaces)
    }
    if let ip = request.remoteAddress?.ipAddress {
        return ip
    }
    return "unknown"
}

struct GenerationSecurityMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        if let expectedToken = request.application.generationAuthToken {
            let receivedToken = request.headers.first(name: "X-Generation-Token")
            guard receivedToken == expectedToken else {
                throw Abort(.unauthorized, reason: "Missing or invalid generation token.")
            }
        }

        // Only throttle POST /generate; GET /generated is read-heavy and shares the same route group.
        if request.method == .POST, let limiter = request.application.generationRateLimiter {
            let key = clientKey(for: request)
            let isAllowed = await limiter.allow(clientKey: key)
            guard isAllowed else {
                throw Abort(.tooManyRequests, reason: "Rate limit exceeded for generation.")
            }
        }

        return try await next.respond(to: request)
    }
}
