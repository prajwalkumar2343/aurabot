import SwiftUI

@available(macOS 14.0, *)
struct DashboardView: View {
    @ObservedObject var service: AppService
    @State private var showingNewMemory = false
    @State private var appearAnimation = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.xxxl) {
                // Header with greeting
                DashboardHeaderSection(service: service)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
                
                // Stats row
                StatsSection(service: service)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
                
                // Recent memories
                RecentMemoriesSection(service: service, showingNewMemory: $showingNewMemory)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
            }
            .padding(Spacing.xxxl)
        }
        .sheet(isPresented: $showingNewMemory) {
            NewMemorySheet { content in
                // Add memory
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appearAnimation = true
            }
        }
    }
}

@available(macOS 14.0, *)
struct DashboardHeaderSection: View {
    @ObservedObject var service: AppService
    @State private var greeting = ""
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(greeting)
                    .font(Typography.title1)
                    .foregroundColor(Colors.textPrimary)
                    .task {
                        greeting = getGreeting()
                    }
                
                Text("Here's what's happening with your memory")
                    .font(Typography.body)
                    .foregroundColor(Colors.textSecondary)
            }
            
            Spacer()
            
            // Date
            VStack(alignment: .trailing, spacing: Spacing.xs) {
                Text(Date(), style: .date)
                    .font(Typography.headline)
                    .foregroundColor(Colors.textPrimary)
                
                Text(Date(), style: .time)
                    .font(Typography.subheadline)
                    .foregroundColor(Colors.textSecondary)
            }
        }
    }
    
    private func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning, John"
        case 12..<17: return "Good afternoon, John"
        default: return "Good evening, John"
        }
    }
}

@available(macOS 14.0, *)
struct StatsSection: View {
    @ObservedObject var service: AppService
    
    var body: some View {
        HStack(spacing: Spacing.lg) {
            AnimatedStatWidget(
                title: "Total Memories",
                value: service.memories.count,
                icon: "brain.head.profile",
                color: Colors.primary
            )
            
            StatWidget(
                title: "Capture Interval",
                value: "30s",
                icon: "timer",
                color: Colors.secondary,
                trend: "Optimal"
            )
            
            StatWidget(
                title: "Last Activity",
                value: service.lastActivity.isEmpty ? "Just now" : service.lastActivity,
                icon: "waveform",
                color: Colors.success
            )
            
            StatWidget(
                title: "Storage Used",
                value: "24%",
                icon: "externaldrive",
                color: Colors.accent
            )
        }
    }
}

@available(macOS 14.0, *)
struct RecentMemoriesSection: View {
    @ObservedObject var service: AppService
    @Binding var showingNewMemory: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Recent Memories")
                        .font(Typography.title2)
                        .foregroundColor(Colors.textPrimary)
                    
                    Text("Your latest captured moments")
                        .font(Typography.subheadline)
                        .foregroundColor(Colors.textSecondary)
                }
                
                Spacer()
                
                NavigationLink(value: "memories") {
                    Text("View All")
                        .font(Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Colors.primary)
                }
                .buttonStyle(.plain)
            }
            
            // Memories list or empty state
            if service.memories.isEmpty {
                EmptyMemoriesState(onStart: {
                    service.toggleCapture()
                })
            } else {
                VStack(spacing: Spacing.md) {
                    ForEach(Array(service.memories.prefix(5).enumerated()), id: \.element.id) { index, memory in
                        MemoryCell(memory: memory)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
            }
        }
    }
}

@available(macOS 14.0, *)
struct EmptyMemoriesState: View {
    let onStart: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: Spacing.xl) {
            // Animated illustration
            ZStack {
                Circle()
                    .fill(Colors.primary.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Circle()
                    .fill(Colors.primary.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(Colors.primary)
                    .scaleEffect(isHovered ? 1.1 : 1.0)
            }
            
            VStack(spacing: Spacing.sm) {
                Text("No memories yet")
                    .font(Typography.title3)
                    .foregroundColor(Colors.textPrimary)
                
                Text("Start screen capture to begin recording your activities and building your AI memory")
                    .font(Typography.body)
                    .foregroundColor(Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 400)
            
            GradientButton("Start Capture", icon: "play.fill") {
                onStart()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xxxxl)
        .background(
            RoundedRectangle(cornerRadius: Radius.xxl)
                .fill(Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xxl)
                        .stroke(Colors.border, lineWidth: 1)
                )
                .overlay(
                    // Subtle gradient mesh
                    MeshGradient()
                        .opacity(0.3)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.xxl))
                )
        )
        .animation(AnimationPresets.hover, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

@available(macOS 14.0, *)
struct NewMemorySheet: View {
    let onSave: (String) -> Void
    @State private var content: String = ""
    @Environment(\.dismiss) var dismiss
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: Spacing.xl) {
            // Header
            HStack {
                Text("New Memory")
                    .font(Typography.title2)
                    .foregroundColor(Colors.textPrimary)
                
                Spacer()
                
                IconButton("xmark", size: 32, background: Colors.surface) {
                    dismiss()
                }
            }
            
            // Text editor
            TextEditor(text: $content)
                .font(Typography.body)
                .foregroundColor(Colors.textPrimary)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .fill(Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.lg)
                                .stroke(isFocused ? Colors.borderFocus : Colors.border, lineWidth: isFocused ? 2 : 1)
                        )
                )
                .focused($isFocused)
                .frame(minHeight: 150)
            
            // Footer
            HStack {
                Text("\(content.count) characters")
                    .font(Typography.caption)
                    .foregroundColor(Colors.textMuted)
                
                Spacer()
                
                SecondaryButton("Cancel") {
                    dismiss()
                }
                
                GradientButton("Save Memory", icon: "checkmark") {
                    onSave(content)
                    dismiss()
                }
                .disabled(content.isEmpty)
            }
        }
        .padding(Spacing.xl)
        .frame(width: 500)
        .background(Colors.background)
        .onAppear {
            isFocused = true
        }
    }
}

@available(macOS 14.0, *)
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView(service: AppService())
            .background(Colors.background)
    }
}
