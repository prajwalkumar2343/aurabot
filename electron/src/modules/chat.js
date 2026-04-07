/**
 * AuraBot Electron - Chat Module
 * Enhances AuraApp with chat functionality
 */

AuraApp.prototype.setupChat = function () {
    const chatInput = document.getElementById('chat-input');
    const sendBtn = document.getElementById('btn-send-message');

    const sendMessage = async () => {
        const message = chatInput?.value?.trim();
        if (!message) return;

        // Add user message
        this.addChatMessage(message, 'user');
        chatInput.value = '';

        // Show typing
        this.showTypingIndicator();

        try {
            const result = await window.electronAPI?.chat(message);
            this.hideTypingIndicator();

            if (result?.success) {
                const response = result.data?.response || result.data || 'No response';
                this.addChatMessage(response, 'assistant');
            } else {
                throw new Error(result?.error || 'Chat failed');
            }
        } catch (error) {
            this.hideTypingIndicator();
            this.addChatMessage('Sorry, I encountered an error. Please try again.', 'assistant');
            console.error('Chat error:', error);
        }
    };

    sendBtn?.addEventListener('click', sendMessage);
    chatInput?.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') sendMessage();
    });
};

AuraApp.prototype.addChatMessage = function (content, type) {
    const container = document.getElementById('chat-messages');
    if (!container) return;

    const time = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

    const avatar = type === 'user' ? '' : `
        <div class="message-avatar">
            <svg viewBox="0 0 24 24" fill="none">
                <defs>
                    <linearGradient id="grad-${Date.now()}" x1="2" y1="2" x2="22" y2="22">
                        <stop offset="0%" stop-color="#F5D76E"/>
                        <stop offset="100%" stop-color="#E8C84A"/>
                    </linearGradient>
                </defs>
                <circle cx="12" cy="12" r="10" fill="url(#grad-${Date.now()})"/>
                <path d="M8 14s1.5 2 4 2 4-2 4-2M9 9h.01M15 9h.01" stroke="#1A1A1A" stroke-width="2" stroke-linecap="round"/>
            </svg>
        </div>
    `;

    const html = `
        <div class="chat-message ${type}">
            ${avatar}
            <div class="message-content">
                <p>${this.escapeHtml(content)}</p>
                <span class="message-time">${time}</span>
            </div>
        </div>
    `;

    container.insertAdjacentHTML('beforeend', html);
    container.scrollTop = container.scrollHeight;
};

AuraApp.prototype.showTypingIndicator = function () {
    const container = document.getElementById('chat-messages');
    if (!container) return;

    const indicator = document.createElement('div');
    indicator.id = 'typing-indicator';
    indicator.className = 'chat-message assistant';
    indicator.innerHTML = `
        <div class="message-avatar">
            <svg viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="10" fill="#F5D76E"/></svg>
        </div>
        <div class="message-content"><p>Thinking...</p></div>
    `;
    container.appendChild(indicator);
    container.scrollTop = container.scrollHeight;
};

AuraApp.prototype.hideTypingIndicator = function () {
    document.getElementById('typing-indicator')?.remove();
};
