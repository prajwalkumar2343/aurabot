import SwiftUI

@available(macOS 14.0, *)
struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: (() -> Void)?
    
    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    
    init(
        text: Binding<String>,
        placeholder: String = "Search...",
        onSubmit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isFocused ? Colors.primary : Colors.textMuted)
                .animation(AnimationPresets.easeFast, value: isFocused)
            
            // Text field
            TextField(placeholder, text: $text)
                .font(Typography.body)
                .foregroundColor(Colors.textPrimary)
                .focused($isFocused)
                .onSubmit {
                    onSubmit?()
                }
            
            // Clear button
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Colors.textMuted)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(Colors.white.opacity(isFocused ? 0.5 : 0.3))
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(
                        isFocused ? Colors.borderFocus : Colors.glassBorder,
                        lineWidth: isFocused ? 1.5 : 1
                    )
            }
        )
        .shadow(
            color: isFocused ? Colors.primaryGlow : Color.clear,
            radius: isFocused ? 16 : 0,
            x: 0,
            y: isFocused ? 6 : 0
        )
        .scaleEffect(isFocused ? 1.01 : 1.0)
        .animation(AnimationPresets.spring, value: isFocused)
        .animation(AnimationPresets.hover, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

@available(macOS 14.0, *)
struct ExpandableSearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    @FocusState private var isFocused: Bool
    @State private var isExpanded = false
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isFocused ? Colors.primary : Colors.textMuted)
            
            if isExpanded || !text.isEmpty {
                TextField(placeholder, text: $text)
                    .font(Typography.body)
                    .foregroundColor(Colors.textPrimary)
                    .focused($isFocused)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Colors.textMuted)
                }
                .buttonStyle(.plain)
                .transition(.scale)
            }
        }
        .padding(.horizontal, isExpanded ? Spacing.lg : Spacing.md)
        .padding(.vertical, Spacing.md)
        .frame(width: isExpanded ? 300 : 44)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(Colors.white.opacity(isFocused ? 0.5 : 0.3))
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(
                        isFocused ? Colors.borderFocus : Colors.glassBorder,
                        lineWidth: isFocused ? 1.5 : 1
                    )
            }
        )
        .shadow(
            color: isFocused ? Colors.primaryGlow : Color.clear,
            radius: isFocused ? 16 : 0
        )
        .onTapGesture {
            withAnimation(AnimationPresets.spring) {
                isExpanded = true
                isFocused = true
            }
        }
        .onChange(of: isFocused) { focused in
            if !focused && text.isEmpty {
                withAnimation(AnimationPresets.spring) {
                    isExpanded = false
                }
            }
        }
    }
}

@available(macOS 14.0, *)
struct FilterSearchBar: View {
    @Binding var text: String
    @Binding var selectedFilter: String?
    let filters: [String]
    let placeholder: String
    
    @FocusState private var isFocused: Bool
    @State private var showFilters = false
    
    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Search field
            HStack(spacing: Spacing.md) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isFocused ? Colors.primary : Colors.textMuted)
                
                TextField(placeholder, text: $text)
                    .font(Typography.body)
                    .foregroundColor(Colors.textPrimary)
                    .focused($isFocused)
                
                // Filter button
                Button(action: { 
                    withAnimation(AnimationPresets.spring) {
                        showFilters.toggle()
                    }
                }) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 14))
                        if selectedFilter != nil {
                            Circle()
                                .fill(Colors.primary)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .fill(showFilters ? Colors.primary.opacity(0.1) : Color.clear)
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .stroke(showFilters ? Colors.primary.opacity(0.2) : Color.clear, lineWidth: 1)
                        }
                    )
                    .foregroundColor(showFilters ? Colors.primary : Colors.textMuted)
                }
                .buttonStyle(.plain)
                
                // Clear button
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Colors.textMuted)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .fill(Colors.white.opacity(isFocused ? 0.5 : 0.3))
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .stroke(
                            isFocused ? Colors.borderFocus : Colors.glassBorder,
                            lineWidth: isFocused ? 1.5 : 1
                        )
                }
            )
            .shadow(
                color: isFocused ? Colors.primaryGlow : Color.clear,
                radius: isFocused ? 16 : 0
            )
            
            // Filter chips
            if showFilters {
                HStack(spacing: Spacing.sm) {
                    FilterChip(
                        title: "All",
                        isSelected: selectedFilter == nil,
                        action: { selectedFilter = nil }
                    )
                    
                    ForEach(filters, id: \.self) { filter in
                        FilterChip(
                            title: filter,
                            isSelected: selectedFilter == filter,
                            action: { selectedFilter = filter }
                        )
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

@available(macOS 14.0, *)
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.caption)
                .fontWeight(isSelected ? .semibold : .medium)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(
                    ZStack {
                        Capsule()
                            .fill(isSelected ? Colors.primary : (isHovered ? Colors.surfaceHover : Colors.surface))
                        Capsule()
                            .stroke(isSelected ? Color.clear : Colors.glassBorder, lineWidth: 1)
                    }
                )
                .foregroundColor(isSelected ? .white : Colors.textSecondary)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(AnimationPresets.hover, value: isHovered)
        .animation(AnimationPresets.spring, value: isSelected)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

@available(macOS 14.0, *)
struct SearchBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Spacing.xl) {
            SearchBar(text: .constant(""), placeholder: "Search memories...")
            
            SearchBar(text: .constant("Dashboard design"), placeholder: "Search memories...")
            
            ExpandableSearchBar(text: .constant(""), placeholder: "Search...")
            
            FilterSearchBar(
                text: .constant(""),
                selectedFilter: .constant("Work"),
                filters: ["Work", "Code", "Meeting", "Browse"],
                placeholder: "Search memories..."
            )
        }
        .padding()
        .background(Colors.background)
    }
}
