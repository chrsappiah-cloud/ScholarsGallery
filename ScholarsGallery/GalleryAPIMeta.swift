import Foundation

/// Shared API host for the iOS app (matches `GALLERY_API_BASE_URL` in Info / xcconfig).
enum GalleryAPIConfiguration {
    private static let fallbackBaseURL = URL(string: "http://127.0.0.1:8081")!
    private static let productionBaseURL = URL(string: "https://api.scholarsgallery.app")!

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

    static var isProductionConfigured: Bool {
        baseURL.host?.lowercased() == productionBaseURL.host?.lowercased()
    }

    static var hostDisplayName: String {
        baseURL.host ?? baseURL.absoluteString
    }

    static var baseURL: URL {
        if let override = runtimeOverrideString,
           let url = normalizedAbsoluteURL(from: override) {
            return rewriteLocalhostForPhysicalDevice(url)
        }
        if let configured = Bundle.main.object(forInfoDictionaryKey: "GALLERY_API_BASE_URL") as? String,
           let url = normalizedAbsoluteURL(from: configured) {
            return rewriteLocalhostForPhysicalDevice(url)
        }
        return rewriteLocalhostForPhysicalDevice(fallbackBaseURL)
    }

    static func remoteAssetURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let absolute = normalizedAbsoluteURL(from: trimmed) {
            return absolute
        }
        if trimmed.hasPrefix("/") {
            return URL(string: trimmed, relativeTo: baseURL)?.absoluteURL
        }
        return baseURL.appendingPathComponent(trimmed).absoluteURL
    }

    private static var runtimeOverrideString: String? {
        for key in ["UITEST_GALLERY_API_BASE_URL", "GALLERY_API_BASE_URL_OVERRIDE"] {
            if let raw = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !raw.isEmpty {
                return raw
            }
        }

        if let raw = Bundle.main.url(forResource: "gallery-api-base-url", withExtension: "txt")
            .flatMap({ try? String(contentsOf: $0, encoding: .utf8) })?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty {
            return raw
        }

        return nil
    }

    private static func normalizedAbsoluteURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let components = URLComponents(string: trimmed),
           components.scheme != nil,
           components.host != nil,
           let url = components.url {
            return url
        }
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
              let components = URLComponents(string: encoded),
              components.scheme != nil,
              components.host != nil else {
            return nil
        }
        return components.url
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
