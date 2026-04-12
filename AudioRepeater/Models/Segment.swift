import Foundation
import SwiftData

@Model
final class Segment {
    @Attribute(.unique) var id: UUID
    var startTime: TimeInterval
    var endTime: TimeInterval
    var index: Int
    var isMarkedHeart: Bool
    var isMarkedStar: Bool
    var project: Project?

    init(
        startTime: TimeInterval,
        endTime: TimeInterval,
        index: Int
    ) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.index = index
        self.isMarkedHeart = false
        self.isMarkedStar = false
    }

    var duration: TimeInterval {
        endTime - startTime
    }
}
