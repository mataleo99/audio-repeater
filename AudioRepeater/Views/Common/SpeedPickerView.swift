import SwiftUI

struct SpeedPickerView: View {
    let speed: Float
    let onSpeedChanged: (Float) -> Void

    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    var body: some View {
        Menu {
            ForEach(speeds, id: \.self) { s in
                Button {
                    onSpeedChanged(s)
                } label: {
                    HStack {
                        Text(formatSpeed(s))
                        if abs(s - speed) < 0.01 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(formatSpeed(speed))
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.secondary.opacity(0.1))
                .clipShape(Capsule())
        }
    }

    private func formatSpeed(_ s: Float) -> String {
        if s == Float(Int(s)) {
            return "\(Int(s))x"
        }
        return String(format: "%.2gx", s)
    }
}
