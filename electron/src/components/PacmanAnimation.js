/**
 * AuraBot Electron - Pacman Animation Module
 * Extends the EnhancedInput component with Pac-Man eating animations
 */

/**
 * Initialize Pacman specific DOM elements within the EnhancedInput wrapper
 */
EnhancedInput.prototype.initPacmanDOM = function () {
    // Create Pac-Man container with PROPER SVG
    this.pacmanContainer = document.createElement('div');
    this.pacmanContainer.className = 'pacman-container';
    this.pacmanContainer.innerHTML = `
        <svg class="pacman-svg" viewBox="0 0 36 36" xmlns="http://www.w3.org/2000/svg">
            <!-- Top half (rotates up to open mouth) -->
            <g class="pacman-mouth-top">
                <path d="M 18 18 L 34 18 A 16 16 0 0 0 18 2 L 18 18 Z" fill="#FFFF00" stroke="#E6C800" stroke-width="0.5"/>
            </g>
            
            <!-- Bottom half (rotates down to open mouth) -->
            <g class="pacman-mouth-bottom">
                <path d="M 18 18 L 18 34 A 16 16 0 0 0 34 18 L 18 18 Z" fill="#FFFF00" stroke="#E6C800" stroke-width="0.5"/>
            </g>
            
            <!-- Back half (always visible, doesn't move) -->
            <path d="M 18 2 A 16 16 0 0 0 18 34 L 18 18 Z" fill="#FFFF00" stroke="#E6C800" stroke-width="0.5"/>
        </svg>
    `;
    this.wrapper.appendChild(this.pacmanContainer);

    // Create dots container (pellets to eat)
    this.dotsContainer = document.createElement('div');
    this.dotsContainer.className = 'pacman-dots';
    this.wrapper.appendChild(this.dotsContainer);
};

/**
 * Create dots (pellets) along the path for Pac-Man to eat
 */
EnhancedInput.prototype.createDots = function () {
    this.dotsContainer.innerHTML = '';
    const containerWidth = this.wrapper.offsetWidth || 500;
    const numDots = Math.max(5, Math.floor(containerWidth / 60));

    for (let i = 0; i < numDots; i++) {
        const dot = document.createElement('div');
        dot.className = 'pacman-dot';
        dot.style.left = `${(i + 1) * (100 / (numDots + 1))}%`;
        dot.dataset.index = i;
        this.dotsContainer.appendChild(dot);
    }

    this.dots = Array.from(this.dotsContainer.querySelectorAll('.pacman-dot'));
};

/**
 * Trigger the Pac-Man enhancement animation
 * @param {string} newText - The enhanced text to reveal
 * @param {Object} options - Animation options
 */
EnhancedInput.prototype.enhanceText = async function (newText, options = {}) {
    if (this.isAnimating) return;

    this.isAnimating = true;
    this.enhancedText = newText;

    const {
        baseSpeed = 0.05,
        minDuration = 0.8,
        maxDuration = 3.0,
        useTypewriter = false
    } = options;

    // Calculate animation duration based on text length
    const textLength = this.originalText.length || 1;
    let duration = Math.max(minDuration, Math.min(maxDuration, textLength * baseSpeed));

    // Sync text overlay for animation
    this.syncTextOverlay();

    // Create dots
    this.createDots();

    // Disable input
    this.textarea.disabled = true;
    this.wrapper.classList.add('disabled');
    this.enhanceBtn.disabled = true;
    this.enhanceBtn.style.opacity = '0';

    // Show status
    this.statusLabel.classList.add('show');

    // Show dots
    this.dotsContainer.classList.add('show');

    // Start Pac-Man animation
    await this.animatePacManEating(duration);

    // Hide Pac-Man instantly
    this.pacmanContainer.classList.remove('animating');
    this.pacmanContainer.style.opacity = '0';

    // Hide dots
    this.dotsContainer.classList.remove('show');

    // Show enhanced text
    await this.revealEnhancedText(useTypewriter);

    // Show reset button
    this.resetBtn.classList.add('show');

    // Hide status
    this.statusLabel.classList.remove('show');

    this.isAnimating = false;
};

/**
 * Animate Pac-Man eating the text
 */
EnhancedInput.prototype.animatePacManEating = function (duration) {
    return new Promise((resolve) => {
        const pacman = this.pacmanContainer;
        const progressBar = this.progressBar;
        const charCount = this.charSpans.length;

        // Show Pac-Man
        pacman.classList.add('animating');

        // Set animation duration
        pacman.style.setProperty('--eat-duration', `${duration}s`);

        // Add moving class
        pacman.classList.add('pacman-moving');
        pacman.style.animationDuration = `${duration}s`;

        // Progress bar
        progressBar.classList.add('animating');
        progressBar.style.transition = `width ${duration}s linear`;
        requestAnimationFrame(() => {
            progressBar.style.width = '100%';
        });

        // Character eating and dot eating timing
        const eatStartTime = performance.now();
        const dotsCount = this.dots ? this.dots.length : 0;

        const eatFrame = () => {
            const elapsed = (performance.now() - eatStartTime) / 1000;
            const progress = Math.min(1, elapsed / duration);

            // Eat characters
            const charsToEat = Math.floor(progress * charCount);
            for (let i = 0; i < charsToEat && i < charCount; i++) {
                if (this.charSpans[i] && !this.charSpans[i].classList.contains('eaten')) {
                    this.charSpans[i].classList.add('eaten');
                }
            }

            // Eat dots
            const dotsToEat = Math.floor(progress * dotsCount);
            for (let i = 0; i < dotsToEat && i < dotsCount; i++) {
                if (this.dots[i] && !this.dots[i].classList.contains('eaten')) {
                    this.dots[i].classList.add('eaten');
                    this.createWakaEffect(this.dots[i]);
                }
            }

            if (progress < 1) {
                requestAnimationFrame(eatFrame);
            } else {
                // Ensure everything is eaten
                this.charSpans.forEach(span => span.classList.add('eaten'));
                this.dots.forEach(dot => dot.classList.add('eaten'));
                resolve();
            }
        };

        requestAnimationFrame(eatFrame);
    });
};

/**
 * Create "WAKA" text effect when eating dots
 */
EnhancedInput.prototype.createWakaEffect = function (dotElement) {
    // Occasionally show "WAKA" text (20% chance)
    if (Math.random() > 0.8) {
        const waka = document.createElement('div');
        waka.className = 'waka-text';
        waka.textContent = 'WAKA';
        waka.style.left = dotElement.style.left;
        this.dotsContainer.appendChild(waka);

        requestAnimationFrame(() => {
            waka.classList.add('show');
        });

        setTimeout(() => waka.remove(), 500);
    }
};

/**
 * Reveal the enhanced text
 */
EnhancedInput.prototype.revealEnhancedText = function (useTypewriter = false) {
    return new Promise((resolve) => {
        this.resultContainer.textContent = '';
        this.resultContainer.classList.remove('show');

        if (useTypewriter) {
            // Typewriter effect
            this.resultContainer.classList.add('typewriter');
            const chars = this.enhancedText.split('');

            chars.forEach((char, index) => {
                setTimeout(() => {
                    if (char === '\n') {
                        this.resultContainer.appendChild(document.createElement('br'));
                    } else {
                        const span = document.createElement('span');
                        span.className = 'typewriter-char';
                        span.textContent = char;
                        span.style.animationDelay = `${index * 0.02}s`;
                        this.resultContainer.appendChild(span);
                    }

                    if (index === chars.length - 1) {
                        setTimeout(resolve, 100);
                    }
                }, index * 20);
            });
        } else {
            // Fade in effect
            this.resultContainer.classList.remove('typewriter');
            this.resultContainer.textContent = this.enhancedText;

            // Trigger reflow
            void this.resultContainer.offsetWidth;

            this.resultContainer.classList.add('show');

            setTimeout(resolve, 500);
        }
    });
};
