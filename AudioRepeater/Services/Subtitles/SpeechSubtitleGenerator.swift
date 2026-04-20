import Foundation
import Speech

struct SubtitleCueData: Sendable {
    let index: Int
    let start: TimeInterval
    let end: TimeInterval
    let text: String
}

struct SpeechSubtitleGenerator {
    /// Runs speech recognition and returns Sendable cue data.
    /// Safe to call from any isolation domain.
    static func recognizeSpeech(audioURL: URL) async throws -> [SubtitleCueData] {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .notDetermined {
            let granted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
            guard granted else { throw SpeechSubtitleError.notAuthorized }
        } else if status != .authorized {
            throw SpeechSubtitleError.notAuthorized
        }

        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw SpeechSubtitleError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.addsPunctuation = true
        request.requiresOnDeviceRecognition = false

        let wordData: [(substring: String, timestamp: TimeInterval, duration: TimeInterval)] =
            try await withCheckedThrowingContinuation { continuation in
                var hasResumed = false

                recognizer.recognitionTask(with: request) { result, error in
                    guard !hasResumed else { return }

                    if let result = result, result.isFinal {
                        hasResumed = true
                        let data = result.bestTranscription.segments.map {
                            (substring: $0.substring, timestamp: $0.timestamp, duration: $0.duration)
                        }
                        continuation.resume(returning: data)
                    } else if let error = error, result == nil {
                        hasResumed = true
                        continuation.resume(throwing: error)
                    }
                }
            }

        guard !wordData.isEmpty else {
            throw SpeechSubtitleError.noSpeechDetected
        }

        return buildCues(from: wordData)
    }

    private static func buildCues(
        from words: [(substring: String, timestamp: TimeInterval, duration: TimeInterval)]
    ) -> [SubtitleCueData] {
        var cues: [SubtitleCueData] = []
        var phraseWords: [String] = []
        var phraseStart: TimeInterval = words[0].timestamp
        var lastEnd: TimeInterval = words[0].timestamp + words[0].duration

        for word in words {
            let gap = word.timestamp - lastEnd
            let isPause = gap > 0.3

            let lastWord = phraseWords.last ?? ""
            let endsSentence = lastWord.hasSuffix(".") || lastWord.hasSuffix("?") ||
                              lastWord.hasSuffix("!") || lastWord.hasSuffix(";")

            if (isPause || endsSentence) && !phraseWords.isEmpty {
                let text = phraseWords.joined(separator: " ")
                cues.append(SubtitleCueData(index: cues.count + 1, start: phraseStart, end: lastEnd, text: text))
                phraseWords = []
                phraseStart = word.timestamp
            }

            phraseWords.append(word.substring)
            lastEnd = word.timestamp + word.duration
        }

        if !phraseWords.isEmpty {
            let text = phraseWords.joined(separator: " ")
            cues.append(SubtitleCueData(index: cues.count + 1, start: phraseStart, end: lastEnd, text: text))
        }

        return cues
    }

    enum SpeechSubtitleError: Error, LocalizedError {
        case notAuthorized
        case recognizerUnavailable
        case noSpeechDetected

        var errorDescription: String? {
            switch self {
            case .notAuthorized: return "Speech recognition not authorized. Go to Settings > Privacy > Speech Recognition to enable."
            case .recognizerUnavailable: return "Speech recognition is not available on this device. This feature requires a physical device with Siri enabled."
            case .noSpeechDetected: return "No speech detected in audio"
            }
        }
    }
}
