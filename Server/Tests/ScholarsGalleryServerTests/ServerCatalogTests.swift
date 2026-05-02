import Foundation
import Testing
import Vapor
import XCTVapor
@testable import ScholarsGalleryServer

struct ServerCatalogTests {
    @Test
    func metaEndpointReflectsPersistenceAndCatalogFlags() async throws {
        let app = try await Application.make(.testing)
        app.generatedArtworkPersistenceKind = .file
        app.catalogPersistenceKind = .static
        app.catalogLoader = .static
        try routes(app)

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "api/meta", afterResponse: { response in
                #expect(response.status == .ok)
                let meta = try response.content.decode(APIMetaResponse.self)
                #expect(meta.ok == true)
                #expect(meta.persistence == "file")
                #expect(meta.catalog == "static")
                #expect(meta.hasOpenAI == false)
                #expect(meta.version == "1")
                #expect(meta.checkoutEnabled == true)
                #expect(meta.generationEnabled == true)
                #expect(meta.adminPanelConfigured == false)
                #expect(meta.dolaAssistantEnabled == true)
                #expect(meta.dolaAssistantConfigured == false)
            })
        }

        try await app.asyncShutdown()
    }

    @Test
    func staticCatalogExhibitionsEssaysManifestAndArtworks() async throws {
        let app = try await Application.make(.testing)
        app.catalogLoader = .static
        try routes(app)

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "api/exhibitions", afterResponse: { response in
                #expect(response.status == .ok)
                let list = try response.content.decode([ExhibitionResponse].self)
                #expect(list.count == 1)
                #expect(list[0].slug == "worlds-written-in-light")
                #expect(list[0].manifestURL?.contains("/api/exhibitions/worlds-written-in-light/manifest") == true)
            })
        }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "api/essays", afterResponse: { response in
                #expect(response.status == .ok)
                let summaries = try response.content.decode([EssaySummaryResponse].self)
                #expect(summaries.count == 2)
                #expect(summaries.contains { $0.id == "essay-001" })
                #expect(summaries.contains { $0.id == "essay-002" })
            })
        }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "api/essays/essay-002", afterResponse: { response in
                #expect(response.status == .ok)
                let essay = try response.content.decode(EssayResponse.self)
                #expect(essay.id == "essay-002")
                #expect(essay.title.contains("Spatial"))
                #expect(essay.references.contains("Serpentine R&D"))
            })
        }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "api/exhibitions/worlds-written-in-light/manifest", afterResponse: { response in
                #expect(response.status == .ok)
                let manifest = try response.content.decode(RoomManifestResponse.self)
                #expect(manifest.exhibitionId == "worlds-written-in-light")
                #expect(manifest.rooms.count == 2)
                #expect(manifest.rooms.first?.id == "threshold")
            })
        }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "api/exhibitions/worlds-written-in-light/artworks", afterResponse: { response in
                #expect(response.status == .ok)
                let artworks = try response.content.decode([ArtworkPackageResponse].self)
                #expect(artworks.count == 4)
                #expect(artworks.first?.displayManifest.heroAssetURL.contains("promo_three_apps_suite") == true)
            })
        }

        try await app.asyncShutdown()
    }

    @Test
    func unknownExhibitionSlugReturnsNotFound() async throws {
        let app = try await Application.make(.testing)
        app.catalogLoader = .static
        try routes(app)

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "api/exhibitions/unknown-slug/manifest", afterResponse: { response in
                #expect(response.status == .notFound)
            })
        }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "api/exhibitions/unknown-slug/artworks", afterResponse: { response in
                #expect(response.status == .notFound)
            })
        }

        try await app.asyncShutdown()
    }
}
