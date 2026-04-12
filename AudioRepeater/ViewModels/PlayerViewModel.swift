import Foundation
import SwiftData

@Observable
@MainActor
final class PlayerViewModel {
    private let audioService = AudioPlayerService()
    var currentProject: Project?
    var isSegmenting = false

    var isPlaying: Bool { audioService.state.isPlaying }
    var currentTime: TimeInterval { audioService.state.currentTime }
    var duration: TimeInterval { audioService.state.duration }
    var speed: Float { audioService.state.speed }
    var isLoaded: Bool { audioService.state.isLoaded }

    // MARK: - Segments

    var sortedSegments: [Segment] {
        currentProject?.segments.sorted(by: { $0.index < $1.index }) ?? []
    }

    var currentSegment: Segment? {
        sortedSegments.first { currentTime >= $0.startTime && currentTime < $0.endTime }
    }

    var currentSegmentIndex: Int? {
        guard let current = currentSegment else { return nil }
        return sortedSegments.firstIndex(where: { $0.id == current.id })
    }

    var hasSegments: Bool {
        !(currentProject?.segments.isEmpty ?? true)
    }

    // MARK: - Project Loading

    func loadProject(_ project: Project, modelContainer: ModelContainer) {
        currentProject = project
        project.lastOpenedAt = Date()

        do {
            try audioService.load(url: project.audioFileURL)
            if project.lastPlaybackPosition > 0 {
                audioService.seek(to: project.lastPlaybackPosition)
            }
            if project.playbackSpeed != 1.0 {
                audioService.setSpeed(project.playbackSpeed)
            }
        } catch {
            print("Failed to load audio: \(error)")
        }

        // Run segmentation if no segments exist
        if project.segments.isEmpty {
            runSegmentation(for: project, modelContainer: modelContainer)
        }
    }

    func runSegmentation(for project: Project, modelContainer: ModelContainer) {
        isSegmenting = true
        let projectID = project.persistentModelID
        let audioURL = project.audioFileURL
        let duration = project.duration

        Task.detached {
            let engine = SegmentationEngine(modelContainer: modelContainer)
            try? await engine.segmentProject(projectID: projectID, audioURL: audioURL, duration: duration)
            await MainActor.run { [weak self] in
                self?.isSegmenting = false
            }
        }
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        if isPlaying {
            audioService.pause()
        } else {
            audioService.play()
        }
    }

    func seek(to time: TimeInterval) {
        audioService.seek(to: time)
    }

    func setSpeed(_ speed: Float) {
        currentProject?.playbackSpeed = speed
        audioService.setSpeed(speed)
    }

    func skipForward() {
        let target = min(currentTime + AppConstants.seekForwardInterval, duration)
        seek(to: target)
    }

    func skipBackward() {
        let target = max(currentTime - AppConstants.seekBackwardInterval, 0)
        seek(to: target)
    }

    // MARK: - Segment Navigation

    func nextSegment() {
        let segs = sortedSegments
        guard !segs.isEmpty else { return }

        if let idx = currentSegmentIndex, idx + 1 < segs.count {
            seek(to: segs[idx + 1].startTime)
        } else if let first = segs.first(where: { $0.startTime > currentTime }) {
            seek(to: first.startTime)
        }
    }

    func previousSegment() {
        let segs = sortedSegments
        guard !segs.isEmpty else { return }

        if let idx = currentSegmentIndex {
            // If we're more than 2s into the current segment, restart it
            let current = segs[idx]
            if currentTime - current.startTime > 2.0 {
                seek(to: current.startTime)
            } else if idx > 0 {
                seek(to: segs[idx - 1].startTime)
            } else {
                seek(to: current.startTime)
            }
        } else if let last = segs.last(where: { $0.endTime <= currentTime }) {
            seek(to: last.startTime)
        } else {
            seek(to: 0)
        }
    }

    // MARK: - State

    func savePosition() {
        currentProject?.lastPlaybackPosition = currentTime
    }

    var formattedCurrentTime: String {
        currentTime.formatMatchingDuration(duration)
    }

    var formattedDuration: String {
        duration.formatMatchingDuration(duration)
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
}
