import SwiftUI

@available(macOS 14.0, *)
struct GlassSidebar: View {
    @Binding var selectedTab: SidebarTab
    @ObservedObject var service: AppService
    
    @State private var showStatusPanel = false
    
    var body: some View {
        GlassCard(
            padding: 0,
            cornerRadius: Radius.xxl,
            shadow: Shadows.lg,
            showBorder: true,
            blur: .thinMaterial
        ) {
            VStack(spacing: 0) {
                // App Brand
                BrandHeader()
                    .padding(.top, Spacing.xl)
                    .padding(.horizontal, Spacing.lg)
                
                Divider()
                    .background(Colors.glassBorder)
                    .padding(.vertical, Spacing.lg)
                    .padding(.horizontal, Spacing.lg)
                
                // Navigation
                VStack(spacing: Spacing.xs) {
                    NavButton(
                        title: "Dashboard",
                        icon: "square.grid.2x2",
                        tab: .dashboard,
                        selectedTab: $selectedTab
                    )
                    
                    NavButton(
                        title: "Memories",
                        icon: "bubble.left.and.bubble.right",
                        tab: .memories,
                        selectedTab: $selectedTab
                    )
                    
                    NavButton(
                        title: "Chat",
                        icon: "message.fill",
                        tab: .chat,
                        selectedTab: $selectedTab
                    )
                    
                    NavButton(
                        title: "Settings",
                        icon: "gear",
                        tab: .settings,
                        selectedTab: $selectedTab
                    )
                }
                .padding(.horizontal, Spacing.sm)
                
                Spacer()
                
                // Status Panel
                StatusPanel(service: service)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.lg)
                
                Divider()
                    .background(Colors.glassBorder)
                    .padding(.horizontal, Spacing.lg)
                
                // User Profile
                UserProfileSection()
                    .padding(Spacing.lg)
            }
        }
        .frame(width: 280)
        .padding(.vertical, Spacing.lg)
        .padding(.leading, Spacing.lg)
    }
}

@available(macOS 14.0, *)
struct BrandHeader: View {
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Logo
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Colors.primary, Colors.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .shadow(
                        color: Colors.primary.opacity(0.3),
                        radius: isHovered ? 16 : 8,
                        x: 0,
                        y: isHovered ? 8 : 4
                    )
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white)
            }
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .rotationEffect(.degrees(isHovered ? 10 : 0))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Aura")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Colors.textPrimary)
                
                Text("AI Memory")
                    .font(Typography.caption)
                    .foregroundColor(Colors.textSecondary)
            }
            
            Spacer()
        }
        .animation(AnimationPresets.hover, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

@available(macOS 14.0, *)
enum SidebarTab: Hashable {
    case dashboard, memories, chat, settings
}

@available(macOS 14.0, *)
struct NavButton: View {
    let title: String
    let icon: String
    let tab: SidebarTab
    @Binding var selectedTab: SidebarTab
    
    @State private var isHovered = false
    @State private var magneticOffset: CGSize = .zero
    
    var isSelected: Bool {
        selectedTab == tab
    }
    
    var body: some View {
        Button(action: { 
            withAnimation(AnimationPresets.spring) {
                selectedTab = tab
            }
        }) {
            HStack(spacing: Spacing.md) {
                // Icon with background
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: Radius.md)
                            .fill(Colors.primary.opacity(0.15))
                            .frame(width: 32, height: 32)
                            .matchedGeometryEffect(id: "iconBg_\(tab)", in: namespace)
                    }
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? Colors.primary : Colors.textSecondary)
                        .frame(width: 32, height: 32)
                }
                
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? Colors.textPrimary : Colors.textSecondary)
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Circle()
                        .fill(Colors.primary)
                        .frame(width: 6, height: 6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: Radius.lg)
                            .fill(Colors.primary.opacity(0.08))
                            .matchedGeometryEffect(id: "selection_\(tab)", in: namespace)
                    }
                    
                    if isHovered && !isSelected {
                        RoundedRectangle(cornerRadius: Radius.lg)
                            .fill(Colors.surfaceHover)
                    }
                }
            )
            .offset(magneticOffset)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(AnimationPresets.hover, value: isHovered)
        .animation(AnimationPresets.spring, value: isSelected)
        .onHover { hovering in
            isHovered = hovering
            if !hovering {
                magneticOffset = .zero
            }
        }
    }
    
    @Namespace private var namespace
}

@available(macOS 14.0, *)
struct StatusPanel: View {
    @ObservedObject var service: AppService
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Status")
                    .font(Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Colors.textMuted)
                
                Spacer()
                
                // Pulse indicator
                StatusPulse(isActive: service.captureEnabled)
            }
            
            // Capture toggle
            HStack {
                Toggle("Capture", isOn: .init(
                    get: { service.captureEnabled },
                    set: { _ in service.toggleCapture() }
                ))
                .toggleStyle(SwitchToggleStyle(tint: Colors.success))
                
                Spacer()
                
                Text("30s")
                    .font(Typography.caption)
                    .foregroundColor(Colors.textMuted)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 2)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .fill(Colors.surfaceHover)
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .stroke(Colors.glassBorder, lineWidth: 1)
                        }
                    )
            }
            
            // System status
            HStack(spacing: Spacing.lg) {
                StatusDot(color: Colors.success, label: "LLM")
                StatusDot(color: Colors.success, label: "Memory")
                StatusDot(
                    color: service.captureEnabled ? Colors.success : Colors.textMuted,
                    label: "Capture"
                )
            }
        }
        .padding(Spacing.md)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(Colors.white.opacity(0.3))
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(Colors.glassBorder, lineWidth: 1)
            }
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(
            color: isHovered ? Shadows.sm.color : Color.clear,
            radius: isHovered ? Shadows.sm.radius : 0
        )
        .animation(AnimationPresets.hover, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

@available(macOS 14.0, *)
struct StatusPulse: View {
    let isActive: Bool
    
    @State private var isPulsing = false
    
    var body: some View {
        Circle()
            .fill(isActive ? Colors.success : Colors.textMuted)
            .frame(width: 6, height: 6)
            .overlay(
                Circle()
                    .stroke(isActive ? Colors.success : Colors.textMuted, lineWidth: 2)
                    .scaleEffect(isPulsing ? 2 : 1)
                    .opacity(isPulsing ? 0 : 0.5)
            )
            .onAppear {
                if isActive {
                    withAnimation(.easeOut(duration: 1).repeatForever(autoreverses: false)) {
                        isPulsing = true
                    }
                }
            }
            .onChange(of: isActive) { active in
                if active {
                    withAnimation(.easeOut(duration: 1).repeatForever(autoreverses: false)) {
                        isPulsing = true
                    }
                } else {
                    isPulsing = false
                }
            }
    }
}

@available(macOS 14.0, *)
struct StatusDot: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            
            Text(label)
                .font(Typography.caption2)
                .foregroundColor(Colors.textSecondary)
        }
    }
}

@available(macOS 14.0, *)
struct UserProfileSection: View {
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Colors.primary.opacity(0.2), Colors.secondary.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Text("JD")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Colors.primary)
            }
            .overlay(
                Circle()
                    .stroke(Colors.primary.opacity(0.3), lineWidth: 2)
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("John Doe")
                    .font(Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(Colors.textPrimary)
                
                Text("Pro Plan")
                    .font(Typography.caption2)
                    .foregroundColor(Colors.primary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 12))
                .foregroundColor(Colors.textMuted)
                .rotationEffect(.degrees(isHovered ? 180 : 0))
        }
        .padding(Spacing.sm)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(isHovered ? Colors.surfaceHover : Color.clear)
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(isHovered ? Colors.glassBorder : Color.clear, lineWidth: 1)
            }
        )
        .animation(AnimationPresets.hover, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

@available(macOS 14.0, *)
struct GlassSidebar_Previews: PreviewProvider {
    static var previews: some View {
        GlassSidebar(
            selectedTab: .constant(.dashboard),
            service: AppService()
        )
        .frame(height: 800)
        .background(Colors.background)
    }
}
