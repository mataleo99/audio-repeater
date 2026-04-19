import Foundation
import os
import Speech

private let logger = Logger(subsystem: "com.audiorepeater.app", category: "SpeechSegmenter")

struct WordTiming: Sendable {
    let timestamp: TimeInterval
    let duration: TimeInterval
}

struct SpeechSegmenter {
    let minPauseDuration: TimeInterval
    let minSegmentDuration: TimeInterval

    init(
        minPauseDuration: TimeInterval = AppConstants.defaultMinPauseBetweenPhrases,
        minSegmentDuration: TimeInterval = AppConstants.defaultMinSegmentDuration
    ) {
        self.minPauseDuration = minPauseDuration
        self.minSegmentDuration = minSegmentDuration
    }

    func detectPhrases(in url: URL, duration: TimeInterval) async throws -> [(start: TimeInterval, end: TimeInterval)] {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .notDetermined {
            let granted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
            guard granted else { throw SpeechSegmenterError.notAuthorized }
        } else if status != .authorized {
            throw SpeechSegmenterError.notAuthorized
        }

        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw SpeechSegmenterError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.addsPunctuation = true

        // Extract word timings inside the callback to avoid sending non-Sendable SFSpeechRecognitionResult
        let wordTimings: [WordTiming] = try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let result = result, result.isFinal {
                    let timings = result.bestTranscription.segments.map { seg in
                        WordTiming(timestamp: seg.timestamp, duration: seg.duration)
                    }
                    continuation.resume(returning: timings)
                }
            }
        }

        return buildSegments(from: wordTimings, duration: duration)
    }

    private func buildSegments(from wordTimings: [WordTiming], duration: TimeInterval) -> [(start: TimeInterval, end: TimeInterval)] {
        guard !wordTimings.isEmpty else {
            return [(start: 0, end: duration)]
        }

        // Find pause points: gaps between consecutive words that exceed minPauseDuration
        // The Speech framework often reports durations that span to the next word,
        // so we use timestamp differences instead: gap = next.timestamp - (current.timestamp + current.duration)
        // But duration can be inaccurate — also check timestamp-to-timestamp gaps.
        var breakpoints: [TimeInterval] = []

        for i in 0..<(wordTimings.count - 1) {
            let currentEnd = wordTimings[i].timestamp + wordTimings[i].duration
            let nextStart = wordTimings[i + 1].timestamp

            // Use the larger of: explicit gap, or timestamp-based gap
            let gap = nextStart - currentEnd

            // Also compute a normalized gap: time between word starts minus expected word duration
            // This catches cases where duration is reported as 0
            let timestampGap = nextStart - wordTimings[i].timestamp
            let effectiveGap = max(gap, timestampGap - wordTimings[i].duration)

            if effectiveGap >= minPauseDuration {
                let splitTime = min(currentEnd, nextStart)
                breakpoints.append(splitTime)
            }

            // Debug: log gaps to understand the data
            if i < 30 || effectiveGap > 0.1 {
                logger.info("Word \(i): ts=\(String(format: "%.3f", wordTimings[i].timestamp)) dur=\(String(format: "%.3f", wordTimings[i].duration)) gap=\(String(format: "%.3f", gap)) effective=\(String(format: "%.3f", effectiveGap))")
            }
        }

        // Build segments from breakpoints
        var segments: [(start: TimeInterval, end: TimeInterval)] = []
        var segStart: TimeInterval = 0

        for bp in breakpoints {
            let segDuration = bp - segStart
            if segDuration >= minSegmentDuration {
                segments.append((start: segStart, end: bp))
            } else if !segments.isEmpty {
                // Merge short segment into previous
                segments[segments.count - 1] = (start: segments.last!.start, end: bp)
            }
            segStart = bp
        }

        // Final segment
        if segStart < duration {
            let segDuration = duration - segStart
            if segDuration >= minSegmentDuration {
                segments.append((start: segStart, end: duration))
            } else if !segments.isEmpty {
                segments[segments.count - 1] = (start: segments.last!.start, end: duration)
            } else {
                segments.append((start: segStart, end: duration))
            }
        }

        return segments.isEmpty ? [(start: 0, end: duration)] : segments
    }

    enum SpeechSegmenterError: Error, LocalizedError {
        case notAuthorized
        case recognizerUnavailable

        var errorDescription: String? {
            switch self {
            case .notAuthorized: return "Speech recognition not authorized"
            case .recognizerUnavailable: return "Speech recognizer unavailable"
            }
        }
    }
}
