import Foundation
import MediaPlayer

struct NowPlayingCommandHandlers {
    let togglePlayPause: () -> Void
    let play: () -> Void
    let pause: () -> Void
    let nextTrack: () -> Void
    let previousTrack: () -> Void
    let skipForward: (TimeInterval) -> Void
    let skipBackward: (TimeInterval) -> Void
    let seek: (TimeInterval) -> Void
}

@MainActor
final class NowPlayingService {
    static let shared = NowPlayingService()

    private var handlers: NowPlayingCommandHandlers?
    private var registered = false

    private init() {}

    func register(handlers: NowPlayingCommandHandlers) {
        self.handlers = handlers
        guard !registered else { return }
        registered = true

        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            self?.handlers?.play()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.handlers?.pause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.handlers?.togglePlayPause()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.handlers?.nextTrack()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.handlers?.previousTrack()
            return .success
        }

        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak self] event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            self?.handlers?.skipForward(interval)
            return .success
        }

        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            self?.handlers?.skipBackward(interval)
            return .success
        }

        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.handlers?.seek(positionEvent.positionTime)
            return .success
        }
    }

    func update(
        title: String,
        artist: String? = nil,
        duration: TimeInterval,
        elapsed: TimeInterval,
        isPlaying: Bool,
        rate: Float
    ) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? rate : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: rate,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        if let artist {
            info[MPMediaItemPropertyArtist] = artist
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }
}
