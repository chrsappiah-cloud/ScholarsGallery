import Combine
import Foundation
import SwiftUI

@MainActor
final class GalleryBackendMetaModel: ObservableObject {
    @Published private(set) var meta: GalleryAPIMeta?
    @Published private(set) var lastRefreshFailed = false
    @Published private(set) var hasStudioAccess = false

    private static let cache = AppJSONCache()
    private static let cacheKey = "cache.apiMeta"

    private var paymentCancellable: AnyCancellable?

    init() {
        paymentCancellable = StoreKitPaymentService.shared.$purchasedProductIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ids in
                self?.hasStudioAccess = ids.contains(StoreKitPaymentService.ProductID.studioMonthly.rawValue)
                    || ids.contains(StoreKitPaymentService.ProductID.studioYearly.rawValue)
            }
    }

    func refresh() async {
        do {
            let m = try await Self.fetchMeta()
            meta = m
            lastRefreshFailed = false
        } catch {
            if meta == nil {
                meta = Self.cache.load(GalleryAPIMeta.self, for: Self.cacheKey)
            }
            lastRefreshFailed = true
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
}
