# Screen Memory Assistant Makefile

.PHONY: build test clean run deps install build-go test-go

BINARY_NAME=screen-memory-assistant
BUILD_DIR=build
GO_DIR=go
PYTHON_DIR=python

# ========== Go Commands ==========

# Build the Go application
build-go:
	mkdir -p $(BUILD_DIR)
	cd $(GO_DIR) && go build -o ../$(BUILD_DIR)/$(BINARY_NAME) .

# Build for macOS
build-macos:
	mkdir -p $(BUILD_DIR)
	cd $(GO_DIR) && GOOS=darwin GOARCH=amd64 go build -o ../$(BUILD_DIR)/$(BINARY_NAME)-macos-amd64 .
	cd $(GO_DIR) && GOOS=darwin GOARCH=arm64 go build -o ../$(BUILD_DIR)/$(BINARY_NAME)-macos-arm64 .

# Build for Windows
build-windows:
	mkdir -p $(BUILD_DIR)
	cd $(GO_DIR) && GOOS=windows GOARCH=amd64 go build -o ../$(BUILD_DIR)/$(BINARY_NAME)-windows.exe .

# Run Go tests
test-go:
	cd $(GO_DIR) && go test -v ./...

# Run Go tests with coverage
test-coverage-go:
	cd $(GO_DIR) && go test -cover ./...

# Download Go dependencies
deps-go:
	cd $(GO_DIR) && go mod download
	cd $(GO_DIR) && go mod tidy

# Run the Go application
run-go:
	cd $(GO_DIR) && go run .

# Install Go binary locally
install-go:
	cd $(GO_DIR) && go install .

# Development mode with verbose logging
dev-go:
	cd $(GO_DIR) && go run . -verbose

# ========== Python Commands ==========

# Install Python dependencies
deps-py:
	pip install -r $(PYTHON_DIR)/requirements.txt

# Run Python tests
test-py:
	cd $(PYTHON_DIR) && python -m pytest tests/ -v

# Run Python server
run-server-py:
	cd $(PYTHON_DIR)/src && python mem0_server.py

# Run local model server
run-local-py:
	cd $(PYTHON_DIR)/src && python local_model_server.py

# ========== Desktop App Commands ==========

APP_DIR=go/cmd/app
APP_BINARY=mem0

# Build desktop app (requires Wails)
build-app:
	cd $(APP_DIR) && wails build -platform $(shell go env GOOS)/$(shell go env GOARCH)

# Build desktop app for Windows
build-app-windows:
	cd $(APP_DIR) && wails build -platform windows/amd64

# Build desktop app for macOS
build-app-macos:
	cd $(APP_DIR) && wails build -platform darwin/universal

# Build desktop app for Linux
build-app-linux:
	cd $(APP_DIR) && wails build -platform linux/amd64

# Run desktop app in dev mode
dev-app:
	cd $(APP_DIR) && wails dev

# Test desktop app
test-app:
	cd $(APP_DIR) && go test -v .

# Install Wails CLI
install-wails:
	go install github.com/wailsapp/wails/v2/cmd/wails@latest

# ========== General Commands ==========

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)

# Run all tests
test: test-go test-py

# Install all dependencies
deps: deps-go deps-py

# Legacy aliases (backward compatibility)
build: build-go
run: run-go
