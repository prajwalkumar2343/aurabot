package enhancer

import (
	"context"
	"fmt"
	"log"
	"strings"
	"sync"
	"time"

	"screen-memory-assistant/internal/memory"
)

// Enhancer handles prompt enhancement using stored memories
type Enhancer struct {
	memoryStore *memory.Store

	// Stats tracking
	statsMu          sync.RWMutex
	enhancementsMade int
	lastEnhancement  time.Time
}

// EnhancementResult contains the enhanced prompt and metadata
type EnhancementResult struct {
	OriginalPrompt   string
	EnhancedPrompt   string
	MemoriesUsed     []string
	EnhancementType  string // "contextual", "detailed", "minimal"
}

// MemoryInfo represents a simplified memory for the extension
type MemoryInfo struct {
	ID       string    `json:"id"`
	Content  string    `json:"content"`
	Context  string    `json:"context"`
	Score    float64   `json:"score"`
	Date     time.Time `json:"date"`
}

// New creates a new prompt enhancer
func New(memoryStore *memory.Store) *Enhancer {
	return &Enhancer{
		memoryStore: memoryStore,
	}
}

// Enhance takes a prompt and enhances it with relevant memories
func (e *Enhancer) Enhance(ctx context.Context, prompt, pageContext string, maxMemories int) (*EnhancementResult, error) {
	// Search for relevant memories based on the prompt
	results, err := e.memoryStore.Search(prompt, maxMemories)
	if err != nil {
		return nil, fmt.Errorf("memory search failed: %w", err)
	}

	log.Printf("[Enhancer] Found %d relevant memories for prompt", len(results))

	// If no memories found, return original prompt
	if len(results) == 0 {
		return &EnhancementResult{
			OriginalPrompt:  prompt,
			EnhancedPrompt:  prompt,
			MemoriesUsed:    []string{},
			EnhancementType: "none",
		}, nil
	}

	// Extract memory contents and build contextual enhancement
	var memoriesUsed []string
	var memoryContents []string
	var highRelevanceMemories []string
	var contextualMemories []string

	for _, result := range results {
		memoriesUsed = append(memoriesUsed, result.Memory.Content)
		
		// Categorize memories by relevance score
		if result.Score > 0.85 {
			highRelevanceMemories = append(highRelevanceMemories, result.Memory.Content)
		} else {
			contextualMemories = append(contextualMemories, result.Memory.Content)
		}
		
		// Build formatted memory content with metadata
		content := result.Memory.Content
		if result.Memory.Metadata.Context != "" {
			content = fmt.Sprintf("[%s] %s", result.Memory.Metadata.Context, content)
		}
		memoryContents = append(memoryContents, content)
	}

	// Determine enhancement type based on relevance and context
	enhancementType := e.determineEnhancementType(len(highRelevanceMemories), len(contextualMemories), pageContext)

	// Build enhanced prompt based on enhancement type
	enhancedPrompt := e.buildEnhancedPrompt(prompt, highRelevanceMemories, contextualMemories, memoryContents, enhancementType)

	// Update stats
	e.statsMu.Lock()
	e.enhancementsMade++
	e.lastEnhancement = time.Now()
	e.statsMu.Unlock()

	log.Printf("[Enhancer] Enhanced prompt using %d memories (type: %s)", len(memoriesUsed), enhancementType)

	return &EnhancementResult{
		OriginalPrompt:  prompt,
		EnhancedPrompt:  enhancedPrompt,
		MemoriesUsed:    memoriesUsed,
		EnhancementType: enhancementType,
	}, nil
}

// determineEnhancementType decides how to enhance the prompt
func (e *Enhancer) determineEnhancementType(highRelevance, contextual int, pageContext string) string {
	if highRelevance >= 2 {
		return "contextual"
	}
	if highRelevance == 1 && contextual >= 2 {
		return "detailed"
	}
	if highRelevance == 0 && contextual > 0 {
		return "minimal"
	}
	return "contextual"
}

// buildEnhancedPrompt creates the enhanced prompt based on type
func (e *Enhancer) buildEnhancedPrompt(
	originalPrompt string,
	highRelevanceMemories []string,
	contextualMemories []string,
	allMemories []string,
	enhancementType string,
) string {
	var builder strings.Builder

	// Always include the original prompt
	builder.WriteString(originalPrompt)

	switch enhancementType {
	case "contextual":
		// Rich context enhancement for highly relevant scenarios
		builder.WriteString("\n\n[Context from previous sessions]\n")
		builder.WriteString("Based on my previous activities and context:\n")
		
		for i, memory := range highRelevanceMemories {
			builder.WriteString(fmt.Sprintf("- %s\n", memory))
			if i >= 2 { // Limit to top 3 high relevance
				break
			}
		}
		
		if len(contextualMemories) > 0 {
			builder.WriteString("\nAdditional context:\n")
			for i, memory := range contextualMemories {
				builder.WriteString(fmt.Sprintf("- %s\n", memory))
				if i >= 1 { // Limit to 2 additional
					break
				}
			}
		}

	case "detailed":
		// Moderate detail enhancement
		builder.WriteString("\n\n[Relevant background]\n")
		for i, memory := range allMemories {
			builder.WriteString(fmt.Sprintf("- %s\n", memory))
			if i >= 3 { // Limit total memories
				break
			}
		}

	case "minimal":
		// Light touch - just add context note
		if len(allMemories) > 0 {
			builder.WriteString("\n\n[Note: Consider previous context: ")
			builder.WriteString(allMemories[0])
			if len(allMemories) > 1 {
				builder.WriteString(" and related activities")
			}
			builder.WriteString("]")
		}
	}

	return builder.String()
}

// SearchMemories performs a memory search and returns simplified results
func (e *Enhancer) SearchMemories(ctx context.Context, query string, limit int) ([]MemoryInfo, error) {
	results, err := e.memoryStore.Search(query, limit)
	if err != nil {
		return nil, err
	}

	var memories []MemoryInfo
	for _, result := range results {
		memories = append(memories, MemoryInfo{
			ID:      result.Memory.ID,
			Content: result.Memory.Content,
			Context: result.Memory.Metadata.Context,
			Score:   result.Score,
			Date:    result.Memory.CreatedAt,
		})
	}

	return memories, nil
}

// GetRecentMemories returns the most recent memories
func (e *Enhancer) GetRecentMemories(limit int) ([]MemoryInfo, error) {
	memories, err := e.memoryStore.GetRecent(limit)
	if err != nil {
		return nil, err
	}

	var result []MemoryInfo
	for _, m := range memories {
		result = append(result, MemoryInfo{
			ID:      m.ID,
			Content: m.Content,
			Context: m.Metadata.Context,
			Date:    m.CreatedAt,
		})
	}

	return result, nil
}

// Stats contains enhancer statistics
type Stats struct {
	EnhancementsMade int       `json:"enhancements_made"`
	LastEnhancement  time.Time `json:"last_enhancement,omitempty"`
}

// GetStats returns current statistics
func (e *Enhancer) GetStats() Stats {
	e.statsMu.RLock()
	defer e.statsMu.RUnlock()
	return Stats{
		EnhancementsMade: e.enhancementsMade,
		LastEnhancement:  e.lastEnhancement,
	}
}

// QuickEnhance provides a one-line enhancement for simple prompts
func (e *Enhancer) QuickEnhance(ctx context.Context, prompt string) (string, error) {
	result, err := e.Enhance(ctx, prompt, "", 3)
	if err != nil {
		return "", err
	}
	return result.EnhancedPrompt, nil
}
