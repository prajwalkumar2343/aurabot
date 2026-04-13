import SwiftUI

@available(macOS 14.0, *)
struct ChatView: View {
    @ObservedObject var service: AppService
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var appearAnimation = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            ChatHeader()
                .padding(.horizontal, Spacing.xxxl)
                .padding(.top, Spacing.xxxl)
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : -20)
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: Spacing.lg) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .transition(.asymmetric(
                                    insertion: .move(edge: message.isUser ? .trailing : .leading).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                        
                        if isLoading {
                            TypingIndicator()
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, Spacing.xxxl)
                    .padding(.vertical, Spacing.lg)
                    .id("bottom")
                }
                .onChange(of: messages.count) { _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: isLoading) { _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            
            // Input bar
            ChatInputBar(
                text: $inputText,
                isLoading: isLoading,
                onSend: sendMessage
            )
            .focused($isInputFocused)
            .padding(.horizontal, Spacing.xxxl)
            .padding(.vertical, Spacing.lg)
            .background(.ultraThinMaterial)
        }
        .background(Colors.background)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appearAnimation = true
            }
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let userMessage = ChatMessage(content: inputText, isUser: true)
        withAnimation(AnimationPresets.spring) {
            messages.append(userMessage)
        }
        
        let text = inputText
        inputText = ""
        isLoading = true
        
        Task {
            do {
                let response = try await service.chat(message: text)
                await MainActor.run {
                    withAnimation(AnimationPresets.spring) {
                        messages.append(ChatMessage(content: response, isUser: false))
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(AnimationPresets.spring) {
                        messages.append(ChatMessage(content: "Sorry, I couldn't process that request. Please try again.", isUser: false))
                        isLoading = false
                    }
                }
            }
        }
    }
}

@available(macOS 14.0, *)
struct ChatHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Chat")
                        .font(Typography.title1)
                        .foregroundColor(Colors.textPrimary)
                    
                    Text("Ask about your memories and activities")
                        .font(Typography.body)
                        .foregroundColor(Colors.textSecondary)
                }
                
                Spacer()
                
                // Status indicator
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Colors.success)
                        .frame(width: 8, height: 8)
                    
                    Text("Aura is online")
                        .font(Typography.caption)
                        .foregroundColor(Colors.textSecondary)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule()
                        .fill(Colors.success.opacity(0.1))
                )
            }
        }
    }
}

@available(macOS 14.0, *)
struct MessageBubble: View {
    let message: ChatMessage
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: Spacing.xs) {
                // Sender name
                HStack(spacing: Spacing.xs) {
                    if !message.isUser {
                        ZStack {
                            Circle()
                                .fill(Colors.primary.opacity(0.15))
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Colors.primary)
                        }
                    }
                    
                    Text(message.isUser ? "You" : "Aura")
                        .font(Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(message.isUser ? Colors.textSecondary : Colors.primary)
                    
                    if message.isUser {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Colors.textMuted)
                    }
                }
                
                // Message content
                Text(message.content)
                    .font(Typography.body)
                    .foregroundColor(message.isUser ? Colors.textPrimary : .white)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .background(
                        Group {
                            if message.isUser {
                                RoundedRectangle(cornerRadius: Radius.lg)
                                    .fill(Colors.surfaceHover)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Radius.lg)
                                            .stroke(Colors.border, lineWidth: 1)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: Radius.lg)
                                    .fill(
                                        LinearGradient(
                                            colors: [Colors.primary, Colors.secondary],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                    )
                    .shadow(
                        color: message.isUser ? Color.clear : Colors.primary.opacity(0.3),
                        radius: 12,
                        x: 0,
                        y: 4
                    )
                
                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(Typography.caption2)
                    .foregroundColor(Colors.textMuted)
                    .padding(.horizontal, Spacing.xs)
            }
            .frame(maxWidth: 600, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(AnimationPresets.hover, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

@available(macOS 14.0, *)
struct TypingIndicator: View {
    @State private var animationStep = 0
    
    var body: some View {
        HStack {
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(Colors.primary.opacity(0.15))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Colors.primary)
                }
                
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Colors.primary)
                            .frame(width: 6, height: 6)
                            .scaleEffect(animationStep == index ? 1.2 : 0.8)
                            .opacity(animationStep == index ? 1 : 0.5)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(Colors.surfaceHover)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg)
                            .stroke(Colors.border, lineWidth: 1)
                    )
            )
            
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                animationStep = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                    animationStep = 2
                }
            }
        }
    }
}

@available(macOS 14.0, *)
struct ChatInputBar: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void
    
    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Text field
            HStack(spacing: Spacing.md) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 20))
                    .foregroundColor(Colors.textMuted)
                
                TextField("Ask about your memories...", text: $text)
                    .font(Typography.body)
                    .foregroundColor(Colors.textPrimary)
                    .focused($isFocused)
                    .onSubmit(onSend)
                
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
                RoundedRectangle(cornerRadius: Radius.xl)
                    .fill(isFocused ? Colors.surfaceHover : Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.xl)
                            .stroke(isFocused ? Colors.borderFocus : Colors.border, lineWidth: isFocused ? 2 : 1)
                    )
            )
            .shadow(
                color: isFocused ? Colors.primaryGlow : Color.clear,
                radius: isFocused ? 16 : 0
            )
            
            // Send button
            SendButton(isLoading: isLoading, isEnabled: !text.isEmpty) {
                onSend()
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xl)
                        .stroke(Colors.border, lineWidth: 1)
                )
        )
        .shadow(color: Shadows.md.color, radius: Shadows.md.radius, x: Shadows.md.x, y: Shadows.md.y)
    }
}

@available(macOS 14.0, *)
struct SendButton: View {
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isEnabled ? Colors.primary : Colors.textMuted.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .shadow(
                        color: isEnabled && isHovered ? Colors.primary.opacity(0.4) : Color.clear,
                        radius: isHovered ? 16 : 0
                    )
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(isHovered ? -45 : 0))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .scaleEffect(isPressed ? 0.9 : isHovered ? 1.1 : 1.0)
        .animation(AnimationPresets.hover, value: isHovered)
        .animation(AnimationPresets.press, value: isPressed)
        .onHover { hovering in
            isHovered = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

@available(macOS 14.0, *)
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp = Date()
}

@available(macOS 14.0, *)
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView(service: AppService())
    }
}
