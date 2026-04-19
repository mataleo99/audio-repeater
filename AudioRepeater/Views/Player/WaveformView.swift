import SwiftUI
import DSWaveformImageViews
import DSWaveformImage

struct AudioWaveformView: View {
    let audioURL: URL
    let duration: TimeInterval
    let currentTime: TimeInterval
    let segments: [Segment]
    let onSeek: (TimeInterval) -> Void

    // How many seconds of audio are visible on screen at once
    private let visibleSeconds: Double = 10.0
    private let waveformHeight: CGFloat = 80

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let zoom = zoomFactor
            let totalWidth = screenWidth * zoom
            let offsetX = waveformOffset(screenWidth: screenWidth, totalWidth: totalWidth)

            ZStack(alignment: .leading) {
                // Background waveform (dimmed)
                WaveformView(audioURL: audioURL) { shape in
                    shape.fill(.tint.opacity(0.3))
                }
                .frame(width: totalWidth, height: waveformHeight)

                // Progress fill waveform (bright, masked to current position)
                WaveformView(audioURL: audioURL) { shape in
                    shape.fill(.tint)
                }
                .frame(width: totalWidth, height: waveformHeight)
                .mask(alignment: .leading) {
                    Rectangle()
                        .frame(width: progressWidth(in: totalWidth))
                }

                // Segment markers and playhead
                SegmentMarkerOverlay(
                    duration: duration,
                    currentTime: currentTime,
                    segments: segments,
                    width: totalWidth,
                    height: waveformHeight
                )
                .frame(width: totalWidth, height: waveformHeight)
            }
            .offset(x: offsetX)
            .frame(width: screenWidth, height: waveformHeight, alignment: .leading)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        // Map tap position back to time
                        let tapX = value.location.x - offsetX
                        let fraction = max(0, min(1, tapX / totalWidth))
                        let time = fraction * duration
                        onSeek(time)
                    }
            )
            .overlay(alignment: .center) {
                // Fixed playhead line at center of visible area
                if duration > visibleSeconds {
                    Rectangle()
                        .fill(.primary.opacity(0.8))
                        .frame(width: 2, height: waveformHeight)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(height: waveformHeight)
        .animation(.linear(duration: 0.1), value: currentTime)
    }

    private var zoomFactor: Double {
        guard duration > 0 else { return 1.0 }
        // For short audio (<= visibleSeconds), show the full track (zoom = 1)
        // For longer audio, zoom in proportionally
        return max(1.0, duration / visibleSeconds)
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(currentTime / duration) * totalWidth
    }

    private func waveformOffset(screenWidth: CGFloat, totalWidth: CGFloat) -> CGFloat {
        guard duration > 0, totalWidth > screenWidth else { return 0 }

        // Position of playhead in the full waveform
        let playheadX = CGFloat(currentTime / duration) * totalWidth

        // We want the playhead centered on screen
        let targetOffset = -(playheadX - screenWidth / 2)

        // Clamp so we don't scroll past the edges
        let minOffset = -(totalWidth - screenWidth)
        let maxOffset: CGFloat = 0
        return max(minOffset, min(maxOffset, targetOffset))
    }
}
