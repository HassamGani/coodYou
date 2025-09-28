import SwiftUI

struct Theme: Sendable {
    struct ColorPalette: Sendable {
        let backgroundBase: DynamicColor
        let foregroundPrimary: DynamicColor
        let foregroundSecondary: DynamicColor
        let accentPrimary: DynamicColor
        let accentSuccess: DynamicColor
        let accentWarning: DynamicColor
        let accentError: DynamicColor
    }

    struct Typography: Sendable {
        let titleXL: FontDescriptor
        let titleM: FontDescriptor
        let body: FontDescriptor
        let caption: FontDescriptor
    }

    struct Spacing: Sendable {
        let xs: CGFloat
        let sm: CGFloat
        let md: CGFloat
        let lg: CGFloat
        let xl: CGFloat
    }

    struct Radius: Sendable {
        let control: CGFloat
        let sheet: CGFloat
    }

    struct DynamicColor: Sendable {
        let light: Color
        let dark: Color

        func resolve(for scheme: ColorScheme) -> Color {
            switch scheme {
            case .dark: return dark
            default: return light
            }
        }
    }

    struct FontDescriptor: Sendable {
        let size: CGFloat
        let weight: Font.Weight
        let lineHeight: CGFloat

        func font(textStyle: Font.TextStyle? = nil) -> Font {
            if let textStyle {
                return Font.system(textStyle, design: .rounded).weight(weight)
            } else {
                return Font.system(size: size, weight: weight, design: .rounded)
            }
        }
    }

    let colors: ColorPalette
    let typography: Typography
    let spacing: Spacing
    let radius: Radius

    static let current = Theme(
        colors: ColorPalette(
            backgroundBase: DynamicColor(light: Color(hex: "#FFFFFF"), dark: Color(hex: "#0B0B0C")),
            foregroundPrimary: DynamicColor(light: Color(white: 0.1), dark: Color(white: 0.92)),
            foregroundSecondary: DynamicColor(light: Color(white: 0.4), dark: Color(white: 0.3)),
            accentPrimary: DynamicColor(light: Color(hex: "#0A84FF"), dark: Color(hex: "#0A84FF")),
            accentSuccess: DynamicColor(light: Color(hex: "#34C759"), dark: Color(hex: "#34C759")),
            accentWarning: DynamicColor(light: Color(hex: "#FFD60A"), dark: Color(hex: "#FFD60A")),
            accentError: DynamicColor(light: Color(hex: "#FF3B30"), dark: Color(hex: "#FF3B30"))
        ),
        typography: Typography(
            titleXL: FontDescriptor(size: 34, weight: .semibold, lineHeight: 41),
            titleM: FontDescriptor(size: 22, weight: .semibold, lineHeight: 26),
            body: FontDescriptor(size: 17, weight: .regular, lineHeight: 22),
            caption: FontDescriptor(size: 13, weight: .regular, lineHeight: 18)
        ),
        spacing: Spacing(xs: 4, sm: 8, md: 16, lg: 24, xl: 32),
        radius: Radius(control: 16, sheet: 28)
    )
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.current
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension Color {
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var int: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hexSanitized.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension View {
    func themedBackground(_ color: Theme.DynamicColor) -> some View {
        modifier(ThemedBackground(color: color))
    }
}

private struct ThemedBackground: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let color: Theme.DynamicColor

    func body(content: Content) -> some View {
        content.background(color.resolve(for: scheme))
    }
}
