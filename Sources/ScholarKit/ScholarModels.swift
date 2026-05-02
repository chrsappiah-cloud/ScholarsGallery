import Foundation
import CoreModels

public struct ScholarlyEssay: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let author: String
    public let markdownBody: String
    public let references: [String]

    public init(id: String, title: String, author: String, markdownBody: String, references: [String]) {
        self.id = id
        self.title = title
        self.author = author
        self.markdownBody = markdownBody
        self.references = references
    }
}
