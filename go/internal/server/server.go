package server

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"screen-memory-assistant/internal/enhancer"
)

// Server handles HTTP requests from browser extension
type Server struct {
	enhancer   *enhancer.Enhancer
	httpServer *http.Server
	port       int
}

// New creates a new HTTP server
func New(enhancer *enhancer.Enhancer, port int) *Server {
	if port <= 0 {
		port = 7345 // Default port (AURA)
	}

	return &Server{
		enhancer: enhancer,
		port:     port,
	}
}

// Start begins listening for requests
func (s *Server) Start() error {
	mux := http.NewServeMux()

	// CORS middleware
	handler := corsMiddleware(mux)

	// Routes
	mux.HandleFunc("/health", s.handleHealth)
	mux.HandleFunc("/api/enhance", s.handleEnhance)
	mux.HandleFunc("/api/memories/search", s.handleMemorySearch)
	mux.HandleFunc("/api/status", s.handleStatus)

	s.httpServer = &http.Server{
		Addr:    fmt.Sprintf(":%d", s.port),
		Handler: handler,
	}

	log.Printf("Extension server starting on port %d", s.port)

	go func() {
		if err := s.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Printf("Extension server error: %v", err)
		}
	}()

	return nil
}

// Stop gracefully shuts down the server
func (s *Server) Stop(ctx context.Context) error {
	if s.httpServer == nil {
		return nil
	}
	return s.httpServer.Shutdown(ctx)
}

// allowedOrigins defines the list of permitted CORS origins
var allowedOrigins = []string{
	"http://localhost:3000",    // React dev server
	"http://localhost:8080",    // Swift app
	"http://localhost:7345",    // Extension API
	"chrome-extension://",      // Chrome extension (prefix match)
	"https://chat.openai.com",  // ChatGPT
	"https://chatgpt.com",
	"https://claude.ai",
	"https://gemini.google.com",
	"https://perplexity.ai",
}

// isAllowedOrigin checks if the request origin is in the allowed list
func isAllowedOrigin(origin string) bool {
	if origin == "" {
		return true // Same-origin request
	}
	for _, allowed := range allowedOrigins {
		if allowed == origin {
			return true
		}
		// Check for prefix match (for chrome-extension://*)
		if strings.HasSuffix(allowed, "://") && strings.HasPrefix(origin, allowed) {
			return true
		}
	}
	return false
}

// corsMiddleware adds CORS headers for browser extension requests
func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		
		// Only set CORS headers for allowed origins
		if isAllowedOrigin(origin) {
			if origin == "" {
				origin = "http://localhost:3000"
			}
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
			w.Header().Set("Access-Control-Allow-Credentials", "true")
		}

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// handleHealth returns server status
func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	response := map[string]interface{}{
		"status":    "ok",
		"service":   "aurabot-extension-api",
		"timestamp": time.Now().Unix(),
	}

	writeJSON(w, response)
}

// handleEnhanceRequest represents a prompt enhancement request
type handleEnhanceRequest struct {
	Prompt      string `json:"prompt"`
	Context     string `json:"context,omitempty"`     // Optional page context (e.g., "chatgpt", "claude")
	MaxMemories int    `json:"max_memories,omitempty"` // Max memories to include
}

// handleEnhanceResponse represents the enhancement response
type handleEnhanceResponse struct {
	OriginalPrompt   string   `json:"original_prompt"`
	EnhancedPrompt   string   `json:"enhanced_prompt"`
	MemoriesUsed     []string `json:"memories_used"`
	MemoryCount      int      `json:"memory_count"`
	EnhancementType  string   `json:"enhancement_type"`
}

// handleEnhance enhances a prompt with relevant memories
func (s *Server) handleEnhance(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req handleEnhanceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, fmt.Sprintf("Invalid JSON: %v", err), http.StatusBadRequest)
		return
	}

	if req.Prompt == "" {
		http.Error(w, "Prompt is required", http.StatusBadRequest)
		return
	}

	if req.MaxMemories <= 0 {
		req.MaxMemories = 5
	}

	// Enhance the prompt
	result, err := s.enhancer.Enhance(r.Context(), req.Prompt, req.Context, req.MaxMemories)
	if err != nil {
		log.Printf("Enhancement failed: %v", err)
		http.Error(w, fmt.Sprintf("Enhancement failed: %v", err), http.StatusInternalServerError)
		return
	}

	response := handleEnhanceResponse{
		OriginalPrompt:  req.Prompt,
		EnhancedPrompt:  result.EnhancedPrompt,
		MemoriesUsed:    result.MemoriesUsed,
		MemoryCount:     len(result.MemoriesUsed),
		EnhancementType: result.EnhancementType,
	}

	writeJSON(w, response)
}

// handleMemorySearch searches memories without enhancing
func (s *Server) handleMemorySearch(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	query := r.URL.Query().Get("q")
	if query == "" {
		http.Error(w, "Query parameter 'q' is required", http.StatusBadRequest)
		return
	}

	limitStr := r.URL.Query().Get("limit")
	limit := 5
	if limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 {
			limit = l
		}
	}

	memories, err := s.enhancer.SearchMemories(r.Context(), query, limit)
	if err != nil {
		log.Printf("Memory search failed: %v", err)
		http.Error(w, fmt.Sprintf("Search failed: %v", err), http.StatusInternalServerError)
		return
	}

	writeJSON(w, map[string]interface{}{
		"query":    query,
		"memories": memories,
		"count":    len(memories),
	})
}

// handleStatus returns the current service status
func (s *Server) handleStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	stats := s.enhancer.GetStats()
	writeJSON(w, map[string]interface{}{
		"status":  "running",
		"port":    s.port,
		"stats":   stats,
	})
}

// writeJSON writes a JSON response
func writeJSON(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}
