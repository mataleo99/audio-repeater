import AVFoundation

final class AudioSessionManager: Sendable {
    static let shared = AudioSessionManager()

    private init() {}

    func configure() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    func handleInterruption(_ notification: Notification) -> InterruptionEvent? {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return nil
        }

        switch type {
        case .began:
            return .began
        case .ended:
            let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            return .ended(shouldResume: options.contains(.shouldResume))
        @unknown default:
            return nil
        }
    }

    enum InterruptionEvent {
        case began
        case ended(shouldResume: Bool)
    }
}
