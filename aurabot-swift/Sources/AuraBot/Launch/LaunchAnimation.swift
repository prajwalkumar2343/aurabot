import SwiftUI

@available(macOS 14.0, *)
struct LaunchAnimation: View {
    @Binding var isComplete: Bool
    
    @State private var phase: LaunchPhase = .start
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var logoGlow: Double = 0
    @State private var backgroundOpacity: Double = 0
    @State private var windowShapeProgress: CGFloat = 0
    
    enum LaunchPhase {
        case start
        case logoAppear
        case logoPulse
        case expandWindow
        case revealBackground
        case complete
    }
    
    var body: some View {
        ZStack {
            // Background gradient mesh
            MeshGradient()
                .opacity(backgroundOpacity)
            
            // Logo with glow
            ZStack {
                // Outer glow rings
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Colors.primary.opacity(0.3 - Double(i) * 0.1), lineWidth: 2)
                        .scaleEffect(logoScale * (1.0 + CGFloat(i) * 0.3 + CGFloat(logoGlow) * 0.2))
                        .opacity(logoOpacity * (1.0 - Double(i) * 0.3))
                }
                
                // Main logo circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Colors.primary, Colors.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .shadow(
                        color: Colors.primary.opacity(0.5 + logoGlow * 0.3),
                        radius: 40 + logoGlow * 20,
                        x: 0,
                        y: 0
                    )
                
                // Brain icon
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(.white)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
            }
            .clipShape(
                RoundedRectangle(cornerRadius: 24 * (1 - windowShapeProgress))
            )
            .scaleEffect(1 + windowShapeProgress * 10)
            .opacity(1 - windowShapeProgress)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
            startAnimationSequence()
        }
    }
    
    private func startAnimationSequence() {
        // Phase 1: Logo fade in
        withAnimation(.easeOut(duration: 0.5)) {
            logoOpacity = 1
            logoScale = 1
        }
        
        // Phase 2: Pulse glow
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.8).repeatCount(2, autoreverses: true)) {
                logoGlow = 1
            }
        }
        
        // Phase 3: Expand to window shape
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeIn(duration: 0.6)) {
                windowShapeProgress = 1
            }
        }
        
        // Phase 4: Reveal background
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.8)) {
                backgroundOpacity = 1
            }
        }
        
        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                isComplete = true
            }
        }
    }
}

@available(macOS 14.0, *)
struct MeshGradient: View {
    @State private var phase: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated gradient orbs
                MeshOrb(
                    color: Colors.primary.opacity(0.15),
                    size: 400,
                    position: CGPoint(
                        x: geometry.size.width * 0.2,
                        y: geometry.size.height * 0.3
                    ),
                    phase: phase
                )
                
                MeshOrb(
                    color: Colors.secondary.opacity(0.12),
                    size: 500,
                    position: CGPoint(
                        x: geometry.size.width * 0.8,
                        y: geometry.size.height * 0.2
                    ),
                    phase: phase + 1
                )
                
                MeshOrb(
                    color: Colors.accent.opacity(0.08),
                    size: 350,
                    position: CGPoint(
                        x: geometry.size.width * 0.7,
                        y: geometry.size.height * 0.8
                    ),
                    phase: phase + 2
                )
                
                MeshOrb(
                    color: Colors.success.opacity(0.08),
                    size: 300,
                    position: CGPoint(
                        x: geometry.size.width * 0.3,
                        y: geometry.size.height * 0.7
                    ),
                    phase: phase + 3
                )
                
                // White overlay for clean look
                Color.white.opacity(0.85)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                phase = 2 * .pi
            }
        }
    }
}

@available(macOS 14.0, *)
struct MeshOrb: View {
    let color: Color
    let size: CGFloat
    let position: CGPoint
    let phase: Double
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [color, Color.clear]),
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .position(
                x: position.x + sin(phase) * 30,
                y: position.y + cos(phase) * 20
            )
            .blur(radius: 40)
    }
}

@available(macOS 14.0, *)
struct ContentTransitionView: View {
    @State private var showContent = false
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            MeshGradient()
            
            VStack(spacing: Spacing.xxl) {
                // Logo
                HStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Colors.primary, Colors.secondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(.white)
                    }
                    
                    Text("Aura")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Colors.textPrimary)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : -20)
                
                // Loading indicator
                HStack(spacing: Spacing.sm) {
                    ForEach(0..<3) { i in
                        LoadingDot(delay: Double(i) * 0.2)
                    }
                }
                .opacity(showContent ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                showContent = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                onComplete()
            }
        }
    }
}

@available(macOS 14.0, *)
struct LoadingDot: View {
    let delay: Double
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .fill(Colors.primary)
            .frame(width: 8, height: 8)
            .scaleEffect(isAnimating ? 1.5 : 0.5)
            .opacity(isAnimating ? 1 : 0.3)
            .animation(
                Animation.easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

@available(macOS 14.0, *)
struct LaunchAnimation_Previews: PreviewProvider {
    static var previews: some View {
        LaunchAnimation(isComplete: .constant(false))
    }
}
