import Foundation

enum AppAPIError: LocalizedError, Equatable {
    case networkCached
    case networkConnect
    case decodingFailed
    case unexpected

    var errorDescription: String? {
        switch self {
        case .networkCached:
            return String(localized: "error.networkCached")
        case .networkConnect:
            return String(localized: "error.networkConnect")
        case .decodingFailed:
            return String(localized: "error.decodeFailed")
        case .unexpected:
            return String(localized: "error.unexpected")
        }
    }
}

enum AppAPIErrorMapper {
    static func map(_ error: Error) -> AppAPIError {
        if let appError = error as? AppAPIError { return appError }
        if error is DecodingError { return .decodingFailed }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                return .networkCached
            default:
                return .networkConnect
            }
        }
        return .unexpected
    }
}

struct AppJSONCache {
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save<T: Codable>(_ value: T, for key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    func load<T: Codable>(_ type: T.Type, for key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

enum AppPerformanceTuning {
    private static let targetMemoryCapacity = 64 * 1024 * 1024
    private static let targetDiskCapacity = 512 * 1024 * 1024

    static func configureCaches() {
        let shared = URLCache.shared
        guard shared.memoryCapacity < targetMemoryCapacity || shared.diskCapacity < targetDiskCapacity else {
            return
        }

        URLCache.shared = URLCache(
            memoryCapacity: max(shared.memoryCapacity, targetMemoryCapacity),
            diskCapacity: max(shared.diskCapacity, targetDiskCapacity),
            diskPath: nil
        )
    }
}

enum AppHTTPSession {
    static let shared: URLSession = {
        AppPerformanceTuning.configureCaches()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = false
        config.urlCache = URLCache.shared
        config.requestCachePolicy = .useProtocolCachePolicy
        config.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: config)
    }()
}

struct GeneratedArtworkHistoryCache {
    private let cache: AppJSONCache

    init(cache: AppJSONCache = AppJSONCache()) {
        self.cache = cache
    }

    func load(limit: Int) -> [GeneratedArtwork]? {
        cache.load([GeneratedArtwork].self, for: cacheKey(limit: limit))
    }

    func save(_ artworks: [GeneratedArtwork], limit: Int) {
        cache.save(artworks, for: cacheKey(limit: limit))
    }

    func merge(_ artwork: GeneratedArtwork, into existing: [GeneratedArtwork], limit: Int) -> [GeneratedArtwork] {
        let cappedLimit = max(1, min(100, limit))
        var seenIDs: Set<UUID> = []
        var merged: [GeneratedArtwork] = []

        for item in [artwork] + existing {
            guard seenIDs.insert(item.id).inserted else { continue }
            merged.append(item)
            if merged.count == cappedLimit {
                break
            }
        }

        return merged
    }

    private func cacheKey(limit: Int) -> String {
        "cache.generatedArtworks.\(max(1, min(100, limit)))"
    }
}

struct CollectionRecordCodec {
    static func encode(_ records: [CollectionRecord]) -> String {
        guard let data = try? JSONEncoder().encode(records),
              let raw = String(data: data, encoding: .utf8) else { return "" }
        return raw
    }

    static func decode(_ raw: String) -> [CollectionRecord] {
        guard let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([CollectionRecord].self, from: data) else { return [] }
        return decoded
    }
}
