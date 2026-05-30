import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]

    private var settings: AppSettings {
        if let existing = settingsList.first {
            return existing
        }
        let new = AppSettings()
        modelContext.insert(new)
        return new
    }

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: Binding(
                    get: { AppTheme(rawValue: settings.themeName) ?? .system },
                    set: { settings.themeName = $0.rawValue }
                )) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.navigationLink)

                Stepper(
                    "Subtitle Font Size: \(Int(settings.subtitleFontSize))",
                    value: Binding(
                        get: { settings.subtitleFontSize },
                        set: { settings.subtitleFontSize = $0 }
                    ),
                    in: 12...32,
                    step: 1
                )
            }

            Section("Segmentation") {
                VStack(alignment: .leading) {
                    Text("Silence Threshold: \(Int(settings.silenceThresholdDB)) dB")
                    Slider(
                        value: Binding(
                            get: { Double(settings.silenceThresholdDB) },
                            set: { settings.silenceThresholdDB = Float($0) }
                        ),
                        in: -60...(-20),
                        step: 1
                    )
                }

                VStack(alignment: .leading) {
                    Text("Min Silence: \(String(format: "%.2f", settings.minSilenceDuration))s")
                    Slider(
                        value: Binding(
                            get: { settings.minSilenceDuration },
                            set: { settings.minSilenceDuration = $0 }
                        ),
                        in: 0.05...1.0,
                        step: 0.05
                    )
                }

                VStack(alignment: .leading) {
                    Text("Min Segment: \(String(format: "%.2f", settings.minSegmentDuration))s")
                    Slider(
                        value: Binding(
                            get: { settings.minSegmentDuration },
                            set: { settings.minSegmentDuration = $0 }
                        ),
                        in: 0.3...3.0,
                        step: 0.1
                    )
                }
            }
        }
        .navigationTitle("Settings")
    }
}
