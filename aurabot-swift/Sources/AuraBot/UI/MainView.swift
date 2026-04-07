import SwiftUI

@available(macOS 12.3, *)
struct MainView: View {
    @StateObject private var service = AppService()
    @State private var selectedTab: Tab = .dashboard
    
    enum Tab {
        case dashboard, memories, chat, settings
    }
    
    var body: some View {
        NavigationSplitView {
            Sidebar(selectedTab: $selectedTab, service: service)
                .frame(minWidth: 260)
        } detail: {
            switch selectedTab {
            case .dashboard:
                DashboardView(service: service)
            case .memories:
                MemoriesView(service: service)
            case .chat:
                ChatView(service: service)
            case .settings:
                SettingsView()
            }
        }
        .onAppear {
            service.start()
        }
    }
}

@available(macOS 12.3, *)
struct Sidebar: View {
    @Binding var selectedTab: MainView.Tab
    @ObservedObject var service: AppService
    
    var body: some View {
        VStack(spacing: 0) {
            // App Brand
            HStack {
                Image(systemName: "brain")
                    .font(.title2)
                Text("Aura")
                    .font(.title2.bold())
                Spacer()
            }
            .padding()
            
            // Navigation
            VStack(spacing: 4) {
                NavButton(title: "Dashboard", icon: "square.grid.2x2", tab: .dashboard, selected: $selectedTab)
                NavButton(title: "Memories", icon: "bubble.left", tab: .memories, selected: $selectedTab)
                NavButton(title: "Chat", icon: "message", tab: .chat, selected: $selectedTab)
                NavButton(title: "Settings", icon: "gear", tab: .settings, selected: $selectedTab)
            }
            .padding(.horizontal, 8)
            
            Spacer()
            
            // Status Card
            VStack(alignment: .leading, spacing: 12) {
                Text("Capture Status")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Toggle("Active", isOn: $service.captureEnabled)
                    .onChange(of: service.captureEnabled) { _ in
                        service.toggleCapture()
                    }
                
                Text("Interval: 30s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // System Status
            HStack(spacing: 12) {
                StatusDot(color: .green)
                Text("LLM")
                    .font(.caption)
                
                StatusDot(color: .green)
                Text("Memory")
                    .font(.caption)
                
                StatusDot(color: service.captureEnabled ? .green : .red)
                Text("Capture")
                    .font(.caption)
            }
            .padding()
            
            Divider()
            
            // User Profile
            HStack {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 32, height: 32)
                    .overlay(Text("JD").font(.caption))
                
                VStack(alignment: .leading) {
                    Text("John Doe")
                        .font(.callout)
                    Text("Pro Plan")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

@available(macOS 12.3, *)
struct NavButton: View {
    let title: String
    let icon: String
    let tab: MainView.Tab
    @Binding var selected: MainView.Tab
    
    var isSelected: Bool {
        selected == tab
    }
    
    var body: some View {
        Button(action: { selected = tab }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                    .fontWeight(isSelected ? .semibold : .regular)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.yellow.opacity(0.2) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .primary : .secondary)
    }
}

struct StatusDot: View {
    let color: Color
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
    }
}
