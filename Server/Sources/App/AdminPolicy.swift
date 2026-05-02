import Foundation
import Vapor

/// Operator-editable flags persisted on the server (JSON file). Used for public routes + admin API.
struct AdminPolicySnapshot: Content, Codable, Equatable, Sendable {
    var checkoutEnabled: Bool
    var generationEnabled: Bool
    var announcement: String?
    /// Toggle for the **Dola** Smart AI Assistant route (`POST /api/dola/assist`).
    /// Defaults to `true` for backward compatibility when the field is absent.
    var dolaAssistantEnabled: Bool?

    var effectiveDolaAssistantEnabled: Bool { dolaAssistantEnabled ?? true }

    static let `default` = AdminPolicySnapshot(
        checkoutEnabled: true,
        generationEnabled: true,
        announcement: nil,
        dolaAssistantEnabled: true
    )
}

struct AdminOverviewDTO: Content {
    var policy: AdminPolicySnapshot
    var generationTokenConfigured: Bool
    var openAIConfigured: Bool
    var catalogPersistence: String
    var generationPersistence: String
    /// `true` if Dola has a usable provider configured on the server (OpenAI key present);
    /// the mock fallback never reports as `true` here so operators can see real wiring.
    var dolaAssistantConfigured: Bool
    /// Provider label that Dola will return in `/api/dola/assist` responses (`openai` / `mock`).
    var dolaAssistantProvider: String
}

private struct AdminPolicyStoreStorageKey: StorageKey {
    typealias Value = AdminPolicyStore
}

private struct AdminAPITokenStorageKey: StorageKey {
    typealias Value = String
}

extension Application {
    var adminPolicyStore: AdminPolicyStore? {
        get { storage[AdminPolicyStoreStorageKey.self] }
        set { storage[AdminPolicyStoreStorageKey.self] = newValue }
    }

    /// When set, `X-Admin-Token` must match for `/api/admin/*` routes.
    var adminAPIToken: String? {
        get { storage[AdminAPITokenStorageKey.self] }
        set { storage[AdminAPITokenStorageKey.self] = newValue }
    }

    var adminPanelConfigured: Bool {
        adminAPIToken != nil && !(adminAPIToken ?? "").isEmpty
    }
}

actor AdminPolicyStore {
    private var snapshot: AdminPolicySnapshot
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
        let decoder = JSONCoding.makeDecoder()
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode(AdminPolicySnapshot.self, from: data) {
            snapshot = decoded
        } else {
            snapshot = .default
        }
    }

    func current() -> AdminPolicySnapshot {
        snapshot
    }

    func replace(with newSnapshot: AdminPolicySnapshot) {
        snapshot = newSnapshot
        persist()
    }

    private func persist() {
        let folder = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONCoding.makeEncoder()
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

struct AdminSecurityMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let expected = request.application.adminAPIToken, !expected.isEmpty else {
            throw Abort(
                .serviceUnavailable,
                reason: "Admin API is not configured (set ADMIN_API_TOKEN on the server)."
            )
        }
        let received = request.headers.first(name: "X-Admin-Token")
        guard received == expected else {
            throw Abort(.unauthorized, reason: "Missing or invalid admin token.")
        }
        return try await next.respond(to: request)
    }
}
