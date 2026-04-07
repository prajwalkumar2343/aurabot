package main

import (
	"context"
	"fmt"
	"time"

	"github.com/wailsapp/wails/v2/pkg/runtime"
	"screen-memory-assistant/internal/config"
	"screen-memory-assistant/internal/enhancer"
	"screen-memory-assistant/internal/memory"
	"screen-memory-assistant/internal/quickenhance"
	"screen-memory-assistant/internal/server"
	"screen-memory-assistant/internal/service"
)

// App struct
type App struct {
	ctx           context.Context
	service       *service.Service
	config        *config.Config
	enhancer      *enhancer.Enhancer
	apiServer     *server.Server
	quickEnhance  *quickenhance.QuickEnhance
}

// NewApp creates a new App application struct
func NewApp() *App {
	return &App{}
}

// Startup is called when the app starts
func (a *App) Startup(ctx context.Context) {
	a.ctx = ctx

	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		fmt.Printf("Failed to load config: %v\n", err)
		return
	}
	a.config = cfg

	// Create service instance
	svc, err := service.New(cfg)
	if err != nil {
		fmt.Printf("Failed to create service: %v\n", err)
		return
	}
	a.service = svc

	// Create memory store for enhancer
	memoryStore := memory.NewStore(&cfg.Memory)

	// Create enhancer
	a.enhancer = enhancer.New(memoryStore)

	// Start API server for browser extension
	if cfg.Extension.Enabled {
		a.apiServer = server.New(a.enhancer, cfg.Extension.Port)
		if err := a.apiServer.Start(); err != nil {
			fmt.Printf("Failed to start extension API server: %v\n", err)
		}
	}

	// Initialize quick enhance (global hotkey)
	a.quickEnhance = quickenhance.New(a.enhancer)
	a.quickEnhance.SetCallback(func(text string) {
		// When hotkey pressed, emit event to frontend
		// Frontend will show the quick enhance dialog
		if a.ctx != nil {
			runtime.EventsEmit(a.ctx, "quickenhance:triggered", map[string]string{
				"text": text,
			})
		}
	})
	
	if err := a.quickEnhance.Start(); err != nil {
		fmt.Printf("Failed to start quick enhance: %v\n", err)
	}

	// Start service in background
	go func() {
		serviceCtx, cancel := context.WithCancel(context.Background())
		defer cancel()
		if err := svc.Run(serviceCtx); err != nil {
			fmt.Printf("Service error: %v\n", err)
		}
	}()
}

// Shutdown is called when the app shuts down
func (a *App) Shutdown(ctx context.Context) {
	// Shutdown quick enhance
	if a.quickEnhance != nil {
		a.quickEnhance.Stop()
	}
	
	// Shutdown API server
	if a.apiServer != nil {
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		a.apiServer.Stop(shutdownCtx)
	}
}

// GetStatus returns the current service status
func (a *App) GetStatus() map[string]interface{} {
	if a.service == nil {
		return map[string]interface{}{
			"running":    false,
			"platform":   "unknown",
			"lastState":  "Service not initialized",
			"extension":  a.getExtensionStatus(),
			"quickEnhance": map[string]bool{
				"running": a.quickEnhance != nil,
			},
		}
	}

	status := a.service.GetStatus()
	status["extension"] = a.getExtensionStatus()
	status["quickEnhance"] = map[string]bool{
		"running": a.quickEnhance != nil,
	}
	return status
}

// getExtensionStatus returns extension server status
func (a *App) getExtensionStatus() map[string]interface{} {
	if a.config == nil {
		return map[string]interface{}{"enabled": false}
	}
	return map[string]interface{}{
		"enabled": a.config.Extension.Enabled,
		"port":    a.config.Extension.Port,
		"running": a.apiServer != nil,
	}
}

// Chat sends a message and returns the response
func (a *App) Chat(message string) (string, error) {
	if a.service == nil {
		return "", fmt.Errorf("service not initialized")
	}

	ctx, cancel := context.WithTimeout(a.ctx, 30*time.Second)
	defer cancel()

	return a.service.Chat(ctx, message)
}

// GetConfig returns the current configuration
func (a *App) GetConfig() map[string]interface{} {
	if a.config == nil {
		return map[string]interface{}{}
	}

	return map[string]interface{}{
		"capture": map[string]interface{}{
			"intervalSeconds": a.config.Capture.IntervalSeconds,
			"quality":         a.config.Capture.Quality,
			"maxWidth":        a.config.Capture.MaxWidth,
			"maxHeight":       a.config.Capture.MaxHeight,
			"enabled":         a.config.Capture.Enabled,
		},
		"llm": map[string]interface{}{
			"baseUrl":        a.config.LLM.BaseURL,
			"model":          a.config.LLM.Model,
			"maxTokens":      a.config.LLM.MaxTokens,
			"temperature":    a.config.LLM.Temperature,
			"timeoutSeconds": a.config.LLM.TimeoutSeconds,
		},
		"memory": map[string]interface{}{
			"baseUrl":        a.config.Memory.BaseURL,
			"userId":         a.config.Memory.UserID,
			"collectionName": a.config.Memory.CollectionName,
		},
		"app": map[string]interface{}{
			"verbose":          a.config.App.Verbose,
			"processOnCapture": a.config.App.ProcessOnCapture,
			"memoryWindow":     a.config.App.MemoryWindow,
		},
		"extension": map[string]interface{}{
			"enabled": a.config.Extension.Enabled,
			"port":    a.config.Extension.Port,
		},
		"quickEnhance": map[string]interface{}{
			"hotkey": "Ctrl+Alt+E",
		},
	}
}

// UpdateConfig updates configuration values
func (a *App) UpdateConfig(updates map[string]interface{}) error {
	if a.config == nil {
		return fmt.Errorf("config not initialized")
	}

	// Update capture settings
	if capture, ok := updates["capture"].(map[string]interface{}); ok {
		if v, ok := capture["intervalSeconds"].(float64); ok {
			a.config.Capture.IntervalSeconds = int(v)
		}
		if v, ok := capture["quality"].(float64); ok {
			a.config.Capture.Quality = int(v)
		}
		if v, ok := capture["enabled"].(bool); ok {
			a.config.Capture.Enabled = v
		}
	}

	// Save config to file
	return a.config.Save("config.yaml")
}

// GetMemories returns recent memories
func (a *App) GetMemories(limit int) ([]enhancer.MemoryInfo, error) {
	if a.enhancer == nil {
		return nil, fmt.Errorf("enhancer not initialized")
	}
	return a.enhancer.GetRecentMemories(limit)
}

// SearchMemories searches memories by query
func (a *App) SearchMemories(query string, limit int) ([]enhancer.MemoryInfo, error) {
	if a.enhancer == nil {
		return nil, fmt.Errorf("enhancer not initialized")
	}
	ctx, cancel := context.WithTimeout(a.ctx, 10*time.Second)
	defer cancel()
	return a.enhancer.SearchMemories(ctx, query, limit)
}

// EnhancePrompt enhances a prompt with memories
func (a *App) EnhancePrompt(prompt string, pageContext string) (*enhancer.EnhancementResult, error) {
	if a.enhancer == nil {
		return nil, fmt.Errorf("enhancer not initialized")
	}
	ctx, cancel := context.WithTimeout(a.ctx, 15*time.Second)
	defer cancel()
	return a.enhancer.Enhance(ctx, prompt, pageContext, 5)
}

// QuickEnhanceText enhances text and returns result (called from frontend)
func (a *App) QuickEnhanceText(text string) (*enhancer.EnhancementResult, error) {
	return a.EnhancePrompt(text, "")
}

// PasteEnhanced pastes enhanced text to active window
func (a *App) PasteEnhanced(text string) error {
	if a.quickEnhance != nil {
		a.quickEnhance.PasteEnhanced(text)
		return nil
	}
	return fmt.Errorf("quick enhance not initialized")
}

// ToggleCapture enables/disables screen capture
func (a *App) ToggleCapture(enabled bool) bool {
	if a.config == nil {
		return false
	}
	a.config.Capture.Enabled = enabled
	return a.config.Capture.Enabled
}

// TriggerQuickEnhance manually triggers quick enhance (for UI button)
func (a *App) TriggerQuickEnhance() string {
	// This will be called when user clicks the enhance button in UI
	// The frontend handles getting text and showing dialog
	return ""
}
