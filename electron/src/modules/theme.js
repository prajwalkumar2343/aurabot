// ========================================
// Theme Module — Light / Dark Mode
// ========================================

(function () {
    'use strict';

    const STORAGE_KEY = 'aurabot-theme';

    function initTheme() {
        const stored = localStorage.getItem(STORAGE_KEY);
        const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
        const isDark = stored === 'dark' || (!stored && prefersDark);

        applyTheme(isDark);

        // Sidebar toggle
        const sidebarToggle = document.getElementById('theme-toggle');
        if (sidebarToggle) {
            sidebarToggle.checked = isDark;
            sidebarToggle.addEventListener('change', () => {
                toggleTheme();
            });
        }

        // Settings toggle (synced)
        const settingsToggle = document.getElementById('setting-dark-mode');
        if (settingsToggle) {
            settingsToggle.checked = isDark;
            settingsToggle.addEventListener('change', () => {
                toggleTheme();
            });
        }
    }

    function applyTheme(isDark) {
        // Add transition class briefly for smooth switch
        document.documentElement.classList.add('theme-transitioning');

        if (isDark) {
            document.documentElement.setAttribute('data-theme', 'dark');
        } else {
            document.documentElement.removeAttribute('data-theme');
        }

        localStorage.setItem(STORAGE_KEY, isDark ? 'dark' : 'light');

        // Sync toggles
        const sidebarToggle = document.getElementById('theme-toggle');
        const settingsToggle = document.getElementById('setting-dark-mode');
        if (sidebarToggle) sidebarToggle.checked = isDark;
        if (settingsToggle) settingsToggle.checked = isDark;

        // Remove transition class after animation
        setTimeout(() => {
            document.documentElement.classList.remove('theme-transitioning');
        }, 450);
    }

    function toggleTheme() {
        const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
        applyTheme(!isDark);
    }

    // Initialize on DOM ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initTheme);
    } else {
        initTheme();
    }

    // Expose globally
    window.AuraTheme = { initTheme, toggleTheme, applyTheme };
})();
