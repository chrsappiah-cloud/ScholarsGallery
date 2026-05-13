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
    private let maxTrackedClients = 512

    init(maxRequests: Int, intervalSeconds: TimeInterval) {
        self.maxRequests = maxRequests
        self.interval = intervalSeconds
    }

    func allow(clientKey: String, now: Date = Date()) -> Bool {
        let cutoff = now.addingTimeInterval(-interval)
        var times = requestTimesByClient[clientKey, default: []].filter { $0 >= cutoff }
        pruneIfNeeded(cutoff: cutoff)
        guard times.count < maxRequests else {
            requestTimesByClient[clientKey] = times
            return false
        }
        times.append(now)
        requestTimesByClient[clientKey] = times
        return true
    }

    private func pruneIfNeeded(cutoff: Date) {
        guard requestTimesByClient.count > maxTrackedClients else { return }
        requestTimesByClient = requestTimesByClient.reduce(into: [:]) { partialResult, entry in
            let retained = entry.value.filter { $0 >= cutoff }
            if !retained.isEmpty {
                partialResult[entry.key] = retained
            }
        }
    }
}

private func clientKey(for request: Request) -> String {
    if let forwarded = request.headers.first(name: .xForwardedFor)?
        .split(separator: ",")
        .map({ String($0).trimmingCharacters(in: .whitespacesAndNewlines) })
        .first(where: { !$0.isEmpty }) {
        return forwarded
    }
    if let ip = request.remoteAddress?.ipAddress {
        return ip
    }
    return "unknown"
}

private func normalizedToken(_ token: String?) -> String? {
    guard let trimmed = token?.trimmingCharacters(in: .whitespacesAndNewlines),
          !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}

private func secureCompare(_ lhs: String, _ rhs: String) -> Bool {
    let left = Array(lhs.utf8)
    let right = Array(rhs.utf8)
    guard left.count == right.count else { return false }
    var difference = 0
    for index in left.indices {
        difference |= Int(left[index] ^ right[index])
    }
    return difference == 0
}

struct GenerationSecurityMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        if let expectedToken = normalizedToken(request.application.generationAuthToken) {
            let receivedToken = normalizedToken(request.headers.first(name: "X-Generation-Token"))
            guard let receivedToken, secureCompare(receivedToken, expectedToken) else {
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
