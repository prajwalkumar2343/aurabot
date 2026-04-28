import Foundation
import Combine
import CoreGraphics
import AppKit

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
    @Published var capturePermissionMessage: String?
    @Published private(set) var permissionStatuses: [AppPermissionStatus] = PermissionCenter.allStatuses()
    @Published private(set) var appPresentation: AppPresentationPolicy = .hostDefault
    @Published private(set) var windowPolicy: WindowPolicy = .hostDefault
    @Published private(set) var availablePlugins: [WorkspacePluginCatalogItem] = WorkspacePluginCatalog.developmentFallback
    @Published private(set) var installedPlugins: [InstalledPluginRecord] = []
    @Published private(set) var pluginCatalogStatus: PluginCatalogStatus = .idle
    @Published private(set) var activePlugin: InstalledPluginRecord?
    
    @Published private(set) var config: AppConfig
    private let pluginHost = PluginHost()
    private var llmService: LLMService
    private var memoryService: MemoryService
    private var memoryBackendSupervisor: MemoryBackendSupervisor
    private var browserContextService: BrowserContextService
    private var contextRouter: ContextRouter
    private var browserExtensionServer: BrowserExtensionServer?
    private var captureService: ScreenCaptureService?
    private let pluginInstaller = PluginInstaller()
    
    private var contextProcessingTask: Task<Void, Never>?
    
    init(config: AppConfig = .default) {
        self.config = config
        self.llmService = LLMService(config: config.llm)
        self.memoryService = MemoryService(config: config.memory)
        self.memoryBackendSupervisor = MemoryBackendSupervisor(config: config.memory)
        self.browserContextService = BrowserContextService(config: config.browserExtension)
        self.contextRouter = ContextRouter(
            captureConfig: config.capture,
            browserContextService: browserContextService,
            capturePolicy: pluginHost.activeCapturePolicy
        )
        self.browserExtensionServer = config.browserExtension.enabled
            ? BrowserExtensionServer(config: config.browserExtension, browserContextService: browserContextService)
            : nil
        
        self.captureService = ScreenCaptureService(
            config: config.capture,
            browserContextService: browserContextService
        )

        refreshPermissionStatuses()
        installedPlugins = pluginInstaller.installedPlugins
    }
    
    func start() {
        status = .running
        captureEnabled = config.capture.enabled
        captureInterval = config.capture.intervalSeconds
        refreshPermissionStatuses()
        browserExtensionServer?.start()
        Task {
            await refreshPluginCatalog()
            await restoreActivePluginIfNeeded()
        }
        
        if captureEnabled {
            startContextProcessing()
        }
        
        Task {
            _ = await memoryBackendSupervisor.start()
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
        if !health.memory {
            _ = await memoryBackendSupervisor.start()
        }
        isLLMConnected = health.llm
        let memoryHealth = health.memory ? true : await memoryService.checkHealth()
        isMemoryConnected = memoryHealth
        isBackendConnected = isLLMConnected && isMemoryConnected
    }
    
    func stop() async {
        status = .stopped
        stopContextProcessing()
        browserExtensionServer?.stop()
        await memoryBackendSupervisor.stop()
        await captureService?.stop()
    }
    
    func toggleCapture() {
        refreshPermissionStatuses()

        guard requiredPermissionsGranted else {
            capturePermissionMessage = permissionGuidanceMessage
            return
        }

        capturePermissionMessage = nil

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
            await stop()
        }

        try newConfig.save(to: AppConfig.defaultURL.path)
        await applyConfiguration(newConfig)

        if wasRunning {
            start()
        }
    }

    var requiredPermissionStatuses: [AppPermissionStatus] {
        permissionStatuses.filter { $0.kind.isRequired }
    }

    var requiredPermissionsGranted: Bool {
        requiredPermissionStatuses.allSatisfy { $0.isGranted }
    }

    var needsOnboarding: Bool {
        !requiredPermissionsGranted || !config.app.onboardingCompleted
    }

    var permissionGuidanceMessage: String? {
        guard !requiredPermissionsGranted else { return nil }

        if requiredPermissionStatuses.contains(where: { $0.kind == .screenRecording && $0.state == .pendingRestart }) {
            return "Screen Recording was requested. After enabling it in System Settings, restart Aura, then click Refresh Status."
        }

        return "Grant Screen Recording and Accessibility to enable capture."
    }

    func refreshPermissionStatuses() {
        permissionStatuses = PermissionCenter.allStatuses()
        capturePermissionMessage = permissionGuidanceMessage
    }

    func openSystemSettings(for kind: AppPermissionKind) {
        PermissionCenter.openSystemSettings(for: kind)
    }

    func requestPermission(_ kind: AppPermissionKind) {
        PermissionCenter.requestAccess(for: kind)
        refreshPermissionStatuses()
    }

    func completeOnboarding() async throws {
        guard requiredPermissionsGranted else {
            refreshPermissionStatuses()
            return
        }

        var updatedConfig = config
        updatedConfig.app.onboardingCompleted = true
        try updatedConfig.save(to: AppConfig.defaultURL.path)
        config = updatedConfig
        refreshPermissionStatuses()
    }

    var browserExtensionServerURL: String {
        "http://127.0.0.1:\(config.browserExtension.port)"
    }

    func activateWorkspacePlugin(_ descriptor: WorkspacePluginDescriptor) async throws {
        try pluginHost.activateWorkspace(descriptor)
        await applyActivePluginPolicies()
    }

    func installWorkspacePlugin(pluginID: String) async throws {
        guard let plugin = availablePlugins.first(where: { $0.id == pluginID }) else {
            throw PluginInstallError.pluginNotFound
        }

        let record = try await pluginInstaller.install(plugin)
        installedPlugins = pluginInstaller.installedPlugins
        try await activateInstalledPlugin(record)

        if record.manifest.install.requiresHostRelaunch {
            relaunchHost()
        }
    }

    func deactivateWorkspacePlugin(pluginID: String? = nil) async {
        pluginHost.deactivateWorkspace(pluginID: pluginID)
        activePlugin = nil
        await persistActivePluginID(nil)
        await applyActivePluginPolicies()
    }

    func refreshPluginCatalog() async {
        pluginCatalogStatus = .loading

        do {
            availablePlugins = try await pluginInstaller.refreshCatalog()
            pluginCatalogStatus = .loaded
        } catch {
            availablePlugins = WorkspacePluginCatalog.developmentFallback
            pluginCatalogStatus = .failed("Could not load remote plugin catalog. Showing development plugins.")
        }
    }

    func completeActivePluginOnboarding() async throws {
        guard let activePlugin else { return }
        let updated = try pluginInstaller.markOnboardingCompleted(pluginID: activePlugin.pluginID)
        installedPlugins = pluginInstaller.installedPlugins
        self.activePlugin = updated ?? activePlugin
    }

    var browserExtensionConfigured: Bool {
        !config.browserExtension.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func openChromeExtensionsPage() {
        if let url = URL(string: "googlechrome://extensions"),
           NSWorkspace.shared.open(url) {
            return
        }

        guard let chromeURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: chromeURL, configuration: configuration) { _, _ in }
    }

    func installChromeExtension() {
        guard let chromeURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") else {
            openChromeExtensionsPage()
            return
        }

        guard let extensionDirectoryURL = chromeExtensionDirectoryURL else {
            openChromeExtensionsPage()
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.arguments = [
            "--load-extension=\(extensionDirectoryURL.path)",
            "chrome://extensions/"
        ]

        NSWorkspace.shared.openApplication(at: chromeURL, configuration: configuration) { _, _ in }
    }

    var hasChromeExtensionBundle: Bool {
        chromeExtensionDirectoryURL != nil
    }

    private var chromeExtensionDirectoryURL: URL? {
        let fileManager = FileManager.default

        let bundledCandidates = [
            Bundle.module.resourceURL?.appendingPathComponent("BrowserExtension/chromium", isDirectory: true),
            Bundle.module.resourceURL?.appendingPathComponent("chromium", isDirectory: true),
            Bundle.main.resourceURL?.appendingPathComponent("BrowserExtension/chromium", isDirectory: true),
            Bundle.main.resourceURL?.appendingPathComponent("chromium", isDirectory: true)
        ].compactMap { $0 }

        for candidate in bundledCandidates where fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }

        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let repoCandidate = sourceRoot.appendingPathComponent("BrowserExtension/chromium", isDirectory: true)
        if fileManager.fileExists(atPath: repoCandidate.path) {
            return repoCandidate
        }

        return nil
    }

    private func applyConfiguration(_ newConfig: AppConfig) async {
        config = newConfig
        llmService = LLMService(config: newConfig.llm)
        memoryService = MemoryService(config: newConfig.memory)
        memoryBackendSupervisor = MemoryBackendSupervisor(config: newConfig.memory)
        browserContextService = BrowserContextService(config: newConfig.browserExtension)
        contextRouter = ContextRouter(
            captureConfig: newConfig.capture,
            browserContextService: browserContextService,
            capturePolicy: pluginHost.activeCapturePolicy
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
        await applyActivePluginPolicies()
    }

    private func applyActivePluginPolicies() async {
        let capturePolicy = pluginHost.activeCapturePolicy
        let nextPresentation = pluginHost.activeAppPresentation
        let nextWindowPolicy = pluginHost.activeWindowPolicy

        await contextRouter.updateCapturePolicy(capturePolicy)
        appPresentation = nextPresentation
        windowPolicy = nextWindowPolicy
    }

    private func activateInstalledPlugin(_ record: InstalledPluginRecord) async throws {
        try await activateWorkspacePlugin(record.manifest.workspaceDescriptor)
        activePlugin = record
        await persistActivePluginID(record.pluginID)
    }

    private func restoreActivePluginIfNeeded() async {
        guard let pluginID = config.app.activePluginID,
              let record = installedPlugins.first(where: { $0.pluginID == pluginID }) else {
            return
        }

        try? await activateInstalledPlugin(record)
    }

    private func persistActivePluginID(_ pluginID: String?) async {
        var updatedConfig = config
        updatedConfig.app.activePluginID = pluginID

        do {
            try updatedConfig.save(to: AppConfig.defaultURL.path)
            config = updatedConfig
        } catch {
            print("Failed to persist active plugin: \(error)")
        }
    }

    private func relaunchHost() {
        guard let bundleURL = Bundle.main.bundleURL as URL? else { return }

        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, _ in
            NSApp.terminate(nil)
        }
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
        guard requiredPermissionsGranted else { return }

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
                captureReason: capture.captureReason,
                visibleTextHash: capture.browserContext?.visibleTextHash,
                readableTextHash: capture.browserContext?.readableTextHash,
                textCaptureMode: capture.browserContext?.textCaptureMode,
                pageTextSummary: capture.browserContext?.readableTextSummary ?? capture.browserContext?.visibleTextExcerpt,
                browserSourceQuality: capture.browserContext?.sourceQuality.rawValue,
                browserCaptureID: capture.browserContext?.captureID,
                browserSchemaVersion: capture.browserContext?.schemaVersion
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

enum PluginInstallError: Error, Equatable {
    case pluginNotFound
    case unsupportedSchema
    case invalidPluginID
    case downloadFailed(statusCode: Int)
}

enum PluginCatalogStatus: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

enum ServiceStatus: String {
    case running = "Running"
    case stopped = "Stopped"
    case error = "Error"
}
