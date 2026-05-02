import Foundation
import Testing
import Vapor
import XCTVapor
@testable import ScholarsGalleryServer

private struct OkResponder: AsyncResponder {
    func respond(to request: Request) async throws -> Response {
        Response(status: .ok)
    }
}

struct ServerGenerationTests {
    @Test
    func generationStorePersistsRecords() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("scholarsgallery-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let fileURL = folder.appendingPathComponent("generated.json")

        let store = GeneratedArtworkStore(fileURL: fileURL)
        let record = GeneratedArtworkRecord(
            id: UUID(),
            status: "completed",
            imageURL: "https://example.com/image.jpg",
            prompt: "A scholarly, luminous composition in generative style.",
            provider: "mock",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        try await store.append(record)

        let reloaded = GeneratedArtworkStore(fileURL: fileURL)
        let items = try await reloaded.list(limit: 10)
        #expect(items.count == 1)
        #expect(items.first?.prompt == record.prompt)
        #expect(items.first?.provider == "mock")
    }

    @Test
    func rateLimiterBlocksAfterThreshold() async {
        let limiter = GenerationRateLimiter(maxRequests: 2, intervalSeconds: 60)
        #expect(await limiter.allow(clientKey: "127.0.0.1"))
        #expect(await limiter.allow(clientKey: "127.0.0.1"))
        #expect(!(await limiter.allow(clientKey: "127.0.0.1")))
    }

    @Test
    func middlewareRejectsMissingTokenWhenConfigured() async throws {
        let app = try await Application.make(.testing)

        app.generationAuthToken = "secret-token"
        let request = Request(
            application: app,
            method: .POST,
            url: URI(path: "/api/artworks/generate"),
            on: app.eventLoopGroup.next()
        )

        await #expect(throws: Abort.self) {
            _ = try await GenerationSecurityMiddleware().respond(to: request, chainingTo: OkResponder())
        }
        try await app.asyncShutdown()
    }

    @Test
    func middlewareAllowsValidTokenAndWithinRateLimit() async throws {
        let app = try await Application.make(.testing)

        app.generationAuthToken = "secret-token"
        app.generationRateLimiter = GenerationRateLimiter(maxRequests: 1, intervalSeconds: 60)
        let request = Request(
            application: app,
            method: .POST,
            url: URI(path: "/api/artworks/generate"),
            on: app.eventLoopGroup.next()
        )
        request.headers.add(name: "X-Generation-Token", value: "secret-token")

        let firstResponse = try await GenerationSecurityMiddleware().respond(to: request, chainingTo: OkResponder())
        #expect(firstResponse.status == .ok)

        await #expect(throws: Abort.self) {
            _ = try await GenerationSecurityMiddleware().respond(to: request, chainingTo: OkResponder())
        }
        try await app.asyncShutdown()
    }

    @Test
    func generateEndpointContractSuccessAndUnauthorized() async throws {
        let app = try await Application.make(.testing)
        app.generationAuthToken = "secret-token"
        app.generationRateLimiter = GenerationRateLimiter(maxRequests: 100, intervalSeconds: 60)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("scholarsgallery-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("generated.json")
        app.generatedArtworkStore = GeneratedArtworkStore(fileURL: fileURL)
        try routes(app)

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.POST, "api/artworks/generate", beforeRequest: { request in
                request.headers.contentType = .json
                try request.content.encode([
                    "prompt": "A rigorous prompt designed to validate unauthorized generation access.",
                    "artistID": "00000000-0000-0000-0000-000000000001"
                ], as: .json)
            }, afterResponse: { response in
                #expect(response.status == .unauthorized)
            })
        }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.POST, "api/artworks/generate", beforeRequest: { request in
                request.headers.contentType = .json
                request.headers.add(name: "X-Generation-Token", value: "secret-token")
                try request.content.encode([
                    "prompt": "A rigorous prompt designed to validate successful generation payload contracts.",
                    "artistID": "00000000-0000-0000-0000-000000000001"
                ], as: .json)
            }, afterResponse: { response in
                #expect(response.status == .ok)
                let payload = try response.content.decode(GeneratedArtworkRecord.self)
                #expect(payload.status == "completed")
                #expect(!payload.id.uuidString.isEmpty)
                #expect(!payload.imageURL.isEmpty)
                #expect(!payload.provider.isEmpty)
            })
        }

        try await app.asyncShutdown()
    }

    @Test
    func generatedHistoryEndpointReturnsPersistedItems() async throws {
        let app = try await Application.make(.testing)
        app.generationAuthToken = "secret-token"
        app.generationRateLimiter = GenerationRateLimiter(maxRequests: 100, intervalSeconds: 60)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("scholarsgallery-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("generated.json")
        app.generatedArtworkStore = GeneratedArtworkStore(fileURL: fileURL)
        try routes(app)

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.POST, "api/artworks/generate", beforeRequest: { request in
                request.headers.contentType = .json
                request.headers.add(name: "X-Generation-Token", value: "secret-token")
                try request.content.encode([
                    "prompt": "A persisted generation used for history endpoint contract tests.",
                    "artistID": "00000000-0000-0000-0000-000000000001"
                ], as: .json)
            }, afterResponse: { response in
                #expect(response.status == .ok)
            })
        }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "api/artworks/generated?limit=10", beforeRequest: { request in
                request.headers.add(name: "X-Generation-Token", value: "secret-token")
            }, afterResponse: { response in
                #expect(response.status == .ok)
                let payload = try response.content.decode([GeneratedArtworkRecord].self)
                #expect(!payload.isEmpty)
                #expect(payload[0].prompt.contains("history endpoint contract tests"))
            })
        }

        try await app.asyncShutdown()
    }
}
