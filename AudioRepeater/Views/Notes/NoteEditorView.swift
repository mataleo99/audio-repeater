import SwiftUI

struct NoteEditorView: View {
    @Bindable var project: Project
    @FocusState private var isFocused: Bool

    private var noteText: Binding<String> {
        Binding(
            get: { project.note?.text ?? "" },
            set: { newValue in
                if let note = project.note {
                    note.text = newValue
                    note.updatedAt = Date()
                } else {
                    let note = Note(text: newValue)
                    project.note = note
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: noteText)
                .focused($isFocused)
                .padding(.horizontal, 4)

            if let note = project.note, !note.text.isEmpty {
                HStack {
                    Text("Last edited \(note.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("\(note.text.count) characters")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .navigationTitle("Notes")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isFocused = true
        }
    }
}
