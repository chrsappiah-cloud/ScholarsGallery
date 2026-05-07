import Foundation

public struct Artist: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let biography: String
    public let role: String
    public let heroImageURL: URL?
    public let websiteURL: URL?
    public let exhibitionSlugs: [String]

    public init(
        id: UUID = UUID(),
        name: String,
        biography: String,
        role: String = "Artist",
        heroImageURL: URL? = nil,
        websiteURL: URL? = nil,
        exhibitionSlugs: [String] = []
    ) {
        self.id = id
        self.name = name
        self.biography = biography
        self.role = role
        self.heroImageURL = heroImageURL
        self.websiteURL = websiteURL
        self.exhibitionSlugs = exhibitionSlugs
    }
}
