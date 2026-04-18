import SwiftUI

@available(macOS 14.0, *)
struct ContentView: View {
    @ObservedObject var service: AppService
    @State private var selectedTab: SidebarTab = .dashboard
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            // Main content
            MainContentView(service: service, selectedTab: $selectedTab)
                .opacity(isLoading ? 0 : 1)
            
            // Loading screen
            if isLoading {
                LoadingScreen()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isLoading = false
                }
            }
        }
    }
}

@available(macOS 14.0, *)
struct LoadingScreen: View {
    @State private var opacity = 0.0
    
    var body: some View {
        ZStack {
            // Soft gradient background
            Colors.background
            
            // Logo
            VStack(spacing: 16) {
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(Color(hex: "#2563EB"))
                        .frame(width: 100, height: 100)
                        .blur(radius: 30)
                        .opacity(0.4)
                    
                    // Main circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#2563EB"),
                                    Color(hex: "#7C3AED")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    // Icon
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(.white)
                }
                
                Text("Aura")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "#111827"))
            }
            .opacity(opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = 1.0
            }
        }
    }
}

@available(macOS 14.0, *)
struct MainContentView: View {
    @ObservedObject var service: AppService
    @Binding var selectedTab: SidebarTab
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            GlassSidebar(selectedTab: $selectedTab, service: service)
            
            // Content area
            ZStack {
                // Content based on selected tab
                switch selectedTab {
                case .dashboard:
                    DashboardView(service: service)
                case .memories:
                    MemoriesView(service: service)
                case .chat:
                    ChatView(service: service)
                case .settings:
                    SettingsView(service: service)
                }
            }
            .background(.ultraThinMaterial)
            .background(Colors.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: Radius.xxl))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xxl)
                    .stroke(Colors.glassBorder, lineWidth: 1)
            )
            .shadow(color: Shadows.lg.color, radius: Shadows.lg.radius, x: Shadows.lg.x, y: Shadows.lg.y)
            .padding(.vertical, 12)
            .padding(.trailing, 12)
        }
        .background(
            MeshGradientBackground()
                .ignoresSafeArea()
        )
    }
}

@available(macOS 14.0, *)
struct MeshGradientBackground: View {
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base soft color
                Colors.background
                
                // Animated soft orbs for mesh-like effect
                Circle()
                    .fill(Colors.primary.opacity(0.08))
                    .frame(width: geometry.size.width * 0.8, height: geometry.size.width * 0.8)
                    .blur(radius: 80)
                    .offset(
                        x: animate ? 40 : -40,
                        y: animate ? -60 : 60
                    )
                
                Circle()
                    .fill(Colors.secondary.opacity(0.06))
                    .frame(width: geometry.size.width * 0.6, height: geometry.size.width * 0.6)
                    .blur(radius: 70)
                    .offset(
                        x: animate ? -50 : 50,
                        y: animate ? 80 : -80
                    )
                
                Circle()
                    .fill(Colors.accent.opacity(0.04))
                    .frame(width: geometry.size.width * 0.5, height: geometry.size.width * 0.5)
                    .blur(radius: 60)
                    .offset(
                        x: animate ? 30 : -30,
                        y: animate ? 40 : -40
                    )
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                    animate.toggle()
                }
            }
        }
    }
}

@available(macOS 14.0, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(service: AppService())
            .frame(width: 1200, height: 800)
    }
}
