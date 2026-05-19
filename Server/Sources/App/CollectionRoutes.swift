import Foundation
import Vapor

struct CollectionRecordDTO: Content {
    let id: String
    let artworkID: String
    let acquiredAt: Date
    let certificateID: String
}

struct CollectionSyncInput: Content {
    let records: [CollectionRecordDTO]
}

struct FavoritesSyncInput: Content {
    let artworkIDs: [String]
}

struct UploadResponseDTO: Content {
    let imageURL: String
    let artworkId: String
}

enum CollectionPersistenceKind: String, Sendable {
    case file
    case supabase
}

func registerCollectionRoutes(_ app: Application) throws {
    let collection = app.grouped("api", "collection")

    collection.get { req async throws -> [CollectionRecordDTO] in
        guard let store = req.application.collectionStore else {
            return []
        }
        return try await store.all()
    }

    collection.get("favorites") { req async throws -> [String] in
        guard let store = req.application.collectionStore else {
            return []
        }
        return try await store.allFavorites()
    }

    collection.post("sync") { req async throws -> HTTPStatus in
        let input = try req.content.decode(CollectionSyncInput.self)
        guard let store = req.application.collectionStore else {
            throw Abort(.serviceUnavailable, reason: "Collection store not configured.")
        }
        try await store.merge(input.records)
        return .ok
    }

    collection.post("favorites") { req async throws -> HTTPStatus in
        let input = try req.content.decode(FavoritesSyncInput.self)
        guard let store = req.application.collectionStore else {
            throw Abort(.serviceUnavailable, reason: "Collection store not configured.")
        }
        try await store.syncFavorites(input.artworkIDs)
        return .ok
    }

    collection.on(.POST, "upload", body: .collect(maxSize: "20mb")) { req async throws -> UploadResponseDTO in
        guard let contentType = req.headers.contentType, contentType.type == "multipart" else {
            throw Abort(.badRequest, reason: "Expected multipart/form-data.")
        }

        let boundary = contentType.parameters["boundary"] ?? ""
        guard !boundary.isEmpty else {
            throw Abort(.badRequest, reason: "Missing multipart boundary.")
        }

        var artworkId: String?
        var imageData: Data?
        var filename: String = "\(UUID().uuidString).jpg"

        let body = req.body.data ?? ByteBuffer()
        let bodyData = Data(buffer: body)

        let parts = parseMultipart(data: bodyData, boundary: boundary)
        for part in parts {
            if part.name == "artworkId" {
                artworkId = String(data: part.data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if part.name == "image" {
                imageData = part.data
                if let fn = part.filename, !fn.isEmpty {
                    filename = fn
                }
            }
        }

        guard let rawArtworkId = artworkId,
              let artworkId = normalizedArtworkID(rawArtworkId),
              let imageData,
              !imageData.isEmpty else {
            throw Abort(.badRequest, reason: "Missing artworkId or image data.")
        }

        guard let imageFormat = detectedImageFormat(for: imageData) else {
            throw Abort(.unsupportedMediaType, reason: "Unsupported image payload.")
        }

        let uploadsDir = URL(fileURLWithPath: ServerPaths.publicDirectory)
            .appendingPathComponent("uploads", isDirectory: true)
        try FileManager.default.createDirectory(at: uploadsDir, withIntermediateDirectories: true)

        let sanitizedFilename = sanitizeUploadFilename(filename)
        let filenameStem = (sanitizedFilename as NSString).deletingPathExtension
        let finalStem = filenameStem.isEmpty ? "upload" : filenameStem
        let savedFilename = "\(artworkId)_\(finalStem)_\(UUID().uuidString).\(imageFormat.fileExtension)"
        let savedURL = uploadsDir.appendingPathComponent(savedFilename)
        try imageData.write(to: savedURL, options: .atomic)

        let publicPath = uploadPublicBaseURL(for: req)
            .appendingPathComponent("uploads/\(savedFilename)")
            .absoluteString
        req.logger.info("Saved uploaded image", metadata: [
            "artworkId": "\(artworkId)",
            "path": "\(publicPath)",
            "size": "\(imageData.count)"
        ])

        return UploadResponseDTO(imageURL: publicPath, artworkId: artworkId)
    }

    app.post("api", "payment", "validate") { req async throws -> PaymentValidationResponse in
        struct PaymentValidationInput: Content {
            let receiptData: String?
            let transactionId: String?
            let productId: String
        }

        let input = try req.content.decode(PaymentValidationInput.self)
        req.logger.info("Payment validation request", metadata: [
            "productId": "\(input.productId)",
            "hasReceipt": "\(input.receiptData != nil)",
            "hasTransactionId": "\(input.transactionId != nil)"
        ])

        return PaymentValidationResponse(
            valid: true,
            productId: input.productId,
            expiresAt: Date().addingTimeInterval(30 * 24 * 60 * 60)
        )
    }
}

struct PaymentValidationResponse: Content {
    let valid: Bool
    let productId: String
    let expiresAt: Date?
}

// MARK: - Collection Store

actor CollectionStoreActor {
    private enum Backend {
        case file(URL, [CollectionRecordDTO], Set<String>)
        case supabase(projectURL: URL, serviceRoleKey: String)
    }

    private var backend: Backend

    init(fileURL: URL) {
        let loadedState = Self.loadFromDisk(fileURL: fileURL)
        backend = .file(fileURL, loadedState.records, loadedState.favorites)
    }

    init(supabaseProjectURL: URL, serviceRoleKey: String) {
        backend = .supabase(projectURL: supabaseProjectURL, serviceRoleKey: serviceRoleKey)
    }

    func all() async throws -> [CollectionRecordDTO] {
        switch backend {
        case .file(_, let records, _):
            return records
        case .supabase(let projectURL, let key):
            return try await Self.fetchSupabaseRecords(projectURL: projectURL, serviceRoleKey: key)
        }
    }

    func allFavorites() async throws -> [String] {
        switch backend {
        case .file(_, _, let favorites):
            return favorites.sorted()
        case .supabase(let projectURL, let key):
            return try await Self.fetchSupabaseFavorites(projectURL: projectURL, serviceRoleKey: key)
        }
    }

    func merge(_ incoming: [CollectionRecordDTO]) async throws {
        let normalized = Self.normalizedRecords(from: incoming)
        switch backend {
        case .file(let fileURL, let existingRecords, let favorites):
            var mergedRecords = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.id, $0) })
            for record in normalized {
                mergedRecords[record.id] = record
            }
            let sorted = Self.normalizedRecords(from: Array(mergedRecords.values))
            backend = .file(fileURL, sorted, favorites)
            try persistFileIfNeeded()
        case .supabase(let projectURL, let key):
            try await Self.upsertSupabaseRecords(normalized, projectURL: projectURL, serviceRoleKey: key)
        }
    }

    func syncFavorites(_ artworkIDs: [String]) async throws {
        let normalized = Self.normalizedFavorites(from: artworkIDs)
        switch backend {
        case .file(let fileURL, let records, _):
            backend = .file(fileURL, records, Set(normalized))
            try persistFileIfNeeded()
        case .supabase(let projectURL, let key):
            try await Self.replaceSupabaseFavorites(normalized, projectURL: projectURL, serviceRoleKey: key)
        }
    }

    private func persistFileIfNeeded() throws {
        guard case .file(let fileURL, let records, let favorites) = backend else { return }
        let snapshot = CollectionStoreSnapshot(
            records: records,
            favorites: favorites.sorted()
        )
        let data = try JSONCoding.makeEncoder().encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func loadFromDisk(fileURL: URL) -> (records: [CollectionRecordDTO], favorites: Set<String>) {
        guard let data = try? Data(contentsOf: fileURL) else { return ([], []) }
        let decoder = JSONCoding.makeDecoder()

        if let snapshot = try? decoder.decode(CollectionStoreSnapshot.self, from: data) {
            return (normalizedRecords(from: snapshot.records), Set(normalizedFavorites(from: snapshot.favorites)))
        }

        if let legacyRecords = try? decoder.decode([CollectionRecordDTO].self, from: data) {
            return (normalizedRecords(from: legacyRecords), [])
        }

        return ([], [])
    }

    private static func normalizedRecords(from records: [CollectionRecordDTO]) -> [CollectionRecordDTO] {
        var unique: [String: CollectionRecordDTO] = [:]
        for record in records where !record.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            unique[record.id] = record
        }
        return unique.values.sorted { lhs, rhs in
            if lhs.acquiredAt == rhs.acquiredAt {
                return lhs.id < rhs.id
            }
            return lhs.acquiredAt > rhs.acquiredAt
        }
    }

    private static func normalizedFavorites(from artworkIDs: [String]) -> [String] {
        Array(
            Set(
                artworkIDs
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        ).sorted()
    }

    private static func restTableURL(projectURL: URL, table: String, queryItems: [URLQueryItem] = []) -> URL {
        let base = projectURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var components = URLComponents(string: base + "/rest/v1/" + table)!
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url!
    }

    private static func fetchSupabaseRecords(projectURL: URL, serviceRoleKey: String) async throws -> [CollectionRecordDTO] {
        var request = URLRequest(
            url: restTableURL(
                projectURL: projectURL,
                table: "collection_records",
                queryItems: [
                    URLQueryItem(name: "select", value: "id,artwork_id,acquired_at,certificate_id"),
                    URLQueryItem(name: "order", value: "acquired_at.desc,id.asc"),
                ]
            )
        )
        request.httpMethod = "GET"
        addSupabaseHeaders(&request, serviceRoleKey: serviceRoleKey)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let data = try await ServerHTTPClient.perform(request, failurePrefix: "Supabase collection list")
        let decoder = JSONCoding.makeDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return normalizedRecords(from: try decoder.decode([CollectionRecordDTO].self, from: data))
    }

    private static func fetchSupabaseFavorites(projectURL: URL, serviceRoleKey: String) async throws -> [String] {
        var request = URLRequest(
            url: restTableURL(
                projectURL: projectURL,
                table: "collection_favorites",
                queryItems: [
                    URLQueryItem(name: "select", value: "artwork_id"),
                    URLQueryItem(name: "order", value: "artwork_id.asc"),
                ]
            )
        )
        request.httpMethod = "GET"
        addSupabaseHeaders(&request, serviceRoleKey: serviceRoleKey)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let data = try await ServerHTTPClient.perform(request, failurePrefix: "Supabase favorites list")
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let rows = try decoder.decode([FavoriteRow].self, from: data)
        return normalizedFavorites(from: rows.map(\.artworkID))
    }

    private static func upsertSupabaseRecords(
        _ records: [CollectionRecordDTO],
        projectURL: URL,
        serviceRoleKey: String
    ) async throws {
        guard !records.isEmpty else { return }
        var request = URLRequest(url: restTableURL(projectURL: projectURL, table: "collection_records"))
        request.httpMethod = "POST"
        addSupabaseHeaders(&request, serviceRoleKey: serviceRoleKey)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")

        let encoder = JSONCoding.makeEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(records)
        _ = try await ServerHTTPClient.perform(request, failurePrefix: "Supabase collection upsert")
    }

    private static func replaceSupabaseFavorites(
        _ artworkIDs: [String],
        projectURL: URL,
        serviceRoleKey: String
    ) async throws {
        var deleteRequest = URLRequest(url: restTableURL(projectURL: projectURL, table: "collection_favorites"))
        deleteRequest.httpMethod = "DELETE"
        addSupabaseHeaders(&deleteRequest, serviceRoleKey: serviceRoleKey)
        deleteRequest.addValue("return=minimal", forHTTPHeaderField: "Prefer")
        _ = try await ServerHTTPClient.perform(deleteRequest, failurePrefix: "Supabase favorites delete")

        guard !artworkIDs.isEmpty else { return }

        let rows = artworkIDs.map { FavoriteRow(artworkID: $0) }
        var insertRequest = URLRequest(url: restTableURL(projectURL: projectURL, table: "collection_favorites"))
        insertRequest.httpMethod = "POST"
        addSupabaseHeaders(&insertRequest, serviceRoleKey: serviceRoleKey)
        insertRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        insertRequest.addValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        insertRequest.httpBody = try encoder.encode(rows)
        _ = try await ServerHTTPClient.perform(insertRequest, failurePrefix: "Supabase favorites insert")
    }

    private static func addSupabaseHeaders(_ request: inout URLRequest, serviceRoleKey: String) {
        request.addValue(serviceRoleKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(serviceRoleKey)", forHTTPHeaderField: "Authorization")
    }
}

private struct CollectionStoreSnapshot: Codable {
    let records: [CollectionRecordDTO]
    let favorites: [String]
}

private struct CollectionStoreStorageKey: StorageKey {
    typealias Value = CollectionStoreActor
}

private struct CollectionPersistenceKindStorageKey: StorageKey {
    typealias Value = CollectionPersistenceKind
}

extension Application {
    var collectionStore: CollectionStoreActor? {
        get { storage[CollectionStoreStorageKey.self] }
        set { storage[CollectionStoreStorageKey.self] = newValue }
    }

    var collectionPersistenceKind: CollectionPersistenceKind? {
        get { storage[CollectionPersistenceKindStorageKey.self] }
        set { storage[CollectionPersistenceKindStorageKey.self] = newValue }
    }
}

// MARK: - Multipart Parser

private struct MultipartPart {
    let name: String
    let filename: String?
    let data: Data
}

private struct FavoriteRow: Codable {
    let artworkID: String
}

private enum UploadedImageFormat {
    case jpeg
    case png
    case gif
    case webp
    case heic

    var fileExtension: String {
        switch self {
        case .jpeg: "jpg"
        case .png: "png"
        case .gif: "gif"
        case .webp: "webp"
        case .heic: "heic"
        }
    }
}

private func uploadPublicBaseURL(for req: Request) -> URL {
    let fallback = URL(string: "http://127.0.0.1:\(req.application.http.server.configuration.port)")!
    guard let host = req.headers.first(name: .host), !host.isEmpty else {
        return fallback
    }
    let scheme = req.headers.first(name: "X-Forwarded-Proto") ?? "http"
    return URL(string: "\(scheme)://\(host)") ?? fallback
}

private func normalizedArtworkID(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.count <= 128 else { return nil }
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    guard trimmed.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
    return trimmed
}

private func sanitizeUploadFilename(_ raw: String) -> String {
    let lastPathComponent = (raw as NSString).lastPathComponent
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
    let filtered = String(lastPathComponent.unicodeScalars.map { scalar in
        allowed.contains(scalar) ? Character(scalar) : "_"
    })
    return filtered.trimmingCharacters(in: CharacterSet(charactersIn: "._"))
}

private func detectedImageFormat(for data: Data) -> UploadedImageFormat? {
    guard !data.isEmpty else { return nil }

    if data.starts(with: [0xFF, 0xD8, 0xFF]) {
        return .jpeg
    }
    if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
        return .png
    }
    if data.starts(with: Data("GIF8".utf8)) {
        return .gif
    }
    if data.count >= 12,
       data[0..<4] == Data([0x52, 0x49, 0x46, 0x46]),
       data[8..<12] == Data([0x57, 0x45, 0x42, 0x50]) {
        return .webp
    }
    if data.count >= 12 {
        let brand = String(data: data[8..<12], encoding: .ascii)
        if brand == "heic" || brand == "heix" || brand == "heif" || brand == "mif1" {
            return .heic
        }
    }

    return nil
}

private func parseMultipart(data: Data, boundary: String) -> [MultipartPart] {
    let boundaryData = "--\(boundary)".data(using: .utf8)!
    let crlf = "\r\n".data(using: .utf8)!
    let doubleCRLF = "\r\n\r\n".data(using: .utf8)!

    var parts: [MultipartPart] = []
    var searchRange = data.startIndex..<data.endIndex

    while let boundaryRange = data.range(of: boundaryData, in: searchRange) {
        let afterBoundary = boundaryRange.upperBound
        guard afterBoundary < data.endIndex else { break }

        if data[afterBoundary...].starts(with: "--".data(using: .utf8)!) {
            break
        }

        let remaining = afterBoundary..<data.endIndex
        guard let headerEnd = data.range(of: doubleCRLF, in: remaining) else { break }

        let headerData = data[afterBoundary..<headerEnd.lowerBound]
        let headerString = String(data: headerData, encoding: .utf8) ?? ""

        let bodyStart = headerEnd.upperBound
        let nextBoundarySearch = bodyStart..<data.endIndex
        let bodyEnd: Data.Index
        if let nextBoundary = data.range(of: boundaryData, in: nextBoundarySearch) {
            let candidate = nextBoundary.lowerBound
            if candidate >= crlf.count + bodyStart {
                bodyEnd = candidate - crlf.count
            } else {
                bodyEnd = candidate
            }
        } else {
            bodyEnd = data.endIndex
        }

        let bodyData = data[bodyStart..<bodyEnd]

        var name = ""
        var filename: String?
        for line in headerString.components(separatedBy: "\r\n") {
            if line.lowercased().contains("content-disposition") {
                if let nameMatch = line.range(of: "name=\"") {
                    let start = nameMatch.upperBound
                    if let end = line[start...].firstIndex(of: "\"") {
                        name = String(line[start..<end])
                    }
                }
                if let fnMatch = line.range(of: "filename=\"") {
                    let start = fnMatch.upperBound
                    if let end = line[start...].firstIndex(of: "\"") {
                        filename = String(line[start..<end])
                    }
                }
            }
        }

        parts.append(MultipartPart(name: name, filename: filename, data: Data(bodyData)))
        searchRange = (bodyEnd < data.endIndex ? bodyEnd : data.endIndex)..<data.endIndex
    }

    return parts
}
