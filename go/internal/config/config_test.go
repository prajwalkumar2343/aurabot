package config

import (
	"os"
	"testing"

	"gopkg.in/yaml.v3"
)

func TestLoad_DefaultValues(t *testing.T) {
	// Remove config file if exists
	os.Remove("config.yaml")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}

	// Check defaults
	if cfg.Capture.IntervalSeconds != 30 {
		t.Errorf("Expected interval 30, got %d", cfg.Capture.IntervalSeconds)
	}
	if cfg.Capture.Quality != 85 {
		t.Errorf("Expected quality 85, got %d", cfg.Capture.Quality)
	}
	if !cfg.Capture.Enabled {
		t.Error("Expected capture enabled")
	}
	if cfg.LLM.BaseURL != "http://localhost:1234/v1" {
		t.Errorf("Expected LM Studio URL, got %s", cfg.LLM.BaseURL)
	}
	if cfg.Memory.BaseURL != "http://localhost:8000" {
		t.Errorf("Expected Mem0 URL, got %s", cfg.Memory.BaseURL)
	}
}

func TestLoad_EnvOverrides(t *testing.T) {
	os.Setenv("LM_STUDIO_URL", "http://custom:1234/v1")
	os.Setenv("MEM0_URL", "http://custom:8000")
	defer func() {
		os.Unsetenv("LM_STUDIO_URL")
		os.Unsetenv("MEM0_URL")
	}()

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}

	if cfg.LLM.BaseURL != "http://custom:1234/v1" {
		t.Errorf("Expected custom LLM URL, got %s", cfg.LLM.BaseURL)
	}
	if cfg.Memory.BaseURL != "http://custom:8000" {
		t.Errorf("Expected custom Mem0 URL, got %s", cfg.Memory.BaseURL)
	}
}

func TestLoad_ConfigFile(t *testing.T) {
	// Create test config
	content := `
capture:
  interval_seconds: 60
  quality: 90
  enabled: false
`
	if err := os.WriteFile("config_test.yaml", []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	defer os.Remove("config_test.yaml")

	cfg := &Config{}
	data, err := os.ReadFile("config_test.yaml")
	if err != nil {
		t.Fatal(err)
	}

	// Parse using yaml
	if err := yaml.Unmarshal(data, cfg); err != nil {
		t.Fatal(err)
	}

	if cfg.Capture.IntervalSeconds != 60 {
		t.Errorf("Expected interval 60, got %d", cfg.Capture.IntervalSeconds)
	}
	if cfg.Capture.Quality != 90 {
		t.Errorf("Expected quality 90, got %d", cfg.Capture.Quality)
	}
}
