package service

import (
	"context"
	"fmt"
	"log"
	"strings"
	"sync"
	"time"

	"screen-memory-assistant/internal/capture"
	"screen-memory-assistant/internal/config"
	"screen-memory-assistant/internal/llm"
	"screen-memory-assistant/internal/memory"
)

// Service orchestrates the screen capture and memory pipeline
type Service struct {
	config   *config.Config
	capturer *capture.Capturer
	llm      *llm.Client
	memory   *memory.Store

	running   bool
	stopChan  chan struct{}
	wg        sync.WaitGroup
	lastState string
	
	// Rate limiting for LLM vision requests
	visionSem chan struct{}
}

// New creates a new service instance
func New(cfg *config.Config) (*Service, error) {
	capturer := capture.New(&cfg.Capture)
	llmClient := llm.NewClient(&cfg.LLM)
	memoryStore := memory.NewStore(&cfg.Memory)

	return &Service{
		config:    cfg,
		capturer:  capturer,
		llm:       llmClient,
		memory:    memoryStore,
		stopChan:  make(chan struct{}),
		visionSem: make(chan struct{}, 1), // Only 1 vision request at a time
	}, nil
}

// Run starts the service
func (s *Service) Run(ctx context.Context) error {
	// Health checks
	if err := s.checkDependencies(ctx); err != nil {
		return fmt.Errorf("dependency check failed: %w", err)
	}

	log.Println("Screen Memory Assistant started")
	log.Printf("Capture interval: %ds", s.config.Capture.IntervalSeconds)
	log.Printf("Platform: %s", capture.GetPlatform())

	s.running = true

	// Start capture loop if enabled
	if s.config.Capture.Enabled {
		s.wg.Add(1)
		go s.captureLoop(ctx)
	}

	// Wait for shutdown
	<-ctx.Done()
	s.stop()

	return nil
}

// captureLoop handles periodic screen capture
func (s *Service) captureLoop(ctx context.Context) {
	defer s.wg.Done()

	ticker := time.NewTicker(time.Duration(s.config.Capture.IntervalSeconds) * time.Second)
	defer ticker.Stop()

	// Do first capture immediately
	s.processCapture(ctx)

	for {
		select {
		case <-ticker.C:
			s.processCapture(ctx)
		case <-s.stopChan:
			return
		case <-ctx.Done():
			return
		}
	}
}

// processCapture captures screen and optionally processes with LLM
func (s *Service) processCapture(ctx context.Context) {
	cap, err := s.capturer.CapturePrimary()
	if err != nil {
		if s.config.App.Verbose {
			log.Printf("Capture failed: %v", err)
		}
		return
	}

	if s.config.App.Verbose {
		log.Printf("Captured display %d (%d bytes)", cap.DisplayNum, len(cap.Compressed))
	}

	if !s.config.App.ProcessOnCapture {
		return
	}

	// Process with LLM in background
	s.wg.Add(1)
	go func() {
		defer s.wg.Done()
		s.analyzeAndStore(ctx, cap)
	}()
}

// analyzeAndStore sends to LLM and stores in memory
func (s *Service) analyzeAndStore(ctx context.Context, cap *capture.Capture) {
	// Rate limit: only 1 vision request at a time to prevent LM Studio overload
	select {
	case s.visionSem <- struct{}{}:
		defer func() { <-s.visionSem }()
	case <-ctx.Done():
		return
	}

	// Get recent memories for context
	memories, err := s.memory.GetRecent(s.config.App.MemoryWindow)
	if err != nil && s.config.App.Verbose {
		log.Printf("Failed to get memories: %v", err)
	}

	// Build context from previous memories
	var contextBuilder strings.Builder
	for _, m := range memories {
		contextBuilder.WriteString(m.Content)
		contextBuilder.WriteString(" ")
	}

	// Analyze with LLM
	result, err := s.llm.AnalyzeScreen(ctx, cap.Compressed, contextBuilder.String())
	if err != nil {
		if s.config.App.Verbose {
			log.Printf("LLM analysis failed: %v", err)
		}
		return
	}

	// Create memory content
	memoryContent := fmt.Sprintf("%s | Context: %s | Intent: %s",
		result.Summary, result.Context, result.UserIntent)

	// Store in Mem0
	metadata := memory.Metadata{
		Timestamp:   cap.Timestamp.Format(time.RFC3339),
		Context:     result.Context,
		Activities:  result.Activities,
		KeyElements: result.KeyElements,
		UserIntent:  result.UserIntent,
		DisplayNum:  cap.DisplayNum,
	}

	_, err = s.memory.Add(memoryContent, metadata)
	if err != nil {
		if s.config.App.Verbose {
			log.Printf("Failed to store memory: %v", err)
		}
		return
	}

	s.lastState = result.Summary
	if s.config.App.Verbose {
		log.Printf("Memory stored: %s", result.Summary)
	}
}

// Chat allows conversational interaction with context
func (s *Service) Chat(ctx context.Context, message string) (string, error) {
	// Get relevant memories
	results, err := s.memory.Search(message, s.config.App.MemoryWindow)
	if err != nil {
		log.Printf("[DEBUG] Memory search failed: %v", err)
	} else {
		log.Printf("[DEBUG] Memory search returned %d results", len(results))
		for i, r := range results {
			log.Printf("[DEBUG] Result %d: ID=%s, ContentLength=%d, ContentPreview=%.50s", i+1, r.Memory.ID, len(r.Memory.Content), r.Memory.Content)
		}
	}

	// Extract memory contents
	var memories []string
	for i, r := range results {
		log.Printf("[DEBUG] Memory %d: ID=%s, ContentLength=%d, ContentPreview=%.50s", i+1, r.Memory.ID, len(r.Memory.Content), r.Memory.Content)
		memories = append(memories, r.Memory.Content)
	}
	log.Printf("[DEBUG] Extracted %d memories for prompt", len(memories))

	// Generate response
	return s.llm.GenerateResponse(ctx, message, memories)
}

// GetStatus returns current service status
func (s *Service) GetStatus() map[string]interface{} {
	return map[string]interface{}{
		"running":    s.running,
		"platform":   capture.GetPlatform(),
		"last_state": s.lastState,
		"config": map[string]interface{}{
			"capture_interval": s.config.Capture.IntervalSeconds,
			"capture_enabled":  s.config.Capture.Enabled,
		},
	}
}

// checkDependencies verifies all services are available
func (s *Service) checkDependencies(ctx context.Context) error {
	// Check LLM
	if err := s.llm.CheckHealth(ctx); err != nil {
		return fmt.Errorf("LLM not available at %s: %w", s.config.LLM.BaseURL, err)
	}
	log.Println("✓ LLM connected")

	// Check Mem0
	if err := s.memory.CheckHealth(); err != nil {
		return fmt.Errorf("Mem0 not available at %s: %w", s.config.Memory.BaseURL, err)
	}
	log.Println("✓ Mem0 connected")

	return nil
}

// stop gracefully shuts down the service
func (s *Service) stop() {
	s.running = false
	close(s.stopChan)
	s.wg.Wait()
	log.Println("Service stopped")
}
