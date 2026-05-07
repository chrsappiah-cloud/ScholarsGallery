import Foundation

public struct GalleryFeature: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let subtitle: String
    public let imageURL: URL?
    public let category: Category

    public enum Category: String, Codable, Hashable, Sendable {
        case exhibition
        case artwork
        case artist
        case journal
        case collection
    }

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        imageURL: URL? = nil,
        category: Category = .exhibition
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.imageURL = imageURL
        self.category = category
    }
}
