import Foundation
import Testing
import Vapor
import XCTVapor
@testable import ScholarsGalleryServer

struct SubscriptionRoutesTests {

    // MARK: - Helpers

    private func makeApp() async throws -> (Application, URL) {
        let app = try await Application.make(.testing)
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("sg-subscription-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let grantsURL = folder.appendingPathComponent("access-grants.json")
        app.accessGrantStore = AccessGrantStore(fileURL: grantsURL)
        app.adminAPIToken = "test-admin-token"
        try routes(app)
        try app.register(collection: SubscriptionRouteCollection())
        return (app, grantsURL)
    }

    // MARK: - Public endpoint: GET /api/access/check

    @Test func checkAccess_missingDeviceID_returnsNotGranted() async throws {
        let (app, _) = try await makeApp()
        defer { Task { try? await app.asyncShutdown() } }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "api/access/check", afterResponse: { response in
                #expect(response.status == .ok)
                let body = try response.content.decode(AccessCheckResponse.self)
                #expect(body.granted == false)
            })
        }
    }

    @Test func checkAccess_unknownDevice_returnsNotGranted() async throws {
        let (app, _) = try await makeApp()
        defer { Task { try? await app.asyncShutdown() } }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "api/access/check", beforeRequest: { req in
                req.headers.add(name: "X-Device-ID", value: "NOTGRANTED")
            }, afterResponse: { response in
                #expect(response.status == .ok)
                let body = try response.content.decode(AccessCheckResponse.self)
                #expect(body.granted == false)
            })
        }
    }

    // MARK: - Admin endpoint: POST /api/admin/access/grant

    @Test func grantAccess_requiresAdminToken() async throws {
        let (app, _) = try await makeApp()
        defer { Task { try? await app.asyncShutdown() } }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.POST, "api/admin/access/grant", beforeRequest: { req in
                try req.content.encode(["deviceID": "DEVICE001"], as: .json)
            }, afterResponse: { response in
                #expect(response.status == .unauthorized)
            })
        }
    }

    @Test func grantAccess_withAdminToken_returnsGrant() async throws {
        let (app, _) = try await makeApp()
        defer { Task { try? await app.asyncShutdown() } }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.POST, "api/admin/access/grant", beforeRequest: { req in
                req.headers.add(name: "X-Admin-Token", value: "test-admin-token")
                try req.content.encode(["deviceID": "DEVICE001"], as: .json)
            }, afterResponse: { response in
                #expect(response.status == .ok)
                let grant = try response.content.decode(AccessGrant.self)
                #expect(grant.deviceID == "DEVICE001")
                #expect(grant.expiresAt == nil)
            })
        }
    }

    @Test func grantAccess_emptyDeviceID_returns400() async throws {
        let (app, _) = try await makeApp()
        defer { Task { try? await app.asyncShutdown() } }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.POST, "api/admin/access/grant", beforeRequest: { req in
                req.headers.add(name: "X-Admin-Token", value: "test-admin-token")
                try req.content.encode(["deviceID": "   "], as: .json)
            }, afterResponse: { response in
                #expect(response.status == .badRequest)
            })
        }
    }

    // MARK: - Admin endpoint: GET /api/admin/access/grants

    @Test func listGrants_requiresAdminToken() async throws {
        let (app, _) = try await makeApp()
        defer { Task { try? await app.asyncShutdown() } }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "api/admin/access/grants", afterResponse: { response in
                #expect(response.status == .unauthorized)
            })
        }
    }

    @Test func listGrants_afterGrant_containsDevice() async throws {
        let (app, _) = try await makeApp()
        defer { Task { try? await app.asyncShutdown() } }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.POST, "api/admin/access/grant", beforeRequest: { req in
                req.headers.add(name: "X-Admin-Token", value: "test-admin-token")
                try req.content.encode(["deviceID": "LISTED-DEVICE"], as: .json)
            }, afterResponse: { _ in })

            try app.test(.GET, "api/admin/access/grants", beforeRequest: { req in
                req.headers.add(name: "X-Admin-Token", value: "test-admin-token")
            }, afterResponse: { response in
                #expect(response.status == .ok)
                let grants = try response.content.decode([AccessGrant].self)
                #expect(grants.contains { $0.deviceID == "LISTED-DEVICE" })
            })
        }
    }

    // MARK: - Admin endpoint: DELETE /api/admin/access/:deviceID

    @Test func revokeAccess_thenCheckReturnsFalse() async throws {
        let (app, _) = try await makeApp()
        defer { Task { try? await app.asyncShutdown() } }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            // Grant
            try app.test(.POST, "api/admin/access/grant", beforeRequest: { req in
                req.headers.add(name: "X-Admin-Token", value: "test-admin-token")
                try req.content.encode(["deviceID": "REVOKE-ME"], as: .json)
            }, afterResponse: { _ in })

            // Verify granted
            try app.test(.GET, "api/access/check", beforeRequest: { req in
                req.headers.add(name: "X-Device-ID", value: "REVOKE-ME")
            }, afterResponse: { response in
                let body = try response.content.decode(AccessCheckResponse.self)
                #expect(body.granted == true)
            })

            // Revoke
            try app.test(.DELETE, "api/admin/access/REVOKE-ME", beforeRequest: { req in
                req.headers.add(name: "X-Admin-Token", value: "test-admin-token")
            }, afterResponse: { response in
                #expect(response.status == .ok)
            })

            // Verify no longer granted
            try app.test(.GET, "api/access/check", beforeRequest: { req in
                req.headers.add(name: "X-Device-ID", value: "REVOKE-ME")
            }, afterResponse: { response in
                let body = try response.content.decode(AccessCheckResponse.self)
                #expect(body.granted == false)
            })
        }
    }

    // MARK: - AccessGrantStore unit tests

    @Test func accessGrantStore_isGranted_noExpiry() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let store = AccessGrantStore(fileURL: folder.appendingPathComponent("grants.json"))
        await store.grant(deviceID: "DEV-A", expiresAt: nil, reason: nil)
        let granted = await store.isGranted(deviceID: "DEV-A")
        #expect(granted == true)
    }

    @Test func accessGrantStore_isGranted_futureExpiry() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let store = AccessGrantStore(fileURL: folder.appendingPathComponent("grants.json"))
        let future = Date().addingTimeInterval(3600)
        await store.grant(deviceID: "DEV-B", expiresAt: future, reason: nil)
        let granted = await store.isGranted(deviceID: "DEV-B")
        #expect(granted == true)
    }

    @Test func accessGrantStore_isNotGranted_pastExpiry() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let store = AccessGrantStore(fileURL: folder.appendingPathComponent("grants.json"))
        let past = Date().addingTimeInterval(-3600)
        await store.grant(deviceID: "DEV-C", expiresAt: past, reason: nil)
        let granted = await store.isGranted(deviceID: "DEV-C")
        #expect(granted == false)
    }

    @Test func accessGrantStore_revoke_removesGrant() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let store = AccessGrantStore(fileURL: folder.appendingPathComponent("grants.json"))
        await store.grant(deviceID: "DEV-D", expiresAt: nil, reason: nil)
        let revoked = await store.revoke(deviceID: "DEV-D")
        #expect(revoked == true)
        let granted = await store.isGranted(deviceID: "DEV-D")
        #expect(granted == false)
    }
}
