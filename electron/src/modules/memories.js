/**
 * AuraBot Electron - Memories Module
 * Enhances AuraApp with memory management functionality
 */

AuraApp.prototype.setupMemories = function () {
    // Search functionality
    const searchInput = document.getElementById('memories-search-input');
    const searchBtn = document.getElementById('btn-search');

    const doSearch = async () => {
        const query = searchInput?.value?.trim();
        if (query) {
            this.showToast(`Searching for "${query}"...`);
            try {
                const result = await window.electronAPI?.searchMemories(query, 20);
                if (result?.success) {
                    this.memories = result.data || [];
                    this.renderMemories();
                }
            } catch (error) {
                console.error('Search failed:', error);
            }
        } else {
            this.loadMemories();
        }
    };

    searchBtn?.addEventListener('click', doSearch);
    searchInput?.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') doSearch();
    });
};

AuraApp.prototype.loadMemories = async function () {
    try {
        const result = await window.electronAPI?.getMemories(20);
        if (result?.success) {
            this.memories = result.data || [];
        } else {
            // Demo data
            this.loadDemoMemories();
        }
    } catch (error) {
        console.error('Failed to load memories:', error);
        this.loadDemoMemories();
    }
    this.renderMemories();
};

AuraApp.prototype.loadDemoMemories = function () {
    this.memories = [
        {
            id: '1',
            content: 'The key insight from today\'s meeting is that we need to pivot our approach to focus on the enterprise market rather than SMBs. The data shows that enterprise customers have a 3x higher LTV and significantly lower churn rates.',
            timestamp: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
            metadata: { context: 'Product Strategy Notes', aiEnhanced: true }
        },
        {
            id: '2',
            content: 'Good design is actually a lot harder to notice than poor design, in part because good designs fit our needs so well that the design is invisible. Three key principles: Visibility, Feedback, and Constraints.',
            timestamp: new Date(Date.now() - 4 * 60 * 60 * 1000).toISOString(),
            metadata: { context: 'Design of Everyday Things' }
        },
        {
            id: '3',
            content: 'const useAsync = (asyncFunction, immediate = true) => { const [status, setStatus] = useState("idle"); const [value, setValue] = useState(null); const [error, setError] = useState(null); }',
            timestamp: new Date(Date.now() - 8 * 60 * 60 * 1000).toISOString(),
            metadata: { context: 'React Hook Pattern' }
        },
        {
            id: '4',
            content: 'Meeting with the team about Q4 planning. Key decisions: 1) Launch new feature by Nov 15, 2) Increase marketing budget by 40%, 3) Hire 3 new engineers.',
            timestamp: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(),
            metadata: { context: 'Q4 Planning Meeting' }
        }
    ];
};

AuraApp.prototype.renderMemories = function (memoriesToRender = this.memories) {
    this.updateStats(memoriesToRender.length);

    const dashboardList = document.getElementById('dashboard-memories');
    const allList = document.getElementById('all-memories-list');

    const html = memoriesToRender.map((m, i) => this.createMemoryCard(m, i)).join('');

    if (dashboardList) {
        if (memoriesToRender.length === 0) {
            dashboardList.innerHTML = `
                <div class="empty-state">
                    <div class="empty-icon">🧠</div>
                    <h3>No memories yet</h3>
                    <p>Start screen capture to begin recording your activities</p>
                    <button class="btn-primary" id="btn-add-memory-empty">Add Memory</button>
                </div>
            `;
            // Add listener after injection
            document.getElementById('btn-add-memory-empty')?.addEventListener('click', () => {
                this.openModal();
            });
        } else {
            dashboardList.innerHTML = html;
        }
    }

    if (allList) {
        allList.innerHTML = html || `
            <div class="empty-state">
                <div class="empty-icon">🔍</div>
                <h3>No memories found</h3>
                <p>Try a different search term</p>
            </div>
        `;
    }

    // Setup card expansion
    document.querySelectorAll('.memory-card').forEach(card => {
        card.addEventListener('click', (e) => {
            if (e.target.closest('.memory-actions') || e.target.closest('.btn-text')) return;
            this.toggleCardExpansion(card);
        });
    });
};

AuraApp.prototype.createMemoryCard = function (memory, index) {
    const date = new Date(memory.timestamp);
    const timeStr = date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    const isToday = new Date().toDateString() === date.toDateString();
    const displayTime = isToday ? `Today, ${timeStr}` : date.toLocaleDateString();

    const aiBadge = memory.metadata?.aiEnhanced ? '<span class="tag">AI Enhanced</span>' : '';

    return `
        <article class="memory-card" data-id="${memory.id}" style="animation: messageIn 0.3s ease ${index * 0.05}s both;">
            <div class="memory-header">
                <div class="memory-icon">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M12 18v-5.25m0 0a6.01 6.01 0 001.5-.189m-1.5.189a6.01 6.01 0 01-1.5-.189m3.75 7.478a12.06 12.06 0 01-4.5 0m3.75 2.383a14.406 14.406 0 01-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 10-7.517 0c.85.493 1.509 1.333 1.509 2.316V18"/>
                    </svg>
                </div>
                <div class="memory-meta">
                    <div class="memory-title">${this.escapeHtml(memory.metadata?.context || 'Memory')}</div>
                    <div class="memory-tags">${aiBadge}</div>
                </div>
            </div>
            <div class="memory-preview">${this.escapeHtml(memory.content)}</div>
            <div class="memory-full hidden">
                ${memory.metadata?.aiEnhanced ? `
                    <div class="ai-summary-box">
                        <div class="ai-summary-label">AI Summary</div>
                        <p>Strategic pivot recommended from SMB to Enterprise market. Key metrics: 3x LTV, lower churn.</p>
                    </div>
                ` : ''}
                <div class="memory-actions">
                    <button class="btn-text">Copy</button>
                    <button class="btn-text">Share</button>
                    <button class="btn-text primary">AI Enhance</button>
                </div>
            </div>
            <div class="memory-footer">
                <span>${displayTime}</span>
                <span>•</span>
                <span class="category-tag">#${memory.metadata?.context?.toLowerCase().replace(/\s+/g, '-') || 'general'}</span>
            </div>
        </article>
    `;
};

AuraApp.prototype.toggleCardExpansion = function (card) {
    const id = card.dataset.id;
    const full = card.querySelector('.memory-full');
    if (!full) return;

    const isExpanded = this.expandedCards.has(id);

    if (isExpanded) {
        full.classList.add('hidden');
        this.expandedCards.delete(id);
        card.classList.remove('expanded');
    } else {
        full.classList.remove('hidden');
        this.expandedCards.add(id);
        card.classList.add('expanded');
    }
};

AuraApp.prototype.updateStats = function (count) {
    const statEl = document.getElementById('stat-memories');
    if (statEl) statEl.textContent = count;
};
