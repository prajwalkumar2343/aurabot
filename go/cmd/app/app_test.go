package main

import (
	"testing"
)

func TestNewApp(t *testing.T) {
	app := NewApp()
	if app == nil {
		t.Fatal("NewApp() returned nil")
	}

	if app.ctx != nil {
		t.Error("Expected nil context before Startup")
	}

	if app.service != nil {
		t.Error("Expected nil service before Startup")
	}

	if app.config != nil {
		t.Error("Expected nil config before Startup")
	}
}

func TestAppGetStatus(t *testing.T) {
	app := NewApp()

	// Test before startup - should return not running status
	status := app.GetStatus()
	if status == nil {
		t.Fatal("GetStatus() returned nil")
	}

	running, ok := status["running"].(bool)
	if !ok {
		t.Error("Expected 'running' key in status")
	}

	if running {
		t.Error("Expected service to not be running before startup")
	}

	platform, ok := status["platform"].(string)
	if !ok || platform == "" {
		t.Error("Expected 'platform' key in status")
	}
}

func TestAppGetConfig(t *testing.T) {
	app := NewApp()

	// Test before startup - should return empty config
	config := app.GetConfig()
	if config == nil {
		t.Fatal("GetConfig() returned nil")
	}

	// Before startup, config should be empty
	if len(config) != 0 {
		t.Error("Expected empty config before startup")
	}
}

func TestAppChatBeforeStartup(t *testing.T) {
	app := NewApp()

	// Test chat before startup - should return error
	response, err := app.Chat("test message")
	if err == nil {
		t.Error("Expected error when chatting before startup")
	}

	if response != "" {
		t.Error("Expected empty response when service not initialized")
	}

	expectedErr := "service not initialized"
	if err != nil && err.Error() != expectedErr {
		t.Errorf("Expected error '%s', got '%s'", expectedErr, err.Error())
	}
}

func TestAppGetMemories(t *testing.T) {
	app := NewApp()

	memories := app.GetMemories(10)
	if memories == nil {
		t.Fatal("GetMemories() returned nil")
	}

	// Should return at least one mock memory
	if len(memories) == 0 {
		t.Error("Expected at least one mock memory")
	}

	// Check memory structure
	for i, memory := range memories {
		if _, ok := memory["id"]; !ok {
			t.Errorf("Memory %d missing 'id' field", i)
		}
		if _, ok := memory["content"]; !ok {
			t.Errorf("Memory %d missing 'content' field", i)
		}
		if _, ok := memory["timestamp"]; !ok {
			t.Errorf("Memory %d missing 'timestamp' field", i)
		}
	}
}

func TestAppToggleCapture(t *testing.T) {
	app := NewApp()

	// Test before startup - should return false
	result := app.ToggleCapture(true)
	if result {
		t.Error("Expected ToggleCapture to return false before startup")
	}
}

func TestAppUpdateConfigBeforeStartup(t *testing.T) {
	app := NewApp()

	// Test update before startup - should return error
	updates := map[string]interface{}{
		"capture": map[string]interface{}{
			"intervalSeconds": 60,
		},
	}

	err := app.UpdateConfig(updates)
	if err == nil {
		t.Error("Expected error when updating config before startup")
	}
}
