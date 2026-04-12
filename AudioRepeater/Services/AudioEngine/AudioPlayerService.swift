import AVFoundation

struct PlaybackState {
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var speed: Float = 1.0
    var isLoaded: Bool = false
}

@MainActor
@Observable
final class AudioPlayerService {
    private(set) var state = PlaybackState()

    private var engine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var timePitch = AVAudioUnitTimePitch()
    private var audioFile: AVAudioFile?
    private var seekFrame: AVAudioFramePosition = 0
    private var isPlayerReady = false
    private var timeUpdateTimer: Timer?

    init() {
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        engine.attach(playerNode)
        engine.attach(timePitch)
        engine.connect(playerNode, to: timePitch, format: nil)
        engine.connect(timePitch, to: engine.mainMixerNode, format: nil)
    }

    func load(url: URL) throws {
        stop()

        let file = try AVAudioFile(forReading: url)
        audioFile = file
        seekFrame = 0

        engine.disconnectNodeOutput(playerNode)
        engine.disconnectNodeOutput(timePitch)
        engine.connect(playerNode, to: timePitch, format: file.processingFormat)
        engine.connect(timePitch, to: engine.mainMixerNode, format: file.processingFormat)

        state.duration = Double(file.length) / file.processingFormat.sampleRate
        state.currentTime = 0
        state.isLoaded = true
        state.isPlaying = false

        isPlayerReady = true
    }

    func play() {
        guard isPlayerReady, let file = audioFile else { return }

        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                print("Failed to start audio engine: \(error)")
                return
            }
        }

        playerNode.stop()
        let frameCount = AVAudioFrameCount(file.length - seekFrame)
        guard frameCount > 0 else { return }

        playerNode.scheduleSegment(
            file,
            startingFrame: seekFrame,
            frameCount: frameCount,
            at: nil
        ) { [weak self] in
            Task { @MainActor [weak self] in
                self?.handlePlaybackCompletion()
            }
        }

        playerNode.play()
        startTimeUpdates()
        state.isPlaying = true
    }

    func pause() {
        guard isPlayerReady else { return }

        playerNode.pause()
        stopTimeUpdates()
        updateCurrentTime()
        state.isPlaying = false
    }

    func stop() {
        playerNode.stop()
        stopTimeUpdates()
        if engine.isRunning {
            engine.stop()
        }
        seekFrame = 0
        isPlayerReady = false

        state.isPlaying = false
        state.currentTime = 0
        state.isLoaded = false
    }

    func seek(to time: TimeInterval) {
        guard let file = audioFile else { return }

        let sampleRate = file.processingFormat.sampleRate
        let targetFrame = AVAudioFramePosition(time * sampleRate)
        seekFrame = max(0, min(targetFrame, file.length))
        state.currentTime = time

        if state.isPlaying {
            playerNode.stop()
            let frameCount = AVAudioFrameCount(file.length - seekFrame)
            guard frameCount > 0 else { return }

            playerNode.scheduleSegment(
                file,
                startingFrame: seekFrame,
                frameCount: frameCount,
                at: nil
            ) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handlePlaybackCompletion()
                }
            }
            playerNode.play()
        }
    }

    func setSpeed(_ speed: Float) {
        let clamped = max(AppConstants.minPlaybackSpeed, min(speed, AppConstants.maxPlaybackSpeed))
        timePitch.rate = clamped
        state.speed = clamped
    }

    // MARK: - Private

    private func computeCurrentTime() -> TimeInterval {
        guard let file = audioFile,
              let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else {
            return Double(seekFrame) / (audioFile?.processingFormat.sampleRate ?? 44100)
        }
        let currentFrame = seekFrame + playerTime.sampleTime
        return Double(currentFrame) / file.processingFormat.sampleRate
    }

    private func updateCurrentTime() {
        let time = computeCurrentTime()
        seekFrame = AVAudioFramePosition(time * (audioFile?.processingFormat.sampleRate ?? 44100))
        state.currentTime = time
    }

    private func startTimeUpdates() {
        stopTimeUpdates()
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateCurrentTime()
            }
        }
    }

    private func stopTimeUpdates() {
        timeUpdateTimer?.invalidate()
        timeUpdateTimer = nil
    }

    private func handlePlaybackCompletion() {
        stopTimeUpdates()
        seekFrame = 0
        state.isPlaying = false
        state.currentTime = 0
    }
}
