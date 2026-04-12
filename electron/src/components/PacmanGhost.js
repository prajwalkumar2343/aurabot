/**
 * AuraBot Electron - Pacman Ghost Animation Module
 * Standalone Pacman animation for ghost mode (hotkey triggered)
 * Eats text and reveals enhanced version
 */

(function () {
    'use strict';

    console.log('[PacmanGhost] Module loading...');

    // Create the Pacman Ghost overlay container
    function createOverlay() {
        console.log('[PacmanGhost] Creating overlay...');
        let overlay = document.getElementById('pacman-ghost-overlay');
        if (overlay) {
            console.log('[PacmanGhost] Overlay already exists');
            return overlay;
        }

        overlay = document.createElement('div');
        overlay.id = 'pacman-ghost-overlay';
        overlay.className = 'pacman-ghost-overlay';
        overlay.innerHTML = `
            <div class="pacman-ghost-container">
                <!-- Text container showing what Pacman will eat -->
                <div class="pacman-text-container" id="pacman-text-container"></div>
                
                <!-- Pacman -->
                <div class="pacman-ghost-player" id="pacman-ghost-player">
                    <svg class="pacman-ghost-svg" viewBox="0 0 36 36" xmlns="http://www.w3.org/2000/svg">
                        <g class="pacman-mouth-top">
                            <path d="M 18 18 L 34 18 A 16 16 0 0 0 18 2 L 18 18 Z" fill="#FFFF00" stroke="#E6C800" stroke-width="0.5"/>
                        </g>
                        <g class="pacman-mouth-bottom">
                            <path d="M 18 18 L 18 34 A 16 16 0 0 0 34 18 L 18 18 Z" fill="#FFFF00" stroke="#E6C800" stroke-width="0.5"/>
                        </g>
                        <path d="M 18 2 A 16 16 0 0 0 18 34 L 18 18 Z" fill="#FFFF00" stroke="#E6C800" stroke-width="0.5"/>
                        <circle cx="14" cy="10" r="2.5" fill="#1A1A1A"/>
                    </svg>
                </div>
                
                <!-- Dots trail -->
                <div class="pacman-dots-trail" id="pacman-dots-trail"></div>
                
                <!-- WAKA text effect -->
                <div class="pacman-waka" id="pacman-waka">WAKA WAKA!</div>
                
                <!-- Result container -->
                <div class="pacman-result" id="pacman-result"></div>
                
                <!-- Status -->
                <div class="pacman-status" id="pacman-status">
                    <span class="status-dot"></span>
                    <span class="status-text">Aura is enhancing your text...</span>
                </div>
            </div>
        `;
        document.body.appendChild(overlay);
        console.log('[PacmanGhost] Overlay created and appended to body');
        return overlay;
    }

    // Split text into characters for animation
    function createTextElements(text) {
        console.log('[PacmanGhost] Creating text elements, length:', text.length);
        const container = document.getElementById('pacman-text-container');
        container.innerHTML = '';
        
        const chars = text.split('').map((char, index) => {
            const span = document.createElement('span');
            span.className = 'pacman-char';
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

        chars.forEach(span => container.appendChild(span));
        console.log('[PacmanGhost] Created', chars.length, 'character elements');
        return chars;
    }

    // Create dots along the path
    function createDots(textLength) {
        const container = document.getElementById('pacman-dots-trail');
        container.innerHTML = '';
        
        const numDots = Math.min(20, Math.max(8, Math.floor(textLength / 3)));
        const dots = [];
        
        for (let i = 0; i < numDots; i++) {
            const dot = document.createElement('div');
            dot.className = 'pacman-dot-trail';
            dot.style.left = `${(i / (numDots - 1)) * 80 + 10}%`;
            container.appendChild(dot);
            dots.push(dot);
        }
        
        return dots;
    }

    // Show WAKA text at position
    function showWaka(x, y) {
        const waka = document.getElementById('pacman-waka');
        waka.style.left = x + 'px';
        waka.style.top = y + 'px';
        waka.classList.add('show');
        
        setTimeout(() => {
            waka.classList.remove('show');
        }, 600);
    }

    // Animate Pacman eating the text
    async function animateEating(text) {
        console.log('[PacmanGhost] Starting animateEating');
        const overlay = document.getElementById('pacman-ghost-overlay');
        const player = document.getElementById('pacman-ghost-player');
        const charElements = createTextElements(text);
        const dots = createDots(text.length);
        const container = document.getElementById('pacman-text-container');
        
        const duration = Math.max(1.5, Math.min(3.5, text.length * 0.05));
        console.log('[PacmanGhost] Animation duration:', duration, 'seconds');
        
        // Show overlay
        overlay.classList.add('active');
        console.log('[PacmanGhost] Overlay activated');
        
        // Start animation
        await new Promise(resolve => {
            // Show pacman
            player.classList.add('animating');
            
            // Start movement
            setTimeout(() => {
                player.classList.add('moving');
                player.style.animationDuration = `${duration}s`;
            }, 100);
            
            // Track eating progress
            const startTime = performance.now();
            let lastWaka = 0;
            
            const updateFrame = () => {
                const elapsed = (performance.now() - startTime) / 1000;
                const progress = Math.min(1, elapsed / duration);
                
                // Eat characters
                const charsToEat = Math.floor(progress * charElements.length);
                for (let i = 0; i < charsToEat && i < charElements.length; i++) {
                    if (!charElements[i].classList.contains('eaten')) {
                        charElements[i].classList.add('eaten');
                    }
                }
                
                // Eat dots
                const dotsToEat = Math.floor(progress * dots.length);
                for (let i = 0; i < dotsToEat && i < dots.length; i++) {
                    if (!dots[i].classList.contains('eaten')) {
                        dots[i].classList.add('eaten');
                    }
                }
                
                // Show WAKA occasionally
                if (elapsed - lastWaka > 0.5) {
                    const rect = player.getBoundingClientRect();
                    showWaka(rect.left + 20, rect.top - 30);
                    lastWaka = elapsed;
                }
                
                if (progress < 1) {
                    requestAnimationFrame(updateFrame);
                } else {
                    // Ensure everything is eaten
                    charElements.forEach(c => c.classList.add('eaten'));
                    dots.forEach(d => d.classList.add('eaten'));
                    console.log('[PacmanGhost] Eating animation frame loop complete');
                    resolve();
                }
            };
            
            requestAnimationFrame(updateFrame);
        });
        
        // Hide pacman
        player.classList.remove('animating', 'moving');
        container.style.opacity = '0';
        console.log('[PacmanGhost] Pacman hidden, text container faded');
    }

    // Show the enhanced result
    async function showResult(enhancedText) {
        console.log('[PacmanGhost] Showing result, length:', enhancedText?.length);
        const resultEl = document.getElementById('pacman-result');
        const statusEl = document.getElementById('pacman-status');
        
        statusEl.innerHTML = '<span class="status-success">✨ Enhanced!</span>';
        
        resultEl.textContent = enhancedText;
        resultEl.classList.add('show');
        
        // Auto-hide after delay
        await new Promise(resolve => setTimeout(resolve, 2000));
    }

    // Hide overlay
    function hideOverlay() {
        console.log('[PacmanGhost] Hiding overlay');
        const overlay = document.getElementById('pacman-ghost-overlay');
        if (!overlay) return;
        
        overlay.classList.remove('active');
        
        // Reset after transition
        setTimeout(() => {
            const player = document.getElementById('pacman-ghost-player');
            const container = document.getElementById('pacman-text-container');
            const resultEl = document.getElementById('pacman-result');
            const statusEl = document.getElementById('pacman-status');
            
            if (player) player.classList.remove('animating', 'moving');
            if (container) {
                container.innerHTML = '';
                container.style.opacity = '1';
            }
            if (resultEl) {
                resultEl.textContent = '';
                resultEl.classList.remove('show');
            }
            if (statusEl) {
                statusEl.innerHTML = '<span class="status-dot"></span><span class="status-text">Aura is enhancing your text...</span>';
            }
        }, 300);
    }

    // Main function to run Pacman ghost animation
    async function runPacmanGhost(text, onComplete) {
        console.log('[PacmanGhost] runPacmanGhost called with text length:', text?.length);
        createOverlay();
        
        try {
            // Step 1: Animate eating
            await animateEating(text);
            
            // Step 2: Show result (placeholder - actual enhancement happens outside)
            if (onComplete) {
                await onComplete();
            }
        } catch (error) {
            console.error('[PacmanGhost] Animation error:', error);
            hideOverlay();
        }
    }

    // Expose globally
    window.PacmanGhost = {
        run: runPacmanGhost,
        hide: hideOverlay,
        showResult: showResult
    };
    
    console.log('[PacmanGhost] Module loaded and window.PacmanGhost exposed');
})();
