import Foundation
import Vapor
import ScholarKit

enum CatalogPersistenceKind: String, Sendable {
    case `static`
    case supabase
}

private struct CatalogLoaderStorageKey: StorageKey {
    typealias Value = CatalogLoader
}

private struct CatalogPersistenceKindStorageKey: StorageKey {
    typealias Value = CatalogPersistenceKind
}

extension Application {
    /// When unset (e.g. minimal tests), routes treat catalog as ``CatalogLoader/static``.
    var catalogLoader: CatalogLoader? {
        get { storage[CatalogLoaderStorageKey.self] }
        set { storage[CatalogLoaderStorageKey.self] = newValue }
    }

    var catalogPersistenceKind: CatalogPersistenceKind? {
        get { storage[CatalogPersistenceKindStorageKey.self] }
        set { storage[CatalogPersistenceKindStorageKey.self] = newValue }
    }
}

enum CatalogLoader: Sendable {
    case `static`
    case supabase(projectURL: URL, serviceRoleKey: String)

    func exhibitions(publicBaseURL: URL) async throws -> [ExhibitionResponse] {
        switch self {
        case .static:
            return StaticCatalog.exhibitions(publicBaseURL: publicBaseURL)
        case .supabase(let projectURL, let key):
            return try await Self.supabaseExhibitions(projectURL: projectURL, serviceRoleKey: key, publicBaseURL: publicBaseURL)
        }
    }

    func manifest(slug: String) async throws -> RoomManifestResponse {
        switch self {
        case .static:
            return try StaticCatalog.manifest(slug: slug)
        case .supabase(let projectURL, let key):
            return try await Self.supabaseManifest(slug: slug, projectURL: projectURL, serviceRoleKey: key)
        }
    }

    func essaySummaries() async throws -> [EssaySummaryResponse] {
        switch self {
        case .static:
            return StaticCatalog.essaySummaries()
        case .supabase(let projectURL, let key):
            return try await Self.supabaseEssaySummaries(projectURL: projectURL, serviceRoleKey: key)
        }
    }

    func essay(id: String) async throws -> EssayResponse {
        switch self {
        case .static:
            return try StaticCatalog.essay(id: id)
        case .supabase(let projectURL, let key):
            return try await Self.supabaseEssay(id: id, projectURL: projectURL, serviceRoleKey: key)
        }
    }

    func artworks(exhibitionSlug: String, publicBaseURL: URL) async throws -> [ArtworkPackageResponse] {
        switch self {
        case .static:
            return try StaticCatalog.artworks(exhibitionSlug: exhibitionSlug, publicBaseURL: publicBaseURL)
        case .supabase(let projectURL, let key):
            return try await Self.supabaseArtworks(
                exhibitionSlug: exhibitionSlug,
                projectURL: projectURL,
                serviceRoleKey: key,
                publicBaseURL: publicBaseURL
            )
        }
    }

    // MARK: - Supabase (PostgREST)

    private static func restURL(projectURL: URL, table: String, queryItems: [URLQueryItem]?) throws -> URL {
        let base = projectURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var components = URLComponents(string: base + "/rest/v1/" + table)!
        components.queryItems = queryItems
        guard let url = components.url else {
            throw Abort(.badGateway, reason: "Invalid Supabase REST URL.")
        }
        return url
    }

    private static func supabaseGET(url: URL, serviceRoleKey: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(serviceRoleKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(serviceRoleKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        return try await ServerHTTPClient.perform(request, failurePrefix: "Supabase catalog GET")
    }

    private static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    private struct ExhibitionListRow: Decodable {
        let id: UUID
        let slug: String
        let title: String
        let subtitle: String
        let openingAt: Date
    }

    private struct ManifestRow: Decodable {
        let manifest: RoomManifestResponse
    }

    private struct EssaySummaryRow: Decodable {
        let id: String
        let title: String
        let author: String
    }

    private struct EssayDetailRow: Decodable {
        let id: String
        let title: String
        let author: String
        let markdownBody: String
        let references: [String]
    }

    private struct ArtworkRow: Decodable {
        let id: UUID
        let title: String
        let tags: [String]
        let heroAssetPath: String
        let thumbnailAssetPath: String?
        let wallLabelMarkdown: String
        let editionNumber: Int?
        let editionTotal: Int?
    }

    private static func supabaseExhibitions(
        projectURL: URL,
        serviceRoleKey: String,
        publicBaseURL: URL
    ) async throws -> [ExhibitionResponse] {
        let url = try restURL(
            projectURL: projectURL,
            table: "exhibitions",
            queryItems: [
                URLQueryItem(name: "select", value: "id,slug,title,subtitle,opening_at"),
                URLQueryItem(name: "order", value: "sort_order.asc"),
            ]
        )
        let data = try await supabaseGET(url: url, serviceRoleKey: serviceRoleKey)
        let rows = try makeDecoder().decode([ExhibitionListRow].self, from: data)
        return rows.map { row in
            let manifestURL = publicBaseURL
                .appendingPathComponent("api/exhibitions/\(row.slug)/manifest")
                .absoluteString
            return ExhibitionResponse(
                id: row.id,
                slug: row.slug,
                title: row.title,
                subtitle: row.subtitle,
                openingDate: row.openingAt,
                manifestURL: manifestURL
            )
        }
    }

    private static func supabaseManifest(slug: String, projectURL: URL, serviceRoleKey: String) async throws -> RoomManifestResponse {
        let url = try restURL(
            projectURL: projectURL,
            table: "exhibitions",
            queryItems: [
                URLQueryItem(name: "select", value: "manifest"),
                URLQueryItem(name: "slug", value: "eq.\(slug)"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        let data = try await supabaseGET(url: url, serviceRoleKey: serviceRoleKey)
        let rows = try JSONDecoder().decode([ManifestRow].self, from: data)
        guard let first = rows.first else {
            throw Abort(.notFound)
        }
        return first.manifest
    }

    private static func supabaseEssaySummaries(projectURL: URL, serviceRoleKey: String) async throws -> [EssaySummaryResponse] {
        let url = try restURL(
            projectURL: projectURL,
            table: "essays",
            queryItems: [
                URLQueryItem(name: "select", value: "id,title,author"),
                URLQueryItem(name: "order", value: "id.asc"),
            ]
        )
        let data = try await supabaseGET(url: url, serviceRoleKey: serviceRoleKey)
        let rows = try makeDecoder().decode([EssaySummaryRow].self, from: data)
        return rows.map { EssaySummaryResponse(id: $0.id, title: $0.title, author: $0.author) }
    }

    private static func supabaseEssay(id: String, projectURL: URL, serviceRoleKey: String) async throws -> EssayResponse {
        let url = try restURL(
            projectURL: projectURL,
            table: "essays",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "id", value: "eq.\(id)"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        let data = try await supabaseGET(url: url, serviceRoleKey: serviceRoleKey)
        let rows = try makeDecoder().decode([EssayDetailRow].self, from: data)
        guard let row = rows.first else {
            throw Abort(.notFound)
        }
        return EssayResponse(
            id: row.id,
            title: row.title,
            author: row.author,
            markdownBody: row.markdownBody,
            references: row.references
        )
    }

    private static func absoluteMediaURL(publicBaseURL: URL, assetPath: String) -> String {
        let trimmed = assetPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let base = publicBaseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return base + "/" + trimmed
    }

    private static func supabaseArtworks(
        exhibitionSlug: String,
        projectURL: URL,
        serviceRoleKey: String,
        publicBaseURL: URL
    ) async throws -> [ArtworkPackageResponse] {
        let url = try restURL(
            projectURL: projectURL,
            table: "exhibition_artworks",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "exhibition_slug", value: "eq.\(exhibitionSlug)"),
                URLQueryItem(name: "order", value: "sort_order.asc"),
            ]
        )
        let data = try await supabaseGET(url: url, serviceRoleKey: serviceRoleKey)
        let decoder = makeDecoder()
        let rows = try decoder.decode([ArtworkRow].self, from: data)
        guard !rows.isEmpty else {
            throw Abort(.notFound)
        }
        return rows.map { row in
            let hero = absoluteMediaURL(publicBaseURL: publicBaseURL, assetPath: row.heroAssetPath)
            let thumb = absoluteMediaURL(
                publicBaseURL: publicBaseURL,
                assetPath: row.thumbnailAssetPath ?? row.heroAssetPath
            )
            let edition: ArtworkPackageResponse.EditionResponse? = {
                guard let n = row.editionNumber, let t = row.editionTotal else { return nil }
                return ArtworkPackageResponse.EditionResponse(number: n, total: t)
            }()
            return ArtworkPackageResponse(
                id: row.id,
                title: row.title,
                tags: row.tags,
                displayManifest: .init(
                    heroAssetURL: hero,
                    thumbnailURL: thumb,
                    wallLabelMarkdown: row.wallLabelMarkdown
                ),
                edition: edition
            )
        }
    }
}

// MARK: - Static catalog (default / fallback)

enum StaticCatalog {
    static let worldsExhibitionID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private static let artworkOneID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    private static let artworkTwoID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
    private static let artworkThreeID = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
    private static let artworkFourID = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!

    static func exhibitions(publicBaseURL: URL) -> [ExhibitionResponse] {
        [
            ExhibitionResponse(
                id: worldsExhibitionID,
                slug: "worlds-written-in-light",
                title: "Worlds Written in Light",
                subtitle: "A scholarly immersive biennale of generative media.",
                openingDate: .now,
                manifestURL: publicBaseURL
                    .appendingPathComponent("api/exhibitions/worlds-written-in-light/manifest")
                    .absoluteString
            ),
        ]
    }

    static func manifest(slug: String) throws -> RoomManifestResponse {
        guard slug == "worlds-written-in-light" else {
            throw Abort(.notFound)
        }
        return RoomManifestResponse(
            exhibitionId: "worlds-written-in-light",
            title: "Worlds Written in Light",
            rooms: [
                .init(
                    id: "threshold",
                    kind: "intro",
                    title: "Threshold",
                    artworkIDs: ["a1", "a2"],
                    ambientAudio: "ambient/threshold.m4a",
                    lighting: RoomManifestResponse.LightingResponse(preset: "soft_gold", intensity: 0.45),
                    wallEssayID: nil,
                    transitions: ["theory-hall"]
                ),
                .init(
                    id: "theory-hall",
                    kind: "essay-space",
                    title: "Theory Hall",
                    artworkIDs: ["a3"],
                    ambientAudio: nil,
                    lighting: RoomManifestResponse.LightingResponse(preset: "neutral_white", intensity: 0.30),
                    wallEssayID: "essay-001",
                    transitions: ["threshold"]
                ),
            ]
        )
    }

    static func essaySummaries() -> [EssaySummaryResponse] {
        [
            EssaySummaryResponse(
                id: "essay-001",
                title: "Generative Art as Scholarly Surface",
                author: "ScholarsGallery Editorial Board"
            ),
            EssaySummaryResponse(
                id: "essay-002",
                title: "Curation in Spatial Digital Museums",
                author: "Curatorial Systems Lab"
            ),
        ]
    }

    static func essay(id: String) throws -> EssayResponse {
        let essay: ScholarlyEssay
        switch id {
        case "essay-002":
            essay = ScholarlyEssay(
                id: id,
                title: "Curation in Spatial Digital Museums",
                author: "Curatorial Systems Lab",
                markdownBody: """
                Spatial digital museums ask curators to choreograph **attention, navigation, and evidence** \
                across rooms that behave like essays, datasets, and stages at once.
                """,
                references: ["Whitney Artport", "Serpentine R&D", "MoMA Post"]
            )
        default:
            essay = ScholarlyEssay(
                id: id,
                title: "Generative Art as Scholarly Surface",
                author: "ScholarsGallery Editorial Board",
                markdownBody: """
                This essay examines generative media as a scholarly object:
                provenance, interpretation, and computational aesthetics.
                """,
                references: ["teamLab", "ARTECHOUSE", "Museum of Other Realities"]
            )
        }
        return EssayResponse(
            id: essay.id,
            title: essay.title,
            author: essay.author,
            markdownBody: essay.markdownBody,
            references: essay.references
        )
    }

    static func artworks(exhibitionSlug: String, publicBaseURL: URL) throws -> [ArtworkPackageResponse] {
        guard exhibitionSlug == "worlds-written-in-light" else {
            throw Abort(.notFound)
        }
        func wcsPromoURL(_ filename: String) -> String {
            publicBaseURL.appendingPathComponent("media/wcs-social-promo/\(filename)").absoluteString
        }
        return [
            ArtworkPackageResponse(
                id: artworkOneID,
                title: "WCS — Three Apps Suite",
                tags: ["WCS", "Social", "Product"],
                displayManifest: .init(
                    heroAssetURL: wcsPromoURL("promo_three_apps_suite_1080.png"),
                    thumbnailURL: wcsPromoURL("promo_three_apps_suite_1080.png"),
                    wallLabelMarkdown: "Social promo: the **ScholarsGallery** suite alongside companion WCS apps — one story across three surfaces."
                ),
                edition: .init(number: 1, total: 20)
            ),
            ArtworkPackageResponse(
                id: artworkTwoID,
                title: "Explore WCS",
                tags: ["WCS", "Brand", "Discovery"],
                displayManifest: .init(
                    heroAssetURL: wcsPromoURL("promo_explore_wcs_1080.png"),
                    thumbnailURL: wcsPromoURL("promo_explore_wcs_1080.png"),
                    wallLabelMarkdown: "Invitation to explore the **World Computational Salon** platform and gallery ecosystem."
                ),
                edition: .init(number: 2, total: 20)
            ),
            ArtworkPackageResponse(
                id: artworkThreeID,
                title: "WCS Platform",
                tags: ["WCS", "Platform", "Scholarship"],
                displayManifest: .init(
                    heroAssetURL: wcsPromoURL("promo_wcs_platform_1080.png"),
                    thumbnailURL: wcsPromoURL("promo_wcs_platform_1080.png"),
                    wallLabelMarkdown: "Platform-wide social asset highlighting **scholarship, curation, and generative media** under WCS."
                ),
                edition: .init(number: 3, total: 20)
            ),
            ArtworkPackageResponse(
                id: artworkFourID,
                title: "Ethereal Veil",
                tags: ["WCS", "Aesthetic", "Light"],
                displayManifest: .init(
                    heroAssetURL: wcsPromoURL("promo_ethereal_veil_1080.png"),
                    thumbnailURL: wcsPromoURL("promo_ethereal_veil_1080.png"),
                    wallLabelMarkdown: "Brand-forward **ethereal veil** visual from the WCS social promo set — light, depth, and digital atmosphere."
                ),
                edition: .init(number: 4, total: 20)
            ),
        ]
    }
}
