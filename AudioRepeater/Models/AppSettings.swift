import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: UUID
    var themeName: String
    var subtitleFontSize: Double
    var reminderEnabled: Bool
    var reminderTime: Date?
    var silenceThresholdDB: Float
    var minSilenceDuration: TimeInterval
    var minSegmentDuration: TimeInterval

    init() {
        self.id = UUID()
        self.themeName = "system"
        self.subtitleFontSize = 17.0
        self.reminderEnabled = false
        self.reminderTime = nil
        self.silenceThresholdDB = AppConstants.defaultSilenceThresholdDB
        self.minSilenceDuration = AppConstants.defaultMinSilenceDuration
        self.minSegmentDuration = AppConstants.defaultMinSegmentDuration
    }
}
