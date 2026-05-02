import Foundation
import Testing
import Vapor
import XCTVapor
@testable import ScholarsGalleryServer

struct DolaAssistantTests {
    private func makeAppWithMockDola() async throws -> Application {
        let app = try await Application.make(.testing)
        app.dolaAssistantService = DolaAssistantService(openAI: nil, model: "mock")
        try routes(app)
        return app
    }

    @Test
    func assistReturnsRefinedPromptFromMockProvider() async throws {
        let app = try await makeAppWithMockDola()

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.POST, "api/dola/assist", beforeRequest: { request in
                request.headers.contentType = .json
                try request.content.encode([
                    "prompt": "a quiet cathedral interior at dawn",
                    "mood": "dreamlike",
                    "intent": "scene"
                ], as: .json)
            }, afterResponse: { response in
                #expect(response.status == .ok)
                let dto = try response.content.decode(DolaAssistResponse.self)
                #expect(dto.provider == "mock")
                #expect(dto.refinedPrompt.contains("cathedral"))
                #expect(dto.suggestions.count == 3)
                #expect(dto.palette.count >= 3)
            })
        }

        try await app.asyncShutdown()
    }

    @Test
    func assistRejectsTooShortPrompt() async throws {
        let app = try await makeAppWithMockDola()

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.POST, "api/dola/assist", beforeRequest: { request in
                request.headers.contentType = .json
                try request.content.encode(DolaAssistRequest(
                    prompt: "hi",
                    mood: nil,
                    intent: nil
                ), as: .json)
            }, afterResponse: { response in
                #expect(response.status == .badRequest)
            })
        }

        try await app.asyncShutdown()
    }

    @Test
    func assistReturns403WhenPolicyDisablesDola() async throws {
        let app = try await Application.make(.testing)
        app.dolaAssistantService = DolaAssistantService(openAI: nil, model: "mock")

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("scholarsgallery-dola-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let policyURL = folder.appendingPathComponent("policy.json")
        let snap = AdminPolicySnapshot(
            checkoutEnabled: true,
            generationEnabled: true,
            announcement: nil,
            dolaAssistantEnabled: false
        )
        let data = try JSONCoding.makeEncoder().encode(snap)
        try data.write(to: policyURL)
        app.adminPolicyStore = AdminPolicyStore(fileURL: policyURL)
        try routes(app)

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.POST, "api/dola/assist", beforeRequest: { request in
                request.headers.contentType = .json
                try request.content.encode([
                    "prompt": "twilight harbor with paper lanterns drifting on the tide",
                    "mood": "warm",
                    "intent": "scene"
                ], as: .json)
            }, afterResponse: { response in
                #expect(response.status == .forbidden)
            })
        }

        try await app.asyncShutdown()
    }

    @Test
    func metaExposesDolaFields() async throws {
        let app = try await makeAppWithMockDola()

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "api/meta", afterResponse: { response in
                #expect(response.status == .ok)
                let meta = try response.content.decode(APIMetaResponse.self)
                #expect(meta.dolaAssistantEnabled == true)
                #expect(meta.dolaAssistantConfigured == false)
            })
        }

        try await app.asyncShutdown()
    }
}
