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

    @Published private(set) var config: AppConfig

    private let configPath: String
    private var llmService: LLMService
    private var memoryService: MemoryService
    private let browserContextService: BrowserContextService
    private let browserExtensionServer: BrowserExtensionServer?
    private var captureService: ScreenCaptureService?
    private var healthCheckTimer: Timer?

    private var processingTask: Task<Void, Never>?

    init(configPath: String = AppConfig.defaultPath, config: AppConfig? = nil) {
        let resolvedConfig = config ?? AppConfig.load(from: configPath)

        self.configPath = configPath
        self.config = resolvedConfig
        self.captureEnabled = resolvedConfig.capture.enabled
        self.llmService = LLMService(config: resolvedConfig.llm)
        self.memoryService = MemoryService(config: resolvedConfig.memory)
        self.browserContextService = BrowserContextService(config: resolvedConfig.browserExtension)
        self.browserExtensionServer = resolvedConfig.browserExtension.enabled
            ? BrowserExtensionServer(
                port: resolvedConfig.browserExtension.port,
                browserContextService: browserContextService
            )
            : nil
        self.captureService = nil

        rebuildCaptureService()
    }

    func start() async {
        guard status != .running else { return }

        status = .running
        captureEnabled = config.capture.enabled

        browserExtensionServer?.start()
        startHealthChecks()

        if captureEnabled {
            if let hasPerm = await captureService?.checkPermission() {
                if !hasPerm {
                    permissionError = "Screen recording permission required. Please grant permission in System Settings > Privacy & Security > Screen Recording"
                    captureEnabled = false
                    return
                }
                await captureService?.start()
            }
        }

        await refreshMemories()
    }

    private func startHealthChecks() {
        Task {
            await checkAndUpdateHealth()
        }

        healthCheckTimer?.invalidate()
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

    func stop() async {
        status = .stopped
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        processingTask?.cancel()
        processingTask = nil
        browserExtensionServer?.stop()
        await captureService?.stop()
    }

    func saveConfiguration(_ newConfig: AppConfig) async {
        let wasRunning = status == .running

        if wasRunning {
            await stop()
        }

        config = newConfig
        config.save(to: configPath)

        llmService = LLMService(config: newConfig.llm)
        memoryService = MemoryService(config: newConfig.memory)
        rebuildCaptureService()
        captureEnabled = newConfig.capture.enabled
        permissionError = nil

        if wasRunning {
            await start()
        } else {
            await refreshMemories()
            await checkAndUpdateHealth()
        }
    }

    func toggleCapture() {
        let newState = !captureEnabled

        if newState {
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
            let recent = (try? await memoryService.getRecent(limit: config.app.memoryWindow)) ?? []
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

            do {
                _ = try await memoryService.add(content: content, metadata: metadata)
            } catch {
                print("Failed to save memory: \(error)")
            }

            await MainActor.run {
                lastActivity = analysis.summary
            }

            await refreshMemories()
        } catch {
            print("Failed to process capture: \(error)")
        }
    }

    private func rebuildCaptureService() {
        let service = ScreenCaptureService(
            config: config.capture,
            browserContextService: browserContextService
        )
        service.onCapture = { [weak self] capture in
            await self?.processCapture(capture)
        }
        captureService = service
    }
}

enum ServiceStatus: String {
    case running = "Running"
    case stopped = "Stopped"
    case error = "Error"
}
