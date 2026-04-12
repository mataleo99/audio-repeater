import Foundation
import SwiftData

@Observable
@MainActor
final class PlayerViewModel {
    private let audioService = AudioPlayerService()
    var currentProject: Project?

    var isPlaying: Bool { audioService.state.isPlaying }
    var currentTime: TimeInterval { audioService.state.currentTime }
    var duration: TimeInterval { audioService.state.duration }
    var speed: Float { audioService.state.speed }
    var isLoaded: Bool { audioService.state.isLoaded }

    func loadProject(_ project: Project) {
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
    }

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

    func savePosition() {
        currentProject?.lastPlaybackPosition = currentTime
    }

    var formattedCurrentTime: String {
        currentTime.formattedTime
    }

    var formattedDuration: String {
        duration.formattedTime
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
}
