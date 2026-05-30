import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var settingsList: [AppSettings]

    private var theme: AppTheme {
        guard let name = settingsList.first?.themeName,
              let theme = AppTheme(rawValue: name) else {
            return .system
        }
        return theme
    }

    var body: some View {
        LibraryView()
            .appTheme(theme)
    }
}
