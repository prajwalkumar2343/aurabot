import SwiftUI
import AppKit

@available(macOS 14.0, *)
struct SettingsView: View {
    @ObservedObject var service: AppService
    @State private var captureEnabled = true
    @State private var captureInterval: Double = 30
    @State private var captureQuality: Double = 60
    @State private var llmURL = "https://openrouter.ai/api/v1"
    @State private var openRouterAPIKey = ""
    @State private var visionModel = ""
    @State private var chatModel = ""
    @State private var contextCollectorRewriteEnabled = false
    @State private var memoryURL = MemoryConfig.managedPgliteBaseURL
    @State private var memoryAPIKey = ""
    @State private var memoryUserID = "default_user"
    @State private var memoryCollection = "screen_memories_v3"
    @State private var browserExtensionAPIKey = ""
    @State private var showSavedToast = false
    @State private var appearAnimation = false
    @State private var isSaving = false
    
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
                    openRouterAPIKey: $openRouterAPIKey,
                    visionModel: $visionModel,
                    chatModel: $chatModel,
                    contextCollectorRewriteEnabled: $contextCollectorRewriteEnabled,
                    memoryURL: $memoryURL,
                    memoryAPIKey: $memoryAPIKey,
                    memoryUserID: $memoryUserID,
                    memoryCollection: $memoryCollection,
                    browserExtensionAPIKey: $browserExtensionAPIKey
                )
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : 20)
                
                // Permissions
                PermissionsSection(service: service)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
                
                // Save button
                SaveSection(
                    isSaving: $isSaving,
                    onSave: saveSettings
                )
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : 20)
            }
            .padding(Spacing.xxxl)
        }
        .background(Color.clear)
        .overlay(
            Group {
                if showSavedToast {
                    SavedToast()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        )
        .onAppear {
            loadFromService()
            service.refreshPermissionStatuses()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appearAnimation = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            service.refreshPermissionStatuses()
        }
    }

    private func loadFromService() {
        let config = service.config

        captureEnabled = config.capture.enabled
        captureInterval = Double(config.capture.intervalSeconds)
        captureQuality = Double(config.capture.quality)
        llmURL = config.llm.baseURL
        openRouterAPIKey = config.llm.openRouterAPIKey
        visionModel = config.llm.model
        chatModel = config.llm.openRouterChatModel
        contextCollectorRewriteEnabled = config.llm.contextCollectorRewrite.enabled
        memoryURL = config.memory.baseURL
        memoryAPIKey = config.memory.apiKey
        memoryUserID = config.memory.userID
        memoryCollection = config.memory.collectionName
        browserExtensionAPIKey = config.browserExtension.apiKey
    }

    private func saveSettings() {
        isSaving = true

        Task {
            var updatedConfig = service.config
            updatedConfig.capture.enabled = captureEnabled
            updatedConfig.capture.intervalSeconds = Int(captureInterval)
            updatedConfig.capture.quality = Int(captureQuality)
            updatedConfig.llm.baseURL = llmURL.trimmingCharacters(in: .whitespacesAndNewlines)
            updatedConfig.llm.openRouterAPIKey = openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            updatedConfig.llm.model = visionModel.trimmingCharacters(in: .whitespacesAndNewlines)
            updatedConfig.llm.openRouterChatModel = chatModel.trimmingCharacters(in: .whitespacesAndNewlines)
            updatedConfig.llm.contextCollectorRewrite.enabled = contextCollectorRewriteEnabled
            updatedConfig.memory.baseURL = memoryURL.trimmingCharacters(in: .whitespacesAndNewlines)
            updatedConfig.memory.apiKey = memoryAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            updatedConfig.memory.userID = memoryUserID.trimmingCharacters(in: .whitespacesAndNewlines)
            updatedConfig.memory.collectionName = memoryCollection.trimmingCharacters(in: .whitespacesAndNewlines)
            updatedConfig.browserExtension.apiKey = browserExtensionAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)

            do {
                try await service.saveConfiguration(updatedConfig)

                await MainActor.run {
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
            } catch {
                await MainActor.run {
                    isSaving = false
                }
                print("Failed to save configuration: \(error)")
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
                    .background(Colors.glassBorder)
                
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
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: Radius.sm)
                                        .fill(Colors.primary.opacity(0.1))
                                    RoundedRectangle(cornerRadius: Radius.sm)
                                        .stroke(Colors.primary.opacity(0.15), lineWidth: 1)
                                }
                            )
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
                    .background(Colors.glassBorder)
                
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
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: Radius.sm)
                                        .fill(Colors.primary.opacity(0.1))
                                    RoundedRectangle(cornerRadius: Radius.sm)
                                        .stroke(Colors.primary.opacity(0.15), lineWidth: 1)
                                }
                            )
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
    @Binding var openRouterAPIKey: String
    @Binding var visionModel: String
    @Binding var chatModel: String
    @Binding var contextCollectorRewriteEnabled: Bool
    @Binding var memoryURL: String
    @Binding var memoryAPIKey: String
    @Binding var memoryUserID: String
    @Binding var memoryCollection: String
    @Binding var browserExtensionAPIKey: String
    
    var body: some View {
        SettingsSection(title: "AI & Memory", icon: "brain.head.profile") {
            VStack(spacing: Spacing.xl) {
                CustomTextField(
                    title: "LLM Base URL",
                    placeholder: "https://openrouter.ai/api/v1",
                    text: $llmURL,
                    icon: "network"
                )
                
                Divider()
                    .background(Colors.glassBorder)

                CustomTextField(
                    title: "OpenRouter API Key",
                    placeholder: "sk-or-v1-...",
                    text: $openRouterAPIKey,
                    icon: "key.horizontal",
                    isSecure: true
                )

                Divider()
                    .background(Colors.glassBorder)

                CustomTextField(
                    title: "Vision Model",
                    placeholder: "google/gemini-2.5-flash-preview",
                    text: $visionModel,
                    icon: "photo.on.rectangle"
                )

                Divider()
                    .background(Colors.glassBorder)

                CustomTextField(
                    title: "Chat Model",
                    placeholder: "anthropic/claude-3.5-sonnet",
                    text: $chatModel,
                    icon: "text.bubble"
                )

                Divider()
                    .background(Colors.glassBorder)

                VStack(alignment: .leading, spacing: Spacing.md) {
                    CustomToggle(
                        title: "Optional Context Collector Rewrites",
                        description: "Allow OpenRouter to rewrite app-specific context collection code only when the selected chat model meets the configured capability threshold.",
                        isOn: $contextCollectorRewriteEnabled
                    )

                    let rules = ContextCollectorRewriteModelRule.defaultRules.map(\.label).joined(separator: ", ")
                    let eligible = LLMConfig(
                        baseURL: llmURL,
                        model: visionModel,
                        maxTokens: 512,
                        temperature: 0.7,
                        timeoutSeconds: 30,
                        openRouterAPIKey: openRouterAPIKey,
                        openRouterChatModel: chatModel,
                        contextCollectorRewrite: ContextCollectorRewritePolicy(
                            enabled: contextCollectorRewriteEnabled,
                            allowedModels: ContextCollectorRewriteModelRule.defaultRules
                        )
                    ).allowsContextCollectorRewrite()

                    Text("Allowlist: \(rules)")
                        .font(Typography.caption)
                        .foregroundColor(Colors.textMuted)

                    Text(eligible ? "Current chat model is eligible." : "Current chat model is not eligible.")
                        .font(Typography.caption)
                        .foregroundColor(eligible ? Colors.success : Colors.textMuted)
                }

                Divider()
                    .background(Colors.glassBorder)
                
                CustomTextField(
                    title: "Memory API URL",
                    placeholder: MemoryConfig.managedPgliteBaseURL,
                    text: $memoryURL,
                    icon: "server.rack"
                )

                Divider()
                    .background(Colors.glassBorder)

                CustomTextField(
                    title: "Memory API Key",
                    placeholder: "Optional bearer token",
                    text: $memoryAPIKey,
                    icon: "lock.shield",
                    isSecure: true
                )

                Divider()
                    .background(Colors.glassBorder)

                CustomTextField(
                    title: "Browser Extension API Key",
                    placeholder: "Required for extension context updates",
                    text: $browserExtensionAPIKey,
                    icon: "puzzlepiece.extension",
                    isSecure: true
                )

                Divider()
                    .background(Colors.glassBorder)

                CustomTextField(
                    title: "Memory User ID",
                    placeholder: "default_user",
                    text: $memoryUserID,
                    icon: "person"
                )

                Divider()
                    .background(Colors.glassBorder)

                CustomTextField(
                    title: "Collection Name",
                    placeholder: "screen_memories_v3",
                    text: $memoryCollection,
                    icon: "shippingbox"
                )
            }
        }
    }
}

@available(macOS 14.0, *)
struct PermissionsSection: View {
    @ObservedObject var service: AppService

    var body: some View {
        SettingsSection(title: "Permissions", icon: "lock.shield") {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Live macOS privacy access")
                            .font(Typography.headline)
                            .foregroundColor(Colors.textPrimary)

                        Text("Click any checklist item to jump directly into the matching System Settings panel.")
                            .font(Typography.callout)
                            .foregroundColor(Colors.textSecondary)
                    }

                    Spacer()

                    SecondaryButton("Refresh", icon: "arrow.clockwise") {
                        service.refreshPermissionStatuses()
                    }
                }

                PermissionChecklistGroup(statuses: service.permissionStatuses) { kind in
                    service.requestPermission(kind)
                }

                BrowserExtensionSetupCard(service: service)
            }
        }
    }
}

@available(macOS 14.0, *)
struct SaveSection: View {
    @Binding var isSaving: Bool
    let onSave: () -> Void
    
    var body: some View {
        HStack {
            Spacer()
            
            GradientButton(isSaving ? "Saving..." : "Save Changes", icon: isSaving ? "hourglass" : "checkmark") {
                guard !isSaving else { return }
                onSave()
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
                    .background(Colors.glassBorder)
            }
            
            // Content
            GlassCard(padding: Spacing.xl, showBorder: true, blur: .thinMaterial) {
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
                    .fill(Colors.glassBorder)
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
    var isSecure: Bool = false
    
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

                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(Typography.body)
                .foregroundColor(Colors.textPrimary)
                .focused($isFocused)
            }
            .padding(Spacing.md)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(isFocused ? Colors.surface : Colors.surfaceSecondary)
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(isFocused ? Colors.borderFocus : Colors.border, lineWidth: 1)
                }
            )
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
            ZStack {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(Colors.surface)
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(Colors.success.opacity(0.3), lineWidth: 1)
            }
        )
        .shadow(color: Shadows.md.color, radius: Shadows.md.radius, x: Shadows.md.x, y: Shadows.md.y)
        .padding(.top, Spacing.lg)
    }
}

@available(macOS 14.0, *)
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(service: AppService())
    }
}
