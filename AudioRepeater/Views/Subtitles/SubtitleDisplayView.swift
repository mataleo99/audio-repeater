import SwiftUI

struct SubtitleDisplayView: View {
    let subtitleTrack: SubtitleTrack
    let currentTime: TimeInterval
    var fontSize: Double = 17.0

    private var currentCue: SubtitleCue? {
        subtitleTrack.cues.first { currentTime >= $0.startTime && currentTime < $0.endTime }
    }

    var body: some View {
        Group {
            if let cue = currentCue {
                Text(cue.text)
                    .font(.system(size: fontSize))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.15), value: cue.id)
            } else {
                Color.clear
                    .frame(height: 1)
            }
        }
        .padding(.horizontal)
    }
}
