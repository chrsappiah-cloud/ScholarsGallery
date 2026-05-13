import Foundation
import Vapor

struct GeneratedArtworkRecord: Content {
    let id: UUID
    let status: String
    let imageURL: String
    let prompt: String
    let provider: String
    let createdAt: Date
}

enum GeneratedArtworkPersistenceKind: String, Sendable {
    case file
    case supabase
}

private struct GeneratedArtworkStoreStorageKey: StorageKey {
    typealias Value = GeneratedArtworkStore
}

private struct GeneratedArtworkPersistenceKindStorageKey: StorageKey {
    typealias Value = GeneratedArtworkPersistenceKind
}

extension Application {
    var generatedArtworkStore: GeneratedArtworkStore? {
        get { storage[GeneratedArtworkStoreStorageKey.self] }
        set { storage[GeneratedArtworkStoreStorageKey.self] = newValue }
    }

    var generatedArtworkPersistenceKind: GeneratedArtworkPersistenceKind? {
        get { storage[GeneratedArtworkPersistenceKindStorageKey.self] }
        set { storage[GeneratedArtworkPersistenceKindStorageKey.self] = newValue }
    }
}

/// Persists generation history to a local JSON file or to Supabase Postgres via PostgREST (service role).
actor GeneratedArtworkStore {
    private enum Backend {
        case file(URL, [GeneratedArtworkRecord])
        case supabase(projectURL: URL, serviceRoleKey: String)
    }

    private var backend: Backend

    init(fileURL: URL) {
        let decoder = JSONCoding.makeDecoder()
        let records: [GeneratedArtworkRecord]
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode([GeneratedArtworkRecord].self, from: data) {
            records = Self.normalizedRecords(from: decoded)
        } else {
            records = []
        }
        backend = .file(fileURL, records)
    }

    init(supabaseProjectURL: URL, serviceRoleKey: String) {
        backend = .supabase(projectURL: supabaseProjectURL, serviceRoleKey: serviceRoleKey)
    }

    func append(_ record: GeneratedArtworkRecord) async throws {
        switch backend {
        case .file(let url, var records):
            records = Self.normalizedRecords(from: [record] + records)
            backend = .file(url, records)
            persistFileIfNeeded()
        case .supabase(let projectURL, let key):
            try await Self.insertSupabaseRow(record, projectURL: projectURL, serviceRoleKey: key)
        }
    }

    func list(limit: Int) async throws -> [GeneratedArtworkRecord] {
        let capped = max(1, min(100, limit))
        switch backend {
        case .file(_, let records):
            return Array(records.prefix(capped))
        case .supabase(let projectURL, let key):
            return try await Self.fetchSupabaseRows(limit: capped, projectURL: projectURL, serviceRoleKey: key)
        }
    }

    private func persistFileIfNeeded() {
        guard case .file(let url, let records) = backend else { return }
        let folder = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONCoding.makeEncoder()
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func normalizedRecords(from records: [GeneratedArtworkRecord]) -> [GeneratedArtworkRecord] {
        var uniqueRecords: [UUID: GeneratedArtworkRecord] = [:]
        for record in records {
            if uniqueRecords[record.id] == nil {
                uniqueRecords[record.id] = record
            }
        }
        return uniqueRecords.values
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.id.uuidString > rhs.id.uuidString
                }
                return lhs.createdAt > rhs.createdAt
            }
            .prefix(200)
            .map { $0 }
    }

    private static func restTableURL(projectURL: URL) -> URL {
        let base = projectURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + "/rest/v1/generated_artworks") else {
            preconditionFailure("Invalid Supabase project URL for REST: \(projectURL.absoluteString)")
        }
        return url
    }

    private static func insertSupabaseRow(
        _ record: GeneratedArtworkRecord,
        projectURL: URL,
        serviceRoleKey: String
    ) async throws {
        let url = restTableURL(projectURL: projectURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(serviceRoleKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(serviceRoleKey)", forHTTPHeaderField: "Authorization")
        request.addValue("return=minimal", forHTTPHeaderField: "Prefer")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try encoder.encode(record)
        request.httpBody = body

        _ = try await ServerHTTPClient.perform(request, failurePrefix: "Supabase insert")
    }

    private static func fetchSupabaseRows(
        limit: Int,
        projectURL: URL,
        serviceRoleKey: String
    ) async throws -> [GeneratedArtworkRecord] {
        var components = URLComponents(url: restTableURL(projectURL: projectURL), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: "\(limit)"),
        ]
        guard let url = components.url else {
            throw Abort(.badGateway, reason: "Supabase list: bad URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(serviceRoleKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(serviceRoleKey)", forHTTPHeaderField: "Authorization")

        let data = try await ServerHTTPClient.perform(request, failurePrefix: "Supabase list")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([GeneratedArtworkRecord].self, from: data)
    }
}
