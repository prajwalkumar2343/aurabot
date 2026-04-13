import SwiftUI

@available(macOS 12.3, *)
struct MainView: View {
    @StateObject private var service = AppService()
    @State private var selectedTab: Tab = .dashboard
    @State private var showingOverlay = false
    
    enum Tab {
        case dashboard, memories, chat, settings
    }
    
    var body: some View {
        NavigationSplitView {
            Sidebar(selectedTab: $selectedTab, service: service)
                .frame(minWidth: 260, maxWidth: 280)
        } detail: {
            ZStack {
                // Background gradient
                DesignTokens.accentGradientSubtle
                    .ignoresSafeArea()
                    .opacity(0.3)
                
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
        }
        .onAppear {
            service.start()
        }
        .overlay(alignment: .bottomTrailing) {
            if showingOverlay {
                OverlayPanel(isShowing: $showingOverlay, service: service)
                    .padding(24)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            } else {
                FloatingOrb { 
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingOverlay.toggle()
                    }
                }
                .padding(24)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

@available(macOS 12.3, *)
struct Sidebar: View {
    @Binding var selectedTab: MainView.Tab
    @ObservedObject var service: AppService
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // App Brand
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(DesignTokens.accentGradient)
                            .frame(width: 36, height: 36)
                            .shadow(color: DesignTokens.accent.opacity(0.25), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: "brain")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    GradientText(text: "Aura", font: .system(size: 20, weight: .bold))
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                
                // Navigation
                VStack(spacing: 4) {
                    NavButton(
                        title: "Dashboard",
                        icon: "square.grid.2x2",
                        tab: .dashboard,
                        selected: $selectedTab
                    )
                    NavButton(
                        title: "Memories",
                        icon: "clock.arrow.circlepath",
                        tab: .memories,
                        selected: $selectedTab
                    )
                    NavButton(
                        title: "Chat",
                        icon: "bubble.left.and.bubble.right",
                        tab: .chat,
                        selected: $selectedTab
                    )
                    NavButton(
                        title: "Settings",
                        icon: "gear",
                        tab: .settings,
                        selected: $selectedTab
                    )
                }
                .padding(.horizontal, 12)
                
                Spacer(minLength: 24)
                
                // Capture Status Card
                VStack(alignment: .leading, spacing: 14) {
                    Text("Capture Status")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(0.8)
                    
                    HStack {
                        Text(service.captureEnabled ? "Active" : "Paused")
                            .font(.system(size: 13, weight: .medium))
                        
                        Spacer()
                        
                        Toggle("", isOn: $service.captureEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: DesignTokens.accent))
                            .controlSize(.small)
                            .onChange(of: service.captureEnabled) { _ in
                                service.toggleCapture()
                            }
                    }
                    
                    Text("Interval: \(service.captureInterval)s")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .glassCard(padding: 16, cornerRadius: 16)
                .padding(.horizontal, 12)
                
                // Shortcuts Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Shortcuts")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(0.8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ShortcutRow(key: "⌘K", action: "Search")
                        ShortcutRow(key: "⌘N", action: "New Memory")
                        ShortcutRow(key: "⌃⌥E", action: "Quick Enhance")
                    }
                }
                .padding(16)
                .glassCard(padding: 16, cornerRadius: 16)
                .padding(.horizontal, 12)
                
                Spacer(minLength: 24)
                
                // System Status
                HStack(spacing: 16) {
                    StatusItem(label: "LLM", isOnline: service.isLLMConnected)
                    StatusItem(label: "Memory", isOnline: service.isMemoryConnected)
                    StatusItem(label: "Capture", isOnline: service.captureEnabled)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                
                // Backend Status
                HStack(spacing: 8) {
                    StatusOrb(
                        color: service.isBackendConnected ? DesignTokens.success : DesignTokens.error,
                        isPulsing: service.isBackendConnected
                    )
                    
                    Text(service.isBackendConnected ? "Connected" : "Connecting...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                
                // Theme Toggle
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: colorScheme == .dark ? "moon.fill" : "sun.max.fill")
                            .font(.system(size: 12))
                        Text("Dark Mode")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Toggle("", isOn: .constant(colorScheme == .dark))
                        .toggleStyle(SwitchToggleStyle(tint: DesignTokens.accent))
                        .controlSize(.small)
                        .disabled(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .padding(.bottom, 12)
            }
        }
        .frame(minWidth: 260, maxWidth: 280)
        .background(
            GlassSidebar {
                EmptyView()
            }
        )
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
        Button(action: { 
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selected = tab
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(NavButtonStyle(isSelected: isSelected))
        .overlay(
            // Active indicator
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignTokens.accent)
                    .frame(width: 3, height: isSelected ? 18 : 0)
                    .offset(x: -1)
                Spacer()
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        )
    }
}

@available(macOS 12.3, *)
struct ShortcutRow: View {
    let key: String
    let action: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                )
            
            Text(action)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

@available(macOS 12.3, *)
struct StatusItem: View {
    let label: String
    let isOnline: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            StatusOrb(
                color: isOnline ? DesignTokens.success : DesignTokens.error,
                isPulsing: isOnline
            )
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Overlay Panel

@available(macOS 12.3, *)
struct OverlayPanel: View {
    @Binding var isShowing: Bool
    @ObservedObject var service: AppService
    @State private var message = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(content: "Hello! I'm Aura. How can I help you today?", isUser: false, timestamp: Date())
    ]
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(DesignTokens.accent)
                        .frame(width: 8, height: 8)
                        .shadow(color: DesignTokens.accent.opacity(0.5), radius: 4)
                    
                    Text("Aura Assistant")
                        .font(.system(size: 15, weight: .semibold))
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isShowing = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.primary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Messages
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(messages) { msg in
                        MessageBubble(message: msg)
                    }
                }
                .padding(16)
            }
            .frame(maxHeight: 300)
            
            Divider()
            
            // Input
            HStack(spacing: 8) {
                TextField("Ask something quick...", text: $message)
                    .font(.system(size: 13))
                    .focused($isInputFocused)
                    .textFieldStyle(.plain)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(message.isEmpty ? Color.secondary.opacity(0.3) : DesignTokens.accent)
                        )
                }
                .buttonStyle(.plain)
                .disabled(message.isEmpty)
            }
            .padding(12)
            .padding(.horizontal, 4)
        }
        .frame(width: 360)
        .glassCard(padding: 0, cornerRadius: 20)
        .scaleEffect(isShowing ? 1 : 0.3, anchor: .bottomTrailing)
        .opacity(isShowing ? 1 : 0)
        .shadow(color: Color.black.opacity(0.15), radius: 40, x: 0, y: 16)
    }
    
    func sendMessage() {
        guard !message.isEmpty else { return }
        
        let userMsg = ChatMessage(content: message, isUser: true, timestamp: Date())
        messages.append(userMsg)
        
        let msgContent = message
        message = ""
        
        // Simulate response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let response = ChatMessage(
                content: "I'm processing your request about '\(msgContent)'...",
                isUser: false,
                timestamp: Date()
            )
            messages.append(response)
        }
    }
}

@available(macOS 12.3, *)
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 13))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.isUser ? DesignTokens.accent : Color.primary.opacity(0.05)
                    )
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(message.isUser ? 16 : 16, corners: message.isUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
                
                Text(message.timestamp, style: .time)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .opacity(0.7)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

@available(macOS 12.3, *)
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
