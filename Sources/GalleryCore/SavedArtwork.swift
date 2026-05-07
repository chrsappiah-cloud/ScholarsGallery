import Foundation
import SwiftData

@Model
public final class SavedArtwork {
    @Attribute(.unique) public var artworkID: String
    public var title: String
    public var artistName: String
    public var thumbnailURLString: String
    public var tagsRaw: String
    public var editionLabel: String?
    public var savedAt: Date

    public var tags: [String] {
        guard !tagsRaw.isEmpty else { return [] }
        return tagsRaw.split(separator: "|").map(String.init)
    }

    public var thumbnailURL: URL? { URL(string: thumbnailURLString) }

    public init(
        artworkID: String,
        title: String,
        artistName: String = "",
        thumbnailURLString: String = "",
        tags: [String] = [],
        editionLabel: String? = nil,
        savedAt: Date = Date()
    ) {
        self.artworkID = artworkID
        self.title = title
        self.artistName = artistName
        self.thumbnailURLString = thumbnailURLString
        self.tagsRaw = tags.joined(separator: "|")
        self.editionLabel = editionLabel
        self.savedAt = savedAt
    }
}
