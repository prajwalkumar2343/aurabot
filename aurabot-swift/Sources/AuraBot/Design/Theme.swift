import SwiftUI

// MARK: - Color Palette
@available(macOS 14.0, *)
enum Colors {
    // Background
    static let white = Color.white
    static let background = Color.white
    static let surface = Color.white.opacity(0.8)
    static let surfaceHover = Color.white.opacity(0.95)
    
    // Borders
    static let border = Color(hex: "#E5E7EB")
    static let borderFocus = Color(hex: "#3B82F6")
    
    // Primary - Electric Blue
    static let primary = Color(hex: "#2563EB")
    static let primaryHover = Color(hex: "#1D4ED8")
    static let primaryGlow = Color(hex: "#2563EB").opacity(0.3)
    
    // Secondary - Violet
    static let secondary = Color(hex: "#7C3AED")
    static let secondaryGlow = Color(hex: "#7C3AED").opacity(0.3)
    
    // Accents
    static let accent = Color(hex: "#F59E0B")
    static let success = Color(hex: "#10B981")
    static let danger = Color(hex: "#EF4444")
    static let warning = Color(hex: "#F59E0B")
    
    // Text
    static let textPrimary = Color(hex: "#111827")
    static let textSecondary = Color(hex: "#6B7280")
    static let textMuted = Color(hex: "#9CA3AF")
    
    // Gradients
    static let primaryGradient = LinearGradient(
        colors: [primary, secondary],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let heroGradient = LinearGradient(
        colors: [primary.opacity(0.1), secondary.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let glassGradient = LinearGradient(
        colors: [Color.white.opacity(0.9), Color.white.opacity(0.7)],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Typography
@available(macOS 14.0, *)
enum Typography {
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title1 = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold, design: .default)
    static let body = Font.system(size: 15, weight: .regular, design: .default)
    static let callout = Font.system(size: 14, weight: .regular, design: .default)
    static let subheadline = Font.system(size: 13, weight: .regular, design: .default)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
    
    // Monospace for code/memory metadata
    static let mono = Font.system(size: 13, weight: .medium, design: .monospaced)
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
        color: Color.black.opacity(0.05),
        radius: 4,
        x: 0,
        y: 2
    )
    
    static let md = ShadowStyle(
        color: Color.black.opacity(0.08),
        radius: 8,
        x: 0,
        y: 4
    )
    
    static let lg = ShadowStyle(
        color: Color.black.opacity(0.1),
        radius: 16,
        x: 0,
        y: 8
    )
    
    static let xl = ShadowStyle(
        color: Color.black.opacity(0.12),
        radius: 24,
        x: 0,
        y: 12
    )
    
    static let glow = ShadowStyle(
        color: Colors.primaryGlow,
        radius: 20,
        x: 0,
        y: 0
    )
    
    static let glowHover = ShadowStyle(
        color: Colors.primary.opacity(0.4),
        radius: 30,
        x: 0,
        y: 0
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
                    .shadow(
                        color: Colors.primary.opacity(0.3),
                        radius: isHovered ? 12 : 8,
                        x: 0,
                        y: isHovered ? 4 : 2
                    )
            )
            .foregroundColor(.white)
            .font(Typography.callout.weight(.semibold))
            .scaleEffect(configuration.isPressed ? 0.96 : (isHovered ? 1.02 : 1.0))
            .animation(AnimationPresets.hover, value: isHovered)
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
                    .fill(Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .stroke(Colors.border, lineWidth: 1)
                    )
            )
            .foregroundColor(Colors.textPrimary)
            .font(Typography.callout.weight(.medium))
            .scaleEffect(configuration.isPressed ? 0.96 : (isHovered ? 1.02 : 1.0))
            .animation(AnimationPresets.hover, value: isHovered)
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
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let xxl: CGFloat = 20
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
    func glassStyle() -> some View {
        self
            .background(.ultraThinMaterial)
            .background(Colors.glassGradient)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(Colors.border, lineWidth: 1)
            )
            .cornerRadius(Radius.lg)
    }
    
    func glassCard() -> some View {
        self
            .padding(Spacing.lg)
            .background(.ultraThinMaterial)
            .background(Colors.white.opacity(0.8))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xl)
                    .stroke(Colors.border, lineWidth: 1)
            )
            .cornerRadius(Radius.xl)
            .shadow(color: Shadows.md.color, radius: Shadows.md.radius, x: Shadows.md.x, y: Shadows.md.y)
    }
    
    func primaryGlow() -> some View {
        self
            .shadow(color: Colors.primaryGlow, radius: 20, x: 0, y: 0)
    }
    
    func withShadow(_ shadow: ShadowStyle) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
