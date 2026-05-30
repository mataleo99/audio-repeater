import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case sepia
    case highContrast

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        case .sepia: return "Sepia"
        case .highContrast: return "High Contrast"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light, .sepia: return .light
        case .dark, .highContrast: return .dark
        }
    }

    var tint: Color {
        switch self {
        case .system, .light, .dark: return .accentColor
        case .sepia: return Color(red: 0.55, green: 0.35, blue: 0.15)
        case .highContrast: return .yellow
        }
    }

    /// Background tint applied on top of the base color scheme. nil = use system default.
    var backgroundOverlay: Color? {
        switch self {
        case .sepia: return Color(red: 0.96, green: 0.93, blue: 0.85)
        case .highContrast: return .black
        default: return nil
        }
    }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .system
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

extension View {
    /// Applies the given theme to the view hierarchy: color scheme, tint, and background overlay.
    func appTheme(_ theme: AppTheme) -> some View {
        modifier(AppThemeModifier(theme: theme))
    }
}

private struct AppThemeModifier: ViewModifier {
    let theme: AppTheme

    func body(content: Content) -> some View {
        Group {
            if let overlay = theme.backgroundOverlay {
                content.background(overlay.ignoresSafeArea())
            } else {
                content
            }
        }
        .tint(theme.tint)
        .preferredColorScheme(theme.colorScheme)
        .environment(\.appTheme, theme)
    }
}
