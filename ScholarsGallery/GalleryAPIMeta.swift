import Foundation

/// Shared API host for the iOS app (matches `GALLERY_API_BASE_URL` in Info / xcconfig).
enum GalleryAPIConfiguration {
    /// `true` when the app targets a loopback or LAN dev server (not production).
    static var isLocalDevelopment: Bool {
        guard let host = baseURL.host?.lowercased() else { return false }
        if host == "localhost" || host == "127.0.0.1" { return true }
        if host.hasPrefix("192.168.") || host.hasPrefix("10.") { return true }
        if host.hasPrefix("172.") {
            let octets = host.split(separator: ".")
            if octets.count > 1, let second = Int(octets[1]), second >= 16, second <= 31 { return true }
        }
        return false
    }

    static var baseURL: URL {
        if let override = ProcessInfo.processInfo.environment["UITEST_GALLERY_API_BASE_URL"],
           let url = URL(string: override),
           !override.isEmpty {
            return url
        }
        let configuredString: String
        if let configured = Bundle.main.object(forInfoDictionaryKey: "GALLERY_API_BASE_URL") as? String,
           !configured.isEmpty {
            configuredString = configured
        } else {
            configuredString = "http://127.0.0.1:8081"
        }
        guard let url = URL(string: configuredString) else {
            return URL(string: "http://127.0.0.1:8081")!
        }
        return rewriteLocalhostForPhysicalDevice(url)
    }

    /// On a physical device, `127.0.0.1` is the phone — use `GALLERY_API_LAN_HOST` (Mac LAN IP).
    private static func rewriteLocalhostForPhysicalDevice(_ url: URL) -> URL {
        #if targetEnvironment(simulator)
        return url
        #else
        let host = url.host?.lowercased() ?? ""
        guard host == "127.0.0.1" || host == "localhost" else { return url }
        let lanHost = ProcessInfo.processInfo.environment["GALLERY_API_LAN_HOST"]
            ?? Bundle.main.object(forInfoDictionaryKey: "GALLERY_API_LAN_HOST") as? String
            ?? Bundle.main.url(forResource: "gallery-lan-host", withExtension: "txt")
                .flatMap { try? String(contentsOf: $0, encoding: .utf8) }?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let lanHost, !lanHost.isEmpty,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.host = lanHost
        return components.url ?? url
        #endif
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
