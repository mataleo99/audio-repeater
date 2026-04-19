import Foundation

enum AppConstants {
    static let audioDirectory = "Audio"

    // Playback
    static let defaultPlaybackSpeed: Float = 1.0
    static let minPlaybackSpeed: Float = 0.5
    static let maxPlaybackSpeed: Float = 2.0
    static let playbackSpeedStep: Float = 0.1

    // Silence Detection
    static let defaultSilenceThresholdDB: Float = -35.0
    static let defaultMinSilenceDuration: TimeInterval = 0.1
    static let defaultMinSegmentDuration: TimeInterval = 1.0
    static let rmsWindowSize: Int = 441 // ~10ms at 44100Hz

    // Speech-based segmentation
    static let defaultMinPauseBetweenPhrases: TimeInterval = 0.0

    // Auto-pause
    static let defaultAutoPauseDuration: TimeInterval = 0.0

    // UI
    static let recentFilesLimit = 20
    static let seekBackwardInterval: TimeInterval = 5.0
    static let seekForwardInterval: TimeInterval = 5.0

    // Supported formats
    static let supportedAudioExtensions = ["mp3", "m4a", "wav", "aac", "aiff", "caf"]
    static let supportedSubtitleExtensions = ["srt", "vtt"]
}
