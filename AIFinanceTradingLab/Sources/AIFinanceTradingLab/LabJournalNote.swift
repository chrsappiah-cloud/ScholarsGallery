import Foundation
import SwiftData

/// Single SwiftData entity for the trading lab (local journal / scratch notes).
@Model
final class LabJournalNote {
    var title: String
    var createdAt: Date

    init(title: String, createdAt: Date = .now) {
        self.title = title
        self.createdAt = createdAt
    }
}
