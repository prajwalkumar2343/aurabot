import Foundation

struct AppConfig: Codable {
    var capture: CaptureConfig
    var llm: LLMConfig
    var memory: MemoryConfig
    var app: AppSettings
    var extension: ExtensionConfig
    
    static let `default` = AppConfig(
        capture: CaptureConfig(),
        llm: LLMConfig(),
        memory: MemoryConfig(),
        app: AppSettings(),
        extension: ExtensionConfig()
    )
}

struct CaptureConfig: Codable {
    var intervalSeconds: Int = 30
    var quality: Int = 60
    var maxWidth: Int = 1280
    var maxHeight: Int = 720
    var enabled: Bool = true
}

struct LLMConfig: Codable {
    var baseURL: String = "http://localhost:1234/v1"
    var model: String = "local-model"
    var maxTokens: Int = 512
    var temperature: Double = 0.7
    var timeoutSeconds: Int = 30
    var cerebrasAPIKey: String = ""
    var cerebrasModel: String = "gpt-oss-120b"
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
}

extension AppConfig {
    static func load(from path: String) -> AppConfig {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return .default
        }
        return config
    }
    
    func save(to path: String) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
    }
}
