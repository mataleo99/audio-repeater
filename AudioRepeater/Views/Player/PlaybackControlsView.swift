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

                    if let status = viewModel.statusDescription {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.tint)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    Text(viewModel.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            // Row 1: Back / Play-Pause / Forward
            HStack(spacing: 40) {
                Button {
                    viewModel.previousSegment()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title)
                }
                .disabled(!viewModel.isLoaded || !viewModel.hasSegments)

                Button {
                    viewModel.togglePlayPause()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                }
                .disabled(!viewModel.isLoaded)

                Button {
                    viewModel.nextSegment()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title)
                }
                .disabled(!viewModel.isLoaded || !viewModel.hasSegments)
            }
            .foregroundStyle(.primary)

            // Row 2: Loop + Play Next Phrase
            if viewModel.hasSegments {
                HStack(spacing: 16) {
                    // Loop toggle
                    Button {
                        viewModel.toggleLoop()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.isLooping ? "repeat.1" : "repeat")
                            Text(viewModel.isLooping ? "Looping" : "Loop")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(viewModel.isLooping ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                        .foregroundStyle(viewModel.isLooping ? Color.accentColor : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(!viewModel.isLoaded)

                    // Play Next Phrase
                    Button {
                        viewModel.playNextPhrase()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "forward.frame.fill")
                            Text("Next Phrase")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(viewModel.isPhraseMode ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                        .foregroundStyle(viewModel.isPhraseMode ? Color.accentColor : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(!viewModel.isLoaded)
                }
            }

            // Row 3: Speed + segment marking
            HStack {
                SpeedPickerView(speed: viewModel.speed) { newSpeed in
                    viewModel.setSpeed(newSpeed)
                }

                Spacer()

                if viewModel.hasSegments {
                    HStack(spacing: 16) {
                        Button {
                            viewModel.toggleHeartCurrentSegment()
                        } label: {
                            Image(systemName: viewModel.currentSegment?.isMarkedHeart == true ? "heart.fill" : "heart")
                                .font(.title3)
                                .foregroundStyle(viewModel.currentSegment?.isMarkedHeart == true ? .red : .secondary)
                        }
                        .disabled(viewModel.currentSegment == nil)

                        Button {
                            viewModel.toggleStarCurrentSegment()
                        } label: {
                            Image(systemName: viewModel.currentSegment?.isMarkedStar == true ? "star.fill" : "star")
                                .font(.title3)
                                .foregroundStyle(viewModel.currentSegment?.isMarkedStar == true ? .yellow : .secondary)
                        }
                        .disabled(viewModel.currentSegment == nil)
                    }
                }
            }
        }
    }
}
