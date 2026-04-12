import Foundation
import SwiftData

@Model
final class Folder {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var sortOrder: Int
    var isPlaylist: Bool

    @Relationship(deleteRule: .nullify)
    var projects: [Project]

    @Relationship(deleteRule: .cascade, inverse: \Note.folder)
    var note: Note?

    init(name: String, isPlaylist: Bool = false) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.sortOrder = 0
        self.isPlaylist = isPlaylist
        self.projects = []
        self.note = nil
    }
}
