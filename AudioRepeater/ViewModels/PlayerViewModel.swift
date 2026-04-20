import Foundation
import SwiftData

@Observable
@MainActor
final class PlayerViewModel {
    private let audioService = AudioPlayerService()
    var currentProject: Project?
    var isSegmenting = false

    // Loop: continuously replay current segment
    var isLooping = false

    // Phrase mode: after current segment ends, pause and wait for user to tap "Play Next Phrase"
    var isPhraseMode = false

    // Auto-pause between segments during normal playback (not loop/phrase mode)
    var isAutoPauseEnabled = false
    private var autoPauseTimer: Timer?

    /// The index of the segment we're currently monitoring for its end boundary.
    private var watchingSegmentIndex: Int?

    var isPlaying: Bool { audioService.state.isPlaying }
    var currentTime: TimeInterval { audioService.state.currentTime }
    var duration: TimeInterval { audioService.state.duration }
    var speed: Float { audioService.state.speed }
    var isLoaded: Bool { audioService.state.isLoaded }

    var statusDescription: String? {
        if isLooping { return "Looping" }
        if isPhraseMode && !isPlaying { return "Phrase ended" }
        if isPhraseMode { return "Phrase mode" }
        if isAutoPaused { return "Paused" }
        return nil
    }

    var isAutoPaused: Bool {
        autoPauseTimer != nil
    }

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

    // MARK: - Subtitles

    var primarySubtitleTrack: SubtitleTrack? {
        currentProject?.subtitleTracks.first { $0.isPrimary }
            ?? currentProject?.subtitleTracks.first
    }

    var hasSubtitles: Bool {
        !(currentProject?.subtitleTracks.isEmpty ?? true)
    }

    var isGeneratingSubtitles = false
    var subtitleError: String?

    // MARK: - Project Loading

    func loadProject(_ project: Project, modelContainer: ModelContainer) {
        currentProject = project
        project.lastOpenedAt = Date()

        isAutoPauseEnabled = project.autoPauseDuration > 0

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

        // Set up boundary monitoring
        audioService.onTimeUpdate = { [weak self] time in
            self?.onTimeUpdate(time)
        }

        // Always run segmentation on load to pick up latest settings
        runSegmentation(for: project, modelContainer: modelContainer)
    }

    func runSegmentation(for project: Project, modelContainer: ModelContainer) {
        isSegmenting = true
        let projectID = project.persistentModelID
        let audioURL = project.audioFileURL
        let duration = project.duration

        Task { @MainActor [weak self] in
            await Task.detached {
                do {
                    let engine = SegmentationEngine(modelContainer: modelContainer)
                    try await engine.segmentProject(projectID: projectID, audioURL: audioURL, duration: duration)
                } catch {
                    print("Segmentation error: \(error)")
                }
            }.value

            guard let self else { return }
            // Refresh: fetch segments from a fresh context and copy into the project
            let freshContext = ModelContext(modelContainer)
            var descriptor = FetchDescriptor<Segment>()
            descriptor.predicate = #Predicate<Segment> { segment in
                segment.project?.persistentModelID == projectID
            }
            if let freshSegments = try? freshContext.fetch(descriptor) {
                self.currentProject?.segments = freshSegments.map { fresh in
                    Segment(startTime: fresh.startTime, endTime: fresh.endTime, index: fresh.index)
                }
            }
            self.isSegmenting = false
        }
    }

    func resegment(modelContainer: ModelContainer) {
        guard let project = currentProject else { return }
        project.segments.removeAll()
        watchingSegmentIndex = nil
        isLooping = false
        isPhraseMode = false
        cancelAutoPause()
        runSegmentation(for: project, modelContainer: modelContainer)
    }

    // MARK: - Segment Boundary Monitoring

    private func onTimeUpdate(_ time: TimeInterval) {
        guard hasSegments,
              isLooping || isPhraseMode || isAutoPauseEnabled else { return }

        let segs = sortedSegments

        guard let watchIdx = watchingSegmentIndex else {
            watchingSegmentIndex = segs.firstIndex(where: { time >= $0.startTime && time < $0.endTime })
            return
        }

        guard watchIdx < segs.count else { return }
        let watchedSegment = segs[watchIdx]

        if time >= watchedSegment.endTime {
            handleSegmentEnd(segmentIndex: watchIdx)
        }
    }

    private func handleSegmentEnd(segmentIndex: Int) {
        let segs = sortedSegments

        if isLooping {
            // Loop: seek back to start of this segment, keep playing
            guard segmentIndex < segs.count else { return }
            let segment = segs[segmentIndex]
            watchingSegmentIndex = segmentIndex
            audioService.seek(to: segment.startTime)
        } else if isPhraseMode {
            // Phrase mode: pause at end, wait for user to tap "Play Next Phrase"
            audioService.pause()
        } else if isAutoPauseEnabled {
            // Auto-pause: pause briefly, then continue
            let nextIdx = segmentIndex + 1
            if nextIdx < segs.count {
                watchingSegmentIndex = nextIdx
            }
            startAutoPause()
        }
    }

    private func startAutoPause() {
        let pauseDuration = currentProject?.autoPauseDuration ?? 1.0
        audioService.pause()

        autoPauseTimer?.invalidate()
        autoPauseTimer = Timer.scheduledTimer(withTimeInterval: pauseDuration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.endAutoPause()
            }
        }
    }

    private func endAutoPause() {
        autoPauseTimer?.invalidate()
        autoPauseTimer = nil
        audioService.play()
    }

    private func cancelAutoPause() {
        autoPauseTimer?.invalidate()
        autoPauseTimer = nil
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        if isAutoPaused {
            endAutoPause()
            return
        }

        if isPlaying {
            audioService.pause()
        } else {
            // Clear phrase mode so playback continues past segment boundaries
            isPhraseMode = false
            audioService.play()
        }
    }

    func toggleLoop() {
        isLooping.toggle()
        if isLooping {
            // Cancel phrase mode when entering loop
            isPhraseMode = false
            cancelAutoPause()
            // Start watching the current segment
            if let idx = currentSegmentIndex {
                watchingSegmentIndex = idx
            }
            // If not playing, start playing
            if !isPlaying {
                audioService.play()
            }
        }
    }

    func playNextPhrase() {
        // Advance to next segment. If looping, keep looping the new segment.
        // If not looping, enable phrase mode (pause at end of next segment).
        if !isLooping {
            isPhraseMode = true
        }
        cancelAutoPause()

        let segs = sortedSegments
        guard !segs.isEmpty else { return }

        // Find the next segment to play
        var targetIdx: Int
        if let idx = currentSegmentIndex {
            // If we're paused at the end of a segment (phrase ended),
            // the currentSegmentIndex might be nil (between segments).
            // Use watchingSegmentIndex in that case.
            targetIdx = idx + 1
        } else if let watchIdx = watchingSegmentIndex {
            // We're paused at the end of a segment — advance from there
            targetIdx = watchIdx + 1
        } else {
            // Start from the beginning
            targetIdx = 0
        }

        // Clamp or wrap
        if targetIdx >= segs.count {
            targetIdx = 0
        }

        let segment = segs[targetIdx]
        watchingSegmentIndex = targetIdx
        audioService.seek(to: segment.startTime)
        audioService.play()
    }

    func seek(to time: TimeInterval) {
        cancelAutoPause()
        audioService.seek(to: time)
        let segs = sortedSegments
        watchingSegmentIndex = segs.firstIndex(where: { time >= $0.startTime && time < $0.endTime })
    }

    func setSpeed(_ speed: Float) {
        currentProject?.playbackSpeed = speed
        audioService.setSpeed(speed)
    }

    func setAutoPauseDuration(_ duration: TimeInterval) {
        currentProject?.autoPauseDuration = duration
        isAutoPauseEnabled = duration > 0
    }

    // MARK: - Segment Navigation

    func nextSegment() {
        cancelAutoPause()
        let segs = sortedSegments
        guard !segs.isEmpty else { return }

        if let idx = currentSegmentIndex, idx + 1 < segs.count {
            audioService.seek(to: segs[idx + 1].startTime)
            watchingSegmentIndex = idx + 1
        } else if let first = segs.first(where: { $0.startTime > currentTime }) {
            let idx = segs.firstIndex(where: { $0.id == first.id })
            audioService.seek(to: first.startTime)
            watchingSegmentIndex = idx
        }
    }

    func previousSegment() {
        cancelAutoPause()
        let segs = sortedSegments
        guard !segs.isEmpty else { return }

        if let idx = currentSegmentIndex {
            let current = segs[idx]
            if currentTime - current.startTime > 2.0 {
                audioService.seek(to: current.startTime)
                watchingSegmentIndex = idx
            } else if idx > 0 {
                audioService.seek(to: segs[idx - 1].startTime)
                watchingSegmentIndex = idx - 1
            } else {
                audioService.seek(to: current.startTime)
                watchingSegmentIndex = idx
            }
        } else if let last = segs.last(where: { $0.endTime <= currentTime }) {
            let idx = segs.firstIndex(where: { $0.id == last.id })
            audioService.seek(to: last.startTime)
            watchingSegmentIndex = idx
        } else {
            audioService.seek(to: 0)
            watchingSegmentIndex = nil
        }
    }

    // MARK: - Segment Marking

    func toggleHeart(for segment: Segment) {
        segment.isMarkedHeart.toggle()
    }

    func toggleStar(for segment: Segment) {
        segment.isMarkedStar.toggle()
    }

    func toggleHeartCurrentSegment() {
        guard let segment = currentSegment else { return }
        segment.isMarkedHeart.toggle()
    }

    func toggleStarCurrentSegment() {
        guard let segment = currentSegment else { return }
        segment.isMarkedStar.toggle()
    }

    // MARK: - Subtitles

    func generateSubtitles(modelContext: ModelContext) {
        guard let project = currentProject else { return }
        isGeneratingSubtitles = true
        subtitleError = nil

        let audioURL = project.audioFileURL
        Task {
            do {
                let cueData = try await SpeechSubtitleGenerator.recognizeSpeech(audioURL: audioURL)

                // Remove existing auto-generated tracks
                let existingAuto = project.subtitleTracks.filter { $0.isAutoGenerated }
                for track in existingAuto {
                    modelContext.delete(track)
                }

                let track = SubtitleTrack(
                    fileName: "auto-generated",
                    language: "en",
                    isPrimary: project.subtitleTracks.filter({ !$0.isAutoGenerated }).isEmpty,
                    isAutoGenerated: true
                )
                track.project = project
                modelContext.insert(track)

                for cue in cueData {
                    let subtitleCue = SubtitleCue(
                        index: cue.index,
                        startTime: cue.start,
                        endTime: cue.end,
                        text: cue.text
                    )
                    subtitleCue.track = track
                    modelContext.insert(subtitleCue)
                }

                try modelContext.save()
            } catch {
                subtitleError = error.localizedDescription
                print("Subtitle generation failed: \(error)")
            }
            isGeneratingSubtitles = false
        }
    }

    // MARK: - Bookmarks

    func addBookmark(label: String = "", tags: [String] = []) {
        guard let project = currentProject else { return }
        let bookmark = Bookmark(timestamp: currentTime, label: label, tags: tags)
        project.bookmarks.append(bookmark)
    }

    func deleteBookmark(_ bookmark: Bookmark) {
        currentProject?.bookmarks.removeAll { $0.id == bookmark.id }
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
