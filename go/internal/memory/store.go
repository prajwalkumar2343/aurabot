package memory

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"screen-memory-assistant/internal/config"
)

// Memory represents a stored memory
type Memory struct {
	ID        string    `json:"id"`
	Content   string    `json:"content"`
	UserID    string    `json:"user_id"`
	Metadata  Metadata  `json:"metadata"`
	CreatedAt time.Time `json:"created_at"`
}

// Metadata contains additional context about the memory
type Metadata struct {
	Timestamp   string   `json:"timestamp"`
	Context     string   `json:"context"`
	Activities  []string `json:"activities"`
	KeyElements []string `json:"key_elements"`
	UserIntent  string   `json:"user_intent"`
	DisplayNum  int      `json:"display_num"`
}

// SearchResult represents a memory search result
type SearchResult struct {
	Memory    Memory  `json:"memory"`
	Score     float64 `json:"score"`
	Distance  float64 `json:"distance"`
}

// parseTime parses an ISO8601 time string, returning zero time on error
func parseTime(s string) time.Time {
	t, _ := time.Parse(time.RFC3339, s)
	return t
}

// Store handles Mem0 operations
type Store struct {
	config     *config.MemoryConfig
	httpClient *http.Client
}

// NewStore creates a new memory store
func NewStore(cfg *config.MemoryConfig) *Store {
	return &Store{
		config: cfg,
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// Add stores a new memory
func (s *Store) Add(content string, metadata Metadata) (*Memory, error) {
	url := fmt.Sprintf("%s/v1/memories/", s.config.BaseURL)

	memory := &Memory{
		Content:   content,
		UserID:    s.config.UserID,
		Metadata:  metadata,
		CreatedAt: time.Now(),
	}

	payload := map[string]interface{}{
		"messages": []map[string]string{
			{
				"role":    "user",
				"content": content,
			},
		},
		"user_id":   s.config.UserID,
		"metadata":  metadata,
		"agent_id":  s.config.CollectionName,
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("marshaling memory: %w", err)
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	if s.config.APIKey != "" {
		req.Header.Set("Authorization", "Bearer "+s.config.APIKey)
	}

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("sending request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		return nil, fmt.Errorf("unexpected status: %d", resp.StatusCode)
	}

	return memory, nil
}

// Search retrieves relevant memories based on query
func (s *Store) Search(query string, limit int) ([]SearchResult, error) {
	url := fmt.Sprintf("%s/v1/memories/search/", s.config.BaseURL)

	if limit <= 0 {
		limit = 10
	}

	payload := map[string]interface{}{
		"query":     query,
		"user_id":   s.config.UserID,
		"agent_id":  s.config.CollectionName,
		"limit":     limit,
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("marshaling search: %w", err)
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	if s.config.APIKey != "" {
		req.Header.Set("Authorization", "Bearer "+s.config.APIKey)
	}

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("sending request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status: %d", resp.StatusCode)
	}

	var result struct {
		Results []struct {
			Memory   string    `json:"memory"`
			ID       string    `json:"id"`
			UserID   string    `json:"user_id"`
			Score    float64   `json:"score"`
			Distance float64   `json:"distance"`
			Metadata Metadata  `json:"metadata"`
			CreatedAt string   `json:"created_at"`
		} `json:"results"`
	}
	
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("decoding response: %w", err)
	}
	
	var searchResults []SearchResult
	for _, r := range result.Results {
		searchResults = append(searchResults, SearchResult{
			Memory: Memory{
				ID:        r.ID,
				Content:   r.Memory,
				UserID:    r.UserID,
				Metadata:  r.Metadata,
				CreatedAt: parseTime(r.CreatedAt),
			},
			Score:    r.Score,
			Distance: r.Distance,
		})
	}

	return searchResults, nil
}

// GetRecent retrieves the most recent memories
func (s *Store) GetRecent(limit int) ([]Memory, error) {
	url := fmt.Sprintf("%s/v1/memories/?user_id=%s&agent_id=%s&limit=%d",
		s.config.BaseURL, s.config.UserID, s.config.CollectionName, limit)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}

	if s.config.APIKey != "" {
		req.Header.Set("Authorization", "Bearer "+s.config.APIKey)
	}

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("sending request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status: %d", resp.StatusCode)
	}

	var memories []Memory
	if err := json.NewDecoder(resp.Body).Decode(&memories); err != nil {
		return nil, fmt.Errorf("decoding response: %w", err)
	}

	return memories, nil
}

// Delete removes a memory by ID
func (s *Store) Delete(memoryID string) error {
	url := fmt.Sprintf("%s/v1/memories/%s/", s.config.BaseURL, memoryID)

	req, err := http.NewRequest("DELETE", url, nil)
	if err != nil {
		return fmt.Errorf("creating request: %w", err)
	}

	if s.config.APIKey != "" {
		req.Header.Set("Authorization", "Bearer "+s.config.APIKey)
	}

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("sending request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
		return fmt.Errorf("unexpected status: %d", resp.StatusCode)
	}

	return nil
}

// CheckHealth verifies the Mem0 endpoint is available
func (s *Store) CheckHealth() error {
	url := fmt.Sprintf("%s/health", s.config.BaseURL)

	resp, err := s.httpClient.Get(url)
	if err != nil {
		return fmt.Errorf("health check failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("health check returned: %d", resp.StatusCode)
	}

	return nil
}
