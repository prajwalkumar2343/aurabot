import SwiftUI

@available(macOS 14.0, *)
struct GlassCard<Content: View>: View {
    let content: Content
    let padding: CGFloat
    let cornerRadius: CGFloat
    let shadow: ShadowStyle
    let showBorder: Bool
    let blur: Material
    
    init(
        padding: CGFloat = Spacing.lg,
        cornerRadius: CGFloat = Radius.xl,
        shadow: ShadowStyle = Shadows.md,
        showBorder: Bool = true,
        blur: Material = .thinMaterial,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.showBorder = showBorder
        self.blur = blur
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Colors.surface)

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Colors.surfaceSecondary.opacity(0.45))
                }
            )
            .overlay(
                Group {
                    if showBorder {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Colors.glassBorder, lineWidth: 1)
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
