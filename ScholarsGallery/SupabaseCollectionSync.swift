import Foundation
import os

@MainActor
final class SupabaseCollectionSync {
    static let shared = SupabaseCollectionSync()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ScholarsGallery",
        category: "SupabaseSync"
    )

    private var supabaseURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !raw.isEmpty,
              let url = URL(string: raw) else {
            return GalleryAPIConfiguration.baseURL.host == "127.0.0.1"
                ? nil
                : nil
        }
        return url
    }

    func syncCollection(records: [CollectionSyncRecord]) async {
        let baseURL = GalleryAPIConfiguration.baseURL
        var request = URLRequest(url: baseURL.appendingPathComponent("api/collection/sync"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let body = try? JSONEncoder().encode(CollectionSyncPayload(records: records)) else {
            logger.warning("Failed to encode collection sync payload")
            return
        }
        request.httpBody = body

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                logger.warning("Collection sync returned non-2xx")
                return
            }
            logger.info("Synced \(records.count) collection records to server")
        } catch {
            logger.warning("Collection sync failed: \(error.localizedDescription)")
        }
    }

    func syncFavorites(artworkIDs: [String]) async {
        let baseURL = GalleryAPIConfiguration.baseURL
        var request = URLRequest(url: baseURL.appendingPathComponent("api/collection/favorites"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let body = try? JSONEncoder().encode(FavoritesSyncPayload(artworkIDs: artworkIDs)) else {
            return
        }
        request.httpBody = body

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return
            }
            logger.info("Synced \(artworkIDs.count) favorites to server")
        } catch {
            logger.warning("Favorites sync failed: \(error.localizedDescription)")
        }
    }

    func fetchRemoteCollection() async -> [CollectionSyncRecord] {
        let baseURL = GalleryAPIConfiguration.baseURL
        let url = baseURL.appendingPathComponent("api/collection")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return []
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return (try? decoder.decode([CollectionSyncRecord].self, from: data)) ?? []
        } catch {
            logger.warning("Fetch remote collection failed: \(error.localizedDescription)")
            return []
        }
    }

    func fetchRemoteFavorites() async -> Set<String> {
        let baseURL = GalleryAPIConfiguration.baseURL
        let url = baseURL.appendingPathComponent("api/collection/favorites")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return []
            }
            let decoded = try JSONDecoder().decode([String].self, from: data)
            return Set(decoded)
        } catch {
            logger.warning("Fetch remote favorites failed: \(error.localizedDescription)")
            return []
        }
    }
}

struct CollectionSyncRecord: Codable, Identifiable, Sendable {
    let id: String
    let artworkID: String
    let acquiredAt: Date
    let certificateID: String
}

private struct CollectionSyncPayload: Codable, Sendable {
    let records: [CollectionSyncRecord]
}

private struct FavoritesSyncPayload: Codable, Sendable {
    let artworkIDs: [String]
}
