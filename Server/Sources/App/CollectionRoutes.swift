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

func registerCollectionRoutes(_ app: Application) throws {
    let collection = app.grouped("api", "collection")

    collection.get { req async throws -> [CollectionRecordDTO] in
        guard let store = req.application.collectionStore else {
            return []
        }
        return await store.all()
    }

    collection.get("favorites") { req async throws -> [String] in
        guard let store = req.application.collectionStore else {
            return []
        }
        return await store.allFavorites()
    }

    collection.post("sync") { req async throws -> HTTPStatus in
        let input = try req.content.decode(CollectionSyncInput.self)
        guard let store = req.application.collectionStore else {
            throw Abort(.serviceUnavailable, reason: "Collection store not configured.")
        }
        await store.merge(input.records)
        return .ok
    }

    collection.post("favorites") { req async throws -> HTTPStatus in
        let input = try req.content.decode(FavoritesSyncInput.self)
        guard let store = req.application.collectionStore else {
            throw Abort(.serviceUnavailable, reason: "Collection store not configured.")
        }
        await store.syncFavorites(input.artworkIDs)
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

        guard let artworkId, let imageData, !imageData.isEmpty else {
            throw Abort(.badRequest, reason: "Missing artworkId or image data.")
        }

        let uploadsDir = URL(fileURLWithPath: ServerPaths.publicDirectory)
            .appendingPathComponent("uploads", isDirectory: true)
        try FileManager.default.createDirectory(at: uploadsDir, withIntermediateDirectories: true)

        let savedFilename = "\(artworkId)_\(filename)"
        let savedURL = uploadsDir.appendingPathComponent(savedFilename)
        try imageData.write(to: savedURL)

        let publicPath = "/uploads/\(savedFilename)"
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
    private var records: [CollectionRecordDTO] = []
    private var favorites: Set<String> = []
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
        let loadedState = Self.loadFromDisk(fileURL: fileURL)
        records = loadedState.records
        favorites = loadedState.favorites
    }

    func all() -> [CollectionRecordDTO] {
        records
    }

    func allFavorites() -> [String] {
        favorites.sorted()
    }

    func merge(_ incoming: [CollectionRecordDTO]) {
        var mergedRecords = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        for record in incoming {
            mergedRecords[record.id] = record
        }
        records = mergedRecords.values.sorted { lhs, rhs in
            if lhs.acquiredAt == rhs.acquiredAt {
                return lhs.id < rhs.id
            }
            return lhs.acquiredAt > rhs.acquiredAt
        }
        persist()
    }

    func syncFavorites(_ artworkIDs: [String]) {
        favorites = Set(artworkIDs)
        persist()
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let snapshot = CollectionStoreSnapshot(
            records: records,
            favorites: favorites.sorted()
        )
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: fileURL)
    }

    private static func loadFromDisk(fileURL: URL) -> (records: [CollectionRecordDTO], favorites: Set<String>) {
        guard let data = try? Data(contentsOf: fileURL) else { return ([], []) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let snapshot = try? decoder.decode(CollectionStoreSnapshot.self, from: data) {
            return (snapshot.records, Set(snapshot.favorites))
        }

        if let legacyRecords = try? decoder.decode([CollectionRecordDTO].self, from: data) {
            return (legacyRecords, [])
        }

        return ([], [])
    }
}

private struct CollectionStoreSnapshot: Codable {
    let records: [CollectionRecordDTO]
    let favorites: [String]
}

private struct CollectionStoreStorageKey: StorageKey {
    typealias Value = CollectionStoreActor
}

extension Application {
    var collectionStore: CollectionStoreActor? {
        get { storage[CollectionStoreStorageKey.self] }
        set { storage[CollectionStoreStorageKey.self] = newValue }
    }
}

// MARK: - Multipart Parser

private struct MultipartPart {
    let name: String
    let filename: String?
    let data: Data
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
