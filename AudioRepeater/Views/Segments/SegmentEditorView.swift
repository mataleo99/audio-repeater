import SwiftUI
import DSWaveformImageViews
import DSWaveformImage

struct SegmentEditorView: View {
    @Bindable var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSegmentId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Waveform with draggable handles
            if viewModel.isLoaded, let project = viewModel.currentProject {
                SegmentWaveformEditor(
                    audioURL: project.audioFileURL,
                    duration: viewModel.duration,
                    currentTime: viewModel.currentTime,
                    segments: viewModel.sortedSegments,
                    selectedSegmentId: $selectedSegmentId,
                    onSeek: { time in
                        viewModel.seek(to: time)
                    },
                    onUpdateBoundary: { segmentId, newStart, newEnd in
                        updateSegmentBoundary(segmentId: segmentId, newStart: newStart, newEnd: newEnd)
                    }
                )
                .frame(height: 120)
                .padding()
            }

            // Segment actions
            if let segId = selectedSegmentId,
               let segment = viewModel.sortedSegments.first(where: { $0.id == segId }) {
                VStack(spacing: 12) {
                    Text("Segment #\(segment.index + 1)")
                        .font(.headline)

                    Text("\(segment.startTime.formatMatchingDuration(viewModel.duration)) — \(segment.endTime.formatMatchingDuration(viewModel.duration))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    HStack(spacing: 16) {
                        Button {
                            splitSegment(segment)
                        } label: {
                            Label("Split", systemImage: "scissors")
                        }
                        .buttonStyle(.bordered)
                        .disabled(segment.duration < 1.0)

                        Button {
                            mergeWithNext(segment)
                        } label: {
                            Label("Merge Next", systemImage: "arrow.right.arrow.left")
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.sortedSegments.last?.id == segment.id)

                        Button(role: .destructive) {
                            deleteSegment(segment)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            } else {
                Text("Tap a segment to select it")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            }

            Spacer()
        }
        .navigationTitle("Edit Segments")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func updateSegmentBoundary(segmentId: UUID, newStart: TimeInterval, newEnd: TimeInterval) {
        guard let segment = viewModel.sortedSegments.first(where: { $0.id == segmentId }) else { return }
        segment.startTime = max(0, newStart)
        segment.endTime = min(viewModel.duration, newEnd)
    }

    private func splitSegment(_ segment: Segment) {
        guard let project = viewModel.currentProject else { return }
        let midpoint = (segment.startTime + segment.endTime) / 2

        // Create new segment for the second half
        let newSegment = Segment(
            startTime: midpoint,
            endTime: segment.endTime,
            index: segment.index + 1
        )

        // Shrink original to first half
        segment.endTime = midpoint

        // Increment index of all subsequent segments
        for seg in viewModel.sortedSegments where seg.index >= newSegment.index && seg.id != newSegment.id {
            seg.index += 1
        }

        project.segments.append(newSegment)
        selectedSegmentId = segment.id
    }

    private func mergeWithNext(_ segment: Segment) {
        guard let project = viewModel.currentProject else { return }
        let segs = viewModel.sortedSegments

        guard let idx = segs.firstIndex(where: { $0.id == segment.id }),
              idx + 1 < segs.count else { return }

        let nextSegment = segs[idx + 1]

        // Extend current segment to cover the next one
        segment.endTime = nextSegment.endTime

        // Remove the next segment
        project.segments.removeAll { $0.id == nextSegment.id }

        // Decrement index of all subsequent segments
        for seg in project.segments where seg.index > nextSegment.index {
            seg.index -= 1
        }

        selectedSegmentId = segment.id
    }

    private func deleteSegment(_ segment: Segment) {
        guard let project = viewModel.currentProject else { return }
        let deletedIndex = segment.index

        project.segments.removeAll { $0.id == segment.id }

        // Decrement index of subsequent segments
        for seg in project.segments where seg.index > deletedIndex {
            seg.index -= 1
        }

        selectedSegmentId = nil
    }
}

struct SegmentWaveformEditor: View {
    let audioURL: URL
    let duration: TimeInterval
    let currentTime: TimeInterval
    let segments: [Segment]
    @Binding var selectedSegmentId: UUID?
    let onSeek: (TimeInterval) -> Void
    let onUpdateBoundary: (UUID, TimeInterval, TimeInterval) -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack(alignment: .leading) {
                // Background waveform
                WaveformView(audioURL: audioURL) { shape in
                    shape.fill(.tint.opacity(0.2))
                }

                // Selected segment highlight
                if let selId = selectedSegmentId,
                   let segment = segments.first(where: { $0.id == selId }) {
                    let startX = timeToX(segment.startTime, width: width)
                    let endX = timeToX(segment.endTime, width: width)
                    Rectangle()
                        .fill(.tint.opacity(0.15))
                        .frame(width: endX - startX)
                        .offset(x: startX)
                }

                // Segment boundaries with drag handles
                ForEach(segments) { segment in
                    let startX = timeToX(segment.startTime, width: width)

                    // Boundary line
                    if segment.startTime > 0 {
                        Rectangle()
                            .fill(.secondary)
                            .frame(width: 1, height: height)
                            .offset(x: startX)

                        // Drag handle
                        Circle()
                            .fill(.tint)
                            .frame(width: 16, height: 16)
                            .offset(x: startX - 8, y: -height / 2 + 8)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newTime = xToTime(value.location.x, width: width)
                                        let segs = segments.sorted { $0.index < $1.index }
                                        guard let idx = segs.firstIndex(where: { $0.id == segment.id }) else { return }

                                        // Clamp to neighbors
                                        let minTime = idx > 0 ? segs[idx - 1].startTime + 0.1 : 0
                                        let maxTime = segment.endTime - 0.1
                                        let clampedTime = max(minTime, min(maxTime, newTime))

                                        // Update this segment's start and previous segment's end
                                        if idx > 0 {
                                            onUpdateBoundary(segs[idx - 1].id, segs[idx - 1].startTime, clampedTime)
                                        }
                                        onUpdateBoundary(segment.id, clampedTime, segment.endTime)
                                    }
                            )
                    }
                }

                // Playhead
                let playheadX = timeToX(currentTime, width: width)
                Rectangle()
                    .fill(.primary)
                    .frame(width: 2, height: height)
                    .offset(x: playheadX)
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                let time = xToTime(location.x, width: width)
                // Find which segment was tapped
                if let segment = segments.first(where: { time >= $0.startTime && time < $0.endTime }) {
                    selectedSegmentId = segment.id
                }
                onSeek(time)
            }
        }
    }

    private func timeToX(_ time: TimeInterval, width: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(time / duration) * width
    }

    private func xToTime(_ x: CGFloat, width: CGFloat) -> TimeInterval {
        guard width > 0 else { return 0 }
        return max(0, min(duration, Double(x / width) * duration))
    }
}
