import SwiftUI

@available(macOS 14.0, *)
struct ContentView: View {
    @StateObject private var service = AppService()
    @State private var selectedTab: SidebarTab = .dashboard
    @State private var showLaunchAnimation = true
    @State private var contentReady = false
    
    var body: some View {
        ZStack {
            // Main content
            if contentReady {
                MainContentView(service: service, selectedTab: $selectedTab)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            
            // Launch animation overlay
            if showLaunchAnimation {
                LaunchAnimation(isComplete: $showLaunchAnimation)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .onChange(of: showLaunchAnimation) { showing in
            if !showing {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    contentReady = true
                }
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
            // Glass Sidebar
            GlassSidebar(selectedTab: $selectedTab, service: service)
            
            // Content area with page transitions
            ZStack {
                // Background mesh gradient
                MeshGradient()
                    .opacity(0.5)
                    .ignoresSafeArea()
                
                // Content
                Group {
                    switch selectedTab {
                    case .dashboard:
                        DashboardView(service: service)
                            .transition(pageTransition)
                    case .memories:
                        MemoriesView(service: service)
                            .transition(pageTransition)
                    case .chat:
                        ChatView(service: service)
                            .transition(pageTransition)
                    case .settings:
                        SettingsView()
                            .transition(pageTransition)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.xxl))
            .padding(.vertical, Spacing.lg)
            .padding(.trailing, Spacing.lg)
        }
        .background(Colors.background)
    }
    
    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.98)),
            removal: .opacity
        )
    }
}

@available(macOS 14.0, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
    }
}
