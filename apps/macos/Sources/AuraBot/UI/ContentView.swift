import SwiftUI
import AppKit

@available(macOS 14.0, *)
struct ContentView: View {
    @ObservedObject var service: AppService
    @State private var selectedTab: SidebarTab = .dashboard
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            MainContentView(service: service, selectedTab: $selectedTab)
                .opacity(isLoading ? 0 : 1)
            
            if isLoading {
                LoadingScreen()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.25)) {
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
            Colors.background
            
            VStack(spacing: Spacing.lg) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(Colors.primary)
                
                Text("Aura")
                    .font(Typography.title1)
                    .foregroundColor(Colors.textPrimary)
            }
            .opacity(opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) {
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
            SidebarView(selectedTab: $selectedTab, service: service)
            
            ZStack {
                if service.needsOnboarding {
                    PermissionOnboardingView(service: service)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    switch selectedTab {
                    case .dashboard:
                        DashboardView(service: service)
                    case .memories:
                        MemoriesView(service: service)
                    case .settings:
                        SettingsView(service: service)
                    }
                }
            }
            .background(Colors.background)
            .cornerRadius(Radius.xl)
            .padding(.vertical, Spacing.lg)
            .padding(.trailing, Spacing.lg)
        }
        .background(Colors.background)
        .onAppear {
            service.refreshPermissionStatuses()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            service.refreshPermissionStatuses()
        }
        .onChange(of: service.needsOnboarding) { _, needsOnboarding in
            if !needsOnboarding {
                selectedTab = .dashboard
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
