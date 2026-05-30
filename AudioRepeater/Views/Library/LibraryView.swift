import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.lastOpenedAt, order: .reverse) private var projects: [Project]
    @State private var showFileImporter = false
    @State private var selectedProject: Project?
    @State private var importError: String?
    @State private var showError = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if projects.isEmpty {
                    emptyState
                } else {
                    projectList
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFileImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showSettings = false }
                            }
                        }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: supportedAudioTypes,
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .navigationDestination(item: $selectedProject) { project in
                PlayerView(project: project)
            }
            .alert("Import Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(importError ?? "An unknown error occurred.")
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Audio Files", systemImage: "waveform")
        } description: {
            Text("Import an audio file to get started.")
        } actions: {
            Button("Import Audio") {
                showFileImporter = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var projectList: some View {
        List {
            ForEach(projects) { project in
                ProjectRowView(project: project)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedProject = project
                    }
            }
            .onDelete(perform: deleteProjects)
        }
    }

    private var supportedAudioTypes: [UTType] {
        [.mp3, .mpeg4Audio, .wav, .aiff, .audio]
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let project = try FileImportService.importAudioFile(
                    from: url,
                    modelContext: modelContext
                )
                selectedProject = project
            } catch {
                importError = error.localizedDescription
                showError = true
            }
        case .failure(let error):
            importError = error.localizedDescription
            showError = true
        }
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            let project = projects[index]
            // Delete the audio file
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: project.audioFileURL.path) {
                try? fileManager.removeItem(at: project.audioFileURL)
            }
            modelContext.delete(project)
        }
    }
}
