import SwiftUI

@available(macOS 12.3, *)
struct ChatView: View {
    @ObservedObject var service: AppService
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Chat")
                    .font(.largeTitle.bold())
                Text("Ask about your memories and activities")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(32)
            .background(Color(NSColor.windowBackgroundColor))
            
            // Messages
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding()
            }
            
            // Input
            HStack(spacing: 12) {
                TextField("Ask about your memories...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
        }
    }
    
    private func sendMessage() {
        let userMessage = ChatMessage(content: inputText, isUser: true)
        messages.append(userMessage)
        
        let text = inputText
        inputText = ""
        isLoading = true
        
        Task {
            do {
                let response = try await service.chat(message: text)
                await MainActor.run {
                    messages.append(ChatMessage(content: response, isUser: false))
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    messages.append(ChatMessage(content: "Sorry, I couldn't process that request.", isUser: false))
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
    let timestamp = Date()
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if !message.isUser {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.purple)
                    }
                    
                    Text(message.isUser ? "You" : "Aura")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    if message.isUser {
                        Image(systemName: "person.circle")
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(message.content)
                    .padding(12)
                    .background(message.isUser ? Color.purple.opacity(0.1) : Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }
            .frame(maxWidth: 600, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}
