package config

import (
	"fmt"
	"os"

	"github.com/joho/godotenv"
	"gopkg.in/yaml.v3"
)

// Config holds all application configuration
type Config struct {
	Capture   CaptureConfig   `yaml:"capture"`
	LLM       LLMConfig       `yaml:"llm"`
	Memory    MemoryConfig    `yaml:"memory"`
	App       AppConfig       `yaml:"app"`
	Extension ExtensionConfig `yaml:"extension"`
}

// CaptureConfig holds screen capture settings
type CaptureConfig struct {
	IntervalSeconds       int     `yaml:"interval_seconds"`
	Quality               int     `yaml:"quality"`
	MaxWidth              int     `yaml:"max_width"`
	MaxHeight             int     `yaml:"max_height"`
	Enabled               bool    `yaml:"enabled"`
	Format                string  `yaml:"format"`
	DynamicCaptureEnabled bool    `yaml:"dynamic_capture_enabled"`
	FastIntervalSeconds   int     `yaml:"fast_interval_seconds"`
	DiffThreshold         float64 `yaml:"diff_threshold"`
}

// LLMConfig holds LLM API settings
type LLMConfig struct {
	BaseURL        string  `yaml:"base_url"`
	Model          string  `yaml:"model"`
	MaxTokens      int     `yaml:"max_tokens"`
	Temperature    float32 `yaml:"temperature"`
	TimeoutSeconds int     `yaml:"timeout_seconds"`
}

// OpenRouterConfig holds OpenRouter-specific settings
type OpenRouterConfig struct {
	APIKey         string `yaml:"api_key"`
	VisionModel    string `yaml:"vision_model"`
	ChatModel      string `yaml:"chat_model"`
	EmbeddingModel string `yaml:"embedding_model"`
}

// MemoryConfig holds Mem0 settings
type MemoryConfig struct {
	APIKey         string `yaml:"api_key"`
	BaseURL        string `yaml:"base_url"`
	UserID         string `yaml:"user_id"`
	CollectionName string `yaml:"collection_name"`
}

// AppConfig holds general app settings
type AppConfig struct {
	Verbose          bool `yaml:"verbose"`
	ProcessOnCapture bool `yaml:"process_on_capture"`
	MemoryWindow     int  `yaml:"memory_window"`
}

// ExtensionConfig holds browser extension API settings
type ExtensionConfig struct {
	Enabled bool `yaml:"enabled"`
	Port    int  `yaml:"port"`
}

// OpenRouter holds the OpenRouter configuration (stored separately)
var OpenRouter OpenRouterConfig

// Load reads config from file or creates default
func Load() (*Config, error) {
	// Load .env file if it exists
	_ = godotenv.Load()

	// Load OpenRouter config from environment
	OpenRouter = OpenRouterConfig{
		APIKey:         os.Getenv("OPENROUTER_API_KEY"),
		VisionModel:    getEnvOrDefault("OPENROUTER_VISION_MODEL", "google/gemini-flash-1.5"),
		ChatModel:      getEnvOrDefault("OPENROUTER_CHAT_MODEL", "anthropic/claude-3.5-sonnet"),
		EmbeddingModel: getEnvOrDefault("OPENROUTER_EMBEDDING_MODEL", "openai/text-embedding-3-small"),
	}

	cfg := &Config{
		Capture: CaptureConfig{
			IntervalSeconds:       30,
			Quality:               60,
			MaxWidth:              1280,
			MaxHeight:             720,
			Enabled:               true,
			Format:                "webp",
			DynamicCaptureEnabled: false,
			FastIntervalSeconds:   5,
			DiffThreshold:         0.1,
		},
		LLM: LLMConfig{
			BaseURL:        "https://openrouter.ai/api/v1",
			Model:          OpenRouter.VisionModel,
			MaxTokens:      512,
			Temperature:    0.7,
			TimeoutSeconds: 30,
		},
		Memory: MemoryConfig{
			APIKey:         "",
			BaseURL:        "http://localhost:8000",
			UserID:         "default_user",
			CollectionName: "screen_memories_v3",
		},
		App: AppConfig{
			Verbose:          false,
			ProcessOnCapture: true,
			MemoryWindow:     10,
		},
		Extension: ExtensionConfig{
			Enabled: true,
			Port:    7345,
		},
	}

	// Try to load from file
	if _, err := os.Stat("config.yaml"); err == nil {
		data, err := os.ReadFile("config.yaml")
		if err != nil {
			return nil, fmt.Errorf("reading config file: %w", err)
		}
		if err := yaml.Unmarshal(data, cfg); err != nil {
			return nil, fmt.Errorf("parsing config file: %w", err)
		}
	}

	// Override with environment variables
	if val := os.Getenv("MEM0_URL"); val != "" {
		cfg.Memory.BaseURL = val
	}
	if val := os.Getenv("MEM0_API_KEY"); val != "" {
		cfg.Memory.APIKey = val
	}
	if val := os.Getenv("OPENROUTER_API_KEY"); val != "" {
		OpenRouter.APIKey = val
	}

	return cfg, nil
}

// Save writes current config to file
func (c *Config) Save(path string) error {
	data, err := yaml.Marshal(c)
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0644)
}

func getEnvOrDefault(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}
