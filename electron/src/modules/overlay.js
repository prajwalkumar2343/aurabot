// ========================================
// Overlay Assistant Module
// Floating orb → expanding mini panel
// ========================================

(function () {
    'use strict';

    const orb = document.getElementById('overlay-orb');
    const panel = document.getElementById('overlay-panel');
    const closeBtn = document.getElementById('btn-close-overlay');
    const input = document.getElementById('overlay-input');
    const sendBtn = document.getElementById('overlay-send-btn');
    const messagesContainer = document.getElementById('overlay-messages');

    let isExpanded = false;

    function expand() {
        isExpanded = true;
        panel.classList.add('expanded');
        orb.classList.add('active');
        // Focus input after animation
        setTimeout(() => input && input.focus(), 350);
    }

    function collapse() {
        isExpanded = false;
        panel.classList.remove('expanded');
        orb.classList.remove('active');
    }

    function toggle() {
        if (isExpanded) {
            collapse();
        } else {
            expand();
        }
    }

    function addMessage(text, role) {
        if (!messagesContainer) return;

        const msg = document.createElement('div');
        msg.className = `overlay-message ${role}`;
        msg.textContent = text;
        messagesContainer.appendChild(msg);
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
    }

    async function sendMessage() {
        if (!input) return;

        const text = input.value.trim();
        if (!text) return;

        addMessage(text, 'user');
        input.value = '';

        // Show typing indicator
        const typingMsg = document.createElement('div');
        typingMsg.className = 'overlay-message assistant';
        typingMsg.textContent = 'Thinking...';
        typingMsg.id = 'overlay-typing';
        messagesContainer.appendChild(typingMsg);

        try {
            // Try to use the same chat API as the main chat
            if (window.app && window.app.api) {
                const response = await window.app.api.chat(text);
                const typing = document.getElementById('overlay-typing');
                if (typing) typing.remove();
                addMessage(response || 'I received your message.', 'assistant');
            } else {
                // Fallback
                setTimeout(() => {
                    const typing = document.getElementById('overlay-typing');
                    if (typing) typing.remove();
                    addMessage('Connect to the backend to get responses.', 'assistant');
                }, 800);
            }
        } catch (err) {
            const typing = document.getElementById('overlay-typing');
            if (typing) typing.remove();
            addMessage('Unable to connect. Please check the backend.', 'assistant');
        }
    }

    // Event listeners
    if (orb) {
        orb.addEventListener('click', toggle);
    }

    if (closeBtn) {
        closeBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            collapse();
        });
    }

    if (sendBtn) {
        sendBtn.addEventListener('click', sendMessage);
    }

    if (input) {
        input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                sendMessage();
            }
        });
    }

    // Click outside to close
    document.addEventListener('click', (e) => {
        if (!isExpanded) return;
        const assistant = document.getElementById('overlay-assistant');
        if (assistant && !assistant.contains(e.target)) {
            collapse();
        }
    });

    // Escape to close
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && isExpanded) {
            collapse();
        }
    });

    // Expose globally
    window.AuraOverlay = { expand, collapse, toggle };
})();
