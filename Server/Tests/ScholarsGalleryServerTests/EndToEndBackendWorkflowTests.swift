import Foundation
import Testing
import Vapor
import XCTVapor
@testable import ScholarsGalleryServer

struct EndToEndBackendWorkflowTests {
    @Test
    func backendWorkflowCoversMetaGenerationCollectionAndAdmin() async throws {
        let app = try await Application.make(.testing)

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("scholarsgallery-e2e-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let generatedURL = root.appendingPathComponent("generated.json")
        let collectionURL = root.appendingPathComponent("collection.json")
        let adminPolicyURL = root.appendingPathComponent("admin-policy.json")

        app.generatedArtworkStore = GeneratedArtworkStore(fileURL: generatedURL)
        app.generatedArtworkPersistenceKind = .file
        app.catalogLoader = .static
        app.catalogPersistenceKind = .static
        app.collectionStore = CollectionStoreActor(fileURL: collectionURL)
        app.generationAuthToken = "secret-token"
        app.generationRateLimiter = GenerationRateLimiter(maxRequests: 100, intervalSeconds: 60)
        app.adminAPIToken = "admin-token"
        app.adminPolicyStore = AdminPolicyStore(fileURL: adminPolicyURL)
        app.dolaAssistantService = DolaAssistantService(openAI: nil, model: "mock")

        try routes(app)
        try registerCollectionRoutes(app)

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "api/meta", afterResponse: { response in
                #expect(response.status == .ok)
                let meta = try response.content.decode(APIMetaResponse.self)
                #expect(meta.persistence == "file")
                #expect(meta.catalog == "static")
                #expect(meta.dolaAssistantEnabled == true)
            })
        }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "api/exhibitions", afterResponse: { response in
                #expect(response.status == .ok)
                let exhibitions = try response.content.decode([ExhibitionResponse].self)
                #expect(exhibitions.count == 1)
                #expect(exhibitions[0].slug == "worlds-written-in-light")
            })
        }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.POST, "api/artworks/generate", beforeRequest: { request in
                request.headers.contentType = .json
                request.headers.add(name: "X-Generation-Token", value: "secret-token")
                try request.content.encode([
                    "prompt": "A full-stack end-to-end backend workflow prompt with luminous archival textures.",
                    "artistID": "00000000-0000-0000-0000-000000000001",
                ], as: .json)
            }, afterResponse: { response in
                #expect(response.status == .ok)
                let generated = try response.content.decode(GeneratedArtworkRecord.self)
                #expect(generated.status == "completed")
                #expect(generated.provider == "mock")
            })
        }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "api/artworks/generated?limit=5", beforeRequest: { request in
                request.headers.add(name: "X-Generation-Token", value: "secret-token")
            }, afterResponse: { response in
                #expect(response.status == .ok)
                let generated = try response.content.decode([GeneratedArtworkRecord].self)
                #expect(generated.count == 1)
                #expect(generated[0].prompt.contains("full-stack end-to-end backend workflow"))
            })
        }

        let acquiredAt = Date(timeIntervalSince1970: 1_700_000_000)
        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.POST, "api/collection/sync", beforeRequest: { request in
                request.headers.contentType = .json
                try request.content.encode(CollectionSyncInput(records: [
                    CollectionRecordDTO(
                        id: "e2e-record-001",
                        artworkID: "art-e2e-001",
                        acquiredAt: acquiredAt,
                        certificateID: "CERT-E2E001"
                    )
                ]), as: .json)
            }, afterResponse: { response in
                #expect(response.status == .ok)
            })
        }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.POST, "api/collection/favorites", beforeRequest: { request in
                request.headers.contentType = .json
                try request.content.encode(FavoritesSyncInput(artworkIDs: ["art-e2e-001"]), as: .json)
            }, afterResponse: { response in
                #expect(response.status == .ok)
            })
        }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "api/collection/favorites", afterResponse: { response in
                #expect(response.status == .ok)
                let favorites = try response.content.decode([String].self)
                #expect(favorites == ["art-e2e-001"])
            })
        }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "api/admin/overview", beforeRequest: { request in
                request.headers.add(name: "X-Admin-Token", value: "admin-token")
            }, afterResponse: { response in
                #expect(response.status == .ok)
                let overview = try response.content.decode(AdminOverviewDTO.self)
                #expect(overview.generationPersistence == "file")
                #expect(overview.catalogPersistence == "static")
                #expect(overview.dolaAssistantProvider == "mock")
            })
        }

        try await app.asyncShutdown()
    }
}
