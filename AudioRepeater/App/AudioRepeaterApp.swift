import SwiftUI
import SwiftData

@main
struct AudioRepeaterApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                Project.self,
                Segment.self,
                Bookmark.self,
                Note.self,
                Folder.self,
                SubtitleTrack.self,
                SubtitleCue.self,
                AppSettings.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
        }
        .modelContainer(modelContainer)
    }
}
