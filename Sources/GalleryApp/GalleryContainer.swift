import SwiftData

@MainActor
public struct GalleryContainer {
    public let modelContainer: ModelContainer

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
}
