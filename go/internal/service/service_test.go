package service

import (
	"testing"

	"screen-memory-assistant/internal/config"
)

func TestNew(t *testing.T) {
	cfg := &config.Config{
		Capture: config.CaptureConfig{
			IntervalSeconds: 30,
			Quality:         85,
		},
		LLM: config.LLMConfig{
			BaseURL:     "http://localhost:1234/v1",
			Model:       "test-model",
			MaxTokens:   256,
			Temperature: 0.7,
		},
		Memory: config.MemoryConfig{
			BaseURL:        "http://localhost:8000",
			UserID:         "test_user",
			CollectionName: "test_collection",
		},
		App: config.AppConfig{
			Verbose:          false,
			ProcessOnCapture: true,
			MemoryWindow:     5,
		},
	}

	svc, err := New(cfg)
	if err != nil {
		t.Fatalf("New failed: %v", err)
	}

	if svc == nil {
		t.Fatal("Service is nil")
	}

	if svc.config != cfg {
		t.Error("Config not set correctly")
	}

	if svc.capturer == nil {
		t.Error("Capturer not initialized")
	}

	if svc.llm == nil {
		t.Error("LLM client not initialized")
	}

	if svc.memory == nil {
		t.Error("Memory store not initialized")
	}

	if svc.stopChan == nil {
		t.Error("Stop channel not initialized")
	}
}

func TestService_GetStatus(t *testing.T) {
	cfg := &config.Config{
		Capture: config.CaptureConfig{
			IntervalSeconds: 45,
			Enabled:         true,
		},
	}

	svc, _ := New(cfg)
	svc.lastState = "Testing"

	status := svc.GetStatus()

	if status["running"] != false {
		t.Error("Expected running to be false initially")
	}

	if status["last_state"] != "Testing" {
		t.Errorf("last_state = %v, want 'Testing'", status["last_state"])
	}

	configMap, ok := status["config"].(map[string]interface{})
	if !ok {
		t.Fatal("config is not a map")
	}

	if configMap["capture_interval"] != 45 {
		t.Errorf("capture_interval = %v, want 45", configMap["capture_interval"])
	}
}

func TestService_lastStateTracking(t *testing.T) {
	cfg := &config.Config{}
	svc, _ := New(cfg)

	// Test that lastState can be updated
	svc.lastState = "New State"
	if svc.lastState != "New State" {
		t.Error("lastState not updated")
	}

	// Test empty state
	svc.lastState = ""
	if svc.lastState != "" {
		t.Error("lastState not cleared")
	}
}
