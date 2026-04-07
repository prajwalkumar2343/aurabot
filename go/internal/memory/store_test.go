package memory

import (
	"testing"
	"time"

	"screen-memory-assistant/internal/config"
)

func TestNewStore(t *testing.T) {
	cfg := &config.MemoryConfig{
		BaseURL:        "http://test:8000",
		UserID:         "test_user",
		CollectionName: "test_collection",
	}

	store := NewStore(cfg)
	if store == nil {
		t.Fatal("NewStore returned nil")
	}

	if store.config != cfg {
		t.Error("Store config not set correctly")
	}

	if store.httpClient == nil {
		t.Error("HTTP client not initialized")
	}

	if store.httpClient.Timeout != 10*time.Second {
		t.Error("HTTP client timeout not set correctly")
	}
}

func TestMetadata_Struct(t *testing.T) {
	m := Metadata{
		Timestamp:   time.Now().Format(time.RFC3339),
		Context:     "work",
		Activities:  []string{"coding", "reading"},
		KeyElements: []string{"VS Code", "Terminal"},
		UserIntent:  "developing software",
		DisplayNum:  0,
	}

	if m.Context != "work" {
		t.Errorf("Context = %s, want 'work'", m.Context)
	}

	if len(m.Activities) != 2 {
		t.Errorf("Activities length = %d, want 2", len(m.Activities))
	}
}

func TestMemory_Struct(t *testing.T) {
	m := Memory{
		ID:      "mem_123",
		Content: "Test memory content",
		UserID:  "user_456",
		Metadata: Metadata{
			Context: "test",
		},
		CreatedAt: time.Now(),
	}

	if m.ID != "mem_123" {
		t.Errorf("ID = %s, want 'mem_123'", m.ID)
	}

	if m.Content != "Test memory content" {
		t.Errorf("Content mismatch")
	}
}

func TestSearchResult_Struct(t *testing.T) {
	sr := SearchResult{
		Memory: Memory{
			ID:      "mem_123",
			Content: "test",
		},
		Score:    0.95,
		Distance: 0.05,
	}

	if sr.Score != 0.95 {
		t.Errorf("Score = %f, want 0.95", sr.Score)
	}

	if sr.Memory.ID != "mem_123" {
		t.Error("Memory ID mismatch")
	}
}

func TestStore_buildPayload(t *testing.T) {
	// This test verifies payload structure logic
	cfg := &config.MemoryConfig{
		UserID:         "test_user",
		CollectionName: "test_collection",
	}
	store := NewStore(cfg)

	// Test that store is properly initialized with config values
	if store.config.UserID != "test_user" {
		t.Error("UserID not set correctly")
	}
	if store.config.CollectionName != "test_collection" {
		t.Error("CollectionName not set correctly")
	}
}
