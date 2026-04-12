import SwiftUI

struct ProjectRowView: View {
    let project: Project

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .background(.tint.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(project.duration.formattedTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(project.audioFormat.uppercased())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.1))
                        .clipShape(Capsule())

                    if project.lastPlaybackPosition > 0 && project.duration > 0 {
                        let pct = min(100, Int(project.lastPlaybackPosition / project.duration * 100))
                        Text("\(pct)%")
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                }
            }

            Spacer()

            if let lastOpened = project.lastOpenedAt {
                Text(lastOpened, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
