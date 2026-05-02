import Foundation
import Testing
import Vapor
import XCTVapor
@testable import ScholarsGalleryServer

struct AdminPolicyTests {
    @Test
    func checkoutReturns403WhenPolicyDisablesCheckout() async throws {
        let app = try await Application.make(.testing)
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("scholarsgallery-admin-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let policyURL = folder.appendingPathComponent("policy.json")
        let disabled = AdminPolicySnapshot(checkoutEnabled: false, generationEnabled: true, announcement: nil)
        let data = try JSONCoding.makeEncoder().encode(disabled)
        try data.write(to: policyURL)
        app.adminPolicyStore = AdminPolicyStore(fileURL: policyURL)
        try routes(app)

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.POST, "api/checkout/00000000-0000-0000-0000-000000000001", afterResponse: { response in
                #expect(response.status == .forbidden)
            })
        }

        try await app.asyncShutdown()
    }

    @Test
    func adminOverviewRequiresTokenWhenConfigured() async throws {
        let app = try await Application.make(.testing)
        app.adminAPIToken = "secret-admin"
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("scholarsgallery-admin-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let policyURL = folder.appendingPathComponent("policy.json")
        app.adminPolicyStore = AdminPolicyStore(fileURL: policyURL)
        try routes(app)

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "api/admin/overview", afterResponse: { response in
                #expect(response.status == .unauthorized)
            })
        }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "api/admin/overview", beforeRequest: { req in
                req.headers.add(name: "X-Admin-Token", value: "secret-admin")
            }, afterResponse: { response in
                #expect(response.status == .ok)
                let dto = try response.content.decode(AdminOverviewDTO.self)
                #expect(dto.policy.checkoutEnabled == true)
            })
        }

        try await app.asyncShutdown()
    }

    @Test
    func adminPutPolicyPersists() async throws {
        let app = try await Application.make(.testing)
        app.adminAPIToken = "adm"
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("scholarsgallery-admin-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let policyURL = folder.appendingPathComponent("policy.json")
        app.adminPolicyStore = AdminPolicyStore(fileURL: policyURL)
        try routes(app)

        let updated = AdminPolicySnapshot(
            checkoutEnabled: false,
            generationEnabled: true,
            announcement: "Maintenance"
        )

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.PUT, "api/admin/policy", beforeRequest: { req in
                req.headers.add(name: "X-Admin-Token", value: "adm")
                req.headers.contentType = .json
                try req.content.encode(updated, as: .json)
            }, afterResponse: { response in
                #expect(response.status == .ok)
            })
        }

        let reloaded = AdminPolicyStore(fileURL: policyURL)
        let snap = await reloaded.current()
        #expect(snap.checkoutEnabled == false)
        #expect(snap.announcement == "Maintenance")

        try await app.asyncShutdown()
    }

    @Test
    func generationReturns403WhenPolicyDisablesGeneration() async throws {
        let app = try await Application.make(.testing)
        app.generationAuthToken = "gen-token"
        app.generationRateLimiter = GenerationRateLimiter(maxRequests: 100, intervalSeconds: 60)
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("scholarsgallery-admin-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let policyURL = folder.appendingPathComponent("policy.json")
        let snap = AdminPolicySnapshot(checkoutEnabled: true, generationEnabled: false, announcement: nil)
        let enc = try JSONCoding.makeEncoder().encode(snap)
        try enc.write(to: policyURL)
        app.adminPolicyStore = AdminPolicyStore(fileURL: policyURL)
        try routes(app)

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.POST, "api/artworks/generate", beforeRequest: { request in
                request.headers.contentType = .json
                request.headers.add(name: "X-Generation-Token", value: "gen-token")
                try request.content.encode([
                    "prompt": "A sufficiently long prompt for policy-disabled generation contract tests.",
                    "artistID": "00000000-0000-0000-0000-000000000001",
                ], as: .json)
            }, afterResponse: { response in
                #expect(response.status == .forbidden)
            })
        }

        try await app.asyncShutdown()
    }
}
