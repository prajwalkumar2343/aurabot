package llm

import (
	"testing"

	"screen-memory-assistant/internal/config"
)

func TestNewClient(t *testing.T) {
	cfg := &config.LLMConfig{
		BaseURL:     "http://test:1234/v1",
		Model:       "test-model",
		MaxTokens:   256,
		Temperature: 0.5,
	}

	client := NewClient(cfg)
	if client == nil {
		t.Fatal("NewClient returned nil")
	}

	if client.config != cfg {
		t.Error("Client config not set correctly")
	}
}

func TestParseResponse(t *testing.T) {
	client := NewClient(&config.LLMConfig{})

	tests := []struct {
		name     string
		input    string
		expected string // partial check
	}{
		{
			name:     "short response",
			input:    "Testing the screen",
			expected: "Testing the screen",
		},
		{
			name:     "long response truncated",
			input:    string(make([]byte, 600)), // 600 char string
			expected: "...",
		},
		{
			name:     "empty response",
			input:    "",
			expected: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := client.parseResponse(tt.input)

			if result.Context != "unknown" {
				t.Errorf("Context = %s, want 'unknown'", result.Context)
			}
			if result.UserIntent != "unknown" {
				t.Errorf("UserIntent = %s, want 'unknown'", result.UserIntent)
			}
			if result.Activities == nil {
				t.Error("Activities is nil, want empty slice")
			}
		})
	}
}

func TestParseResponse_Truncation(t *testing.T) {
	client := NewClient(&config.LLMConfig{})

	longText := ""
	for i := 0; i < 600; i++ {
		longText += "a"
	}

	result := client.parseResponse(longText)

	if len(result.Summary) > 504 { // 500 + "..."
		t.Errorf("Summary not truncated properly, length = %d", len(result.Summary))
	}

	if result.Summary[len(result.Summary)-3:] != "..." {
		t.Error("Summary doesn't end with '...'")
	}
}
