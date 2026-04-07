package main

import (
	"bufio"
	"context"
	"fmt"
	"log"
	"os"
	"strings"

	"screen-memory-assistant/internal/config"
	"screen-memory-assistant/internal/service"
)

// Simple CLI chat interface to interact with the assistant
func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	svc, err := service.New(cfg)
	if err != nil {
		log.Fatalf("Failed to create service: %v", err)
	}

	ctx := context.Background()

	fmt.Println("╔════════════════════════════════════════╗")
	fmt.Println("║     Screen Memory Assistant Chat       ║")
	fmt.Println("╚════════════════════════════════════════╝")
	fmt.Println("Type 'exit' to quit, 'status' for info")
	fmt.Println()

	scanner := bufio.NewScanner(os.Stdin)

	for {
		fmt.Print("> ")
		if !scanner.Scan() {
			break
		}

		input := strings.TrimSpace(scanner.Text())
		if input == "" {
			continue
		}

		switch strings.ToLower(input) {
		case "exit", "quit":
			fmt.Println("Goodbye!")
			return
		case "status":
			status := svc.GetStatus()
			fmt.Printf("Running: %v\n", status["running"])
			fmt.Printf("Platform: %v\n", status["platform"])
			fmt.Printf("Last State: %v\n", status["last_state"])
		default:
			response, err := svc.Chat(ctx, input)
			if err != nil {
				fmt.Printf("Error: %v\n", err)
				continue
			}
			fmt.Printf("Assistant: %s\n\n", response)
		}
	}
}
