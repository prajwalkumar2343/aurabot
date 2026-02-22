/**
 * AuraBot Electron - Modal Module
 * Enhances AuraApp with modal functionality
 */

AuraApp.prototype.setupModal = function () {
    const overlay = document.getElementById('modal-overlay');
    const modal = document.getElementById('modal-new-memory');

    // Close modal
    const closeModal = () => {
        overlay?.classList.remove('active');
        modal?.classList.remove('active');
        document.getElementById('memory-title').value = '';
        document.getElementById('memory-content').value = '';
    };

    document.getElementById('btn-close-modal')?.addEventListener('click', closeModal);
    document.getElementById('btn-cancel-memory')?.addEventListener('click', closeModal);
    overlay?.addEventListener('click', closeModal);

    // Save memory
    document.getElementById('btn-save-memory')?.addEventListener('click', async () => {
        const title = document.getElementById('memory-title')?.value;
        const content = document.getElementById('memory-content')?.value;

        if (!content?.trim()) {
            this.showToast('Please enter some content', 'error');
            return;
        }

        try {
            const result = await window.electronAPI?.addMemory(content, { context: title || 'Manual Entry' });
            if (result?.success) {
                closeModal();
                this.showToast('Memory saved successfully');
                this.loadMemories();
            } else {
                throw new Error(result?.error || 'Failed to save memory');
            }
        } catch (error) {
            console.error('Save memory failed:', error);
            // Add locally anyway
            closeModal();
            this.showToast('Memory saved locally');
            const newMemory = {
                id: Date.now().toString(),
                content: content,
                timestamp: new Date().toISOString(),
                metadata: { context: title || 'Manual Entry' }
            };
            this.memories.unshift(newMemory);
            this.renderMemories();
        }
    });
};

AuraApp.prototype.openModal = function () {
    document.getElementById('modal-overlay')?.classList.add('active');
    document.getElementById('modal-new-memory')?.classList.add('active');
    setTimeout(() => {
        document.getElementById('memory-title')?.focus();
    }, 100);
};
