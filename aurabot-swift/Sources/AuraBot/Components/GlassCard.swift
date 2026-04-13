import SwiftUI

@available(macOS 14.0, *)
struct GlassCard<Content: View>: View {
    let content: Content
    let padding: CGFloat
    let cornerRadius: CGFloat
    let shadow: ShadowStyle
    let showBorder: Bool
    
    init(
        padding: CGFloat = Spacing.lg,
        cornerRadius: CGFloat = Radius.xl,
        shadow: ShadowStyle = Shadows.md,
        showBorder: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.showBorder = showBorder
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    // Glass background
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                    
                    // Subtle white overlay for frosted look
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Colors.white.opacity(0.6))
                }
            )
            .overlay(
                Group {
                    if showBorder {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Colors.border, lineWidth: 1)
                    }
                }
            )
            .cornerRadius(cornerRadius)
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

@available(macOS 14.0, *)
struct GlassCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Colors.background
            
            GlassCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Glass Card")
                        .font(Typography.title2)
                        .foregroundColor(Colors.textPrimary)
                    
                    Text("This is a frosted glass card component with a subtle border and shadow.")
                        .font(Typography.body)
                        .foregroundColor(Colors.textSecondary)
                }
            }
            .padding()
        }
    }
}
