import SwiftUI

@available(macOS 14.0, *)
struct MemoryCell: View {
    let memory: Memory
    let onTap: (() -> Void)?
    
    @State private var isHovered = false
    
    init(memory: Memory, onTap: (() -> Void)? = nil) {
        self.memory = memory
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: Spacing.lg) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: categoryIcon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(categoryColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(memory.content)
                        .font(Typography.body)
                        .foregroundColor(Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: Spacing.sm) {
                        // Context tag
                        Text(memory.metadata.context)
                            .font(Typography.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(categoryColor.opacity(0.1))
                            .foregroundColor(categoryColor)
                            .cornerRadius(Radius.sm)
                        
                        // Timestamp
                        Text(timeAgo)
                            .font(Typography.caption)
                            .foregroundColor(Colors.textMuted)
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Colors.textMuted)
                    .opacity(isHovered ? 1 : 0.5)
                    .offset(x: isHovered ? 4 : 0)
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Radius.xl)
                    .fill(isHovered ? Colors.surfaceHover : Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.xl)
                            .stroke(isHovered ? Colors.borderFocus : Colors.border, lineWidth: isHovered ? 2 : 1)
                    )
            )
            .shadow(
                color: isHovered ? Colors.primary.opacity(0.1) : Color.clear,
                radius: isHovered ? 16 : 0,
                x: 0,
                y: isHovered ? 8 : 0
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .offset(y: isHovered ? -2 : 0)
        .animation(AnimationPresets.hover, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var categoryColor: Color {
        switch memory.metadata.context.lowercased() {
        case let s where s.contains("work"): return Colors.primary
        case let s where s.contains("code"): return Colors.secondary
        case let s where s.contains("meeting"): return Colors.accent
        case let s where s.contains("browse"): return Colors.success
        default: return Colors.textSecondary
        }
    }
    
    private var categoryIcon: String {
        switch memory.metadata.context.lowercased() {
        case let s where s.contains("work"): return "briefcase.fill"
        case let s where s.contains("code"): return "code"
        case let s where s.contains("meeting"): return "video.fill"
        case let s where s.contains("browse"): return "safari.fill"
        default: return "brain.head.profile"
        }
    }
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: memory.createdAt, relativeTo: Date())
    }
}

@available(macOS 14.0, *)
struct CompactMemoryCell: View {
    let memory: Memory
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(categoryColor.opacity(0.2))
                .frame(width: 8, height: 8)
            
            Text(memory.content)
                .font(Typography.callout)
                .foregroundColor(Colors.textPrimary)
                .lineLimit(1)
            
            Spacer()
            
            Text(timeAgo)
                .font(Typography.caption2)
                .foregroundColor(Colors.textMuted)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(isHovered ? Colors.surfaceHover : Color.clear)
        )
        .animation(AnimationPresets.hover, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var categoryColor: Color {
        switch memory.metadata.context.lowercased() {
        case let s where s.contains("work"): return Colors.primary
        case let s where s.contains("code"): return Colors.secondary
        case let s where s.contains("meeting"): return Colors.accent
        default: return Colors.textSecondary
        }
    }
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: memory.createdAt, relativeTo: Date())
    }
}

@available(macOS 14.0, *)
struct MemoryGridCell: View {
    let memory: Memory
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: categoryIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(categoryColor)
                }
                
                Spacer()
                
                Text(timeAgo)
                    .font(Typography.caption2)
                    .foregroundColor(Colors.textMuted)
            }
            
            // Content
            Text(memory.content)
                .font(Typography.callout)
                .foregroundColor(Colors.textPrimary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            // Tag
            Text(memory.metadata.context)
                .font(Typography.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 2)
                .background(categoryColor.opacity(0.1))
                .foregroundColor(categoryColor)
                .cornerRadius(Radius.sm)
        }
        .padding(Spacing.lg)
        .frame(height: 160)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl)
                .fill(isHovered ? Colors.surfaceHover : Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl)
                        .stroke(isHovered ? Colors.borderFocus : Colors.border, lineWidth: isHovered ? 2 : 1)
                )
        )
        .shadow(
            color: isHovered ? Colors.primary.opacity(0.1) : Color.clear,
            radius: isHovered ? 16 : 0,
            x: 0,
            y: isHovered ? 8 : 0
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .offset(y: isHovered ? -4 : 0)
        .animation(AnimationPresets.hover, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var categoryColor: Color {
        switch memory.metadata.context.lowercased() {
        case let s where s.contains("work"): return Colors.primary
        case let s where s.contains("code"): return Colors.secondary
        case let s where s.contains("meeting"): return Colors.accent
        default: return Colors.textSecondary
        }
    }
    
    private var categoryIcon: String {
        switch memory.metadata.context.lowercased() {
        case let s where s.contains("work"): return "briefcase.fill"
        case let s where s.contains("code"): return "code"
        case let s where s.contains("meeting"): return "video.fill"
        default: return "brain.head.profile"
        }
    }
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: memory.createdAt, relativeTo: Date())
    }
}

@available(macOS 14.0, *)
struct MemoryCell_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Spacing.lg) {
            MemoryCell(memory: Memory(
                id: "1",
                content: "Working on the new dashboard design with glassmorphism effects and modern animations",
                userID: "user1",
                metadata: Metadata(
                    timestamp: "2024-01-01T10:00:00Z",
                    context: "Work",
                    activities: ["designing", "coding"],
                    keyElements: ["dashboard", "glassmorphism"],
                    userIntent: "create modern UI",
                    displayNum: 1,
                    browser: nil,
                    url: nil,
                    captureReason: nil
                ),
                createdAt: Date().addingTimeInterval(-3600)
            ))
            
            CompactMemoryCell(memory: Memory(
                id: "2",
                content: "Reviewing pull request #42",
                userID: "user1",
                metadata: Metadata(
                    timestamp: "2024-01-01T09:00:00Z",
                    context: "Code",
                    activities: ["reviewing"],
                    keyElements: ["PR", "code review"],
                    userIntent: "ensure code quality",
                    displayNum: 2,
                    browser: nil,
                    url: nil,
                    captureReason: nil
                ),
                createdAt: Date().addingTimeInterval(-7200)
            ))
            
            MemoryGridCell(memory: Memory(
                id: "3",
                content: "Team standup meeting about Q4 roadmap",
                userID: "user1",
                metadata: Metadata(
                    timestamp: "2024-01-01T08:00:00Z",
                    context: "Meeting",
                    activities: ["planning"],
                    keyElements: ["standup", "roadmap"],
                    userIntent: "align team",
                    displayNum: 3,
                    browser: nil,
                    url: nil,
                    captureReason: nil
                ),
                createdAt: Date().addingTimeInterval(-14400)
            ))
        }
        .padding()
        .background(Colors.background)
    }
}
