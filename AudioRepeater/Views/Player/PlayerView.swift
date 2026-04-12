import SwiftUI

struct PlayerView: View {
    let project: Project
    @State private var viewModel = PlayerViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Title
            VStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 60))
                    .foregroundStyle(.tint)

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
            }

            Spacer()

            // Playback controls
            PlaybackControlsView(viewModel: viewModel)
                .padding(.horizontal)
                .padding(.bottom, 40)
        }
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadProject(project)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                viewModel.savePosition()
            }
        }
    }
}
