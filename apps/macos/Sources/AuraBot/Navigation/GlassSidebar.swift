import SwiftUI

@available(macOS 14.0, *)
struct SidebarView: View {
    @Binding var selectedTab: SidebarTab
    @ObservedObject var service: AppService
    
    var body: some View {
        VStack(spacing: 0) {
            BrandHeader()
                .padding(.top, Spacing.xl)
                .padding(.horizontal, Spacing.lg)
            
            Divider()
                .padding(.vertical, Spacing.lg)
                .padding(.horizontal, Spacing.lg)
            
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
                    title: "Settings",
                    icon: "gear",
                    tab: .settings,
                    selectedTab: $selectedTab
                )
            }
            .padding(.horizontal, Spacing.sm)
            
            Spacer()

            UserProfileSection()
                .padding(Spacing.lg)
        }
        .frame(width: 260)
        .background(Colors.surface)
        .padding(.vertical, Spacing.lg)
        .padding(.leading, Spacing.lg)
    }
}

@available(macOS 14.0, *)
struct BrandHeader: View {
    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Colors.primary)
                .frame(width: 36, height: 36)
                .background(Colors.primaryMuted)
                .cornerRadius(Radius.md)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Aura")
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .foregroundColor(Colors.textPrimary)
                
                Text("AI Memory")
                    .font(Typography.caption)
                    .foregroundColor(Colors.textSecondary)
            }
            
            Spacer()
        }
    }
}

@available(macOS 14.0, *)
enum SidebarTab: Hashable {
    case dashboard, memories, settings
}

@available(macOS 14.0, *)
struct NavButton: View {
    let title: String
    let icon: String
    let tab: SidebarTab
    @Binding var selectedTab: SidebarTab
    
    @State private var isHovered = false
    
    var isSelected: Bool {
        selectedTab == tab
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.easeOut(duration: 0.2)) {
                selectedTab = tab
            }
        }) {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Colors.primary : Colors.textSecondary)
                    .frame(width: 28, height: 28)
                
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Colors.textPrimary : Colors.textSecondary)
                
                Spacer()
                
                if isSelected {
                    Circle()
                        .fill(Colors.primary)
                        .frame(width: 5, height: 5)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(isSelected ? Colors.primaryMuted : (isHovered ? Colors.surfaceTertiary : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(.easeOut(duration: 0.2), value: isSelected)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

@available(macOS 14.0, *)
struct UserProfileSection: View {
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            Text("JD")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Colors.primary)
                .frame(width: 32, height: 32)
                .background(Colors.primaryMuted)
                .cornerRadius(Radius.md)
            
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
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Colors.textTertiary)
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(isHovered ? Colors.surfaceTertiary : Color.clear)
        )
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

@available(macOS 14.0, *)
struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView(
            selectedTab: .constant(.dashboard),
            service: AppService()
        )
        .frame(height: 800)
        .background(Colors.background)
    }
}
