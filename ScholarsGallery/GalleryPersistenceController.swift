import Foundation
import SwiftData

enum GalleryPersistence {
    static let allModels: [any PersistentModel.Type] = [
        CachedExhibition.self,
        CachedArtwork.self,
        CachedEssay.self,
        PersistedCollectionRecord.self,
        PersistedFavorite.self,
        PersistedGeneratedArtwork.self
    ]

    static let schema = Schema(allModels)

    static func makeContainer() throws -> ModelContainer {
        // Keep SwiftData local-only. Cloud sync is handled explicitly via CloudKitSyncManager.
        let localConfig = ModelConfiguration(
            "GalleryLocal",
            schema: schema,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [localConfig])
    }

    static func makeFallbackContainer() throws -> ModelContainer {
        let fallbackConfig = ModelConfiguration(
            "GalleryFallback",
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [fallbackConfig])
    }
}
