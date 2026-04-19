import Foundation
import os
import SwiftData

private let logger = Logger(subsystem: "com.audiorepeater.app", category: "SegmentationEngine")

@ModelActor
actor SegmentationEngine {
    func segmentProject(projectID: PersistentIdentifier, audioURL: URL, duration: TimeInterval) async throws {
        let detector = SilenceDetector()
        let silenceRegions = try detector.detectSilence(in: audioURL)
        logger.info("Silence detection found \(silenceRegions.count) regions")

        // Convert silence regions to segment boundaries
        var segments: [(start: TimeInterval, end: TimeInterval)] = []

        if silenceRegions.isEmpty {
            segments.append((start: 0, end: duration))
        } else {
            // First segment: from file start to first silence
            if silenceRegions[0].start > 0 {
                let end = silenceRegions[0].start
                if end >= AppConstants.defaultMinSegmentDuration {
                    segments.append((start: 0, end: end))
                }
            }

            // Middle segments: between consecutive silence regions
            for i in 0..<(silenceRegions.count - 1) {
                let start = silenceRegions[i].end
                let end = silenceRegions[i + 1].start
                let segDuration = end - start
                if segDuration >= AppConstants.defaultMinSegmentDuration {
                    segments.append((start: start, end: end))
                } else if !segments.isEmpty {
                    // Merge short segment into previous
                    segments[segments.count - 1] = (start: segments.last!.start, end: silenceRegions[i + 1].start)
                }
            }

            // Last segment: from last silence to file end
            if let lastSilence = silenceRegions.last, lastSilence.end < duration {
                let start = lastSilence.end
                let segDuration = duration - start
                if segDuration >= AppConstants.defaultMinSegmentDuration {
                    segments.append((start: start, end: duration))
                } else if !segments.isEmpty {
                    segments[segments.count - 1] = (start: segments.last!.start, end: duration)
                }
            }
        }

        if segments.isEmpty {
            segments.append((start: 0, end: duration))
        }

        logger.info("Created \(segments.count) segments from \(silenceRegions.count) silence regions")

        // Delete existing segments for this project
        guard let project = modelContext.model(for: projectID) as? Project else { return }
        for existing in project.segments {
            modelContext.delete(existing)
        }

        // Create new segments
        for (index, seg) in segments.enumerated() {
            let segment = Segment(startTime: seg.start, endTime: seg.end, index: index)
            segment.project = project
            modelContext.insert(segment)
        }

        project.segmentationMode = "silence"
        try modelContext.save()
    }
}
