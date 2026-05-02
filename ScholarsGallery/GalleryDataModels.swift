import Foundation
import SwiftData

@Model
final class CachedExhibition {
    @Attribute(.unique) var exhibitionID: String
    var slug: String
    var title: String
    var subtitle: String
    var openingDate: Date
    var manifestURLString: String?
    var lastSyncedAt: Date

    init(exhibitionID: String, slug: String, title: String, subtitle: String,
         openingDate: Date, manifestURLString: String?, lastSyncedAt: Date = Date()) {
        self.exhibitionID = exhibitionID
        self.slug = slug
        self.title = title
        self.subtitle = subtitle
        self.openingDate = openingDate
        self.manifestURLString = manifestURLString
        self.lastSyncedAt = lastSyncedAt
    }
}

@Model
final class CachedArtwork {
    @Attribute(.unique) var artworkID: String
    var title: String
    var tagsRaw: String
    var heroAssetURLString: String
    var thumbnailURLString: String
    var wallLabelMarkdown: String
    var editionNumber: Int?
    var editionTotal: Int?
    var exhibitionSlug: String
    var lastSyncedAt: Date

    var tags: [String] {
        tagsRaw.split(separator: "|").map(String.init)
    }

    init(artworkID: String, title: String, tags: [String],
         heroAssetURLString: String, thumbnailURLString: String,
         wallLabelMarkdown: String, editionNumber: Int?, editionTotal: Int?,
         exhibitionSlug: String, lastSyncedAt: Date = Date()) {
        self.artworkID = artworkID
        self.title = title
        self.tagsRaw = tags.joined(separator: "|")
        self.heroAssetURLString = heroAssetURLString
        self.thumbnailURLString = thumbnailURLString
        self.wallLabelMarkdown = wallLabelMarkdown
        self.editionNumber = editionNumber
        self.editionTotal = editionTotal
        self.exhibitionSlug = exhibitionSlug
        self.lastSyncedAt = lastSyncedAt
    }
}

@Model
final class CachedEssay {
    @Attribute(.unique) var essayID: String
    var title: String
    var author: String
    var markdownBody: String
    var referencesRaw: String
    var lastSyncedAt: Date

    var references: [String] {
        guard !referencesRaw.isEmpty else { return [] }
        return referencesRaw.split(separator: "|||").map(String.init)
    }

    init(essayID: String, title: String, author: String,
         markdownBody: String, references: [String],
         lastSyncedAt: Date = Date()) {
        self.essayID = essayID
        self.title = title
        self.author = author
        self.markdownBody = markdownBody
        self.referencesRaw = references.joined(separator: "|||")
        self.lastSyncedAt = lastSyncedAt
    }
}

@Model
final class PersistedCollectionRecord {
    @Attribute(.unique) var artworkID: String
    var acquiredAt: Date
    var certificateID: String
    var syncedToCloud: Bool

    init(artworkID: String, acquiredAt: Date, certificateID: String, syncedToCloud: Bool = false) {
        self.artworkID = artworkID
        self.acquiredAt = acquiredAt
        self.certificateID = certificateID
        self.syncedToCloud = syncedToCloud
    }
}

@Model
final class PersistedFavorite {
    @Attribute(.unique) var artworkID: String
    var addedAt: Date

    init(artworkID: String, addedAt: Date = Date()) {
        self.artworkID = artworkID
        self.addedAt = addedAt
    }
}

@Model
final class PersistedGeneratedArtwork {
    @Attribute(.unique) var generationID: String
    var status: String
    var imageURLString: String
    var prompt: String
    var provider: String
    var createdAt: Date

    init(generationID: String, status: String, imageURLString: String,
         prompt: String, provider: String, createdAt: Date) {
        self.generationID = generationID
        self.status = status
        self.imageURLString = imageURLString
        self.prompt = prompt
        self.provider = provider
        self.createdAt = createdAt
    }
}
