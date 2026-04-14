import Foundation
import Combine

@available(macOS 14.0, *)
@MainActor
class AppService: ObservableObject {
    @Published var status: ServiceStatus = .stopped
    @Published var lastActivity: String = ""
    @Published var memories: [Memory] = []
    @Published var captureEnabled: Bool = true
    @Published var isLLMConnected: Bool = false
    @Published var isMemoryConnected: Bool = false
    @Published var isBackendConnected: Bool = false
    @Published var captureInterval: Int = 30
    
    let config: AppConfig
    private let llmService: LLMService
    private let memoryService: MemoryService
    private let browserContextService: BrowserContextService
    private let browserExtensionServer: BrowserExtensionServer?
    private var captureService: ScreenCaptureService?
    
    private var processingTask: Task<Void, Never>?
    
    init(config: AppConfig = .default) {
        self.config = config
        self.llmService = LLMService(config: config.llm)
        self.memoryService = MemoryService(config: config.memory)
        self.browserContextService = BrowserContextService(config: config.browserExtension)
        self.browserExtensionServer = config.browserExtension.enabled
            ? BrowserExtensionServer(port: config.browserExtension.port, browserContextService: browserContextService)
            : nil
        
        self.captureService = ScreenCaptureService(
            config: config.capture,
            browserContextService: browserContextService
        )
    }
    
    func start() {
        status = .running
        captureEnabled = config.capture.enabled
        captureInterval = config.capture.intervalSeconds
        browserExtensionServer?.start()
        
        if captureEnabled {
            Task {
                await captureService?.start()
            }
        }
        
        Task {
            await refreshMemories()
            await updateHealthStatus()
        }
        
        // Start health check polling
        Task {
            while status == .running {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                guard status == .running else { break }
                await updateHealthStatus()
            }
        }
    }
    
    private func updateHealthStatus() async {
        let health = await checkHealth()
        isLLMConnected = health.llm
        isMemoryConnected = health.memory
        isBackendConnected = health.llm && health.memory
    }
    
    func stop() {
        status = .stopped
        browserExtensionServer?.stop()
        Task {
            await captureService?.stop()
        }
    }
    
    func toggleCapture() {
        captureEnabled.toggle()
        if captureEnabled {
            Task { await captureService?.start() }
        } else {
            Task { await captureService?.stop() }
        }
    }
    
    func chat(message: String) async throws -> String {
        return try await llmService.generateResponse(message: message, memories: [])
    }
    
    func refreshMemories() async {
        do {
            memories = try await memoryService.getRecent(limit: 20)
        } catch {
            print("Failed to refresh memories: \(error)")
        }
    }
    
    func checkHealth() async -> (llm: Bool, memory: Bool) {
        async let llmHealth = llmService.checkHealth()
        async let memoryHealth = memoryService.checkHealth()
        return await (llm: llmHealth, memory: memoryHealth)
    }
    
    func saveConfiguration(_ config: AppConfig) {
        // Save config to file or update as needed
        // For now, this is a placeholder
        print("Configuration saved")
    }
    
    func enhance(text: String) async throws -> EnhancementResult {
        // Get relevant memories for context
        let relevantMemories = try await memoryService.search(query: text, limit: 5)
        let memoryInfos = relevantMemories.map { 
            MemoryInfo(
                id: $0.memory.id,
                content: $0.memory.content,
                context: $0.memory.metadata.context,
                score: $0.score,
                date: $0.memory.createdAt
            )
        }
        
        // Generate enhanced prompt using LLM
        return try await llmService.enhancePrompt(prompt: text, memories: memoryInfos)
    }
    
    private func processCapture(_ capture: ScreenCapture) async {
        guard config.app.processOnCapture else { return }
        
        do {
            let recent = try await memoryService.getRecent(limit: config.app.memoryWindow)
            var contextParts = recent.map { $0.content }

            if let browserContext = capture.browserContext {
                contextParts.append(browserContext.llmSummary)
            }

            let context = contextParts.joined(separator: " ")
            
            let analysis = try await llmService.analyzeScreen(
                imageData: capture.imageData,
                context: context
            )
            
            let content = "\(analysis.summary) | Context: \(analysis.context) | Intent: \(analysis.userIntent)"
            
            let metadata = Metadata(
                timestamp: ISO8601DateFormatter().string(from: Date()),
                context: analysis.context,
                activities: analysis.activities,
                keyElements: analysis.keyElements,
                userIntent: analysis.userIntent,
                displayNum: capture.displayNum,
                browser: capture.browserContext?.browser,
                url: capture.browserContext?.url,
                captureReason: capture.captureReason
            )
            
            _ = try await memoryService.add(content: content, metadata: metadata)
            
            await MainActor.run {
                lastActivity = analysis.summary
            }
            
            await refreshMemories()
            
        } catch {
            print("Failed to process capture: \(error)")
        }
    }
}

enum ServiceStatus: String {
    case running = "Running"
    case stopped = "Stopped"
    case error = "Error"
}
