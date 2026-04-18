# AuraBot Makefile - macOS Native App

.PHONY: build test clean run deps install

BINARY_NAME=AuraBot
BUILD_DIR=build
SWIFT_DIR=apps/macos
PYTHON_DIR=services/memory-api
PYTHON ?= python3
PIP ?= pip3

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

# ========== Python Commands ==========

# Install Python dependencies
deps-py:
	$(PIP) install -r $(PYTHON_DIR)/requirements.txt

# Run Python tests
test-py:
	cd $(PYTHON_DIR) && $(PYTHON) -m unittest discover -s tests -v

# Run Python memory server
run-server:
	python start.py

# Run local model server
run-local:
	cd $(PYTHON_DIR)/src && $(PYTHON) local_server.py

# ========== General Commands ==========

# Clean all build artifacts
clean: clean-swift
	rm -rf $(BUILD_DIR)

# Run all tests
test: test-py

# Install all dependencies
deps-all: deps deps-py
