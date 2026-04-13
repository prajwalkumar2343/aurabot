import SwiftUI

// MARK: - Design Tokens

@available(macOS 12.3, *)
enum DesignTokens {
    // Colors - Light Mode
    static let bgPrimary = Color(NSColor.windowBackgroundColor)
    static let bgSecondary = Color(NSColor.controlBackgroundColor)
    static let bgSidebar = Color.white.opacity(0.72)
    static let bgCard = Color.white.opacity(0.80)
    static let bgGlass = Color.white.opacity(0.65)
    static let bgGlassHeavy = Color.white.opacity(0.82)
    
    // Colors - Dark Mode
    static let bgPrimaryDark = Color(NSColor.windowBackgroundColor)
    static let bgSidebarDark = Color(white: 0.17, opacity: 0.78)
    static let bgCardDark = Color(white: 0.17, opacity: 0.75)
    static let bgGlassDark = Color(white: 0.17, opacity: 0.65)
    
    // Accent Colors
    static let accent = Color(red: 0, green: 0.48, blue: 1)
    static let accentHover = Color(red: 0, green: 0.40, blue: 0.84)
    static let accentLight = Color(red: 0, green: 0.48, blue: 1).opacity(0.08)
    static let accentCyan = Color(red: 0.35, green: 0.78, blue: 0.98)
    static let accentViolet = Color(red: 0.69, green: 0.32, blue: 0.87)
    
    // Status Colors
    static let success = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let warning = Color(red: 1, green: 0.62, blue: 0.04)
    static let error = Color(red: 1, green: 0.23, blue: 0.19)
    
    // Gradients
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentCyan, accentViolet],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var accentGradientSubtle: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.08), accentCyan.opacity(0.06), accentViolet.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Typography
    static let fontFamily = "SF Pro Display"
    static let fontMono = "SF Mono"
    
    // Spacing
    static let spaceXs: CGFloat = 4
    static let spaceSm: CGFloat = 8
    static let spaceMd: CGFloat = 12
    static let spaceLg: CGFloat = 16
    static let spaceXl: CGFloat = 24
    static let space2Xl: CGFloat = 32
    static let space3Xl: CGFloat = 48
    
    // Radius
    static let radiusSm: CGFloat = 8
    static let radiusMd: CGFloat = 12
    static let radiusLg: CGFloat = 16
    static let radiusXl: CGFloat = 20
    static let radius2Xl: CGFloat = 24
    static let radiusFull: CGFloat = 9999
    
    // Shadows
    static let shadowSm = ShadowStyle(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    static let shadowMd = ShadowStyle(color: .black.opacity(0.06), radius: 16, x: 0, y: 4)
    static let shadowLg = ShadowStyle(color: .black.opacity(0.08), radius: 32, x: 0, y: 8)
    static let shadowGlow = ShadowStyle(color: accent.opacity(0.15), radius: 24, x: 0, y: 0)
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

// MARK: - Glass Card View

@available(macOS 12.3, *)
struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    let content: Content
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = DesignTokens.radiusXl
    
    init(padding: CGFloat = 16, cornerRadius: CGFloat = DesignTokens.radiusXl, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(colorScheme == .dark ? DesignTokens.bgCardDark : DesignTokens.bgCard)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .modifier(DesignTokens.shadowSm.swiftUIShadow)
    }
}

// MARK: - Glass Sidebar

@available(macOS 12.3, *)
struct GlassSidebar<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .frame(minWidth: 250, maxWidth: 280)
            .background(
                Rectangle()
                    .fill(colorScheme == .dark ? DesignTokens.bgSidebarDark : DesignTokens.bgSidebar)
                    .background(.ultraThinMaterial)
            )
            .overlay(
                Rectangle()
                    .stroke(Color.primary.opacity(0.04), lineWidth: 1)
            )
    }
}

// MARK: - Animated Button Styles

@available(macOS 12.3, *)
struct GlassButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    var isAccent: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusFull, style: .continuous)
                    .fill(isAccent ? DesignTokens.accent : (colorScheme == .dark ? DesignTokens.bgCardDark : DesignTokens.bgCard))
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.radiusFull, style: .continuous)
                            .fill(isAccent ? DesignTokens.accent : .ultraThinMaterial)
                    )
                    .shadow(
                        color: isAccent ? DesignTokens.accent.opacity(0.3) : Color.black.opacity(0.04),
                        radius: isAccent ? 8 : 4,
                        x: 0,
                        y: isAccent ? 4 : 2
                    )
            )
            .foregroundColor(isAccent ? .white : .primary)
            .font(.system(size: 13, weight: .semibold))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

@available(macOS 12.3, *)
struct NavButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.radiusMd, style: .continuous)
                    .fill(isSelected ? DesignTokens.accentLight : Color.clear)
            )
            .foregroundColor(isSelected ? DesignTokens.accent : .secondary)
            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
            .contentShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMd))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Status Orb

@available(macOS 12.3, *)
struct StatusOrb: View {
    let color: Color
    var isPulsing: Bool = false
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 3)
                    .frame(width: 14, height: 14)
            )
            .overlay(
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .opacity(isPulsing ? 0.5 : 0)
                    .scaleEffect(isPulsing ? 2 : 1)
                    .animation(
                        Animation.easeOut(duration: 1).repeatForever(autoreverses: false),
                        value: isPulsing
                    )
            )
    }
}

// MARK: - Animated Gradient Text

@available(macOS 12.3, *)
struct GradientText: View {
    let text: String
    let font: Font
    
    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(DesignTokens.accentGradient)
    }
}

// MARK: - Typing Indicator

@available(macOS 12.3, *)
struct TypingIndicator: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .offset(y: animating ? -4 : 0)
                    .animation(
                        Animation.easeInOut(duration: 0.4)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }
}

// MARK: - Floating Action Button (Orb)

@available(macOS 12.3, *)
struct FloatingOrb: View {
    @State private var isHovered = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "brain")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(DesignTokens.accentGradient)
                        .shadow(
                            color: DesignTokens.accent.opacity(0.4),
                            radius: isHovered ? 16 : 12,
                            x: 0,
                            y: isHovered ? 8 : 4
                        )
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Search Bar

@available(macOS 12.3, *)
struct GlassSearchBar: View {
    @Binding var text: String
    let placeholder: String
    @FocusState var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16, weight: .medium))
            
            TextField(placeholder, text: $text)
                .font(.system(size: 14))
                .focused($isFocused)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.radiusFull, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusFull, style: .continuous)
                        .stroke(isFocused ? DesignTokens.accent : Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
        .shadow(color: isFocused ? DesignTokens.accent.opacity(0.1) : Color.clear, radius: 8)
        .animation(.easeOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Section Header

@available(macOS 12.3, *)
struct SectionHeader: View {
    let title: String
    var action: (() -> Void)?
    var actionTitle: String?
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
            
            Spacer()
            
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DesignTokens.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - View Extensions

@available(macOS 12.3, *)
extension View {
    func glassCard(padding: CGFloat = 16, cornerRadius: CGFloat = DesignTokens.radiusXl) -> some View {
        modifier(GlassCardModifier(padding: padding, cornerRadius: cornerRadius))
    }
}

@available(macOS 12.3, *)
struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let padding: CGFloat
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(colorScheme == .dark ? DesignTokens.bgCardDark : DesignTokens.bgCard)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}
