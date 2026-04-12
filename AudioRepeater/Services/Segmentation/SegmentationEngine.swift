import Foundation
import SwiftData

@ModelActor
actor SegmentationEngine {
    func segmentProject(projectID: PersistentIdentifier, audioURL: URL, duration: TimeInterval) throws {
        let detector = SilenceDetector()
        let silenceRegions = try detector.detectSilence(in: audioURL)

        // Convert silence regions to segment boundaries
        // Segments are the non-silent regions between silence gaps
        var segments: [(start: TimeInterval, end: TimeInterval)] = []

        if silenceRegions.isEmpty {
            // No silence found — treat entire file as one segment
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
                }
            }

            // Last segment: from last silence to file end
            if let lastSilence = silenceRegions.last, lastSilence.end < duration {
                let start = lastSilence.end
                let segDuration = duration - start
                if segDuration >= AppConstants.defaultMinSegmentDuration {
                    segments.append((start: start, end: duration))
                }
            }
        }

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
