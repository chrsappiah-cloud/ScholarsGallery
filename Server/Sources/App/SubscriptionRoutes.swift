import Vapor

struct SubscriptionRouteCollection: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Public — checked by the iOS app on every Scholarship tab appearance
        routes.get("api", "access", "check", use: checkAccess)

        // Admin-only access grant management
        let admin = routes.grouped(AdminSecurityMiddleware())
        admin.get("api", "admin", "access", "grants", use: listGrants)
        admin.post("api", "admin", "access", "grant", use: grantAccess)
        admin.delete("api", "admin", "access", ":deviceID", use: revokeAccess)
    }

    // MARK: - Public

    /// `GET /api/access/check`
    /// Header: `X-Device-ID: <identifierForVendor>`
    func checkAccess(req: Request) async throws -> AccessCheckResponse {
        guard let store = req.application.accessGrantStore else {
            return AccessCheckResponse(granted: false, expiresAt: nil)
        }
        let deviceID = req.headers.first(name: "X-Device-ID") ?? ""
        guard !deviceID.isEmpty else {
            return AccessCheckResponse(granted: false, expiresAt: nil)
        }
        let grant = await store.activeGrant(for: deviceID)
        return AccessCheckResponse(granted: grant != nil, expiresAt: grant?.expiresAt)
    }

    // MARK: - Admin

    /// `GET /api/admin/access/grants`
    func listGrants(req: Request) async throws -> [AccessGrant] {
        guard let store = req.application.accessGrantStore else { return [] }
        return await store.listGrants()
    }

    /// `POST /api/admin/access/grant`
    func grantAccess(req: Request) async throws -> AccessGrant {
        guard let store = req.application.accessGrantStore else {
            throw Abort(.serviceUnavailable, reason: "Access grant store not configured.")
        }
        let body = try req.content.decode(GrantAccessRequest.self)
        guard !body.deviceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "deviceID must not be empty.")
        }
        return await store.grant(deviceID: body.deviceID, expiresAt: body.expiresAt, reason: body.reason)
    }

    /// `DELETE /api/admin/access/:deviceID`
    func revokeAccess(req: Request) async throws -> HTTPStatus {
        guard let store = req.application.accessGrantStore else {
            throw Abort(.serviceUnavailable, reason: "Access grant store not configured.")
        }
        guard let deviceID = req.parameters.get("deviceID") else {
            throw Abort(.badRequest, reason: "Missing deviceID parameter.")
        }
        await store.revoke(deviceID: deviceID)
        return .ok
    }
}

// MARK: - DTOs

struct AccessCheckResponse: Content {
    var granted: Bool
    var expiresAt: Date?
}

struct GrantAccessRequest: Content {
    var deviceID: String
    var expiresAt: Date?
    var reason: String?
}
