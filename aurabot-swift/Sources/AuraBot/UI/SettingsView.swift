import SwiftUI

@available(macOS 12.3, *)
struct SettingsView: View {
    @State private var captureEnabled = true
    @State private var captureInterval: Double = 30
    @State private var captureQuality: Double = 60
    @State private var llmURL = "http://localhost:1234/v1"
    @State private var mem0URL = "http://localhost:8000"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.largeTitle.bold())
                    Text("Customize your Aura experience")
                        .foregroundColor(.secondary)
                }
                
                // Capture Settings
                SettingsSection(title: "Capture") {
                    Toggle("Screen Capture", isOn: $captureEnabled)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Capture Interval: \(Int(captureInterval))s")
                        Slider(value: $captureInterval, in: 10...300, step: 5)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("JPEG Quality: \(Int(captureQuality))%")
                        Slider(value: $captureQuality, in: 30...100, step: 5)
                    }
                }
                
                // AI Settings
                SettingsSection(title: "AI & Memory") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LLM Base URL")
                        TextField("URL", text: $llmURL)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mem0 Base URL")
                        TextField("URL", text: $mem0URL)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                // Permissions
                SettingsSection(title: "Permissions") {
                    PermissionRow(
                        title: "Screen Recording",
                        description: "Take screenshots for context-aware assistance",
                        icon: "rectangle.dashed"
                    )
                    
                    PermissionRow(
                        title: "Accessibility",
                        description: "Detect keyboard shortcuts",
                        icon: "keyboard"
                    )
                }
                
                // Save Button
                HStack {
                    Spacer()
                    Button("Save Changes") {}
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(32)
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.bold())
            
            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Grant") {}
                .buttonStyle(.bordered)
        }
    }
}
