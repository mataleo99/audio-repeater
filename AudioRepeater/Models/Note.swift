import Foundation
import SwiftData

@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var text: String
    var updatedAt: Date
    var project: Project?
    var folder: Folder?

    init(text: String = "") {
        self.id = UUID()
        self.text = text
        self.updatedAt = Date()
    }
}
