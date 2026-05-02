import Foundation

/// Shared API host for the iOS app (matches `GALLERY_API_BASE_URL` in Info / xcconfig).
enum GalleryAPIConfiguration {
    static var baseURL: URL {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "GALLERY_API_BASE_URL") as? String,
           let url = URL(string: configured), !configured.isEmpty {
            return url
        }
        return URL(string: "http://127.0.0.1:8080")!
    }
}

/// Matches `GET /api/meta` from ScholarsGalleryServer (Vapor `APIMetaResponse`).
struct GalleryAPIMeta: Codable, Equatable, Sendable {
    let ok: Bool
    let persistence: String
    let catalog: String
    let hasOpenAI: Bool
    let version: String
    let checkoutEnabled: Bool?
    let generationEnabled: Bool?
    let announcement: String?
    let adminPanelConfigured: Bool?
    /// `true` when the server has a real Dola provider (OpenAI key) wired up.
    /// Optional for backwards compatibility with older servers.
    let dolaAssistantConfigured: Bool?
    /// Operator policy gate for the Dola Smart AI Assistant.
    let dolaAssistantEnabled: Bool?

    var effectiveCheckoutEnabled: Bool { checkoutEnabled ?? true }
    var effectiveGenerationEnabled: Bool { generationEnabled ?? true }
    var effectiveDolaAssistantEnabled: Bool { dolaAssistantEnabled ?? true }
    var effectiveDolaAssistantConfigured: Bool { dolaAssistantConfigured ?? false }
}
