import SwiftUI

enum ThemeID: String, Codable, CaseIterable, Identifiable {
    case paper
    case midnight
    case blueprint
    case oxide
    case sage
    case graphite
    case plum

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .paper: "Paper"
        case .midnight: "Midnight"
        case .blueprint: "Blueprint"
        case .oxide: "Oxide"
        case .sage: "Sage"
        case .graphite: "Graphite"
        case .plum: "Plum"
        }
    }
}

/// The whole app is built from these tokens. No component picks its own colour.
struct AppTheme: Equatable {
    let id: ThemeID
    let name: String
    let background: Color
    let surface: Color
    let raised: Color
    let ink: Color
    let secondary: Color
    let line: Color
    let accent: Color
    let accentInk: Color
    let accentSoft: Color
    let green: Color
    let isDark: Bool
    let showsGrid: Bool

    static func resolve(_ id: ThemeID) -> AppTheme {
        switch id {
        case .paper:
            AppTheme(
                id: .paper, name: "Paper",
                background: Color(hex: 0xF5EFEA),
                surface: Color(hex: 0xECE5DE),
                raised: Color(hex: 0xE4DCD4),
                ink: Color(hex: 0x1F1F1F),
                secondary: Color(hex: 0x1F1F1F).opacity(0.58),
                line: Color(hex: 0x1F1F1F).opacity(0.11),
                accent: Color(hex: 0xFF521B),
                accentInk: Color(hex: 0x1F1F1F),
                accentSoft: Color(hex: 0xFF521B).opacity(0.10),
                green: Color(hex: 0x47604C),
                isDark: false, showsGrid: true
            )
        case .midnight:
            AppTheme(
                id: .midnight, name: "Midnight",
                background: Color(hex: 0x1C1C1B),
                surface: Color(hex: 0x242423),
                raised: Color(hex: 0x2E2E2C),
                ink: Color(hex: 0xF5EFEA),
                secondary: Color(hex: 0xF5EFEA).opacity(0.56),
                line: Color(hex: 0xF5EFEA).opacity(0.13),
                accent: Color(hex: 0xFF521B),
                accentInk: Color(hex: 0x1F1F1F),
                accentSoft: Color(hex: 0xFF521B).opacity(0.14),
                green: Color(hex: 0x93AB99),
                isDark: true, showsGrid: true
            )
        case .blueprint:
            AppTheme(
                id: .blueprint, name: "Blueprint",
                background: Color(hex: 0xEFEBE1),
                surface: Color(hex: 0xE7E2D6),
                raised: Color(hex: 0xDCD6C8),
                ink: Color(hex: 0x1F2A26),
                secondary: Color(hex: 0x1F2A26).opacity(0.60),
                line: Color(hex: 0x1F2A26).opacity(0.13),
                accent: Color(hex: 0xFF521B),
                accentInk: Color(hex: 0x1F1F1F),
                accentSoft: Color(hex: 0xFF521B).opacity(0.10),
                green: Color(hex: 0x3F5D4B),
                isDark: false, showsGrid: true
            )
        case .oxide:
            AppTheme(
                id: .oxide, name: "Oxide",
                background: Color(hex: 0xF4E7DE),
                surface: Color(hex: 0xEBDDD3),
                raised: Color(hex: 0xE1D1C5),
                ink: Color(hex: 0x221C19),
                secondary: Color(hex: 0x221C19).opacity(0.58),
                line: Color(hex: 0x221C19).opacity(0.12),
                accent: Color(hex: 0xFF521B),
                accentInk: Color(hex: 0x1F1F1F),
                accentSoft: Color(hex: 0xFF521B).opacity(0.11),
                green: Color(hex: 0x5D5645),
                isDark: false, showsGrid: true
            )
        case .sage:
            AppTheme(
                id: .sage, name: "Sage",
                background: Color(hex: 0xEEF0E8),
                surface: Color(hex: 0xE5E8DD),
                raised: Color(hex: 0xDBDFD1),
                ink: Color(hex: 0x1E241F),
                secondary: Color(hex: 0x1E241F).opacity(0.58),
                line: Color(hex: 0x1E241F).opacity(0.12),
                accent: Color(hex: 0xFF521B),
                accentInk: Color(hex: 0x1F1F1F),
                accentSoft: Color(hex: 0xFF521B).opacity(0.10),
                green: Color(hex: 0x47604C),
                isDark: false, showsGrid: true
            )
        case .graphite:
            AppTheme(
                id: .graphite, name: "Graphite",
                background: Color(hex: 0x232526),
                surface: Color(hex: 0x2B2E2F),
                raised: Color(hex: 0x363A3B),
                ink: Color(hex: 0xF1EEE9),
                secondary: Color(hex: 0xF1EEE9).opacity(0.56),
                line: Color(hex: 0xF1EEE9).opacity(0.13),
                accent: Color(hex: 0xFF521B),
                accentInk: Color(hex: 0x1F1F1F),
                accentSoft: Color(hex: 0xFF521B).opacity(0.14),
                green: Color(hex: 0x9CB2A1),
                isDark: true, showsGrid: true
            )
        case .plum:
            AppTheme(
                id: .plum, name: "Plum",
                background: Color(hex: 0x251F24),
                surface: Color(hex: 0x2E272D),
                raised: Color(hex: 0x393037),
                ink: Color(hex: 0xF5EFEA),
                secondary: Color(hex: 0xF5EFEA).opacity(0.56),
                line: Color(hex: 0xF5EFEA).opacity(0.13),
                accent: Color(hex: 0xFF521B),
                accentInk: Color(hex: 0x1F1F1F),
                accentSoft: Color(hex: 0xFF521B).opacity(0.14),
                green: Color(hex: 0xB2A0A8),
                isDark: true, showsGrid: true
            )
        }
    }

    /// Deep charcoal specimen card used sparingly for emphasis.
    static let charcoal = AppTheme(
        id: .midnight, name: "Charcoal",
        background: Color(hex: 0x1F1F1F),
        surface: Color(hex: 0x262625),
        raised: Color(hex: 0x30302E),
        ink: Color(hex: 0xF5EFEA),
        secondary: Color(hex: 0xF5EFEA).opacity(0.58),
        line: Color(hex: 0xF5EFEA).opacity(0.15),
        accent: Color(hex: 0xFF521B),
        accentInk: Color(hex: 0x1F1F1F),
        accentSoft: Color(hex: 0xFF521B).opacity(0.16),
        green: Color(hex: 0x96AE9C),
        isDark: true, showsGrid: true
    )
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.resolve(.paper)
}

extension EnvironmentValues {
    var theme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum Typeface {
    /// Primary editorial content uses the system face for maximum clarity.
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Technical annotation face.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("IBM Plex Mono", size: size).weight(weight)
    }
}

extension View {
    func monoLabel(_ size: CGFloat = 9.5) -> some View {
        font(Typeface.mono(size, weight: .medium))
            .tracking(1.8)
            .textCase(.uppercase)
    }

    /// A restrained lift for floating layers.
    func floatingShadow(_ theme: AppTheme) -> some View {
        shadow(color: theme.isDark ? .black.opacity(0.42) : Color(hex: 0x2A2016).opacity(0.10),
               radius: 14, x: 0, y: 6)
    }
}
