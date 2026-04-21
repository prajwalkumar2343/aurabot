import Foundation
import Combine
import CoreGraphics

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
    
    @Published private(set) var config: AppConfig
    private var llmService: LLMService
    private var memoryService: MemoryService
    private var browserContextService: BrowserContextService
    private var contextRouter: ContextRouter
    private var browserExtensionServer: BrowserExtensionServer?
    private var captureService: ScreenCaptureService?
    
    private var contextProcessingTask: Task<Void, Never>?
    
    init(config: AppConfig = .default) {
        self.config = config
        self.llmService = LLMService(config: config.llm)
        self.memoryService = MemoryService(config: config.memory)
        self.browserContextService = BrowserContextService(config: config.browserExtension)
        self.contextRouter = ContextRouter(
            captureConfig: config.capture,
            browserContextService: browserContextService
        )
        self.browserExtensionServer = config.browserExtension.enabled
            ? BrowserExtensionServer(config: config.browserExtension, browserContextService: browserContextService)
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
            startContextProcessing()
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
        stopContextProcessing()
        browserExtensionServer?.stop()
        Task {
            await captureService?.stop()
        }
    }
    
    func toggleCapture() {
        captureEnabled.toggle()
        if captureEnabled {
            startContextProcessing()
        } else {
            stopContextProcessing()
        }
    }
    
    func chat(message: String) async throws -> String {
        let relevantMemories = try await memoryService.search(query: message, limit: 5)
        let context = relevantMemories.map(\.content)
        return try await llmService.generateResponse(message: message, memories: context)
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
    
    func saveConfiguration(_ newConfig: AppConfig) async throws {
        let wasRunning = status == .running
        if wasRunning {
            stop()
        }

        try newConfig.save(to: AppConfig.defaultURL.path)
        applyConfiguration(newConfig)

        if wasRunning {
            start()
        }
    }

    private func applyConfiguration(_ newConfig: AppConfig) {
        config = newConfig
        llmService = LLMService(config: newConfig.llm)
        memoryService = MemoryService(config: newConfig.memory)
        browserContextService = BrowserContextService(config: newConfig.browserExtension)
        contextRouter = ContextRouter(
            captureConfig: newConfig.capture,
            browserContextService: browserContextService
        )
        browserExtensionServer = newConfig.browserExtension.enabled
            ? BrowserExtensionServer(config: newConfig.browserExtension, browserContextService: browserContextService)
            : nil
        captureService = ScreenCaptureService(
            config: newConfig.capture,
            browserContextService: browserContextService
        )
        captureEnabled = newConfig.capture.enabled
        captureInterval = newConfig.capture.intervalSeconds
    }
    
    func enhance(text: String) async throws -> EnhancementResult {
        // Get relevant memories for context
        let relevantMemories = try await memoryService.search(query: text, limit: 5)
        let memoryInfos = relevantMemories.map { 
            MemoryInfo(
                id: $0.id,
                content: $0.content,
                context: $0.displayContext,
                score: $0.score,
                date: $0.createdAt
            )
        }
        
        // Generate enhanced prompt using LLM
        return try await llmService.enhancePrompt(prompt: text, memories: memoryInfos)
    }

    private func startContextProcessing() {
        guard contextProcessingTask == nil else { return }

        contextProcessingTask = Task { [weak self] in
            await self?.runContextLoop()
        }
    }

    private func stopContextProcessing() {
        contextProcessingTask?.cancel()
        contextProcessingTask = nil
        Task {
            await captureService?.stop()
        }
    }

    private func runContextLoop() async {
        await processContextTick(force: true)

        while status == .running, captureEnabled, !Task.isCancelled {
            let duration = UInt64(max(config.capture.probeIntervalSeconds, 1)) * 1_000_000_000
            try? await Task.sleep(nanoseconds: duration)

            guard status == .running, captureEnabled, !Task.isCancelled else { break }
            await processContextTick(force: false)
        }
    }

    private func processContextTick(force: Bool) async {
        guard config.app.processOnCapture else { return }

        let plan = await contextRouter.capturePlan(force: force)

        switch plan.screenshotDirective {
        case .skip:
            guard let event = plan.event else { return }
            await storeContextEvent(event)
        case .fallback:
            guard let capture = await captureService?.captureDisplay(
                displayID: CGMainDisplayID(),
                browserContext: plan.browserContext,
                reason: plan.reason
            ) else {
                return
            }
            await processCapture(capture)
        }
    }

    private func storeContextEvent(_ event: ContextEvent) async {
        do {
            _ = try await memoryService.add(
                content: event.memoryContent,
                metadata: event.metadata()
            )

            lastActivity = event.summary
            await refreshMemories()
        } catch {
            print("Failed to store context event: \(error)")
        }
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
