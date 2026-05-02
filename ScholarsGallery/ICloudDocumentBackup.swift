import Foundation
import SwiftData
import os

enum ICloudDocumentBackup {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ScholarsGallery",
                                        category: "ICloudDocs")
    private static let backupFileName = "ScholarsGallery-Backup.json"

    private static var containerURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
    }

    // MARK: - Export full JSON snapshot to iCloud Documents

    @MainActor
    static func exportSnapshot(context: ModelContext) {
        guard let docsURL = containerURL else {
            logger.warning("iCloud Documents container unavailable")
            return
        }

        do {
            if !FileManager.default.fileExists(atPath: docsURL.path) {
                try FileManager.default.createDirectory(at: docsURL, withIntermediateDirectories: true)
            }

            let collectionRecords = (try? context.fetch(FetchDescriptor<PersistedCollectionRecord>())) ?? []
            let favorites = (try? context.fetch(FetchDescriptor<PersistedFavorite>())) ?? []
            let generatedArtworks = (try? context.fetch(FetchDescriptor<PersistedGeneratedArtwork>())) ?? []
            let exhibitions = (try? context.fetch(FetchDescriptor<CachedExhibition>())) ?? []
            let artworks = (try? context.fetch(FetchDescriptor<CachedArtwork>())) ?? []
            let essays = (try? context.fetch(FetchDescriptor<CachedEssay>())) ?? []

            let snapshot = BackupDocument(
                exportedAt: Date(),
                version: "1.0",
                collection: collectionRecords.map {
                    .init(artworkID: $0.artworkID, acquiredAt: $0.acquiredAt, certificateID: $0.certificateID)
                },
                favorites: favorites.map { $0.artworkID },
                generatedArtworks: generatedArtworks.map {
                    .init(id: $0.generationID, status: $0.status, imageURL: $0.imageURLString,
                          prompt: $0.prompt, provider: $0.provider, createdAt: $0.createdAt)
                },
                exhibitions: exhibitions.map {
                    .init(id: $0.exhibitionID, slug: $0.slug, title: $0.title, subtitle: $0.subtitle,
                          openingDate: $0.openingDate, manifestURL: $0.manifestURLString)
                },
                artworks: artworks.map {
                    .init(id: $0.artworkID, title: $0.title, tags: $0.tags,
                          heroAssetURL: $0.heroAssetURLString, thumbnailURL: $0.thumbnailURLString,
                          wallLabelMarkdown: $0.wallLabelMarkdown,
                          editionNumber: $0.editionNumber, editionTotal: $0.editionTotal,
                          exhibitionSlug: $0.exhibitionSlug)
                },
                essays: essays.map {
                    .init(id: $0.essayID, title: $0.title, author: $0.author,
                          markdownBody: $0.markdownBody, references: $0.references)
                }
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)

            let fileURL = docsURL.appendingPathComponent(backupFileName)
            try data.write(to: fileURL, options: .atomic)
            logger.info("Exported iCloud Documents backup (\(data.count) bytes)")
        } catch {
            logger.error("iCloud Documents export failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Import snapshot from iCloud Documents

    static func loadSnapshot() -> BackupDocument? {
        guard let docsURL = containerURL else { return nil }

        let fileURL = docsURL.appendingPathComponent(backupFileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(BackupDocument.self, from: data)
    }

    @MainActor
    static func restoreFromSnapshot(_ doc: BackupDocument, context: ModelContext) {
        for item in doc.collection {
            let artID = item.artworkID
            let descriptor = FetchDescriptor<PersistedCollectionRecord>(
                predicate: #Predicate { $0.artworkID == artID }
            )
            if (try? context.fetch(descriptor))?.first == nil {
                context.insert(PersistedCollectionRecord(
                    artworkID: item.artworkID,
                    acquiredAt: item.acquiredAt,
                    certificateID: item.certificateID,
                    syncedToCloud: false
                ))
            }
        }

        for fav in doc.favorites {
            let favID = fav
            let descriptor = FetchDescriptor<PersistedFavorite>(
                predicate: #Predicate { $0.artworkID == favID }
            )
            if (try? context.fetch(descriptor))?.first == nil {
                context.insert(PersistedFavorite(artworkID: fav))
            }
        }

        for gen in doc.generatedArtworks {
            let genID = gen.id
            let descriptor = FetchDescriptor<PersistedGeneratedArtwork>(
                predicate: #Predicate { $0.generationID == genID }
            )
            if (try? context.fetch(descriptor))?.first == nil {
                context.insert(PersistedGeneratedArtwork(
                    generationID: gen.id,
                    status: gen.status,
                    imageURLString: gen.imageURL,
                    prompt: gen.prompt,
                    provider: gen.provider,
                    createdAt: gen.createdAt
                ))
            }
        }

        try? context.save()
    }
}

// MARK: - Backup Document Schema

struct BackupDocument: Codable, Sendable {
    let exportedAt: Date
    let version: String
    let collection: [CollectionItem]
    let favorites: [String]
    let generatedArtworks: [GeneratedArtworkItem]
    let exhibitions: [ExhibitionItem]
    let artworks: [ArtworkItem]
    let essays: [EssayItem]

    struct CollectionItem: Codable, Sendable {
        let artworkID: String
        let acquiredAt: Date
        let certificateID: String
    }

    struct GeneratedArtworkItem: Codable, Sendable {
        let id: String
        let status: String
        let imageURL: String
        let prompt: String
        let provider: String
        let createdAt: Date
    }

    struct ExhibitionItem: Codable, Sendable {
        let id: String
        let slug: String
        let title: String
        let subtitle: String
        let openingDate: Date
        let manifestURL: String?
    }

    struct ArtworkItem: Codable, Sendable {
        let id: String
        let title: String
        let tags: [String]
        let heroAssetURL: String
        let thumbnailURL: String
        let wallLabelMarkdown: String
        let editionNumber: Int?
        let editionTotal: Int?
        let exhibitionSlug: String
    }

    struct EssayItem: Codable, Sendable {
        let id: String
        let title: String
        let author: String
        let markdownBody: String
        let references: [String]
    }
}
