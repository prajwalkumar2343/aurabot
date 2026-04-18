import SwiftUI

@available(macOS 14.0, *)
struct DashboardView: View {
    @ObservedObject var service: AppService
    @State private var showingNewMemory = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.xxxl) {
                // Header
                DashboardHeader(service: service, showingNewMemory: $showingNewMemory)
                
                // Stats Grid
                StatsGrid(service: service)
                
                // Recent Memories
                RecentMemoriesSection(service: service)
            }
            .padding(Spacing.xxxl)
        }
        .background(Color.clear)
        .sheet(isPresented: $showingNewMemory) {
            NewMemorySheet(service: service)
        }
    }
}

@available(macOS 14.0, *)
struct DashboardHeader: View {
    @ObservedObject var service: AppService
    @Binding var showingNewMemory: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Dashboard")
                    .font(Typography.title1)
                    .foregroundColor(Colors.textPrimary)
                
                Text("Overview of your memory system")
                    .font(Typography.body)
                    .foregroundColor(Colors.textSecondary)
            }
            
            Spacer()
            
            Button(action: { showingNewMemory = true }) {
                Label("New Memory", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }
}

@available(macOS 14.0, *)
struct StatsGrid: View {
    @ObservedObject var service: AppService
    
    var body: some View {
        HStack(spacing: Spacing.lg) {
            StatWidget(
                title: "Total Memories",
                value: "\(service.memories.count)",
                icon: "brain.head.profile",
                color: Colors.primary
            )
            
            StatWidget(
                title: "Capture Interval",
                value: "\(service.captureInterval)s",
                icon: "clock",
                color: Colors.secondary
            )
            
            StatWidget(
                title: "Last Activity",
                value: service.lastActivity.isEmpty ? "--" : "Just now",
                icon: "waveform",
                color: Colors.accent
            )
        }
    }
}

@available(macOS 14.0, *)
struct RecentMemoriesSection: View {
    @ObservedObject var service: AppService
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Text("Recent Memories")
                    .font(Typography.title2)
                    .foregroundColor(Colors.textPrimary)
                
                Spacer()
                
                Button("View All") {}
                    .font(Typography.callout)
                    .foregroundColor(Colors.primary)
            }
            
            if service.memories.isEmpty {
                EmptyMemoriesPlaceholder {
                    service.toggleCapture()
                }
            } else {
                LazyVStack(spacing: Spacing.md) {
                    ForEach(service.memories.prefix(5)) { memory in
                        CompactMemoryCell(memory: memory)
                    }
                }
            }
        }
    }
}

@available(macOS 14.0, *)
struct EmptyMemoriesPlaceholder: View {
    let onStartCapture: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(Colors.textMuted)
            
            Text("No memories yet")
                .font(Typography.title3)
                .foregroundColor(Colors.textPrimary)
            
            Text("Start screen capture to begin recording your activities")
                .font(Typography.body)
                .foregroundColor(Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Start Capture", action: onStartCapture)
                .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xxxxl)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Radius.xxl)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: Radius.xxl)
                    .fill(Colors.white.opacity(0.3))
                RoundedRectangle(cornerRadius: Radius.xxl)
                    .stroke(Colors.glassBorder, lineWidth: 1)
            }
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(AnimationPresets.hover, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

@available(macOS 14.0, *)
struct NewMemorySheet: View {
    @ObservedObject var service: AppService
    @State private var content: String = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: Spacing.xl) {
            HStack {
                Text("New Memory")
                    .font(Typography.title2)
                
                Spacer()
                
                Button("Cancel") { dismiss() }
                    .buttonStyle(PlainButtonStyle())
            }
            
            TextEditor(text: $content)
                .frame(minHeight: 120)
                .padding(Spacing.sm)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.md)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: Radius.md)
                            .fill(Colors.white.opacity(0.3))
                        RoundedRectangle(cornerRadius: Radius.md)
                            .stroke(Colors.glassBorder, lineWidth: 1)
                    }
                )
            
            HStack {
                Spacer()
                
                Button("Save") {
                    // Save memory logic
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(content.isEmpty)
            }
        }
        .padding()
        .frame(width: 500)
    }
}
