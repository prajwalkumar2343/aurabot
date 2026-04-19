# Mem0 Swift Client

A Swift client for the [Mem0](https://mem0.ai) memory API.

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(path: "swift-mem0")
]
```

## Usage

```swift
import Mem0

let mem0 = Mem0(baseURL: "http://localhost:8000", apiKey: "memory-api-token")

// Add a memory
let memory = try await mem0.add(
    content: "I love programming in Swift",
    userId: "user123",
    metadata: ["topic": "programming"]
)

// Search memories
let results = try await mem0.search(
    query: "What do I like?",
    userId: "user123",
    limit: 5
)

// Get recent memories
let recent = try await mem0.getRecent(userId: "user123", limit: 10)

// Delete a memory
try await mem0.delete(memoryId: "memory-id")

// Check health
let isHealthy = await mem0.checkHealth()
```

## Requirements

- macOS 13.0+ / iOS 16.0+
- Swift 5.9+

## Development

This package is tracked as source inside the AuraBot repository, not as a submodule. Build it from the package directory:

```bash
cd swift-mem0
swift build
```

## License

MIT
