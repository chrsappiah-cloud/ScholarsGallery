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
        let persistedRecords = await reloadedStore.all()
        let persistedFavorites = await reloadedStore.allFavorites()
        #expect(persistedRecords.count == 1)
        #expect(persistedRecords.first?.artworkID == "art-001")
        #expect(persistedFavorites == ["art-001", "art-002"])

        try await app.asyncShutdown()
    }
}
