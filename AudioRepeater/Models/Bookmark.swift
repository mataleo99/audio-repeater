import Foundation
import SwiftData

@Model
final class Bookmark {
    @Attribute(.unique) var id: UUID
    var timestamp: TimeInterval
    var label: String
    var tags: [String]
    var createdAt: Date
    var project: Project?

    init(
        timestamp: TimeInterval,
        label: String = "",
        tags: [String] = []
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.label = label
        self.tags = tags
        self.createdAt = Date()
    }
}
