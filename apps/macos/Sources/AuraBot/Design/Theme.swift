import SwiftUI

// MARK: - Color Palette
@available(macOS 14.0, *)
enum Colors {
    // Backgrounds
    static let background = Color(hex: "#F4F6F5")
    static let surface = Color.white
    static let surfaceSecondary = Color(hex: "#F8FAF9")
    static let surfaceTertiary = Color(hex: "#EEF2F1")
    static let surfaceHover = Color(hex: "#E9EFED")
    
    // Borders
    static let border = Color(hex: "#DDE4E1")
    static let borderHover = Color(hex: "#C8D4D0")
    static let borderFocus = Color(hex: "#168A7A")
    static let glassBorder = Color(hex: "#DDE4E1")
    
    // Accents
    static let primary = Color(hex: "#168A7A")
    static let primaryHover = Color(hex: "#0F6F63")
    static let primaryMuted = Color(hex: "#168A7A").opacity(0.14)
    static let primaryGlow = Color(hex: "#168A7A").opacity(0.16)
    static let secondary = Color(hex: "#4E63A6")
    static let accent = Color(hex: "#C95E48")
    
    // Semantic
    static let success = Color(hex: "#2F9E44")
    static let danger = Color(hex: "#C0392B")
    static let warning = Color(hex: "#B7791F")
    
    // Text
    static let textPrimary = Color(hex: "#17201D")
    static let textSecondary = Color(hex: "#56635F")
    static let textTertiary = Color(hex: "#7B8783")
    static let textMuted = Color(hex: "#7B8783")
    static let textInverse = Color.white
    static let white = Color.white
}

// MARK: - Typography
@available(macOS 14.0, *)
enum Typography {
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
    static let title1 = Font.system(size: 28, weight: .bold, design: .default)
    static let title2 = Font.system(size: 22, weight: .semibold, design: .default)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .default)
    static let headline = Font.system(size: 17, weight: .semibold, design: .default)
    static let body = Font.system(size: 15, weight: .regular, design: .default)
    static let callout = Font.system(size: 14, weight: .regular, design: .default)
    static let subheadline = Font.system(size: 13, weight: .regular, design: .default)
    static let footnote = Font.system(size: 13, weight: .regular, design: .default)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
    
    // Monospace for metadata
    static let mono = Font.system(size: 12, weight: .medium, design: .monospaced)
}

// MARK: - Spacing Grid
@available(macOS 14.0, *)
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
    static let xxxxl: CGFloat = 40
    static let huge: CGFloat = 48
    static let xhuge: CGFloat = 64
}

// MARK: - Shadows
@available(macOS 14.0, *)
enum Shadows {
    static let sm = ShadowStyle(
        color: Color.black.opacity(0.03),
        radius: 4,
        x: 0,
        y: 2
    )
    
    static let md = ShadowStyle(
        color: Color.black.opacity(0.05),
        radius: 10,
        x: 0,
        y: 5
    )
    
    static let lg = ShadowStyle(
        color: Color.black.opacity(0.07),
        radius: 18,
        x: 0,
        y: 9
    )

    static let xl = ShadowStyle(
        color: Color.black.opacity(0.08),
        radius: 24,
        x: 0,
        y: 12
    )
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    
    var swiftUIShadow: some ViewModifier {
        ShadowModifier(color: color, radius: radius, x: x, y: y)
    }
}

// MARK: - Button Styles

@available(macOS 14.0, *)
struct PrimaryButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(Colors.primary)
            )
            .foregroundColor(.white)
            .font(Typography.callout.weight(.semibold))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

@available(macOS 14.0, *)
struct SecondaryButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(Colors.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .stroke(Colors.border, lineWidth: 1)
                    )
            )
            .foregroundColor(Colors.textPrimary)
            .font(Typography.callout.weight(.medium))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

struct ShadowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color, radius: radius, x: x, y: y)
    }
}

// MARK: - Corner Radius
@available(macOS 14.0, *)
enum Radius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 8
    static let xl: CGFloat = 8
    static let xxl: CGFloat = 8
    static let full: CGFloat = 9999
}

// MARK: - Color Helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
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

// MARK: - View Extensions for Theme
@available(macOS 14.0, *)
extension View {
    func cardStyle() -> some View {
        self
            .padding(Spacing.lg)
            .background(Colors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(Colors.border, lineWidth: 1)
            )
            .cornerRadius(Radius.lg)
    }
    
    func cardStyleElevated() -> some View {
        self
            .padding(Spacing.lg)
            .background(Colors.surface)
            .cornerRadius(Radius.lg)
            .shadow(color: Shadows.sm.color, radius: Shadows.sm.radius, x: Shadows.sm.x, y: Shadows.sm.y)
    }
    
    func withShadow(_ shadow: ShadowStyle) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
