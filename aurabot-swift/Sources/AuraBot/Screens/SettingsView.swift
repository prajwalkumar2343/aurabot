import SwiftUI

@available(macOS 14.0, *)
struct SettingsView: View {
    @State private var captureEnabled = true
    @State private var captureInterval: Double = 30
    @State private var captureQuality: Double = 60
    @State private var llmURL = "http://localhost:1234/v1"
    @State private var mem0URL = "http://localhost:8000"
    @State private var showSavedToast = false
    @State private var appearAnimation = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.xxxl) {
                // Header
                SettingsHeader()
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
                
                // Capture Settings
                CaptureSettingsSection(
                    captureEnabled: $captureEnabled,
                    captureInterval: $captureInterval,
                    captureQuality: $captureQuality
                )
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : 20)
                
                // AI Settings
                AISettingsSection(
                    llmURL: $llmURL,
                    mem0URL: $mem0URL
                )
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : 20)
                
                // Permissions
                PermissionsSection()
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
                
                // Save button
                SaveSection(showSavedToast: $showSavedToast)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
            }
            .padding(Spacing.xxxl)
        }
        .background(Colors.background)
        .overlay(
            Group {
                if showSavedToast {
                    SavedToast()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        )
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appearAnimation = true
            }
        }
    }
}

@available(macOS 14.0, *)
struct SettingsHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Settings")
                .font(Typography.title1)
                .foregroundColor(Colors.textPrimary)
            
            Text("Customize your Aura experience")
                .font(Typography.body)
                .foregroundColor(Colors.textSecondary)
        }
    }
}

@available(macOS 14.0, *)
struct CaptureSettingsSection: View {
    @Binding var captureEnabled: Bool
    @Binding var captureInterval: Double
    @Binding var captureQuality: Double
    
    var body: some View {
        SettingsSection(title: "Capture", icon: "camera.fill") {
            VStack(spacing: Spacing.xl) {
                // Enable toggle
                CustomToggle(
                    title: "Screen Capture",
                    description: "Automatically capture and analyze your screen",
                    isOn: $captureEnabled
                )
                
                Divider()
                
                // Interval slider
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack {
                        Text("Capture Interval")
                            .font(Typography.subheadline)
                            .foregroundColor(Colors.textPrimary)
                        
                        Spacer()
                        
                        Text("\(Int(captureInterval))s")
                            .font(Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Colors.primary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(Colors.primary.opacity(0.1))
                            .cornerRadius(Radius.sm)
                    }
                    
                    CustomSlider(
                        value: $captureInterval,
                        range: 10...300,
                        step: 5
                    )
                    
                    HStack {
                        Text("10s")
                        Spacer()
                        Text("5min")
                    }
                    .font(Typography.caption2)
                    .foregroundColor(Colors.textMuted)
                }
                
                Divider()
                
                // Quality slider
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack {
                        Text("JPEG Quality")
                            .font(Typography.subheadline)
                            .foregroundColor(Colors.textPrimary)
                        
                        Spacer()
                        
                        Text("\(Int(captureQuality))%")
                            .font(Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Colors.primary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(Colors.primary.opacity(0.1))
                            .cornerRadius(Radius.sm)
                    }
                    
                    CustomSlider(
                        value: $captureQuality,
                        range: 30...100,
                        step: 5
                    )
                    
                    HStack {
                        Text("Low")
                        Spacer()
                        Text("High")
                    }
                    .font(Typography.caption2)
                    .foregroundColor(Colors.textMuted)
                }
            }
        }
    }
}

@available(macOS 14.0, *)
struct AISettingsSection: View {
    @Binding var llmURL: String
    @Binding var mem0URL: String
    
    var body: some View {
        SettingsSection(title: "AI & Memory", icon: "brain.head.profile") {
            VStack(spacing: Spacing.xl) {
                CustomTextField(
                    title: "LLM Base URL",
                    placeholder: "http://localhost:1234/v1",
                    text: $llmURL,
                    icon: "network"
                )
                
                Divider()
                
                CustomTextField(
                    title: "Mem0 Base URL",
                    placeholder: "http://localhost:8000",
                    text: $mem0URL,
                    icon: "server.rack"
                )
            }
        }
    }
}

@available(macOS 14.0, *)
struct PermissionsSection: View {
    var body: some View {
        SettingsSection(title: "Permissions", icon: "lock.shield") {
            VStack(spacing: Spacing.md) {
                PermissionCard(
                    title: "Screen Recording",
                    description: "Take screenshots for context-aware assistance",
                    icon: "rectangle.dashed",
                    color: Colors.primary,
                    isGranted: true
                )
                
                PermissionCard(
                    title: "Accessibility",
                    description: "Detect keyboard shortcuts and window changes",
                    icon: "keyboard",
                    color: Colors.secondary,
                    isGranted: true
                )
                
                PermissionCard(
                    title: "Microphone",
                    description: "Optional voice input for chat",
                    icon: "mic",
                    color: Colors.accent,
                    isGranted: false
                )
            }
        }
    }
}

@available(macOS 14.0, *)
struct SaveSection: View {
    @Binding var showSavedToast: Bool
    @State private var isSaving = false
    
    var body: some View {
        HStack {
            Spacer()
            
            GradientButton("Save Changes", icon: "checkmark") {
                saveSettings()
            }
        }
    }
    
    private func saveSettings() {
        isSaving = true
        
        // Simulate save
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            withAnimation {
                showSavedToast = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showSavedToast = false
                }
            }
        }
    }
}

@available(macOS 14.0, *)
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Section header with animated divider
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.primary)
                
                Text(title)
                    .font(Typography.title2)
                    .foregroundColor(Colors.textPrimary)
                
                Divider()
                    .background(Colors.border)
            }
            
            // Content
            GlassCard(padding: Spacing.xl, showBorder: true) {
                content
            }
        }
    }
}

@available(macOS 14.0, *)
struct CustomToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Colors.textPrimary)
                
                Text(description)
                    .font(Typography.caption)
                    .foregroundColor(Colors.textMuted)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: Colors.success))
                .scaleEffect(0.9)
        }
    }
}

@available(macOS 14.0, *)
struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Colors.border)
                    .frame(height: 8)
                
                // Filled track
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [Colors.primary, Colors.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth(in: geometry.size.width), height: 8)
                
                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .shadow(color: Colors.primary.opacity(0.3), radius: 8, x: 0, y: 2)
                    .offset(x: thumbPosition(in: geometry.size.width) - 10)
            }
        }
        .frame(height: 20)
    }
    
    private func fillWidth(in totalWidth: CGFloat) -> CGFloat {
        let percentage = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return totalWidth * CGFloat(percentage)
    }
    
    private func thumbPosition(in totalWidth: CGFloat) -> CGFloat {
        let percentage = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return totalWidth * CGFloat(percentage)
    }
}

@available(macOS 14.0, *)
struct CustomTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(Typography.subheadline)
                .foregroundColor(Colors.textPrimary)
            
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isFocused ? Colors.primary : Colors.textMuted)
                
                TextField(placeholder, text: $text)
                    .font(Typography.body)
                    .foregroundColor(Colors.textPrimary)
                    .focused($isFocused)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(isFocused ? Colors.surfaceHover : Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .stroke(isFocused ? Colors.borderFocus : Colors.border, lineWidth: isFocused ? 2 : 1)
                    )
            )
        }
    }
}

@available(macOS 14.0, *)
struct PermissionCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isGranted: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: Spacing.lg) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Colors.textPrimary)
                
                Text(description)
                    .font(Typography.caption)
                    .foregroundColor(Colors.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Status
            if isGranted {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Colors.success)
                    
                    Text("Granted")
                        .font(Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Colors.success)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(Colors.success.opacity(0.1))
                .cornerRadius(Radius.sm)
            } else {
                Button("Grant") {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(isHovered ? Colors.surfaceHover : Color.clear)
        )
        .animation(AnimationPresets.hover, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

@available(macOS 14.0, *)
struct SavedToast: View {
    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(Colors.success)
            
            Text("Settings saved successfully")
                .font(Typography.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Colors.textPrimary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(Colors.surfaceHover)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .stroke(Colors.success.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: Shadows.md.color, radius: Shadows.md.radius, x: Shadows.md.x, y: Shadows.md.y)
        .padding(.top, Spacing.lg)
    }
}

@available(macOS 14.0, *)
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
