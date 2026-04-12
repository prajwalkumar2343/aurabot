package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"screen-memory-assistant/internal/config"
	"screen-memory-assistant/internal/enhancer"
	"screen-memory-assistant/internal/server"
	"screen-memory-assistant/internal/service"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	svc, err := service.New(cfg)
	if err != nil {
		log.Fatalf("Failed to create service: %v", err)
	}

	go func() {
		<-sigChan
		fmt.Println("\nShutting down...")
		cancel()
	}()

	// Initialize components
	enh := enhancer.New(svc.Memory())

	// Start HTTP server
	portStr := os.Getenv("AURABOT_EXTENSION_PORT")
	port := 7345
	if p, err := strconv.Atoi(portStr); err == nil {
		port = p
	}

	apiServer := server.New(svc, enh, port)
	if err := apiServer.Start(); err != nil {
		log.Fatalf("Failed to start API server: %v", err)
	}
	defer apiServer.Stop(context.Background())

	// Wait for server to be ready before running service
	time.Sleep(200 * time.Millisecond)
	fmt.Printf("API server ready on port %d\n", port)

	// Run service in background so API stays available
	// This allows the UI to show status even if dependencies fail
	go func() {
		if err := svc.Run(ctx); err != nil {
			log.Printf("Service error: %v", err)
			log.Println("API server will remain running for status queries")
		}
	}()

	// Block until context is cancelled (keeps main alive)
	<-ctx.Done()
}
