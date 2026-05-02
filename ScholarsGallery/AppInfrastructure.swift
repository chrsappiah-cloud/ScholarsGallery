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
