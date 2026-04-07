import Foundation
import Combine

@available(macOS 12.3, *)
@MainActor
class AppService: ObservableObject {
    @Published var status: ServiceStatus = .stopped
    @Published var lastActivity: String = "--"
    @Published var memories: [Memory] = []
    @Published var captureEnabled: Bool = true
    
    let config: AppConfig
    private let llmService: LLMService
    private let memoryService: MemoryService
    private let enhancerService: EnhancerService
    private var captureService: ScreenCaptureService?
    
    private var processingTask: Task<Void, Never>?
    
    init(config: AppConfig = .default) {
        self.config = config
        self.llmService = LLMService(config: config.llm)
        self.memoryService = MemoryService(config: config.memory)
        self.enhancerService = EnhancerService(
            memoryService: memoryService,
            llmService: llmService
        )
        
        if #available(macOS 12.3, *) {
            self.captureService = ScreenCaptureService(config: config.capture)
            self.captureService?.onCapture = { [weak self] capture in
                await self?.processCapture(capture)
            }
        }
    }
    
    func start() {
        status = .running
        captureEnabled = config.capture.enabled
        
        if captureEnabled {
            Task {
                await captureService?.start()
            }
        }
        
        Task {
            await refreshMemories()
        }
    }
    
    func stop() {
        status = .stopped
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
    
    func enhance(text: String) async throws -> EnhancementResult {
        return try await enhancerService.enhance(prompt: text)
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
