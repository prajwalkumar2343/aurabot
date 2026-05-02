# AuraBot Makefile - macOS Native App

.PHONY: build test clean run deps install

BINARY_NAME=AuraBot
BUILD_DIR=build
SWIFT_DIR=apps/macos
PYTHON ?= python3

# ========== Swift/macOS Commands ==========

# Build the Swift macOS app
build:
	cd $(SWIFT_DIR) && swift build -c release

# Build app bundle
build-app:
	cd $(SWIFT_DIR) && ./scripts/build-app.sh

# Run Swift app in development mode
run:
	cd $(SWIFT_DIR) && swift run AuraBot

# Install dependencies
deps:
	cd $(SWIFT_DIR) && swift package resolve

# Clean Swift build artifacts
clean-swift:
	cd $(SWIFT_DIR) && swift package clean
	rm -rf $(SWIFT_DIR)/.build/release/AuraBot
	rm -rf $(SWIFT_DIR)/AuraBot.app
	rm -f $(SWIFT_DIR)/AuraBot-*.zip

# ========== General Commands ==========

# Clean all build artifacts
clean: clean-swift
	rm -rf $(BUILD_DIR)

# Run all tests
test:
	$(PYTHON) -m unittest discover tests
	cd services/memory-pglite && npm test

# Install all dependencies
deps-all: deps
	cd services/memory-pglite && npm install
