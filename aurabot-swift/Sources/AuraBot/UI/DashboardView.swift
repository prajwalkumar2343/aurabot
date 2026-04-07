import SwiftUI

@available(macOS 12.3, *)
struct DashboardView: View {
    @ObservedObject var service: AppService
    @State private var showingNewMemory = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dashboard")
                            .font(.largeTitle.bold())
                        Text("Overview of your memory system")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { showingNewMemory = true }) {
                        Label("New Memory", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                }
                
                // Stats Grid
                HStack(spacing: 16) {
                    StatCard(
                        title: "Total Memories",
                        value: "\(service.memories.count)",
                        icon: "star.fill",
                        color: .yellow
                    )
                    
                    StatCard(
                        title: "Capture Interval",
                        value: "30s",
                        icon: "clock",
                        color: .orange
                    )
                    
                    StatCard(
                        title: "Last Activity",
                        value: service.lastActivity,
                        icon: "waveform",
                        color: .red
                    )
                }
                
                // Recent Memories
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Recent Memories")
                            .font(.title2.bold())
                        
                        Spacer()
                        
                        Button("View All") {
                            // Navigate to memories
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                    
                    if service.memories.isEmpty {
                        EmptyMemoriesView {
                            service.toggleCapture()
                        }
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(service.memories.prefix(5)) { memory in
                                MemoryCard(memory: memory)
                            }
                        }
                    }
                }
            }
            .padding(32)
        }
        .sheet(isPresented: $showingNewMemory) {
            NewMemoryView { content in
                // Add memory
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title.bold())
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
}

struct EmptyMemoriesView: View {
    let onStartCapture: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("🧠")
                .font(.system(size: 48))
            
            Text("No memories yet")
                .font(.headline)
            
            Text("Start screen capture to begin recording your activities")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("Start Capture", action: onStartCapture)
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
        }
        .frame(maxWidth: .infinity)
        .padding(48)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(16)
    }
}

struct MemoryCard: View {
    let memory: Memory
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundColor(.purple)
                .frame(width: 48, height: 48)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(memory.content)
                    .lineLimit(2)
                
                HStack {
                    Text(memory.metadata.context)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    
                    Text(memory.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct NewMemoryView: View {
    let onSave: (String) -> Void
    @State private var content: String = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("New Memory")
                    .font(.headline)
                
                Spacer()
                
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
            }
            
            TextEditor(text: $content)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            HStack {
                Spacer()
                
                Button("Save") {
                    onSave(content)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(content.isEmpty)
            }
        }
        .padding()
        .frame(width: 500)
    }
}

extension Memory: Identifiable {}
