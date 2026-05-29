import Combine
import Foundation
import SwiftUI

@MainActor
final class GalleryBackendMetaModel: ObservableObject {
    @Published private(set) var meta: GalleryAPIMeta?
    @Published private(set) var lastRefreshFailed = false
    @Published private(set) var connectionSummary: String?

    private static let cache = AppJSONCache()
    private static let cacheKey = "cache.apiMeta"

    func refresh() async {
        do {
            let m = try await Self.fetchMeta()
            meta = m
            lastRefreshFailed = false
            connectionSummary = Self.makeConnectionSummary(meta: m, lastRefreshFailed: false)
        } catch {
            if meta == nil {
                meta = Self.cache.load(GalleryAPIMeta.self, for: Self.cacheKey)
            }
            lastRefreshFailed = true
            connectionSummary = Self.makeConnectionSummary(meta: meta, lastRefreshFailed: true)
        }
    }

    private static func fetchMeta() async throws -> GalleryAPIMeta {
        let url = GalleryAPIConfiguration.baseURL.appendingPathComponent("api/meta")
        do {
            let (data, response) = try await AppHTTPSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let decoded = try JSONDecoder().decode(GalleryAPIMeta.self, from: data)
            cache.save(decoded, for: cacheKey)
            return decoded
        } catch {
            if let cached = cache.load(GalleryAPIMeta.self, for: cacheKey) {
                return cached
            }
            throw error
        }
    }

    static func makeConnectionSummary(meta: GalleryAPIMeta?, lastRefreshFailed: Bool) -> String? {
        let host = GalleryAPIConfiguration.hostDisplayName

        if lastRefreshFailed {
            if GalleryAPIConfiguration.isProductionConfigured {
                return "Live backend unavailable. Showing cached content while \(host) is unreachable."
            }
            if GalleryAPIConfiguration.isLocalDevelopment {
                return "Local backend unavailable. Showing cached content while \(host) is unreachable."
            }
            return "Backend unavailable. Showing cached content while \(host) is unreachable."
        }

        guard let meta else {
            return GalleryAPIConfiguration.isLocalDevelopment ? "Local backend active: \(host)" : nil
        }

        let prefix: String
        if GalleryAPIConfiguration.isProductionConfigured {
            prefix = "Live backend active"
        } else if GalleryAPIConfiguration.isLocalDevelopment {
            prefix = "Local backend active"
        } else {
            prefix = "Backend active"
        }

        return "\(prefix): \(host) • \(meta.catalog.capitalized) catalog • \(meta.persistence.capitalized) persistence"
    }
}
