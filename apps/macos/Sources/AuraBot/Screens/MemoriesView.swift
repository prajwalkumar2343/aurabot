import SwiftUI

@available(macOS 14.0, *)
struct MemoriesView: View {
    @ObservedObject var service: AppService
    @State private var searchText: String = ""
    @State private var selectedFilter: String? = nil
    @State private var isGridView = false
    @State private var appearAnimation = false
    
    let filters = ["Work", "Code", "Meeting", "Browse", "Personal"]
    
    var filteredMemories: [Memory] {
        var result = service.memories
        
        if !searchText.isEmpty {
            result = result.filter {
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if let filter = selectedFilter {
            result = result.filter {
                $0.displayContext.localizedCaseInsensitiveContains(filter)
                    || $0.source.displayName.localizedCaseInsensitiveContains(filter)
            }
        }
        
        return result
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.xxxl) {
                // Header
                MemoriesHeaderSection(
                    searchText: $searchText,
                    selectedFilter: $selectedFilter,
                    filters: filters,
                    isGridView: $isGridView,
                    memoryCount: filteredMemories.count
                )
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : 20)
                
                // Memories content
                if filteredMemories.isEmpty {
                    EmptySearchState(
                        hasSearch: !searchText.isEmpty || selectedFilter != nil,
                        onClear: {
                            withAnimation {
                                searchText = ""
                                selectedFilter = nil
                            }
                        }
                    )
                    .opacity(appearAnimation ? 1 : 0)
                } else {
                    if isGridView {
                        MemoriesGrid(memories: filteredMemories)
                            .opacity(appearAnimation ? 1 : 0)
                    } else {
                        MemoriesList(memories: filteredMemories)
                            .opacity(appearAnimation ? 1 : 0)
                    }
                }
            }
            .padding(Spacing.xxxl)
        }
        .background(Color.clear)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appearAnimation = true
            }
        }
    }
}

@available(macOS 14.0, *)
struct MemoriesHeaderSection: View {
    @Binding var searchText: String
    @Binding var selectedFilter: String?
    let filters: [String]
    @Binding var isGridView: Bool
    let memoryCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Title row
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Memories")
                        .font(Typography.title1)
                        .foregroundColor(Colors.textPrimary)
                    
                    Text("\(memoryCount) memories captured")
                        .font(Typography.body)
                        .foregroundColor(Colors.textSecondary)
                }
                
                Spacer()
                
                // View toggle
                HStack(spacing: Spacing.xs) {
                    ViewToggleButton(
                        icon: "list.bullet",
                        isSelected: !isGridView
                    ) {
                        withAnimation(AnimationPresets.spring) {
                            isGridView = false
                        }
                    }
                    
                    ViewToggleButton(
                        icon: "square.grid.2x2",
                        isSelected: isGridView
                    ) {
                        withAnimation(AnimationPresets.spring) {
                            isGridView = true
                        }
                    }
                }
                .padding(Spacing.xs)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.md)
                            .fill(Colors.surfaceSecondary)
                        RoundedRectangle(cornerRadius: Radius.md)
                            .stroke(Colors.border, lineWidth: 1)
                    }
                )
            }
            
            // Search and filters
            FilterSearchBar(
                text: $searchText,
                selectedFilter: $selectedFilter,
                filters: filters,
                placeholder: "Search memories..."
            )
        }
    }
}

@available(macOS 14.0, *)
struct ViewToggleButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : Colors.textSecondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(isSelected ? Colors.primary : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .animation(AnimationPresets.hover, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

@available(macOS 14.0, *)
struct MemoriesList: View {
    let memories: [Memory]
    
    var body: some View {
        LazyVStack(spacing: Spacing.md) {
            ForEach(Array(memories.enumerated()), id: \.element.id) { index, memory in
                MemoryCell(memory: memory)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
    }
}

@available(macOS 14.0, *)
struct MemoriesGrid: View {
    let memories: [Memory]
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: Spacing.lg),
            GridItem(.flexible(), spacing: Spacing.lg)
        ], spacing: Spacing.lg) {
            ForEach(Array(memories.enumerated()), id: \.element.id) { index, memory in
                MemoryGridCell(memory: memory)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
    }
}

@available(macOS 14.0, *)
struct EmptySearchState: View {
    let hasSearch: Bool
    let onClear: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: Spacing.xl) {
            ZStack {
                Circle()
                    .fill(Colors.textMuted.opacity(0.08))
                    .frame(width: 100, height: 100)
                
                Image(systemName: hasSearch ? "magnifyingglass" : "brain.head.profile")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(Colors.textMuted)
            }
            
            VStack(spacing: Spacing.sm) {
                Text(hasSearch ? "No memories found" : "No memories yet")
                    .font(Typography.title3)
                    .foregroundColor(Colors.textPrimary)
                
                Text(hasSearch 
                    ? "Try adjusting your search or filters"
                    : "Your captured memories will appear here")
                    .font(Typography.body)
                    .foregroundColor(Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 300)
            
            if hasSearch {
                SecondaryButton("Clear Search", icon: "xmark") {
                    onClear()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xxxxl)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Radius.xxl)
                    .fill(Colors.surface)
                RoundedRectangle(cornerRadius: Radius.xxl)
                    .stroke(Colors.border, lineWidth: 1)
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
struct MemoriesView_Previews: PreviewProvider {
    static var previews: some View {
        MemoriesView(service: AppService())
    }
}
