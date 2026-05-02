import Foundation
import SwiftData
import CloudKit

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
        let cloudConfig = ModelConfiguration(
            "GalleryCloud",
            schema: schema,
            cloudKitDatabase: .automatic
        )
        return try ModelContainer(for: schema, configurations: [cloudConfig])
    }

    static func makeFallbackContainer() throws -> ModelContainer {
        let localConfig = ModelConfiguration(
            "GalleryLocal",
            schema: schema,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [localConfig])
    }
}
