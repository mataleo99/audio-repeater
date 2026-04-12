import SwiftUI

struct PlaybackControlsView: View {
    @Bindable var viewModel: PlayerViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Progress slider
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { viewModel.progress },
                        set: { newValue in
                            let time = newValue * viewModel.duration
                            viewModel.seek(to: time)
                        }
                    ),
                    in: 0...1
                )
                .disabled(!viewModel.isLoaded)

                HStack {
                    Text(viewModel.formattedCurrentTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Spacer()

                    Text(viewModel.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            // Transport controls
            HStack(spacing: 40) {
                Button {
                    viewModel.skipBackward()
                } label: {
                    Image(systemName: "gobackward.5")
                        .font(.title2)
                }
                .disabled(!viewModel.isLoaded)

                Button {
                    viewModel.togglePlayPause()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                }
                .disabled(!viewModel.isLoaded)

                Button {
                    viewModel.skipForward()
                } label: {
                    Image(systemName: "goforward.5")
                        .font(.title2)
                }
                .disabled(!viewModel.isLoaded)
            }
            .foregroundStyle(.primary)

            // Speed control
            SpeedPickerView(speed: viewModel.speed) { newSpeed in
                viewModel.setSpeed(newSpeed)
            }
        }
    }
}
