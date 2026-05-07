import SwiftUI
import SwiftData
import GalleryCore

@MainActor
public struct GalleryContainer {
    public let modelContainer: ModelContainer

    public init() throws {
        let schema = Schema([SavedArtwork.self])
        let config = ModelConfiguration(
            "GalleryStore",
            schema: schema,
            isStoredInMemoryOnly: false
        )
        self.modelContainer = try ModelContainer(
            for: schema,
            configurations: [config]
        )
    }

    public static func makeFallback() -> ModelContainer {
        let schema = Schema([SavedArtwork.self])
        let config = ModelConfiguration(
            "GalleryStoreFallback",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try! ModelContainer(for: schema, configurations: [config])
    }
}
