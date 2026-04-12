package llm

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/sashabaranov/go-openai"
	"screen-memory-assistant/internal/config"
)

// Client wraps the OpenAI-compatible OpenRouter API
type Client struct {
	client       *openai.Client
	visionModel  string
	chatModel    string
	config       *config.LLMConfig
}

// VisionMessage represents a message with image content
type VisionMessage struct {
	Role        string
	Text        string
	ImageBase64 string
}

// AnalysisResult contains the LLM's understanding of a screen
type AnalysisResult struct {
	Summary     string   `json:"summary"`
	Context     string   `json:"context"`
	Activities  []string `json:"activities"`
	KeyElements []string `json:"key_elements"`
	UserIntent  string   `json:"user_intent"`
}

// NewClient creates a new LLM client using OpenRouter
func NewClient(cfg *config.LLMConfig) *Client {
	apiKey := config.OpenRouter.APIKey
	if apiKey == "" {
		apiKey = os.Getenv("OPENROUTER_API_KEY")
	}

	clientConfig := openai.DefaultConfig(apiKey)
	clientConfig.BaseURL = cfg.BaseURL

	return &Client{
		client:       openai.NewClientWithConfig(clientConfig),
		visionModel:  config.OpenRouter.VisionModel,
		chatModel:    config.OpenRouter.ChatModel,
		config:       cfg,
	}
}

// AnalyzeScreen sends a screen capture to the LLM for analysis
func (c *Client) AnalyzeScreen(ctx context.Context, imageData []byte, previousContext string) (*AnalysisResult, error) {
	ctx, cancel := context.WithTimeout(ctx, time.Duration(c.config.TimeoutSeconds)*time.Second)
	defer cancel()

	base64Image := base64.StdEncoding.EncodeToString(imageData)
	dataURL := fmt.Sprintf("data:image/jpeg;base64,%s", base64Image)

	// Build system prompt
	systemPrompt := `You are a personal AI assistant observing the user's screen. Analyze what you see and provide:
1. A brief summary of what's on screen
2. The context (work, entertainment, communication, etc.)
3. Activities the user might be doing
4. Key UI elements visible
5. What the user likely intends to do

Respond in this exact JSON format:
{
  "summary": "brief description",
  "context": "work/entertainment/social/etc",
  "activities": ["activity1", "activity2"],
  "key_elements": ["element1", "element2"],
  "user_intent": "what user is trying to accomplish"
}`

	// Add previous context if available
	userPrompt := "Analyze this screenshot:"
	if previousContext != "" {
		userPrompt = fmt.Sprintf("Previous context: %s\n\nAnalyze this new screenshot:", previousContext)
	}

	req := openai.ChatCompletionRequest{
		Model: c.visionModel,
		Messages: []openai.ChatCompletionMessage{
			{
				Role:    openai.ChatMessageRoleSystem,
				Content: systemPrompt,
			},
			{
				Role: openai.ChatMessageRoleUser,
				MultiContent: []openai.ChatMessagePart{
					{
						Type: openai.ChatMessagePartTypeText,
						Text: userPrompt,
					},
					{
						Type: openai.ChatMessagePartTypeImageURL,
						ImageURL: &openai.ChatMessageImageURL{
							URL:    dataURL,
							Detail: openai.ImageURLDetailLow, // Use low detail for speed
						},
					},
				},
			},
		},
		MaxTokens:   c.config.MaxTokens,
		Temperature: c.config.Temperature,
	}

	resp, err := c.client.CreateChatCompletion(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("LLM API error: %w", err)
	}

	if len(resp.Choices) == 0 {
		return nil, fmt.Errorf("no response from LLM")
	}

	// Parse the response
	return c.parseResponse(resp.Choices[0].Message.Content), nil
}

// GenerateResponse generates a conversational response based on context
func (c *Client) GenerateResponse(ctx context.Context, prompt string, memories []string) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, time.Duration(c.config.TimeoutSeconds)*time.Second)
	defer cancel()

	systemPrompt := "You are a helpful AI assistant that knows the user well through their screen activity history. Answer based ONLY on the provided memory context. If the information isn't in the memories, say you don't know. Be concise."

	// Include memories as context
	userPrompt := prompt
	if len(memories) > 0 {
		memoryContext := "Based on your activity history:\n"
		for _, m := range memories {
			memoryContext += "- " + m + "\n"
		}
		userPrompt = memoryContext + "\nUser question: " + prompt + "\n\nAnswer based only on the activity history above."
	}

	// DEBUG: Print the full prompt
	fmt.Println("\n" + strings.Repeat("=", 70))
	fmt.Println("FULL PROMPT SENT TO LLM:")
	fmt.Println(strings.Repeat("=", 70))
	fmt.Printf("System:\n%s\n\n", systemPrompt)
	fmt.Printf("User:\n%s\n", userPrompt)
	fmt.Println(strings.Repeat("=", 70))

	req := openai.ChatCompletionRequest{
		Model: c.chatModel,
		Messages: []openai.ChatCompletionMessage{
			{
				Role:    openai.ChatMessageRoleSystem,
				Content: systemPrompt,
			},
			{
				Role:    openai.ChatMessageRoleUser,
				Content: userPrompt,
			},
		},
		MaxTokens:   c.config.MaxTokens,
		Temperature: c.config.Temperature,
	}

	resp, err := c.client.CreateChatCompletion(ctx, req)
	if err != nil {
		return "", fmt.Errorf("LLM API error: %w", err)
	}

	if len(resp.Choices) == 0 {
		return "", fmt.Errorf("no response from LLM")
	}

	return resp.Choices[0].Message.Content, nil
}

// parseResponse extracts structured data from LLM text response
func (c *Client) parseResponse(content string) *AnalysisResult {
	// Store the full LLM output without truncation
	result := &AnalysisResult{
		Summary:     content,
		Context:     "unknown",
		Activities:  []string{},
		KeyElements: []string{},
		UserIntent:  "unknown",
	}

	// Try to parse JSON response if structured
	// This allows the model to return proper JSON that we can extract fields from
	var jsonResult map[string]interface{}
	if err := json.Unmarshal([]byte(content), &jsonResult); err == nil {
		if summary, ok := jsonResult["summary"].(string); ok {
			result.Summary = summary
		}
		if context, ok := jsonResult["context"].(string); ok {
			result.Context = context
		}
		if userIntent, ok := jsonResult["user_intent"].(string); ok {
			result.UserIntent = userIntent
		}
		// Handle arrays
		if activities, ok := jsonResult["activities"].([]interface{}); ok {
			for _, a := range activities {
				if s, ok := a.(string); ok {
					result.Activities = append(result.Activities, s)
				}
			}
		}
		if keyElements, ok := jsonResult["key_elements"].([]interface{}); ok {
			for _, e := range keyElements {
				if s, ok := e.(string); ok {
					result.KeyElements = append(result.KeyElements, s)
				}
			}
		}
	}

	return result
}

// CheckHealth verifies the OpenRouter endpoint is available
func (c *Client) CheckHealth(ctx context.Context) error {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	req := openai.ChatCompletionRequest{
		Model: c.chatModel,
		Messages: []openai.ChatCompletionMessage{
			{
				Role:    openai.ChatMessageRoleUser,
				Content: "Hi",
			},
		},
		MaxTokens: 5,
	}

	_, err := c.client.CreateChatCompletion(ctx, req)
	if err != nil {
		return fmt.Errorf("openrouter client: %w", err)
	}

	return nil
}
