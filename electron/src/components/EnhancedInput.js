/**
 * EnhancedInput Component
 * A reusable input component with arcade-style Pac-Man "eating" animation
 * 
 * Usage:
 *   const input = new EnhancedInput({
 *     container: document.getElementById('input-container'),
 *     placeholder: 'Enter text to enhance...',
 *     onEnhance: async (text) => { return enhancedText; }
 *   });
 */

class EnhancedInput {
    constructor(options = {}) {
        this.container = options.container;
        this.placeholder = options.placeholder || 'Enter text to enhance...';
        this.onEnhance = options.onEnhance || null;
        this.onChange = options.onChange || null;
        this.onSubmit = options.onSubmit || null;

        this.isAnimating = false;
        this.originalText = '';
        this.enhancedText = '';

        this.init();
    }

    init() {
        this.createDOM();
        this.attachEventListeners();
    }

    createDOM() {
        // Create wrapper
        this.wrapper = document.createElement('div');
        this.wrapper.className = 'enhanced-input-wrapper';

        // Create status label
        this.statusLabel = document.createElement('div');
        this.statusLabel.className = 'enhance-status';
        this.statusLabel.innerHTML = '<span class="status-dot"></span>AI is enhancing your text...';
        this.wrapper.appendChild(this.statusLabel);

        // Create input textarea
        this.textarea = document.createElement('textarea');
        this.textarea.className = 'enhanced-input';
        this.textarea.placeholder = this.placeholder;
        this.textarea.spellcheck = false;
        this.wrapper.appendChild(this.textarea);

        // Create text overlay container (for character animation)
        this.textOverlay = document.createElement('div');
        this.textOverlay.className = 'input-text-overlay';
        this.textOverlay.style.cssText = `
            position: absolute;
            top: 16px;
            left: 20px;
            right: 50px;
            pointer-events: none;
            font-size: 15px;
            line-height: 1.8;
            color: transparent;
            white-space: pre-wrap;
            word-wrap: break-word;
            z-index: 2;
        `;
        this.wrapper.appendChild(this.textOverlay);

        // If Pacman extension is loaded, initialize its DOM
        if (typeof this.initPacmanDOM === 'function') {
            this.initPacmanDOM();
        }

        // Create enhanced result container
        this.resultContainer = document.createElement('div');
        this.resultContainer.className = 'enhanced-result';
        this.wrapper.appendChild(this.resultContainer);

        // Create progress bar
        this.progressBar = document.createElement('div');
        this.progressBar.className = 'enhance-progress';
        this.wrapper.appendChild(this.progressBar);

        // Create enhance button
        this.enhanceBtn = document.createElement('button');
        this.enhanceBtn.className = 'enhance-trigger-btn';
        this.enhanceBtn.title = 'Enhance with AI';
        this.enhanceBtn.innerHTML = `
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M13 10V3L4 14h7v7l9-11h-7z"/>
            </svg>
        `;
        this.wrapper.appendChild(this.enhanceBtn);

        // Create reset button (hidden initially)
        this.resetBtn = document.createElement('button');
        this.resetBtn.className = 'enhance-reset-btn';
        this.resetBtn.title = 'Clear and start over';
        this.resetBtn.innerHTML = `
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M6 18L18 6M6 6l12 12"/>
            </svg>
        `;
        this.wrapper.appendChild(this.resetBtn);

        // Append to container
        if (this.container) {
            this.container.appendChild(this.wrapper);
        }
    }

    attachEventListeners() {
        // Textarea input
        this.textarea.addEventListener('input', (e) => {
            this.originalText = e.target.value;
            this.syncTextOverlay();
            if (this.onChange) {
                this.onChange(this.originalText);
            }
        });

        // Enhance button click
        this.enhanceBtn.addEventListener('click', async () => {
            if (this.isAnimating || !this.originalText.trim()) return;

            if (this.onEnhance) {
                this.enhanceBtn.disabled = true;
                try {
                    const enhanced = await this.onEnhance(this.originalText);
                    if (enhanced) {
                        if (this.enhanceText) {
                            this.enhanceText(enhanced);
                        }
                    }
                } catch (error) {
                    console.error('Enhancement failed:', error);
                } finally {
                    this.enhanceBtn.disabled = false;
                }
            }
        });

        // Reset button click
        this.resetBtn.addEventListener('click', () => {
            this.reset();
        });

        // Enter key to submit
        this.textarea.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
                if (this.onSubmit && !this.isAnimating) {
                    e.preventDefault();
                    this.onSubmit(this.getValue());
                }
            }
        });
    }

    syncTextOverlay() {
        // Mirror textarea content in overlay for character animation
        const text = this.textarea.value;
        const chars = text.split('').map((char, index) => {
            const span = document.createElement('span');
            span.className = 'input-char';
            // Preserve spaces and newlines
            if (char === ' ') {
                span.innerHTML = '&nbsp;';
            } else if (char === '\n') {
                span.innerHTML = '<br>';
            } else {
                span.textContent = char;
            }
            span.dataset.index = index;
            return span;
        });

        this.textOverlay.innerHTML = '';
        chars.forEach(span => this.textOverlay.appendChild(span));
        this.charSpans = chars;
    }

    /**
     * Reset the component to initial state
     */
    reset() {
        // Stop any ongoing animation
        this.isAnimating = false;

        // Reset UI
        this.textarea.value = '';
        this.textarea.disabled = false;
        this.wrapper.classList.remove('disabled');
        this.enhanceBtn.disabled = false;
        this.enhanceBtn.style.opacity = '1';

        // Reset Pac-Man
        if (this.pacmanContainer) {
            this.pacmanContainer.classList.remove('animating', 'pacman-moving');
            this.pacmanContainer.style.opacity = '0';
            this.pacmanContainer.style.animationDuration = '';
        }

        // Reset dots
        if (this.dotsContainer) {
            this.dotsContainer.classList.remove('show');
            this.dotsContainer.innerHTML = '';
        }

        // Reset progress bar
        this.progressBar.classList.remove('animating');
        this.progressBar.style.transition = '';
        this.progressBar.style.width = '0%';

        // Reset overlays
        this.textOverlay.innerHTML = '';
        this.resultContainer.textContent = '';
        this.resultContainer.classList.remove('show', 'typewriter');

        // Reset buttons
        this.resetBtn.classList.remove('show');

        // Reset data
        this.originalText = '';
        this.enhancedText = '';
        this.charSpans = [];
        this.dots = [];

        // Focus textarea
        this.textarea.focus();
    }

    /**
     * Get current input value
     */
    getValue() {
        if (this.enhancedText && this.resultContainer.classList.contains('show')) {
            return this.enhancedText;
        }
        return this.textarea.value;
    }

    /**
     * Set input value
     */
    setValue(text) {
        this.originalText = text;
        this.textarea.value = text;
        this.syncTextOverlay();
    }

    /**
     * Focus the input
     */
    focus() {
        this.textarea.focus();
    }

    /**
     * Check if currently animating
     */
    isEnhancing() {
        return this.isAnimating;
    }

    /**
     * Destroy the component
     */
    destroy() {
        if (this.wrapper && this.wrapper.parentNode) {
            this.wrapper.parentNode.removeChild(this.wrapper);
        }
    }
}

// Export for module systems or make available globally
if (typeof module !== 'undefined' && module.exports) {
    module.exports = EnhancedInput;
} else {
    window.EnhancedInput = EnhancedInput;
}
