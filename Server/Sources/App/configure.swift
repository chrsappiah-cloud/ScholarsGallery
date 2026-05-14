import Vapor
import OpenAIConnector

private struct OpenAIImageServiceStorageKey: StorageKey {
    typealias Value = OpenAIImageService
}

extension Application {
    var openAIImageService: OpenAIImageService? {
        get { storage[OpenAIImageServiceStorageKey.self] }
        set { storage[OpenAIImageServiceStorageKey.self] = newValue }
    }
}

func configure(_ app: Application) throws {
    app.routes.defaultMaxBodySize = "10mb"

    let bindHost = Environment.get("BIND_HOST") ?? "127.0.0.1"
    let bindPort = Environment.get("PORT").flatMap(Int.init) ?? 8081
    app.http.server.configuration.hostname = bindHost
    app.http.server.configuration.port = bindPort
    app.logger.info("ScholarsGalleryServer HTTP bind", metadata: [
        "host": "\(bindHost)",
        "port": "\(bindPort)",
    ])

    let jsonEncoder = JSONCoding.makeEncoder()
    let jsonDecoder = JSONCoding.makeDecoder()
    ContentConfiguration.global.use(encoder: jsonEncoder, for: .json)
    ContentConfiguration.global.use(decoder: jsonDecoder, for: .json)

    let publicDirectory = ServerPaths.publicDirectory
    let publicURL = URL(fileURLWithPath: publicDirectory, isDirectory: true)
    try FileManager.default.createDirectory(at: publicURL, withIntermediateDirectories: true)
    app.middleware.use(FileMiddleware(publicDirectory: publicDirectory))
    let openAIKey = (Environment.get("OPENAI_API_KEY") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if !openAIKey.isEmpty {
        app.openAIImageService = OpenAIImageService(apiKey: openAIKey)
    }

    let dolaModel = (Environment.get("DOLA_ASSISTANT_MODEL") ?? "gpt-4o-mini")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let dolaForceMock = (Environment.get("DOLA_ASSISTANT_PROVIDER") ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased() == "mock"
    let dolaChatService: OpenAIChatService? = (openAIKey.isEmpty || dolaForceMock)
        ? nil
        : OpenAIChatService(apiKey: openAIKey)
    app.dolaAssistantService = DolaAssistantService(openAI: dolaChatService, model: dolaModel)
    app.logger.info("Dola assistant provider: \(app.dolaAssistantService?.provider.rawValue ?? "mock") (model=\(dolaModel))")

    let scholarModel = (Environment.get("SCHOLAR_DESCRIPTION_MODEL") ?? "gpt-4o-mini")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let scholarChatService: OpenAIChatService? = openAIKey.isEmpty ? nil : OpenAIChatService(apiKey: openAIKey)
    app.scholarlyDescriptionService = ScholarlyDescriptionService(openAI: scholarChatService, model: scholarModel)
    app.logger.info("Scholarly description provider: \(app.scholarlyDescriptionService?.provider.rawValue ?? "mock") (model=\(scholarModel))")
    if let token = Environment.get("GENERATION_API_TOKEN"), !token.isEmpty {
        app.generationAuthToken = token
    }
    let maxPerMinute = Int(Environment.get("GENERATION_RATE_LIMIT_PER_MINUTE") ?? "") ?? 20
    app.generationRateLimiter = GenerationRateLimiter(maxRequests: maxPerMinute, intervalSeconds: 60)
    let storeURL = ServerPaths.generatedArtworksStoreURL().standardizedFileURL
    let storeParent = storeURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: storeParent, withIntermediateDirectories: true)

    let supabaseURLString = (Environment.get("SUPABASE_URL") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let supabaseKey = (Environment.get("SUPABASE_SERVICE_ROLE_KEY") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if !supabaseURLString.isEmpty, !supabaseKey.isEmpty, let projectURL = URL(string: supabaseURLString) {
        app.generatedArtworkStore = GeneratedArtworkStore(supabaseProjectURL: projectURL, serviceRoleKey: supabaseKey)
        app.generatedArtworkPersistenceKind = .supabase
        app.catalogLoader = .supabase(projectURL: projectURL, serviceRoleKey: supabaseKey)
        app.catalogPersistenceKind = .supabase
        app.logger.info("Generation history persistence: Supabase (PostgREST)")
        app.logger.info("Gallery catalog: Supabase (PostgREST); apply supabase/migrations for exhibitions, essays, artworks")
    } else {
        app.generatedArtworkStore = GeneratedArtworkStore(fileURL: storeURL)
        app.generatedArtworkPersistenceKind = .file
        app.catalogLoader = .static
        app.catalogPersistenceKind = .static
        app.logger.info("Generation history persistence: local JSON file")
        app.logger.info("Gallery catalog: bundled static JSON (no Supabase)")
    }

    let adminPolicyURL = ServerPaths.adminPolicyFileURL().standardizedFileURL
    let adminPolicyParent = adminPolicyURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: adminPolicyParent, withIntermediateDirectories: true)
    app.adminPolicyStore = AdminPolicyStore(fileURL: adminPolicyURL)

    let adminToken = (Environment.get("ADMIN_API_TOKEN") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if !adminToken.isEmpty {
        app.adminAPIToken = adminToken
        app.logger.info("Admin API enabled for /api/admin/* (send X-Admin-Token)")
    } else {
        app.logger.info("Admin API disabled until ADMIN_API_TOKEN is set")
    }

    let collectionStoreURL = ServerPaths.generatedArtworksStoreURL()
        .deletingLastPathComponent()
        .appendingPathComponent("collection-store.json")
    app.collectionStore = CollectionStoreActor(fileURL: collectionStoreURL)

    try routes(app)
    try registerCollectionRoutes(app)
}
