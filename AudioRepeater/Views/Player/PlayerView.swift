import SwiftUI

struct PlayerView: View {
    let project: Project
    @State private var viewModel = PlayerViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @State private var showSegments = false
    @State private var showBookmarks = false
    @State private var showNotes = false

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
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showSegments = true
                } label: {
                    Image(systemName: "list.bullet")
                }
                .disabled(!viewModel.hasSegments)

                Menu {
                    Button {
                        showBookmarks = true
                    } label: {
                        Label("Bookmarks", systemImage: "bookmark")
                    }

                    Button {
                        viewModel.addBookmark()
                    } label: {
                        Label("Add Bookmark Here", systemImage: "bookmark.fill")
                    }
                    .disabled(!viewModel.isLoaded)

                    Button {
                        showNotes = true
                    } label: {
                        Label("Notes", systemImage: "note.text")
                    }

                    Divider()

                    // Auto-pause controls
                    Button {
                        if viewModel.isAutoPauseEnabled {
                            viewModel.setAutoPauseDuration(0)
                        } else {
                            viewModel.setAutoPauseDuration(1.0)
                        }
                    } label: {
                        if viewModel.isAutoPauseEnabled {
                            Label("Auto-Pause: On", systemImage: "checkmark")
                        } else {
                            Label("Auto-Pause Between Phrases", systemImage: "pause.rectangle")
                        }
                    }

                    if viewModel.isAutoPauseEnabled {
                        Menu {
                            ForEach([0.5, 1.0, 2.0, 3.0, 5.0], id: \.self) { dur in
                                Button {
                                    viewModel.setAutoPauseDuration(dur)
                                } label: {
                                    HStack {
                                        Text(String(format: "%.1fs", dur))
                                        if viewModel.currentProject?.autoPauseDuration == dur {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label("Pause Duration", systemImage: "timer")
                        }
                    }

                    Divider()

                    Button {
                        viewModel.resegment(modelContainer: modelContext.container)
                    } label: {
                        Label("Re-analyze Segments", systemImage: "waveform.badge.magnifyingglass")
                    }
                    .disabled(!viewModel.isLoaded || viewModel.isSegmenting)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showSegments) {
            NavigationStack {
                SegmentListView(viewModel: viewModel)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showSegments = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showBookmarks) {
            NavigationStack {
                BookmarkListView(viewModel: viewModel)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showBookmarks = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showNotes) {
            NavigationStack {
                NoteEditorView(project: project)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showNotes = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
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
