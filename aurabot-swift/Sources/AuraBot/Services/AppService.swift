import Foundation
import Combine

@available(macOS 14.0, *)
@MainActor
class AppService: ObservableObject {
    @Published var status: ServiceStatus = .stopped
    @Published var lastActivity: String = "--"
    @Published var memories: [Memory] = []
    @Published var captureEnabled: Bool = true
    @Published var permissionError: String?
    @Published var isBackendConnected: Bool = false
    @Published var connectionError: String?
    
    let config: AppConfig
    private let llmService: LLMService
    private let memoryService: MemoryService
    private var captureService: ScreenCaptureService?
    private var healthCheckTimer: Timer?
    
    private var processingTask: Task<Void, Never>?
    
    init(config: AppConfig = .default) {
        self.config = config
        self.llmService = LLMService(config: config.llm)
        self.memoryService = MemoryService(config: config.memory)
        
        if #available(macOS 14.0, *) {
            self.captureService = ScreenCaptureService(config: config.capture)
            self.captureService?.onCapture = { [weak self] capture in
                await self?.processCapture(capture)
            }
        }
    }
    
    func start() {
        status = .running
        captureEnabled = config.capture.enabled
        
        // Start health check timer
        startHealthChecks()
        
        if captureEnabled {
            Task {
                // Check permission before starting
                if let hasPerm = await captureService?.checkPermission() {
                    if !hasPerm {
                        await MainActor.run {
                            self.permissionError = "Screen recording permission required. Please grant permission in System Settings > Privacy & Security > Screen Recording"
                            self.captureEnabled = false
                        }
                        return
                    }
                    await captureService?.start()
                }
            }
        }
        
        Task {
            await refreshMemories()
        }
    }
    
    private func startHealthChecks() {
        // Check health immediately
        Task {
            await checkAndUpdateHealth()
        }
        
        // Check health every 5 seconds
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.checkAndUpdateHealth()
            }
        }
    }
    
    private func checkAndUpdateHealth() async {
        let health = await checkHealth()
        await MainActor.run {
            self.isBackendConnected = health.memory
            if !health.memory {
                self.connectionError = "Cannot connect to Mem0 server at \(config.memory.baseURL)"
            } else {
                self.connectionError = nil
            }
        }
    }
    
    func stop() {
        status = .stopped
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        Task {
            await captureService?.stop()
        }
    }
    
    func toggleCapture() {
        let newState = !captureEnabled
        
        if newState {
            // Trying to enable - check permission first
            Task {
                if let hasPerm = await captureService?.checkPermission() {
                    if hasPerm {
                        await MainActor.run {
                            self.captureEnabled = true
                            self.permissionError = nil
                        }
                        await captureService?.start()
                    } else {
                        await MainActor.run {
                            self.permissionError = "Screen recording permission required. Go to System Settings > Privacy & Security > Screen Recording"
                            self.captureEnabled = false
                        }
                    }
                }
            }
        } else {
            // Disabling
            captureEnabled = false
            Task { await captureService?.stop() }
        }
    }
    
    func chat(message: String) async throws -> String {
        return try await llmService.generateResponse(message: message, memories: [])
    }
    
    func enhance(text: String) async throws -> EnhancementResult {
        // Get relevant memories
        let relevantMemories = try await memoryService.search(query: text, limit: 5)
        let memoryContents = relevantMemories.map { $0.memory.content }
        
        // Enhance with memories
        let enhanced = try await llmService.enhancePrompt(text, with: memoryContents)
        
        return EnhancementResult(
            originalPrompt: text,
            enhancedPrompt: enhanced,
            memoriesUsed: memoryContents,
            memoryCount: memoryContents.count,
            enhancementType: "context"
        )
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
    
    private func processCapture(_ capture: ScreenCapture) async {
        guard config.app.processOnCapture else { return }
        
        do {
            let recent = try await memoryService.getRecent(limit: config.app.memoryWindow)
            let context = recent.map { $0.content }.joined(separator: " ")
            
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
                displayNum: capture.displayNum
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
