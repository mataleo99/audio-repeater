import SwiftUI

struct BookmarkListView: View {
    @Bindable var viewModel: PlayerViewModel
    @State private var filterTag: String?
    @State private var editingBookmark: Bookmark?

    var allTags: [String] {
        let tags = viewModel.currentProject?.bookmarks.flatMap(\.tags) ?? []
        return Array(Set(tags)).sorted()
    }

    var filteredBookmarks: [Bookmark] {
        let bookmarks = (viewModel.currentProject?.bookmarks ?? [])
            .sorted { $0.timestamp < $1.timestamp }
        if let tag = filterTag {
            return bookmarks.filter { $0.tags.contains(tag) }
        }
        return bookmarks
    }

    var body: some View {
        List {
            if !allTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        TagChipView(title: "All", isSelected: filterTag == nil) {
                            filterTag = nil
                        }
                        ForEach(allTags, id: \.self) { tag in
                            TagChipView(title: tag, isSelected: filterTag == tag) {
                                filterTag = filterTag == tag ? nil : tag
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if filteredBookmarks.isEmpty {
                ContentUnavailableView {
                    Label("No Bookmarks", systemImage: "bookmark")
                } description: {
                    Text("Tap \"Add Bookmark Here\" from the player menu to create one.")
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredBookmarks) { bookmark in
                    BookmarkRowView(
                        bookmark: bookmark,
                        duration: viewModel.duration,
                        onTap: {
                            viewModel.seek(to: bookmark.timestamp)
                        },
                        onEdit: {
                            editingBookmark = bookmark
                        }
                    )
                }
                .onDelete { offsets in
                    let toDelete = offsets.map { filteredBookmarks[$0] }
                    for bookmark in toDelete {
                        viewModel.deleteBookmark(bookmark)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Bookmarks")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingBookmark) { bookmark in
            NavigationStack {
                BookmarkEditorView(bookmark: bookmark)
            }
        }
    }
}

struct BookmarkRowView: View {
    let bookmark: Bookmark
    let duration: TimeInterval
    let onTap: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(.tint)
                    .font(.subheadline)

                VStack(alignment: .leading, spacing: 2) {
                    Text(bookmark.label.isEmpty ? "Bookmark" : bookmark.label)
                        .font(.subheadline)

                    HStack(spacing: 6) {
                        Text(bookmark.timestamp.formatMatchingDuration(duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()

                        if !bookmark.tags.isEmpty {
                            Text(bookmark.tags.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(.tint)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                Button(action: onEdit) {
                    Image(systemName: "pencil.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

struct BookmarkEditorView: View {
    @Bindable var bookmark: Bookmark
    @Environment(\.dismiss) private var dismiss
    @State private var newTag = ""

    var body: some View {
        Form {
            Section("Label") {
                TextField("Bookmark label", text: $bookmark.label)
            }

            Section("Tags") {
                ForEach(bookmark.tags, id: \.self) { tag in
                    HStack {
                        Text(tag)
                        Spacer()
                        Button {
                            bookmark.tags.removeAll { $0 == tag }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("Add tag", text: $newTag)
                        .onSubmit { addTag() }
                    Button("Add") { addTag() }
                        .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section {
                Text("Time: \(bookmark.timestamp.formattedTime)")
                    .foregroundStyle(.secondary)
                Text("Created: \(bookmark.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Edit Bookmark")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !bookmark.tags.contains(tag) else { return }
        bookmark.tags.append(tag)
        newTag = ""
    }
}
