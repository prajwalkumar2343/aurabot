import Foundation

struct AppConfig: Codable {
    var capture: CaptureConfig
    var llm: LLMConfig
    var memory: MemoryConfig
    var app: AppSettings
    var browserExtension: ExtensionConfig
    
    static var `default`: AppConfig {
        AppConfig(
            capture: CaptureConfig(),
            llm: LLMConfig(),
            memory: MemoryConfig(),
            app: AppSettings(),
            browserExtension: ExtensionConfig()
        )
    }
}

struct CaptureConfig: Codable {
    var intervalSeconds: Int = 30
    var quality: Int = 60
    var maxWidth: Int = 1280
    var maxHeight: Int = 720
    var enabled: Bool = true
    var probeIntervalSeconds: Int = 5
    var minCaptureGapSeconds: Int = 20
    var idleCaptureSeconds: Int = 300
    var previewWidth: Int = 160
    var previewHeight: Int = 90
    var meaningfulChangeThreshold: Int = 10
    var scrollCaptureCooldownSeconds: Int = 20
}

struct LLMConfig: Codable {
    var baseURL: String = "https://openrouter.ai/api/v1"
    var model: String = "google/gemini-flash-1.5"
    var maxTokens: Int = 512
    var temperature: Double = 0.7
    var timeoutSeconds: Int = 30
    var openRouterAPIKey: String = ""
    var openRouterChatModel: String = "anthropic/claude-3.5-sonnet"
}

struct MemoryConfig: Codable {
    var apiKey: String = ""
    var baseURL: String = "http://localhost:8000"
    var userID: String = "default_user"
    var collectionName: String = "screen_memories_v3"
}

struct AppSettings: Codable {
    var verbose: Bool = false
    var processOnCapture: Bool = true
    var memoryWindow: Int = 10
}

struct ExtensionConfig: Codable {
    var enabled: Bool = true
    var port: Int = 7345
    var freshnessSeconds: Int = 15
}

extension AppConfig {
    static var defaultPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".aurabot/config.json").path
    }

    static func load(from path: String = defaultPath) -> AppConfig {
        let fallback = mergedWithEnvironment(AppConfig.default)

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return fallback
        }

        return mergedWithEnvironment(config)
    }
    
    func save(to path: String = defaultPath) {
        let fileURL = URL(fileURLWithPath: path)
        let directoryURL = fileURL.deletingLastPathComponent()

        try? FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(self) else { return }
        try? data.write(to: fileURL)
    }

    private static func mergedWithEnvironment(_ config: AppConfig) -> AppConfig {
        let env = ProcessInfo.processInfo.environment
        var merged = config

        if let value = env["OPENROUTER_API_KEY"], !value.isEmpty {
            merged.llm.openRouterAPIKey = value
        }
        if let value = env["OPENROUTER_BASE_URL"], !value.isEmpty {
            merged.llm.baseURL = value
        }
        if let value = env["OPENROUTER_VISION_MODEL"], !value.isEmpty {
            merged.llm.model = value
        }
        if let value = env["OPENROUTER_CHAT_MODEL"], !value.isEmpty {
            merged.llm.openRouterChatModel = value
        }
        if let value = env["MEM0_API_KEY"], !value.isEmpty {
            merged.memory.apiKey = value
        }
        if let value = env["MEM0_HOST"], !value.isEmpty {
            let port = env["MEM0_PORT"] ?? "8000"
            merged.memory.baseURL = "http://\(value):\(port)"
        }

        return merged
    }
}
