import SwiftUI

@available(macOS 14.0, *)
struct ChatView: View {
    @ObservedObject var service: AppService
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Chat")
                    .font(Typography.title1)
                    .foregroundColor(Colors.textPrimary)
                
                Text("Ask about your memories and activities")
                    .font(Typography.body)
                    .foregroundColor(Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.xxxl)
            .background(Colors.background)
            
            // Messages
            ScrollView {
                LazyVStack(spacing: Spacing.lg) {
                    ForEach(messages) { message in
                        MessageBubbleView(message: message)
                    }
                }
                .padding()
            }
            
            // Input
            HStack(spacing: Spacing.md) {
                TextField("Ask about your memories...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(Colors.primary)
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding()
            .background(Colors.surface)
        }
    }
    
    private func sendMessage() {
        let userMessage = ChatMessage(content: inputText, isUser: true, timestamp: Date())
        messages.append(userMessage)
        
        let text = inputText
        inputText = ""
        isLoading = true
        
        Task {
            do {
                let response = try await service.chat(message: text)
                await MainActor.run {
                    messages.append(ChatMessage(content: response, isUser: false, timestamp: Date()))
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    messages.append(ChatMessage(content: "Sorry, I couldn't process that request.", isUser: false, timestamp: Date()))
                    isLoading = false
                }
            }
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
}

@available(macOS 14.0, *)
struct MessageBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    if !message.isUser {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(Colors.primary)
                    }
                    
                    Text(message.isUser ? "You" : "Aura")
                        .font(Typography.caption)
                        .fontWeight(.semibold)
                    
                    if message.isUser {
                        Image(systemName: "person.circle")
                            .foregroundColor(Colors.textSecondary)
                    }
                }
                
                Text(message.content)
                    .padding(Spacing.md)
                    .background(message.isUser ? Colors.primary.opacity(0.1) : Colors.surface)
                    .cornerRadius(Radius.lg)
            }
            .frame(maxWidth: 600, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}
