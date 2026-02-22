/**
 * AuraBot Electron - Quick Enhance Module
 * Enhances AuraApp with Quick Enhance functionality
 */

AuraApp.prototype.setupQuickEnhance = function () {
    const modal = document.getElementById('quick-enhance-modal');
    const overlay = document.getElementById('quick-enhance-overlay');
    const closeBtn = document.getElementById('btn-close-quick-enhance');
    const copyBtn = document.getElementById('btn-copy-enhanced');
    const doneBtn = document.getElementById('btn-close-after-enhance');
    const footer = document.getElementById('quick-enhance-footer');

    // Initialize EnhancedInput component
    const inputContainer = document.getElementById('enhanced-input-container');
    this.enhancedInput = new EnhancedInput({
        container: inputContainer,
        placeholder: 'Enter text to enhance with AI...',
        onEnhance: async (text) => {
            // Call the actual enhancement API
            try {
                const result = await window.electronAPI?.enhancePrompt(text, '');
                if (result?.success) {
                    // Show memories used
                    const memoriesUsed = result.data?.memoriesUsed || result.data?.memories_used || [];
                    this.showEnhanceMemories(memoriesUsed);

                    // Show footer after enhancement
                    if (footer) footer.style.display = 'flex';

                    // Return the enhanced text
                    return result.data?.enhancedPrompt || result.data?.enhanced_prompt || result.data?.response;
                } else {
                    throw new Error(result?.error || 'Enhancement failed');
                }
            } catch (error) {
                console.error('Enhancement API error:', error);
                this.showToast('Enhancement failed: ' + error.message, 'error');
                return null;
            }
        }
    });

    // Close handlers
    const closePopup = () => {
        modal.classList.remove('active');
        overlay.classList.remove('active');
        if (footer) footer.style.display = 'none';

        // Reset the enhanced input component
        if (this.enhancedInput) {
            this.enhancedInput.reset();
        }

        // Clear memories display
        const memoriesContainer = document.getElementById('quick-enhance-memories');
        if (memoriesContainer) {
            memoriesContainer.innerHTML = '';
        }
    };

    closeBtn?.addEventListener('click', closePopup);
    overlay?.addEventListener('click', closePopup);

    // Floating button click (if exists)
    const floatingBtn = document.getElementById('floating-enhance-btn');
    floatingBtn?.addEventListener('click', () => {
        this.openQuickEnhance('');
    });

    // Copy button
    copyBtn?.addEventListener('click', async () => {
        const resultText = this.enhancedInput?.getValue();
        if (!resultText) return;

        try {
            await navigator.clipboard.writeText(resultText);
            this.showToast('Copied to clipboard');
        } catch (err) {
            console.error('Copy failed:', err);
            this.showToast('Failed to copy', 'error');
        }
    });

    // Done button
    doneBtn?.addEventListener('click', () => {
        closePopup();
    });
};

/**
 * Show memories used in enhancement
 */
AuraApp.prototype.showEnhanceMemories = function (memories) {
    const container = document.getElementById('quick-enhance-memories');
    if (!container) return;

    if (!memories || memories.length === 0) {
        container.innerHTML = '';
        return;
    }

    const badge = `<span class="quick-enhance-badge" style="margin-bottom: 8px; display: inline-block;">${memories.length} memories used</span>`;
    const chips = memories.map(m =>
        `<div class="memory-chip" title="${this.escapeHtml(m)}">${this.escapeHtml(m.substring(0, 40))}${m.length > 40 ? '...' : ''}</div>`
    ).join('');

    container.innerHTML = badge + '<div style="display: flex; flex-wrap: wrap; gap: 6px;">' + chips + '</div>';
};

AuraApp.prototype.openQuickEnhance = function (text = '') {
    const modal = document.getElementById('quick-enhance-modal');
    const overlay = document.getElementById('quick-enhance-overlay');
    const footer = document.getElementById('quick-enhance-footer');

    // Reset footer
    if (footer) footer.style.display = 'none';

    // Reset and set input
    if (this.enhancedInput) {
        this.enhancedInput.reset();
        if (text) {
            this.enhancedInput.setValue(text);
        }
        setTimeout(() => this.enhancedInput.focus(), 100);
    }

    // Clear memories
    const memoriesContainer = document.getElementById('quick-enhance-memories');
    if (memoriesContainer) {
        memoriesContainer.innerHTML = '';
    }

    // Show modal
    modal.classList.add('active');
    overlay.classList.add('active');
};
