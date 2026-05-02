import Combine
import Foundation
import SwiftUI

@MainActor
final class GalleryBackendMetaModel: ObservableObject {
    @Published private(set) var meta: GalleryAPIMeta?
    /// `true` after a failed fetch (or decode); cleared on success.
    @Published private(set) var lastRefreshFailed = false

    func refresh() async {
        do {
            let m = try await Self.fetchMeta()
            meta = m
            lastRefreshFailed = false
        } catch {
            meta = nil
            lastRefreshFailed = true
        }
    }

    private static func fetchMeta() async throws -> GalleryAPIMeta {
        let url = GalleryAPIConfiguration.baseURL.appendingPathComponent("api/meta")
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(GalleryAPIMeta.self, from: data)
    }
}
