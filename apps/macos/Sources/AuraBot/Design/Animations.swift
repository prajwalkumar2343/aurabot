import SwiftUI

// MARK: - Animation Presets
@available(macOS 14.0, *)
enum AnimationPresets {
    // Spring animations
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let springBouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)
    static let springSnappy = Animation.spring(response: 0.3, dampingFraction: 0.9)
    
    // Ease animations
    static let ease = Animation.easeInOut(duration: 0.3)
    static let easeFast = Animation.easeInOut(duration: 0.2)
    static let easeSlow = Animation.easeInOut(duration: 0.5)
    
    // Linear for continuous
    static let linear = Animation.linear(duration: 0.3)
    static let linearSlow = Animation.linear(duration: 1.0)
    
    // Specialized
    static let hover = Animation.spring(response: 0.2, dampingFraction: 0.9)
    static let press = Animation.spring(response: 0.15, dampingFraction: 0.8)
    static let appear = Animation.spring(response: 0.5, dampingFraction: 0.7)
    static let disappear = Animation.easeIn(duration: 0.2)
}

// MARK: - Staggered Animation Helper
@available(macOS 14.0, *)
struct StaggeredAnimation {
    let index: Int
    let baseDelay: Double
    let staggerDelay: Double
    
    var delay: Double {
        baseDelay + (Double(index) * staggerDelay)
    }
    
    func animation(for base: Animation = AnimationPresets.spring) -> Animation {
        base.delay(delay)
    }
}

// MARK: - View Animation Modifiers
@available(macOS 14.0, *)
extension View {
    func fadeIn(delay: Double = 0) -> some View {
        self
            .opacity(0)
            .transition(.opacity.animation(AnimationPresets.easeFast.delay(delay)))
    }
    
    func slideIn(from edge: Edge, delay: Double = 0) -> some View {
        self
            .transition(.move(edge: edge).combined(with: .opacity).animation(AnimationPresets.spring.delay(delay)))
    }
    
    func scaleIn(delay: Double = 0) -> some View {
        self
            .scaleEffect(0.9)
            .opacity(0)
            .transition(.scale.combined(with: .opacity).animation(AnimationPresets.spring.delay(delay)))
    }
    
    func withStagger(index: Int, baseDelay: Double = 0.1, stagger: Double = 0.05) -> some View {
        let staggered = StaggeredAnimation(index: index, baseDelay: baseDelay, staggerDelay: stagger)
        return self
            .opacity(0)
            .transition(.opacity.animation(staggered.animation()))
    }
}

// MARK: - Hover Effects
@available(macOS 14.0, *)
struct HoverLift: ViewModifier {
    @State private var isHovered = false
    let scale: CGFloat
    let lift: CGFloat
    let shadow: ShadowStyle
    
    init(scale: CGFloat = 1.02, lift: CGFloat = 4, shadow: ShadowStyle = Shadows.lg) {
        self.scale = scale
        self.lift = lift
        self.shadow = shadow
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .offset(y: isHovered ? -lift : 0)
            .shadow(
                color: isHovered ? shadow.color : Color.clear,
                radius: isHovered ? shadow.radius : 0,
                x: shadow.x,
                y: isHovered ? shadow.y - 2 : 0
            )
            .animation(AnimationPresets.hover, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

@available(macOS 14.0, *)
struct GlowOnHover: ViewModifier {
    @State private var isHovered = false
    let color: Color
    let radius: CGFloat
    
    init(color: Color = Colors.primary, radius: CGFloat = 20) {
        self.color = color
        self.radius = radius
    }
    
    func body(content: Content) -> some View {
        content
            .shadow(color: isHovered ? color.opacity(0.5) : Color.clear, radius: isHovered ? radius : 0)
            .animation(AnimationPresets.hover, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

@available(macOS 14.0, *)
struct ScaleOnHover: ViewModifier {
    @State private var isHovered = false
    let scale: CGFloat
    
    init(scale: CGFloat = 1.05) {
        self.scale = scale
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .animation(AnimationPresets.hover, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

@available(macOS 14.0, *)
struct TiltOnHover: ViewModifier {
    @State private var isHovered = false
    @State private var tiltX: CGFloat = 0
    @State private var tiltY: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(isHovered ? Double(tiltX) : 0),
                axis: (x: 0, y: 1, z: 0)
            )
            .rotation3DEffect(
                .degrees(isHovered ? Double(tiltY) : 0),
                axis: (x: 1, y: 0, z: 0)
            )
            .animation(AnimationPresets.hover, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

@available(macOS 14.0, *)
struct MagneticHover: ViewModifier {
    @State private var location: CGPoint = .zero
    @State private var isHovered = false
    let strength: CGFloat
    
    init(strength: CGFloat = 8) {
        self.strength = strength
    }
    
    func body(content: Content) -> some View {
        content
            .offset(
                x: isHovered ? (location.x - 0.5) * strength : 0,
                y: isHovered ? (location.y - 0.5) * strength : 0
            )
            .animation(AnimationPresets.hover, value: isHovered)
            .animation(AnimationPresets.hover, value: location)
            .onHover { hovering in
                isHovered = hovering
                if !hovering {
                    location = .zero
                }
            }
    }
}

// MARK: - View Extension for Hover Effects
@available(macOS 14.0, *)
extension View {
    func hoverLift(scale: CGFloat = 1.02, lift: CGFloat = 4, shadow: ShadowStyle = Shadows.lg) -> some View {
        modifier(HoverLift(scale: scale, lift: lift, shadow: shadow))
    }
    
    func glowOnHover(color: Color = Colors.primary, radius: CGFloat = 20) -> some View {
        modifier(GlowOnHover(color: color, radius: radius))
    }
    
    func scaleOnHover(_ scale: CGFloat = 1.05) -> some View {
        modifier(ScaleOnHover(scale: scale))
    }
    
    func tiltOnHover() -> some View {
        modifier(TiltOnHover())
    }
    
    func magneticHover(strength: CGFloat = 8) -> some View {
        modifier(MagneticHover(strength: strength))
    }
}

// MARK: - Press Effects
@available(macOS 14.0, *)
struct PressScale: ViewModifier {
    @GestureState private var isPressed = false
    let scale: CGFloat
    
    init(scale: CGFloat = 0.95) {
        self.scale = scale
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(AnimationPresets.press, value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in
                        state = true
                    }
            )
    }
}

@available(macOS 14.0, *)
extension View {
    func pressScale(_ scale: CGFloat = 0.95) -> some View {
        modifier(PressScale(scale: scale))
    }
}

// MARK: - Shimmer Effect
@available(macOS 14.0, *)
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double
    
    init(duration: Double = 1.5) {
        self.duration = duration
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.5),
                            Color.white.opacity(0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (phase * geometry.size.width * 2))
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(Animation.linear(duration: duration).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

@available(macOS 14.0, *)
extension View {
    func shimmer(duration: Double = 1.5) -> some View {
        modifier(ShimmerModifier(duration: duration))
    }
}

// MARK: - Pulse Animation
@available(macOS 14.0, *)
struct PulseModifier: ViewModifier {
    @State private var isPulsing = false
    let scale: CGFloat
    let duration: Double
    
    init(scale: CGFloat = 1.1, duration: Double = 1.0) {
        self.scale = scale
        self.duration = duration
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? scale : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

@available(macOS 14.0, *)
extension View {
    func pulse(scale: CGFloat = 1.1, duration: Double = 1.0) -> some View {
        modifier(PulseModifier(scale: scale, duration: duration))
    }
}

// MARK: - Count Up Animation
@available(macOS 14.0, *)
struct CountUpModifier: ViewModifier {
    let value: Int
    @State private var displayValue: Int = 0
    let duration: Double
    
    init(value: Int, duration: Double = 1.0) {
        self.value = value
        self.duration = duration
    }
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                let steps = 30
                let stepDuration = duration / Double(steps)
                let increment = Double(value) / Double(steps)
                
                for i in 0...steps {
                    DispatchQueue.main.asyncAfter(deadline: .now() + (Double(i) * stepDuration)) {
                        displayValue = min(Int(Double(i) * increment), value)
                    }
                }
            }
    }
}

// MARK: - Matched Geometry Helpers
@available(macOS 14.0, *)
enum TransitionIDs {
    static let sidebar = "sidebar"
    static let content = "content"
    static let header = "header"
    static let card = "card"
}
