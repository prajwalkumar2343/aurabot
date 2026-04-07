# EnhancedInput Component - Usage Guide

## Overview
A reusable input component with Pac-Man "eating" animation for text enhancement.

## Basic Usage

### 1. Include Files
```html
<link rel="stylesheet" href="components/EnhancedInput.css">
<script src="components/EnhancedInput.js"></script>
```

### 2. Create Container
```html
<div id="my-input-container"></div>
```

### 3. Initialize Component
```javascript
const input = new EnhancedInput({
    container: document.getElementById('my-input-container'),
    placeholder: 'Enter text to enhance...',
    onEnhance: async (text) => {
        // Your API call here
        const response = await fetch('/api/enhance', {
            method: 'POST',
            body: JSON.stringify({ prompt: text })
        });
        const data = await response.json();
        return data.enhancedText;
    }
});
```

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `container` | HTMLElement | required | Container element |
| `placeholder` | string | '' | Input placeholder text |
| `onEnhance` | function | null | Async function that returns enhanced text |
| `onChange` | function | null | Callback when input changes |
| `onSubmit` | function | null | Callback on Enter key (Shift+Enter for newline) |

## Methods

### enhanceText(newText, options)
Trigger the Pac-Man animation programmatically.

```javascript
await input.enhanceText('Enhanced text here', {
    baseSpeed: 0.05,      // seconds per character
    minDuration: 0.8,     // minimum animation time
    maxDuration: 3.0,     // maximum animation time
    useTypewriter: false  // use typewriter effect for result
});
```

### getValue()
Get current input value (original or enhanced).

```javascript
const value = input.getValue();
```

### setValue(text)
Set input value.

```javascript
input.setValue('Initial text');
```

### reset()
Reset to initial state.

```javascript
input.reset();
```

### focus()
Focus the input.

```javascript
input.focus();
```

### isEnhancing()
Check if animation is in progress.

```javascript
if (input.isEnhancing()) {
    console.log('Animation in progress...');
}
```

### destroy()
Remove component from DOM.

```javascript
input.destroy();
```

## Animation Options

### Speed Calculation
The animation duration is calculated as:
```
duration = clamp(textLength * baseSpeed, minDuration, maxDuration)
```

For example:
- 10 characters × 0.05s = 0.5s → clamped to 0.8s (min)
- 100 characters × 0.05s = 5s → clamped to 3s (max)
- 40 characters × 0.05s = 2s → used as-is

### Visual Styles

#### Default (Fade In)
Enhanced text fades in smoothly.

```javascript
input.enhanceText('New text', { useTypewriter: false });
```

#### Typewriter Effect
Enhanced text appears character by character.

```javascript
input.enhanceText('New text', { useTypewriter: true });
```

## Advanced Examples

### With Error Handling
```javascript
const input = new EnhancedInput({
    container: document.getElementById('container'),
    onEnhance: async (text) => {
        try {
            const result = await enhanceWithAI(text);
            return result.text;
        } catch (error) {
            console.error('Enhancement failed:', error);
            // Return null to stop animation
            return null;
        }
    }
});
```

### With Loading State
```javascript
const input = new EnhancedInput({
    container: document.getElementById('container'),
    onEnhance: async (text) => {
        showLoadingSpinner();
        try {
            const result = await enhanceWithAI(text);
            return result.text;
        } finally {
            hideLoadingSpinner();
        }
    }
});
```

### Custom Styling
```css
/* Override component styles */
.my-custom-input .enhanced-input {
    border-radius: 8px;
    font-size: 16px;
}

.my-custom-input .pacman-body {
    background: conic-gradient(
        from 0deg,
        #FF6B6B 0deg,    /* Red Pac-Man */
        #FF6B6B 45deg,
        transparent 45deg,
        transparent 135deg,
        #FF6B6B 135deg,
        #FF6B6B 315deg,
        transparent 315deg,
        transparent 360deg
    );
}
```

## Events

The component doesn't dispatch custom events, but you can use callbacks:

```javascript
const input = new EnhancedInput({
    container: container,
    onChange: (text) => {
        console.log('Input changed:', text);
    },
    onSubmit: (text) => {
        console.log('User pressed Enter:', text);
    },
    onEnhance: async (text) => {
        console.log('Enhancing:', text);
        const result = await api.enhance(text);
        console.log('Enhanced:', result);
        return result;
    }
});
```

## Accessibility

The component:
- ✅ Uses semantic HTML (`<textarea>`)
- ✅ Respects `prefers-reduced-motion` (you can add this)
- ✅ Maintains focus states
- ✅ Disables input during animation

To add reduced motion support:
```css
@media (prefers-reduced-motion: reduce) {
    .pacman-container,
    .input-char,
    .enhanced-result {
        animation: none !important;
        transition: none !important;
    }
}
```

## Browser Support

- Chrome/Edge 90+
- Firefox 88+
- Safari 14+
- Electron 28+

Uses:
- CSS `conic-gradient()` for Pac-Man
- CSS `@keyframes` for animations
- `ResizeObserver` (optional, for auto-resize)

## Performance Tips

1. **Limit text length**: Very long texts (>1000 chars) will be capped at 3s animation
2. **Debounce API calls**: If calling enhance on every keystroke, debounce it
3. **Reuse components**: Don't recreate the component unnecessarily

```javascript
// Good: Reuse component
const input = new EnhancedInput({ container, onEnhance });

// Bad: Creating new instance every time
function openModal() {
    new EnhancedInput({ container, onEnhance }); // Don't do this
}
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Pac-Man not appearing | Check that CSS file is loaded |
| Animation too fast/slow | Adjust `baseSpeed` option |
| Input not disabling | Check if `isAnimating` flag is working |
| Text not appearing | Ensure `onEnhance` returns a string |
| Layout issues | Container needs `position: relative` |

## License

MIT - Same as AuraBot project
