import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var title: String
    var audioFileName: String
    var audioFormat: String
    var duration: TimeInterval
    var lastPlaybackPosition: TimeInterval
    var lastOpenedAt: Date?
    var createdAt: Date
    var playbackSpeed: Float
    var autoPauseDuration: TimeInterval
    var repeatCount: Int
    var segmentationMode: String

    @Relationship(deleteRule: .cascade, inverse: \Segment.project)
    var segments: [Segment]

    @Relationship(deleteRule: .cascade, inverse: \Bookmark.project)
    var bookmarks: [Bookmark]

    @Relationship(deleteRule: .cascade, inverse: \SubtitleTrack.project)
    var subtitleTracks: [SubtitleTrack]

    @Relationship(deleteRule: .nullify, inverse: \Folder.projects)
    var folder: Folder?

    @Relationship(deleteRule: .cascade, inverse: \Note.project)
    var note: Note?

    init(
        title: String,
        audioFileName: String,
        audioFormat: String,
        duration: TimeInterval = 0
    ) {
        self.id = UUID()
        self.title = title
        self.audioFileName = audioFileName
        self.audioFormat = audioFormat
        self.duration = duration
        self.lastPlaybackPosition = 0
        self.lastOpenedAt = nil
        self.createdAt = Date()
        self.playbackSpeed = AppConstants.defaultPlaybackSpeed
        self.autoPauseDuration = AppConstants.defaultAutoPauseDuration
        self.repeatCount = 0
        self.segmentationMode = "silence"
        self.segments = []
        self.bookmarks = []
        self.subtitleTracks = []
        self.folder = nil
        self.note = nil
    }

    var audioFileURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL
            .appendingPathComponent(AppConstants.audioDirectory)
            .appendingPathComponent(audioFileName)
    }
}
