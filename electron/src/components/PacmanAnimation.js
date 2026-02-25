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
    
    // Create text eating trail container (shows text being eaten)
    this.trailContainer = document.createElement('div');
    this.trailContainer.className = 'pacman-trail';
    this.wrapper.appendChild(this.trailContainer);
};

/**
 * Create text segments along the path for Pac-Man to eat
 */
EnhancedInput.prototype.createDots = function () {
    this.trailContainer.innerHTML = '';
    const containerWidth = this.wrapper.offsetWidth || 500;
    
    // Create text pieces that will be "eaten" - one per character
    const textLength = this.originalText.length;
    const charsPerSegment = Math.ceil(textLength / 20); // Show ~20 text segments
    
    for (let i = 0; i < this.charSpans.length; i++) {
        const char = this.charSpans[i];
        if (char && !char.classList.contains('eaten')) {
            char.classList.add('eaten');
        }
    }
    
    this.dots = [];
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

    // Prepare characters for eating
    this.createDots();

    // Disable input
    this.textarea.disabled = true;
    this.wrapper.classList.add('disabled');
    this.enhanceBtn.disabled = true;
    this.enhanceBtn.style.opacity = '0';

    // Show status
    this.statusLabel.classList.add('show');

    // Start Pac-Man animation eating the text
    await this.animatePacManEating(duration);

    // Hide Pac-Man instantly
    this.pacmanContainer.classList.remove('animating');
    this.pacmanContainer.style.opacity = '0';

    // Hide text overlay
    this.textOverlay.style.opacity = '0';

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

        // Character eating timing
        const eatStartTime = performance.now();

        const eatFrame = () => {
            const elapsed = (performance.now() - eatStartTime) / 1000;
            const progress = Math.min(1, elapsed / duration);

            // Eat characters as pacman moves across
            const charsToEat = Math.floor(progress * charCount);
            for (let i = 0; i < charsToEat && i < charCount; i++) {
                if (this.charSpans[i] && !this.charSpans[i].classList.contains('eaten')) {
                    this.charSpans[i].classList.add('eaten');
                }
            }

            if (progress < 1) {
                requestAnimationFrame(eatFrame);
            } else {
                // Ensure everything is eaten
                this.charSpans.forEach(span => span.classList.add('eaten'));
                resolve();
            }
        };

        requestAnimationFrame(eatFrame);
    });
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
