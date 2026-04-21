import SwiftUI

@available(macOS 14.0, *)
struct DashboardView: View {
    @ObservedObject var service: AppService
    @State private var showingNewMemory = false
    @State private var isRefreshing = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                DashboardHeader(
                    service: service,
                    showingNewMemory: $showingNewMemory,
                    isRefreshing: $isRefreshing
                )
                
                StatsGrid(service: service)
                
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
    @Binding var isRefreshing: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Aura")
                    .font(Typography.title1)
                    .foregroundColor(Colors.textPrimary)
                
                HStack(spacing: Spacing.sm) {
                    StatusBadge(
                        title: service.captureEnabled ? "Capturing" : "Paused",
                        icon: service.captureEnabled ? "record.circle" : "pause.circle",
                        color: service.captureEnabled ? Colors.success : Colors.textTertiary
                    )

                    StatusBadge(
                        title: service.isBackendConnected ? "Backend online" : "Backend offline",
                        icon: service.isBackendConnected ? "checkmark.seal" : "exclamationmark.triangle",
                        color: service.isBackendConnected ? Colors.primary : Colors.warning
                    )
                }
            }
            
            Spacer()

            Toggle("Capture", isOn: .init(
                get: { service.captureEnabled },
                set: { _ in service.toggleCapture() }
            ))
            .toggleStyle(SwitchToggleStyle(tint: Colors.success))
            
            Button {
                refresh()
            } label: {
                Label(isRefreshing ? "Refreshing" : "Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(isRefreshing)

            Button {
                showingNewMemory = true
            } label: {
                Label("New Memory", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(minHeight: 56)
    }

    private func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            await service.refreshMemories()
            await MainActor.run {
                isRefreshing = false
            }
        }
    }
}

@available(macOS 14.0, *)
struct StatsGrid: View {
    @ObservedObject var service: AppService

    private var capturesToday: Int {
        service.memories.filter { Calendar.current.isDateInToday($0.createdAt) }.count
    }
    
    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 210), spacing: Spacing.lg)],
            alignment: .leading,
            spacing: Spacing.lg
        ) {
            DashboardStatCard(
                title: "Memories",
                value: "\(service.memories.count)",
                detail: "\(capturesToday) today",
                icon: "brain.head.profile",
                color: Colors.primary
            )

            DashboardStatCard(
                title: "Capture",
                value: "\(service.captureInterval)s",
                detail: service.captureEnabled ? "Active interval" : "Paused",
                icon: "timer",
                color: Colors.secondary
            )

            DashboardStatCard(
                title: "LLM",
                value: service.isLLMConnected ? "Online" : "Offline",
                detail: service.config.llm.model.isEmpty ? "No model set" : service.config.llm.model,
                icon: "sparkles",
                color: service.isLLMConnected ? Colors.success : Colors.warning
            )

            DashboardStatCard(
                title: "Memory API",
                value: service.isMemoryConnected ? "Online" : "Offline",
                detail: service.config.memory.collectionName,
                icon: "server.rack",
                color: service.isMemoryConnected ? Colors.primary : Colors.accent
            )
        }
    }
}

@available(macOS 14.0, *)
struct RecentMemoriesSection: View {
    @ObservedObject var service: AppService
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Recent Memories")
                    .font(Typography.title2)
                    .foregroundColor(Colors.textPrimary)
                
                Spacer()

                Text("\(min(service.memories.count, 5)) shown")
                    .font(Typography.caption)
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
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Colors.textTertiary)
            
            Text("No memories yet")
                .font(Typography.title3)
                .foregroundColor(Colors.textPrimary)

            Button {
                onStartCapture()
            } label: {
                Label("Start Capture", systemImage: "record.circle")
            }
                .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xxxxl)
        .background(Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl)
                .stroke(Colors.border, lineWidth: 1)
        )
        .cornerRadius(Radius.xl)
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
                .background(Colors.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(Colors.border, lineWidth: 1)
                )
                .cornerRadius(Radius.md)
            
            HStack {
                Spacer()
                
                Button("Save") {
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(content.isEmpty)
                .opacity(content.isEmpty ? 0.5 : 1.0)
            }
        }
        .padding()
        .frame(width: 500)
    }
}

@available(macOS 14.0, *)
struct StatusBadge: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))

            Text(title)
                .font(Typography.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(color.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.sm)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
        .cornerRadius(Radius.sm)
    }
}

@available(macOS 14.0, *)
struct DashboardStatCard: View {
    let title: String
    let value: String
    let detail: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.12))
                    .cornerRadius(Radius.md)

                Spacer()
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(value)
                    .font(.system(size: 28, weight: .semibold, design: .default))
                    .foregroundColor(Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(title)
                    .font(Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Colors.textSecondary)

                Text(detail)
                    .font(Typography.caption)
                    .foregroundColor(Colors.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .padding(Spacing.lg)
        .background(Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(Colors.border, lineWidth: 1)
        )
        .cornerRadius(Radius.lg)
        .shadow(color: Shadows.sm.color, radius: Shadows.sm.radius, x: Shadows.sm.x, y: Shadows.sm.y)
    }
}
