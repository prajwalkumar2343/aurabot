import SwiftUI

@available(macOS 14.0, *)
struct GradientButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    init(
        _ title: String,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md)
            .background(
                ZStack {
                    // Gradient background
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(
                            LinearGradient(
                                colors: isHovered 
                                    ? [Colors.primaryHover, Colors.secondary]
                                    : [Colors.primary, Colors.secondary.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    // Shine effect on hover
                    if isHovered {
                        RoundedRectangle(cornerRadius: Radius.md)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            )
            .foregroundColor(.white)
            .shadow(
                color: isHovered ? Colors.primary.opacity(0.4) : Colors.primary.opacity(0.2),
                radius: isHovered ? 20 : 12,
                x: 0,
                y: isHovered ? 8 : 4
            )
            .scaleEffect(isPressed ? 0.96 : isHovered ? 1.02 : 1.0)
            .offset(y: isHovered ? -2 : 0)
        }
        .buttonStyle(.plain)
        .animation(AnimationPresets.hover, value: isHovered)
        .animation(AnimationPresets.press, value: isPressed)
        .onHover { hovering in
            isHovered = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

@available(macOS 14.0, *)
struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    init(
        _ title: String,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                }
                
                Text(title)
                    .font(.system(size: 15, weight: .medium))
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(isHovered ? Colors.surfaceHover : Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .stroke(Colors.border, lineWidth: 1)
                    )
            )
            .foregroundColor(Colors.textPrimary)
            .shadow(
                color: isHovered ? Shadows.sm.color : Color.clear,
                radius: isHovered ? Shadows.sm.radius : 0,
                x: Shadows.sm.x,
                y: isHovered ? Shadows.sm.y : 0
            )
            .scaleEffect(isPressed ? 0.96 : isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(AnimationPresets.hover, value: isHovered)
        .animation(AnimationPresets.press, value: isPressed)
        .onHover { hovering in
            isHovered = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

@available(macOS 14.0, *)
struct IconButton: View {
    let icon: String
    let action: () -> Void
    let size: CGFloat
    let background: Color
    let foreground: Color
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    init(
        _ icon: String,
        size: CGFloat = 40,
        background: Color = Colors.surface,
        foreground: Color = Colors.textPrimary,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.background = background
        self.foreground = foreground
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(isHovered ? Colors.surfaceHover : background)
                        .overlay(
                            Circle()
                                .stroke(Colors.border, lineWidth: 1)
                        )
                )
                .foregroundColor(foreground)
                .shadow(
                    color: isHovered ? Shadows.sm.color : Color.clear,
                    radius: isHovered ? Shadows.sm.radius : 0,
                    x: Shadows.sm.x,
                    y: Shadows.sm.y
                )
                .scaleEffect(isPressed ? 0.9 : isHovered ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(AnimationPresets.hover, value: isHovered)
        .animation(AnimationPresets.press, value: isPressed)
        .onHover { hovering in
            isHovered = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

@available(macOS 14.0, *)
struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: Double = 0
    
    var body: some View {
        Button(action: {
            withAnimation(.easeOut(duration: 0.4)) {
                rippleScale = 2
                rippleOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                action()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                rippleScale = 0
            }
        }) {
            ZStack {
                // Ripple effect
                Circle()
                    .fill(Color.white)
                    .scaleEffect(rippleScale)
                    .opacity(rippleOpacity)
                
                // Button background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Colors.primary, Colors.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: Colors.primary.opacity(0.4),
                        radius: isHovered ? 20 : 12,
                        x: 0,
                        y: isHovered ? 10 : 6
                    )
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .scaleEffect(isHovered ? 1.1 : 1.0)
            }
            .frame(width: 56, height: 56)
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .rotationEffect(.degrees(isHovered ? 90 : 0))
        }
        .buttonStyle(.plain)
        .animation(AnimationPresets.spring, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                rippleOpacity = 0.3
            }
        }
    }
}

@available(macOS 14.0, *)
struct GradientButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Spacing.xl) {
            GradientButton("Get Started", icon: "arrow.right") {}
            
            SecondaryButton("Cancel") {}
            
            HStack(spacing: Spacing.md) {
                IconButton("bell") {}
                IconButton("gear") {}
                IconButton("person") {}
            }
            
            FloatingActionButton(icon: "plus") {}
        }
        .padding()
        .background(Colors.background)
    }
}
