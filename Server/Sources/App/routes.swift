import Foundation
import Vapor
import OpenAIConnector

struct GenerateArtworkInput: Content {
    let prompt: String
    let artistID: UUID
}

struct EssayResponse: Content {
    let id: String
    let title: String
    let author: String
    let markdownBody: String
    let references: [String]
}

struct EssaySummaryResponse: Content {
    let id: String
    let title: String
    let author: String
}

struct CheckoutResponseDTO: Content {
    let checkoutURL: String
}

struct ExhibitionResponse: Content {
    let id: UUID
    let slug: String
    let title: String
    let subtitle: String
    let openingDate: Date
    let manifestURL: String?
}

struct RoomManifestResponse: Content {
    struct LightingResponse: Content {
        let preset: String
        let intensity: Double
    }

    struct RoomResponse: Content {
        let id: String
        let kind: String
        let title: String
        let artworkIDs: [String]
        let ambientAudio: String?
        let lighting: LightingResponse?
        let wallEssayID: String?
        let transitions: [String]
    }

    let exhibitionId: String
    let title: String
    let rooms: [RoomResponse]
}

/// Base URL for links returned to the client (prefers `Host` / `X-Forwarded-Proto` when present).
private func publicBaseURL(for req: Request) -> URL {
    let fallback = URL(string: "http://127.0.0.1:\(req.application.http.server.configuration.port)")!
    guard let host = req.headers.first(name: .host), !host.isEmpty else {
        return fallback
    }
    let scheme = req.headers.first(name: "X-Forwarded-Proto") ?? "http"
    return URL(string: "\(scheme)://\(host)") ?? fallback
}

struct ArtworkPackageResponse: Content {
    struct DisplayManifestResponse: Content {
        let heroAssetURL: String
        let thumbnailURL: String
        let wallLabelMarkdown: String
    }

    struct EditionResponse: Content {
        let number: Int
        let total: Int
    }

    let id: UUID
    let title: String
    let tags: [String]
    let displayManifest: DisplayManifestResponse
    let edition: EditionResponse?
}

struct APIMetaResponse: Content {
    let ok: Bool
    let persistence: String
    let catalog: String
    let hasOpenAI: Bool
    let version: String
    let checkoutEnabled: Bool
    let generationEnabled: Bool
    let announcement: String?
    let adminPanelConfigured: Bool
    /// `true` when Dola has a real provider wired up (an OpenAI key is set on the server).
    /// The mock fallback returns `false` here so the iOS Studio knows when answers are deterministic stubs.
    let dolaAssistantConfigured: Bool
    /// Operator policy gate for `POST /api/dola/assist`. Honored by the iOS Studio “Ask Dola” button.
    let dolaAssistantEnabled: Bool
}

private func currentAdminPolicy(on application: Application) async -> AdminPolicySnapshot {
    if let store = application.adminPolicyStore {
        return await store.current()
    }
    return .default
}

func routes(_ app: Application) throws {
    app.get("health") { _ in
        HTTPStatus.ok
    }

    app.get("api", "meta") { req async throws -> APIMetaResponse in
        let persistence = req.application.generatedArtworkPersistenceKind?.rawValue ?? "unknown"
        let catalog = req.application.catalogPersistenceKind?.rawValue ?? "static"
        let policy = await currentAdminPolicy(on: req.application)
        return APIMetaResponse(
            ok: true,
            persistence: persistence,
            catalog: catalog,
            hasOpenAI: req.application.openAIImageService != nil,
            version: "1",
            checkoutEnabled: policy.checkoutEnabled,
            generationEnabled: policy.generationEnabled,
            announcement: policy.announcement,
            adminPanelConfigured: req.application.adminPanelConfigured,
            dolaAssistantConfigured: req.application.dolaAssistantService?.provider == .openai,
            dolaAssistantEnabled: policy.effectiveDolaAssistantEnabled
        )
    }

    app.get("api", "exhibitions") { req async throws -> [ExhibitionResponse] in
        let loader = req.application.catalogLoader ?? .static
        let base = publicBaseURL(for: req)
        return try await loader.exhibitions(publicBaseURL: base)
    }

    app.get("api", "exhibitions", ":slug", "manifest") { req async throws -> RoomManifestResponse in
        guard let slug = req.parameters.get("slug") else {
            throw Abort(.badRequest)
        }
        let loader = req.application.catalogLoader ?? .static
        return try await loader.manifest(slug: slug)
    }

    app.get("api", "essays") { req async throws -> [EssaySummaryResponse] in
        let loader = req.application.catalogLoader ?? .static
        return try await loader.essaySummaries()
    }

    app.get("api", "essays", ":id") { req async throws -> EssayResponse in
        guard let id = req.parameters.get("id") else { throw Abort(.badRequest) }
        let loader = req.application.catalogLoader ?? .static
        return try await loader.essay(id: id)
    }

    app.get("api", "exhibitions", ":slug", "artworks") { req async throws -> [ArtworkPackageResponse] in
        guard let slug = req.parameters.get("slug") else {
            throw Abort(.badRequest)
        }
        let loader = req.application.catalogLoader ?? .static
        let base = publicBaseURL(for: req)
        return try await loader.artworks(exhibitionSlug: slug, publicBaseURL: base)
    }

    let generation = app.grouped("api", "artworks").grouped(GenerationSecurityMiddleware())

    generation.get("generated") { req async throws -> [GeneratedArtworkRecord] in
        let limitRaw: String? = req.query["limit"]
        let limit = limitRaw.flatMap { Int($0) } ?? 20
        guard let store = req.application.generatedArtworkStore else {
            return []
        }
        return try await store.list(limit: limit)
    }

    generation.post("generate") { req async throws -> GeneratedArtworkRecord in
        let input = try req.content.decode(GenerateArtworkInput.self)
        guard input.prompt.trimmingCharacters(in: .whitespacesAndNewlines).count >= 12 else {
            throw Abort(.badRequest, reason: "Prompt must be at least 12 characters.")
        }

        let policy = await currentAdminPolicy(on: req.application)
        guard policy.generationEnabled else {
            throw Abort(.forbidden, reason: "Generation is disabled by gallery policy.")
        }

        let imageURL: URL
        if let imageService = req.application.openAIImageService {
            do {
                imageURL = try await imageService.generate(prompt: input.prompt)
            } catch {
                req.logger.warning("Image generation failed", metadata: [
                    "error": "\(error)"
                ])
                throw Abort(.badGateway, reason: "Image provider unavailable.")
            }
        } else {
            imageURL = URL(string: "https://images.unsplash.com/photo-1518770660439-4636190af475")!
        }

        let generationID = UUID()
        req.logger.info("Accepted generation intake", metadata: [
            "generationID": "\(generationID)",
            "artistID": "\(input.artistID)",
            "promptLength": "\(input.prompt.count)",
            "provider": req.application.openAIImageService == nil ? "mock" : "openai"
        ])
        let record = GeneratedArtworkRecord(
            id: generationID,
            status: "completed",
            imageURL: imageURL.absoluteString,
            prompt: input.prompt,
            provider: req.application.openAIImageService == nil ? "mock" : "openai",
            createdAt: Date()
        )
        if let store = req.application.generatedArtworkStore {
            try await store.append(record)
        }
        return record
    }

    app.post("api", "checkout", ":editionID") { req async throws -> CheckoutResponseDTO in
        guard req.parameters.get("editionID", as: UUID.self) != nil else {
            throw Abort(.badRequest)
        }
        let policy = await currentAdminPolicy(on: req.application)
        guard policy.checkoutEnabled else {
            throw Abort(.forbidden, reason: "Checkout is disabled by gallery policy.")
        }
        return CheckoutResponseDTO(checkoutURL: "https://checkout.stripe.com/pay/example-session")
    }

    app.post("api", "dola", "assist") { req async throws -> DolaAssistResponse in
        let input = try req.content.decode(DolaAssistRequest.self)
        let policy = await currentAdminPolicy(on: req.application)
        guard policy.effectiveDolaAssistantEnabled else {
            throw Abort(.forbidden, reason: "Dola assistant is disabled by gallery policy.")
        }
        let service = req.application.dolaAssistantService
            ?? DolaAssistantService(openAI: nil, model: "mock")
        return try await service.assist(input)
    }

    let admin = app.grouped("api", "admin").grouped(AdminSecurityMiddleware())
    admin.get("overview") { req async throws -> AdminOverviewDTO in
        let policy = await currentAdminPolicy(on: req.application)
        let generationTokenConfigured = !(req.application.generationAuthToken ?? "").isEmpty
        return AdminOverviewDTO(
            policy: policy,
            generationTokenConfigured: generationTokenConfigured,
            openAIConfigured: req.application.openAIImageService != nil,
            catalogPersistence: req.application.catalogPersistenceKind?.rawValue ?? "static",
            generationPersistence: req.application.generatedArtworkPersistenceKind?.rawValue ?? "unknown",
            dolaAssistantConfigured: req.application.dolaAssistantService?.provider == .openai,
            dolaAssistantProvider: req.application.dolaAssistantService?.provider.rawValue ?? "mock"
        )
    }

    admin.get("policy") { req async throws -> AdminPolicySnapshot in
        await currentAdminPolicy(on: req.application)
    }

    admin.put("policy") { req async throws -> AdminPolicySnapshot in
        let body = try req.content.decode(AdminPolicySnapshot.self)
        guard let store = req.application.adminPolicyStore else {
            throw Abort(.internalServerError, reason: "Admin policy store is not configured.")
        }
        await store.replace(with: body)
        return await store.current()
    }
}
