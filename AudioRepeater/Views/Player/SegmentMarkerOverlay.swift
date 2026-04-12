import SwiftUI

struct SegmentMarkerOverlay: View {
    let duration: TimeInterval
    let currentTime: TimeInterval
    let segments: [Segment]
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Canvas { context, size in
            guard duration > 0 else { return }

            // Draw current segment highlight
            if let current = currentSegment {
                let startX = CGFloat(current.startTime / duration) * width
                let endX = CGFloat(current.endTime / duration) * width
                let rect = CGRect(x: startX, y: 0, width: endX - startX, height: height)
                context.fill(Path(rect), with: .color(.blue.opacity(0.1)))
            }

            // Draw segment boundary lines
            for segment in segments {
                let x = CGFloat(segment.startTime / duration) * width
                if x > 0 {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))

                    let color: Color = segment.isMarkedHeart ? .red :
                                       segment.isMarkedStar ? .yellow : .gray
                    context.stroke(path, with: .color(color.opacity(0.6)), lineWidth: 1)
                }
            }

            // Draw playhead
            let playheadX = CGFloat(currentTime / duration) * width
            var playheadPath = Path()
            playheadPath.move(to: CGPoint(x: playheadX, y: 0))
            playheadPath.addLine(to: CGPoint(x: playheadX, y: height))
            context.stroke(playheadPath, with: .color(.primary), lineWidth: 2)
        }
        .allowsHitTesting(false)
    }

    private var currentSegment: Segment? {
        segments.first { currentTime >= $0.startTime && currentTime < $0.endTime }
    }
}
