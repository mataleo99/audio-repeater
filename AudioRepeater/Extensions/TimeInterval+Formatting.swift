import Foundation

extension TimeInterval {
    var formattedTime: String {
        formatMatchingDuration(self)
    }

    func formatMatchingDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        let durationHours = Int(duration) / 3600

        if durationHours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
