import Foundation

public struct Exhibition: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let slug: String
    public let title: String
    public let subtitle: String
    public let openingDate: Date
    public let manifestURL: URL?

    public init(
        id: UUID = UUID(),
        slug: String,
        title: String,
        subtitle: String,
        openingDate: Date,
        manifestURL: URL? = nil
    ) {
        self.id = id
        self.slug = slug
        self.title = title
        self.subtitle = subtitle
        self.openingDate = openingDate
        self.manifestURL = manifestURL
    }
}

public struct ArtworkPackage: Codable, Hashable, Identifiable, Sendable {
    public enum Medium: String, Codable, Hashable, Sendable {
        case generatedImage
        case realtimeGenerative
        case video
        case hybridSpatial
    }

    public struct Edition: Codable, Hashable, Sendable {
        public let number: Int
        public let total: Int
        public let priceMinor: Int
        public let currency: String
        public let collectorRights: [String]

        public init(number: Int, total: Int, priceMinor: Int, currency: String, collectorRights: [String]) {
            self.number = number
            self.total = total
            self.priceMinor = priceMinor
            self.currency = currency
            self.collectorRights = collectorRights
        }
    }

    public struct GenerationSpec: Codable, Hashable, Sendable {
        public let provider: String
        public let model: String
        public let prompt: String
        public let negativePrompt: String?
        public let seed: Int?
        public let aspectRatio: String
        public let version: String

        public init(
            provider: String,
            model: String,
            prompt: String,
            negativePrompt: String?,
            seed: Int?,
            aspectRatio: String,
            version: String
        ) {
            self.provider = provider
            self.model = model
            self.prompt = prompt
            self.negativePrompt = negativePrompt
            self.seed = seed
            self.aspectRatio = aspectRatio
            self.version = version
        }
    }

    public struct DisplayManifest: Codable, Hashable, Sendable {
        public let heroAssetURL: URL
        public let thumbnailURL: URL
        public let ambientAudioURL: URL?
        public let realtimeConfigURL: URL?
        public let wallLabelMarkdown: String
        public let scholarlyEssayID: String?

        public init(
            heroAssetURL: URL,
            thumbnailURL: URL,
            ambientAudioURL: URL?,
            realtimeConfigURL: URL?,
            wallLabelMarkdown: String,
            scholarlyEssayID: String?
        ) {
            self.heroAssetURL = heroAssetURL
            self.thumbnailURL = thumbnailURL
            self.ambientAudioURL = ambientAudioURL
            self.realtimeConfigURL = realtimeConfigURL
            self.wallLabelMarkdown = wallLabelMarkdown
            self.scholarlyEssayID = scholarlyEssayID
        }
    }

    public let id: UUID
    public let slug: String
    public let title: String
    public let artistID: UUID
    public let medium: Medium
    public let generationSpec: GenerationSpec?
    public let edition: Edition?
    public let displayManifest: DisplayManifest
    public let tags: [String]
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        slug: String,
        title: String,
        artistID: UUID,
        medium: Medium,
        generationSpec: GenerationSpec?,
        edition: Edition?,
        displayManifest: DisplayManifest,
        tags: [String],
        createdAt: Date = .now
    ) {
        self.id = id
        self.slug = slug
        self.title = title
        self.artistID = artistID
        self.medium = medium
        self.generationSpec = generationSpec
        self.edition = edition
        self.displayManifest = displayManifest
        self.tags = tags
        self.createdAt = createdAt
    }
}

public struct RoomManifest: Codable, Hashable, Sendable {
    public struct Lighting: Codable, Hashable, Sendable {
        public let preset: String
        public let intensity: Double

        public init(preset: String, intensity: Double) {
            self.preset = preset
            self.intensity = intensity
        }
    }

    public struct Room: Codable, Hashable, Sendable, Identifiable {
        public let id: String
        public let kind: String
        public let title: String
        public let artworkIDs: [String]
        public let ambientAudio: String?
        public let lighting: Lighting?
        public let wallEssayID: String?
        public let transitions: [String]

        public init(
            id: String,
            kind: String,
            title: String,
            artworkIDs: [String],
            ambientAudio: String?,
            lighting: Lighting?,
            wallEssayID: String?,
            transitions: [String]
        ) {
            self.id = id
            self.kind = kind
            self.title = title
            self.artworkIDs = artworkIDs
            self.ambientAudio = ambientAudio
            self.lighting = lighting
            self.wallEssayID = wallEssayID
            self.transitions = transitions
        }
    }

    public let exhibitionId: String
    public let title: String
    public let rooms: [Room]

    public init(exhibitionId: String, title: String, rooms: [Room]) {
        self.exhibitionId = exhibitionId
        self.title = title
        self.rooms = rooms
    }
}
