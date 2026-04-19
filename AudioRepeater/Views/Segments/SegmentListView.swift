import SwiftUI

struct SegmentListView: View {
    @Bindable var viewModel: PlayerViewModel
    @State private var filter: SegmentFilter = .all
    @State private var showEditor = false

    enum SegmentFilter: String, CaseIterable {
        case all = "All"
        case hearted = "Hearted"
        case starred = "Starred"
    }

    var filteredSegments: [Segment] {
        let segs = viewModel.sortedSegments
        switch filter {
        case .all: return segs
        case .hearted: return segs.filter { $0.isMarkedHeart }
        case .starred: return segs.filter { $0.isMarkedStar }
        }
    }

    var body: some View {
        List {
            Picker("Filter", selection: $filter) {
                ForEach(SegmentFilter.allCases, id: \.self) { f in
                    Text(f.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            if filteredSegments.isEmpty {
                ContentUnavailableView {
                    Label(
                        filter == .all ? "No Segments" : "No \(filter.rawValue) Segments",
                        systemImage: "waveform"
                    )
                } description: {
                    Text(filter == .all
                         ? "Segments will appear after audio analysis."
                         : "Mark segments with \(filter == .hearted ? "hearts" : "stars") to see them here.")
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredSegments) { segment in
                    SegmentRowView(
                        segment: segment,
                        isCurrent: viewModel.currentSegment?.id == segment.id,
                        duration: viewModel.duration,
                        onTap: {
                            viewModel.seek(to: segment.startTime)
                        },
                        onToggleHeart: {
                            viewModel.toggleHeart(for: segment)
                        },
                        onToggleStar: {
                            viewModel.toggleStar(for: segment)
                        }
                    )
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Segments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Edit Boundaries") { showEditor = true }
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                SegmentEditorView(viewModel: viewModel)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showEditor = false }
                        }
                    }
            }
        }
    }
}

struct SegmentRowView: View {
    let segment: Segment
    let isCurrent: Bool
    let duration: TimeInterval
    let onTap: () -> Void
    let onToggleHeart: () -> Void
    let onToggleStar: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Segment number
                Text("#\(segment.index + 1)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                    .frame(width: 32)

                // Time range
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(segment.startTime.formatMatchingDuration(duration)) — \(segment.endTime.formatMatchingDuration(duration))")
                        .font(.subheadline)
                        .monospacedDigit()
                    Text(segment.duration.formattedTime)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Marks
                HStack(spacing: 8) {
                    Button(action: onToggleHeart) {
                        Image(systemName: segment.isMarkedHeart ? "heart.fill" : "heart")
                            .foregroundColor(segment.isMarkedHeart ? .red : .secondary.opacity(0.3))
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)

                    Button(action: onToggleStar) {
                        Image(systemName: segment.isMarkedStar ? "star.fill" : "star")
                            .foregroundColor(segment.isMarkedStar ? .yellow : .secondary.opacity(0.3))
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .background(isCurrent ? Color.accentColor.opacity(0.05) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}
