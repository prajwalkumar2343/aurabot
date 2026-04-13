import SwiftUI

@available(macOS 12.3, *)
struct DashboardView: View {
    @ObservedObject var service: AppService
    @State private var showingNewMemory = false
    @State private var greeting = ""
    @State private var currentTime = ""
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 32) {
                // Welcome Section
                VStack(spacing: 8) {
                    GradientText(text: greeting, font: .system(size: 32, weight: .bold))
                    
                    Text("What would you like to recall today?")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    Text(currentTime)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.7))
                        .onReceive(timer) { _ in
                            updateTime()
                        }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
                .padding(.bottom, 8)
                .onAppear {
                    updateGreeting()
                    updateTime()
                }
                
                // Quick Actions
                HStack(spacing: 12) {
                    QuickActionButton(
                        title: "New Memory",
                        icon: "plus",
                        action: { showingNewMemory = true }
                    )
                    
                    QuickActionButton(
                        title: "Ask Aura",
                        icon: "bubble.left.and.bubble.right",
                        action: { }
                    )
                    
                    QuickActionButton(
                        title: "Quick Enhance",
                        icon: "bolt.fill",
                        isAccent: true,
                        action: { }
                    )
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                // Stats Grid
                HStack(spacing: 16) {
                    StatCardGlass(
                        title: "Total Memories",
                        value: "\(service.memories.count)",
                        icon: "star.fill",
                        gradient: [DesignTokens.accent, DesignTokens.accentCyan]
                    )
                    
                    StatCardGlass(
                        title: "Capture Interval",
                        value: "\(service.captureInterval)s",
                        icon: "clock",
                        gradient: [DesignTokens.accentViolet, Color(red: 0.9, green: 0.5, blue: 0.9)]
                    )
                    
                    StatCardGlass(
                        title: "Last Activity",
                        value: service.lastActivity.isEmpty ? "--" : service.lastActivity,
                        icon: "waveform",
                        gradient: [DesignTokens.success, Color(red: 0.3, green: 0.9, blue: 0.5)]
                    )
                }
                
                // Recent Memories Section
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(
                        title: "Recent Memories",
                        action: { },
                        actionTitle: "View All"
                    )
                    
                    if service.memories.isEmpty {
                        EmptyMemoriesGlassView {
                            service.toggleCapture()
                        }
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(service.memories.prefix(5)) { memory in
                                MemoryCardGlass(memory: memory)
                                    .transition(.move(edge: .leading).combined(with: .opacity))
                            }
                        }
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $showingNewMemory) {
            NewMemoryGlassView { content in
                // Add memory
            }
        }
    }
    
    func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: greeting = "Good Morning"
        case 12..<17: greeting = "Good Afternoon"
        case 17..<22: greeting = "Good Evening"
        default: greeting = "Good Night"
        }
    }
    
    func updateTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d • h:mm a"
        currentTime = formatter.string(from: Date())
    }
}

@available(macOS 12.3, *)
struct QuickActionButton: View {
    let title: String
    let icon: String
    var isAccent: Bool = false
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(isAccent ? DesignTokens.accent : Color.clear)
                    .background(
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .stroke(isAccent ? DesignTokens.accent : Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )
            .foregroundColor(isAccent ? .white : .primary)
            .shadow(
                color: isAccent ? DesignTokens.accent.opacity(0.3) : Color.black.opacity(0.04),
                radius: isHovered ? 12 : 8,
                x: 0,
                y: isHovered ? 6 : 4
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

@available(macOS 12.3, *)
struct StatCardGlass: View {
    let title: String
    let value: String
    let icon: String
    let gradient: [Color]
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: gradient.map { $0.opacity(0.15) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 20, cornerRadius: 20)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(
            color: isHovered ? gradient[0].opacity(0.15) : Color.clear,
            radius: 16,
            x: 0,
            y: 8
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

@available(macOS 12.3, *)
struct MemoryCardGlass: View {
    let memory: Memory
    @State private var isHovered = false
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DesignTokens.accentLight)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 20))
                        .foregroundColor(DesignTokens.accent)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(memory.content)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(isExpanded ? nil : 2)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Text(memory.metadata.context)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(DesignTokens.accentLight)
                            .foregroundColor(DesignTokens.accent)
                            .cornerRadius(4)
                        
                        Text(memory.createdAt, style: .relative)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.primary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    // AI Summary
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.accent)
                        
                        Text("AI Summary")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(DesignTokens.accent)
                            .tracking(0.5)
                    }
                    
                    Text("This memory captures a moment of activity related to \(memory.metadata.context). The system detected this as a meaningful context worth remembering.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                    
                    HStack(spacing: 12) {
                        Button(action: {}) {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        
                        Button(action: {}) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {}) {
                            Label("Delete", systemImage: "trash")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(DesignTokens.error)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .glassCard(padding: 16, cornerRadius: 16)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .shadow(
            color: isHovered ? Color.black.opacity(0.08) : Color.clear,
            radius: 16,
            x: 0,
            y: 8
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

@available(macOS 12.3, *)
struct EmptyMemoriesGlassView: View {
    let onStartCapture: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(DesignTokens.accentGradientSubtle)
                    .frame(width: 80, height: 80)
                
                Text("🧠")
                    .font(.system(size: 40))
            }
            
            VStack(spacing: 8) {
                Text("No memories yet")
                    .font(.system(size: 18, weight: .semibold))
                
                Text("Start screen capture to begin recording your activities")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: onStartCapture) {
                HStack(spacing: 8) {
                    Image(systemName: "record.circle")
                        .font(.system(size: 14))
                    Text("Start Capture")
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(DesignTokens.accentGradient)
                )
                .foregroundColor(.white)
                .shadow(
                    color: DesignTokens.accent.opacity(0.3),
                    radius: isHovered ? 16 : 12,
                    x: 0,
                    y: isHovered ? 6 : 4
                )
            }
            .buttonStyle(.plain)
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { isHovered = $0 }
        }
        .frame(maxWidth: .infinity)
        .padding(48)
        .glassCard(padding: 48, cornerRadius: 24)
    }
}

@available(macOS 12.3, *)
struct NewMemoryGlassView: View {
    let onSave: (String) -> Void
    @State private var content: String = ""
    @State private var title: String = ""
    @Environment(\.dismiss) var dismiss
    @FocusState private var isContentFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Memory")
                    .font(.system(size: 17, weight: .semibold))
                
                Spacer()
                
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Content
            VStack(spacing: 16) {
                // Title input
                TextField("Title (optional)", text: $title)
                    .font(.system(size: 15, weight: .medium))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                    )
                
                // Content input
                ZStack(alignment: .topLeading) {
                    if content.isEmpty {
                        Text("What's on your mind?")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.7))
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                    
                    TextEditor(text: $content)
                        .font(.system(size: 14))
                        .lineSpacing(4)
                        .frame(minHeight: 120)
                        .padding(12)
                        .focused($isContentFocused)
                        .scrollContentBackground(.hidden)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isContentFocused ? DesignTokens.accent.opacity(0.5) : Color.primary.opacity(0.08), lineWidth: isContentFocused ? 2 : 1)
                        )
                )
                .animation(.easeOut(duration: 0.2), value: isContentFocused)
            }
            .padding(20)
            
            Spacer()
            
            Divider()
            
            // Footer
            HStack {
                Text("⌘↵ to save")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        onSave(content)
                        dismiss()
                    }) {
                        Text("Save Memory")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 999, style: .continuous)
                                    .fill(content.isEmpty ? Color.secondary.opacity(0.2) : DesignTokens.accent)
                            )
                            .foregroundColor(content.isEmpty ? .secondary : .white)
                    }
                    .buttonStyle(.plain)
                    .disabled(content.isEmpty)
                }
            }
            .padding(20)
        }
        .frame(width: 500, height: 400)
        .glassCard(padding: 0, cornerRadius: 20)
        .padding(40)
    }
}

extension Memory: Identifiable {}
