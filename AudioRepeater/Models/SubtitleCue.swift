import Foundation
import SwiftData

@Model
final class SubtitleCue {
    @Attribute(.unique) var id: UUID
    var index: Int
    var startTime: TimeInterval
    var endTime: TimeInterval
    var text: String
    var track: SubtitleTrack?

    init(
        index: Int,
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String
    ) {
        self.id = UUID()
        self.index = index
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
}
