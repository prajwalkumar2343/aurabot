import SwiftUI

@available(macOS 14.0, *)
struct LaunchAnimation: View {
    @Binding var isComplete: Bool
    
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background
            Colors.background
            
            // Simple gradient background
            LinearGradient(
                colors: [
                    Colors.primary.opacity(0.1),
                    Colors.secondary.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(contentOpacity)
            
            // Logo with glow
            VStack(spacing: 24) {
                ZStack {
                    // Glow
                    Circle()
                        .fill(Colors.primary)
                        .frame(width: 140, height: 140)
                        .blur(radius: 40)
                        .opacity(logoOpacity * 0.5)
                    
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
                        .shadow(
                            color: Colors.primary.opacity(0.5),
                            radius: 30,
                            x: 0,
                            y: 0
                        )
                    
                    // Brain icon
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 50, weight: .light))
                        .foregroundColor(.white)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                
                // App name
                Text("Aura")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(Colors.textPrimary)
                    .opacity(logoOpacity)
                    .offset(y: logoOpacity == 0 ? 20 : 0)
                
                Text("AI Memory Assistant")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
                    .opacity(logoOpacity)
                    .offset(y: logoOpacity == 0 ? 20 : 0)
            }
            
            // Skip button
            VStack {
                Spacer()
                Button("Skip") {
                    finishAnimation()
                }
                .buttonStyle(.plain)
                .foregroundColor(Colors.textMuted)
                .padding()
                .opacity(logoOpacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startAnimationSequence()
        }
    }
    
    private func startAnimationSequence() {
        // Logo fade in and scale
        withAnimation(.easeOut(duration: 0.6)) {
            logoOpacity = 1
            logoScale = 1
        }
        
        // Background fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.8)) {
                contentOpacity = 1
            }
        }
        
        // Complete after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            finishAnimation()
        }
    }
    
    private func finishAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            isComplete = true
        }
    }
}

// MARK: - Mesh Gradient Background (Simplified)
@available(macOS 14.0, *)
struct MeshGradient: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Simple orbs
                Circle()
                    .fill(Colors.primary.opacity(0.15))
                    .frame(width: 400, height: 400)
                    .position(x: geometry.size.width * 0.2, y: geometry.size.height * 0.3)
                    .blur(radius: 60)
                
                Circle()
                    .fill(Colors.secondary.opacity(0.12))
                    .frame(width: 500, height: 500)
                    .position(x: geometry.size.width * 0.8, y: geometry.size.height * 0.2)
                    .blur(radius: 60)
                
                Circle()
                    .fill(Colors.accent.opacity(0.08))
                    .frame(width: 350, height: 350)
                    .position(x: geometry.size.width * 0.7, y: geometry.size.height * 0.8)
                    .blur(radius: 60)
                
                // White overlay
                Color.white.opacity(0.85)
            }
        }
    }
}

@available(macOS 14.0, *)
struct LaunchAnimation_Previews: PreviewProvider {
    static var previews: some View {
        LaunchAnimation(isComplete: .constant(false))
    }
}
