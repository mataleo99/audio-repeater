import SwiftUI

struct PlayerView: View {
    let project: Project
    @State private var viewModel = PlayerViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Title
            VStack(spacing: 8) {
                Text(project.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text(project.audioFormat.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.1))
                    .clipShape(Capsule())

                if viewModel.hasSegments {
                    Text("\(viewModel.sortedSegments.count) segments")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if viewModel.isSegmenting {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Analyzing audio...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Waveform
            if viewModel.isLoaded {
                AudioWaveformView(
                    audioURL: project.audioFileURL,
                    duration: viewModel.duration,
                    currentTime: viewModel.currentTime,
                    segments: viewModel.sortedSegments,
                    onSeek: { time in
                        viewModel.seek(to: time)
                    }
                )
                .padding(.horizontal)
                .padding(.bottom, 16)
            }

            // Playback controls
            PlaybackControlsView(viewModel: viewModel)
                .padding(.horizontal)
                .padding(.bottom, 40)
        }
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadProject(project, modelContainer: modelContext.container)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                viewModel.savePosition()
            }
        }
    }
}
