import Foundation
import Testing
import Vapor
import XCTVapor
@testable import ScholarsGalleryServer

struct CollectionRoutesTests {
    @Test
    func collectionRoutesPersistRecordsAndFavorites() async throws {
        let app = try await Application.make(.testing)
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("scholarsgallery-collection-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let fileURL = folder.appendingPathComponent("collection-store.json")
        app.collectionStore = CollectionStoreActor(fileURL: fileURL)
        try registerCollectionRoutes(app)

        let acquiredAt = Date(timeIntervalSince1970: 1_700_000_000)
        let payload = CollectionSyncInput(records: [
            CollectionRecordDTO(
                id: "rec-001",
                artworkID: "art-001",
                acquiredAt: acquiredAt,
                certificateID: "CERT-001"
            )
        ])

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.POST, "api/collection/sync", beforeRequest: { request in
                request.headers.contentType = .json
                try request.content.encode(payload, as: .json)
            }, afterResponse: { response in
                #expect(response.status == .ok)
            })
        }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.POST, "api/collection/favorites", beforeRequest: { request in
                request.headers.contentType = .json
                try request.content.encode(FavoritesSyncInput(artworkIDs: ["art-001", "art-002"]), as: .json)
            }, afterResponse: { response in
                #expect(response.status == .ok)
            })
        }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "api/collection", afterResponse: { response in
                #expect(response.status == .ok)
                let records = try response.content.decode([CollectionRecordDTO].self)
                #expect(records.count == 1)
                #expect(records.first?.artworkID == "art-001")
                #expect(records.first?.certificateID == "CERT-001")
            })
        }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "api/collection/favorites", afterResponse: { response in
                #expect(response.status == .ok)
                let favorites = try response.content.decode([String].self)
                #expect(favorites == ["art-001", "art-002"])
            })
        }

        let reloadedStore = CollectionStoreActor(fileURL: fileURL)
        let persistedRecords = try await reloadedStore.all()
        let persistedFavorites = try await reloadedStore.allFavorites()
        #expect(persistedRecords.count == 1)
        #expect(persistedRecords.first?.artworkID == "art-001")
        #expect(persistedFavorites == ["art-001", "art-002"])

        try await app.asyncShutdown()
    }

    @Test
    func uploadRouteRejectsNonImagePayloads() async throws {
        let app = try await Application.make(.testing)
        try registerCollectionRoutes(app)

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.POST, "api/collection/upload", beforeRequest: { request in
                let boundary = "Boundary-\(UUID().uuidString)"
                request.headers.replaceOrAdd(name: .contentType, value: "multipart/form-data; boundary=\(boundary)")
                request.body = .init(data: invalidUploadBody(boundary: boundary))
            }, afterResponse: { response in
                #expect(response.status == .unsupportedMediaType)
            })
        }

        try await app.asyncShutdown()
    }

    @Test
    func uploadRouteReturnsAbsoluteSanitizedURL() async throws {
        let app = try await Application.make(.testing)
        try registerCollectionRoutes(app)

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.POST, "api/collection/upload", beforeRequest: { request in
                let boundary = "Boundary-\(UUID().uuidString)"
                request.headers.replaceOrAdd(name: .contentType, value: "multipart/form-data; boundary=\(boundary)")
                request.headers.replaceOrAdd(name: .host, value: "gallery.example.com")
                request.body = .init(data: validJPEGUploadBody(boundary: boundary))
            }, afterResponse: { response in
                #expect(response.status == .ok)
                let payload = try response.content.decode(UploadResponseDTO.self)
                #expect(payload.artworkId == "artwork_001")
                #expect(payload.imageURL.hasPrefix("http://gallery.example.com/uploads/artwork_001_upload_"))
                #expect(payload.imageURL.hasSuffix(".jpg"))
                #expect(!payload.imageURL.contains(".."))
            })
        }

        try await app.asyncShutdown()
    }

    private func invalidUploadBody(boundary: String) -> Data {
        multipartBody(
            boundary: boundary,
            artworkId: "artwork_001",
            filename: "../../bad.txt",
            payload: Data("not-an-image".utf8)
        )
    }

    private func validJPEGUploadBody(boundary: String) -> Data {
        multipartBody(
            boundary: boundary,
            artworkId: "artwork_001",
            filename: "../../upload.jpg",
            payload: Data([0xFF, 0xD8, 0xFF, 0xDB, 0x00, 0x43, 0x00, 0xFF, 0xD9])
        )
    }

    private func multipartBody(boundary: String, artworkId: String, filename: String, payload: Data) -> Data {
        var data = Data()
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"artworkId\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(artworkId)\r\n".data(using: .utf8)!)
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        data.append(payload)
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        return data
    }
}
