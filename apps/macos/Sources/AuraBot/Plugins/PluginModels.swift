import Foundation

enum PluginKind: String, Codable, Sendable {
    case `extension`
    case workspace
    case system
}

enum PluginControlMode: String, Codable, Sendable {
    case none
    case augment
    case replace
}

enum PluginTakeoverSurface: String, Codable, CaseIterable, Sendable {
    case ui
    case agent
    case context
    case capture
    case memory
    case retrieval
    case window
    case commands
    case settings
}

struct PluginTakeoverPolicy: Codable, Equatable, Sendable {
    var ui: PluginControlMode
    var agent: PluginControlMode
    var context: PluginControlMode
    var capture: PluginControlMode
    var memory: PluginControlMode
    var retrieval: PluginControlMode
    var window: PluginControlMode
    var commands: PluginControlMode
    var settings: PluginControlMode

    static let none = PluginTakeoverPolicy(
        ui: .none,
        agent: .none,
        context: .none,
        capture: .none,
        memory: .none,
        retrieval: .none,
        window: .none,
        commands: .none,
        settings: .none
    )

    var requiresActivation: Bool {
        [
            ui,
            agent,
            context,
            capture,
            memory,
            retrieval,
            window,
            commands,
            settings
        ].contains(.replace)
    }
}

enum AppNavigationMode: String, Codable, Sendable {
    case hostDefault = "host_default"
    case pluginWorkspace = "plugin_workspace"
}

enum AppCommandMode: String, Codable, Sendable {
    case hostDefault = "host_default"
    case pluginWorkspace = "plugin_workspace"
    case merged
}

struct AppBehaviorPolicy: Codable, Equatable, Sendable {
    var navigation: AppNavigationMode
    var commands: AppCommandMode
    var fallback: AppNavigationMode

    static let hostDefault = AppBehaviorPolicy(
        navigation: .hostDefault,
        commands: .hostDefault,
        fallback: .hostDefault
    )
}

enum AppPresentationMode: Equatable, Sendable {
    case hostDefault
    case pluginWorkspace(pluginID: String, name: String)
}

struct AppPresentationPolicy: Equatable, Sendable {
    var mode: AppPresentationMode

    static let hostDefault = AppPresentationPolicy(mode: .hostDefault)
}

enum WindowPresentation: String, Codable, Sendable {
    case normal
    case sidePanel = "side_panel"
    case floatingOverlay = "floating_overlay"
    case menuBar = "menu_bar"
}

enum WindowLevelPolicy: String, Codable, Sendable {
    case normal
    case aboveNormal = "above_normal"
    case alwaysOnTop = "always_on_top"
}

enum WindowSuppressionReason: String, Codable, Sendable {
    case screenSharing = "screen_sharing"
    case fullscreenVideo = "fullscreen_video"
    case sensitiveApp = "sensitive_app"
    case focusMode = "focus_mode"
}

struct WindowPolicy: Codable, Equatable, Sendable {
    var presentation: WindowPresentation
    var level: WindowLevelPolicy
    var hideWhen: [WindowSuppressionReason]
    var excludePluginUIFromCapture: Bool

    static let hostDefault = WindowPolicy(
        presentation: .normal,
        level: .normal,
        hideWhen: [],
        excludePluginUIFromCapture: true
    )
}

enum CaptureMethod: String, Codable, CaseIterable, Sendable {
    case browserDOM = "browser_dom"
    case browserTranscript = "browser_transcript"
    case appMetadata = "app_metadata"
    case selectedText = "selected_text"
    case screenOCR = "screen_ocr"
    case screenVision = "screen_vision"
    case screenshot
}

enum CaptureFallback: String, Codable, Sendable {
    case hostDefault = "host_default"
    case screenshot
    case none
}

enum CaptureRedactionPolicy: String, Codable, Sendable {
    case hostDefault = "host_default"
    case strict
}

struct CapturePolicy: Codable, Equatable, Sendable {
    var priority: [CaptureMethod]
    var fallback: CaptureFallback
    var redaction: CaptureRedactionPolicy

    static let hostDefault = CapturePolicy(
        priority: [
            .browserDOM,
            .browserTranscript,
            .appMetadata,
            .selectedText,
            .screenVision,
            .screenshot
        ],
        fallback: .screenshot,
        redaction: .hostDefault
    )

    var allowsBrowserContext: Bool {
        priority.contains(.browserDOM) || priority.contains(.browserTranscript)
    }

    var allowsAppMetadata: Bool {
        priority.contains(.appMetadata)
    }

    var allowsVisualFallback: Bool {
        fallback == .hostDefault
            || fallback == .screenshot
            || priority.contains(.screenVision)
            || priority.contains(.screenOCR)
            || priority.contains(.screenshot)
    }
}

struct WorkspacePluginDescriptor: Equatable, Sendable {
    let pluginID: String
    let name: String
    let takeover: PluginTakeoverPolicy
    let appBehavior: AppBehaviorPolicy
    let capturePolicy: CapturePolicy
    let windowPolicy: WindowPolicy

    init(
        pluginID: String,
        name: String,
        takeover: PluginTakeoverPolicy,
        appBehavior: AppBehaviorPolicy,
        capturePolicy: CapturePolicy,
        windowPolicy: WindowPolicy
    ) {
        self.pluginID = pluginID
        self.name = name
        self.takeover = takeover
        self.appBehavior = appBehavior
        self.capturePolicy = capturePolicy
        self.windowPolicy = windowPolicy
    }
}

struct WorkspacePluginCatalogItem: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let summary: String
    let icon: String
    let version: String
    let source: PluginSource
    let onboarding: PluginOnboardingManifest
    let descriptor: WorkspacePluginDescriptor
}

enum PluginSource: Equatable, Sendable {
    case bundled
    case remote(manifestURL: URL, packageURL: URL?, sha256: String?)
}

struct RemotePluginCatalog: Codable, Sendable {
    let schemaVersion: String
    let plugins: [RemotePluginCatalogEntry]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case plugins
    }
}

struct RemotePluginCatalogEntry: Codable, Identifiable, Sendable {
    let pluginID: String
    let name: String
    let version: String
    let summary: String
    let icon: String?
    let manifestURL: URL
    let packageURL: URL?
    let sha256: String?

    var id: String { pluginID }

    enum CodingKeys: String, CodingKey {
        case pluginID = "plugin_id"
        case name
        case version
        case summary
        case icon
        case manifestURL = "manifest_url"
        case packageURL = "package_url"
        case sha256
    }
}

struct PluginManifest: Codable, Equatable, Sendable {
    let schemaVersion: String
    let pluginID: String
    let name: String
    let version: String
    let description: String
    let icon: String?
    let compatibility: PluginCompatibility
    let entrypoints: PluginEntrypoints
    let permissions: PluginPermissionManifest
    let onboarding: PluginOnboardingManifest
    let install: PluginInstallManifest
    let presentation: PluginPresentationManifest

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case pluginID = "plugin_id"
        case name
        case version
        case description
        case icon
        case compatibility
        case entrypoints
        case permissions
        case onboarding
        case install
        case presentation
    }
}

struct PluginCompatibility: Codable, Equatable, Sendable {
    let hostAPI: String
    let memoryAPI: String

    enum CodingKeys: String, CodingKey {
        case hostAPI = "host_api"
        case memoryAPI = "memory_api"
    }
}

struct PluginEntrypoints: Codable, Equatable, Sendable {
    let ui: String?
    let context: String?
    let memory: String?
    let agent: String?
    let tools: String?
}

struct PluginPermissionManifest: Codable, Equatable, Sendable {
    let hostPermissions: [AppPermissionKind]
    let contextSources: [String]
    let memory: [String]
    let networkDomains: [String]

    enum CodingKeys: String, CodingKey {
        case hostPermissions = "host_permissions"
        case contextSources = "context_sources"
        case memory
        case networkDomains = "network_domains"
        case network
    }

    enum NetworkCodingKeys: String, CodingKey {
        case domains
    }

    init(
        hostPermissions: [AppPermissionKind] = [],
        contextSources: [String] = [],
        memory: [String] = [],
        networkDomains: [String] = []
    ) {
        self.hostPermissions = hostPermissions
        self.contextSources = contextSources
        self.memory = memory
        self.networkDomains = networkDomains
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hostPermissions = try container.decodeIfPresent([AppPermissionKind].self, forKey: .hostPermissions) ?? []
        contextSources = try container.decodeIfPresent([String].self, forKey: .contextSources) ?? []
        memory = try container.decodeIfPresent([String].self, forKey: .memory) ?? []

        if let directDomains = try container.decodeIfPresent([String].self, forKey: .networkDomains) {
            networkDomains = directDomains
        } else if let networkContainer = try? container.nestedContainer(keyedBy: NetworkCodingKeys.self, forKey: .network) {
            networkDomains = try networkContainer.decodeIfPresent([String].self, forKey: .domains) ?? []
        } else {
            networkDomains = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hostPermissions, forKey: .hostPermissions)
        try container.encode(contextSources, forKey: .contextSources)
        try container.encode(memory, forKey: .memory)
        try container.encode(networkDomains, forKey: .networkDomains)
    }
}

struct PluginOnboardingManifest: Codable, Equatable, Sendable {
    let required: Bool
    let title: String
    let detail: String
    let requiredHostPermissions: [AppPermissionKind]
    let steps: [String]

    enum CodingKeys: String, CodingKey {
        case required
        case title
        case detail
        case requiredHostPermissions = "required_host_permissions"
        case steps
    }

    init(
        required: Bool = false,
        title: String = "Plugin setup",
        detail: String = "This plugin has setup steps before its workspace is ready.",
        requiredHostPermissions: [AppPermissionKind] = [],
        steps: [String] = []
    ) {
        self.required = required
        self.title = title
        self.detail = detail
        self.requiredHostPermissions = requiredHostPermissions
        self.steps = steps
    }
}

struct PluginInstallManifest: Codable, Equatable, Sendable {
    let defaultEnabled: Bool
    let requiresHostRelaunch: Bool

    enum CodingKeys: String, CodingKey {
        case defaultEnabled = "default_enabled"
        case requiresHostRelaunch = "requires_host_relaunch"
    }

    init(defaultEnabled: Bool = true, requiresHostRelaunch: Bool = false) {
        self.defaultEnabled = defaultEnabled
        self.requiresHostRelaunch = requiresHostRelaunch
    }
}

struct PluginPresentationManifest: Codable, Equatable, Sendable {
    let workspaceTitle: String
    let workspaceIcon: String
    let workspaceSections: [String]

    enum CodingKeys: String, CodingKey {
        case workspaceTitle = "workspace_title"
        case workspaceIcon = "workspace_icon"
        case workspaceSections = "workspace_sections"
    }

    init(workspaceTitle: String, workspaceIcon: String, workspaceSections: [String]) {
        self.workspaceTitle = workspaceTitle
        self.workspaceIcon = workspaceIcon
        self.workspaceSections = workspaceSections
    }
}

struct InstalledPluginRecord: Codable, Equatable, Identifiable, Sendable {
    let pluginID: String
    let name: String
    let version: String
    let installedAt: Date
    var onboardingCompleted: Bool
    let installDirectory: String
    let manifest: PluginManifest

    var id: String { pluginID }

    enum CodingKeys: String, CodingKey {
        case pluginID = "plugin_id"
        case name
        case version
        case installedAt = "installed_at"
        case onboardingCompleted = "onboarding_completed"
        case installDirectory = "install_directory"
        case manifest
    }
}

enum WorkspacePluginCatalog {
    static let developmentFallback: [WorkspacePluginCatalogItem] = [
        WorkspacePluginCatalogItem(
            id: "com.aurabot.ai-tutor",
            name: "AI Tutor",
            summary: "Turns Aura into a focused study and coaching workspace.",
            icon: "graduationcap",
            version: "0.1.0",
            source: .bundled,
            onboarding: PluginOnboardingManifest(
                required: true,
                title: "AI Tutor setup",
                detail: "AI Tutor needs access to learning context before its workspace is ready.",
                requiredHostPermissions: [.screenRecording, .accessibility],
                steps: ["Confirm learning sources", "Enable context capture", "Start the tutor workspace"]
            ),
            descriptor: WorkspacePluginDescriptor(
                pluginID: "com.aurabot.ai-tutor",
                name: "AI Tutor",
                takeover: PluginTakeoverPolicy(
                    ui: .replace,
                    agent: .replace,
                    context: .replace,
                    capture: .replace,
                    memory: .augment,
                    retrieval: .replace,
                    window: .replace,
                    commands: .replace,
                    settings: .augment
                ),
                appBehavior: AppBehaviorPolicy(
                    navigation: .pluginWorkspace,
                    commands: .pluginWorkspace,
                    fallback: .hostDefault
                ),
                capturePolicy: CapturePolicy(
                    priority: [.browserDOM, .browserTranscript, .appMetadata],
                    fallback: .none,
                    redaction: .strict
                ),
                windowPolicy: WindowPolicy(
                    presentation: .floatingOverlay,
                    level: .alwaysOnTop,
                    hideWhen: [.screenSharing, .sensitiveApp],
                    excludePluginUIFromCapture: true
                )
            )
        ),
        WorkspacePluginCatalogItem(
            id: "com.aurabot.meeting-copilot",
            name: "Meeting Copilot",
            summary: "Creates a lightweight workspace for meeting notes and follow-ups.",
            icon: "person.2.wave.2",
            version: "0.1.0",
            source: .bundled,
            onboarding: PluginOnboardingManifest(
                required: true,
                title: "Meeting Copilot setup",
                detail: "Meeting Copilot can request microphone access and meeting capture consent.",
                requiredHostPermissions: [.microphone, .accessibility],
                steps: ["Choose meeting apps", "Grant optional microphone access", "Open meeting desk"]
            ),
            descriptor: WorkspacePluginDescriptor(
                pluginID: "com.aurabot.meeting-copilot",
                name: "Meeting Copilot",
                takeover: PluginTakeoverPolicy(
                    ui: .replace,
                    agent: .replace,
                    context: .augment,
                    capture: .augment,
                    memory: .augment,
                    retrieval: .replace,
                    window: .replace,
                    commands: .replace,
                    settings: .augment
                ),
                appBehavior: AppBehaviorPolicy(
                    navigation: .pluginWorkspace,
                    commands: .pluginWorkspace,
                    fallback: .hostDefault
                ),
                capturePolicy: CapturePolicy(
                    priority: [.selectedText, .appMetadata, .browserDOM, .screenshot],
                    fallback: .hostDefault,
                    redaction: .hostDefault
                ),
                windowPolicy: WindowPolicy(
                    presentation: .floatingOverlay,
                    level: .alwaysOnTop,
                    hideWhen: [.screenSharing, .sensitiveApp],
                    excludePluginUIFromCapture: true
                )
            )
        ),
        WorkspacePluginCatalogItem(
            id: "com.aurabot.dev-focus",
            name: "Dev Focus",
            summary: "Switches Aura into a coding context workspace for repos and terminals.",
            icon: "chevron.left.forwardslash.chevron.right",
            version: "0.1.0",
            source: .bundled,
            onboarding: PluginOnboardingManifest(
                required: false,
                title: "Dev Focus setup",
                detail: "Dev Focus is ready to use.",
                requiredHostPermissions: [],
                steps: []
            ),
            descriptor: WorkspacePluginDescriptor(
                pluginID: "com.aurabot.dev-focus",
                name: "Dev Focus",
                takeover: PluginTakeoverPolicy(
                    ui: .replace,
                    agent: .replace,
                    context: .replace,
                    capture: .augment,
                    memory: .augment,
                    retrieval: .replace,
                    window: .replace,
                    commands: .replace,
                    settings: .augment
                ),
                appBehavior: AppBehaviorPolicy(
                    navigation: .pluginWorkspace,
                    commands: .pluginWorkspace,
                    fallback: .hostDefault
                ),
                capturePolicy: CapturePolicy(
                    priority: [.appMetadata, .selectedText, .screenVision, .screenshot],
                    fallback: .screenshot,
                    redaction: .hostDefault
                ),
                windowPolicy: WindowPolicy(
                    presentation: .floatingOverlay,
                    level: .alwaysOnTop,
                    hideWhen: [.screenSharing, .sensitiveApp],
                    excludePluginUIFromCapture: true
                )
            )
        )
    ]

    static func item(from manifest: PluginManifest, manifestURL: URL, packageURL: URL?, sha256: String?) -> WorkspacePluginCatalogItem {
        WorkspacePluginCatalogItem(
            id: manifest.pluginID,
            name: manifest.name,
            summary: manifest.description,
            icon: manifest.icon ?? manifest.presentation.workspaceIcon,
            version: manifest.version,
            source: .remote(manifestURL: manifestURL, packageURL: packageURL, sha256: sha256),
            onboarding: manifest.onboarding,
            descriptor: manifest.workspaceDescriptor
        )
    }
}

extension PluginManifest {
    var workspaceDescriptor: WorkspacePluginDescriptor {
        WorkspacePluginDescriptor(
            pluginID: pluginID,
            name: name,
            takeover: PluginTakeoverPolicy(
                ui: .replace,
                agent: .replace,
                context: .augment,
                capture: .augment,
                memory: .augment,
                retrieval: .replace,
                window: .replace,
                commands: .replace,
                settings: .augment
            ),
            appBehavior: AppBehaviorPolicy(
                navigation: .pluginWorkspace,
                commands: .pluginWorkspace,
                fallback: .hostDefault
            ),
            capturePolicy: CapturePolicy(
                priority: capturePriority,
                fallback: .hostDefault,
                redaction: .hostDefault
            ),
            windowPolicy: WindowPolicy(
                presentation: .floatingOverlay,
                level: .alwaysOnTop,
                hideWhen: [.screenSharing, .sensitiveApp],
                excludePluginUIFromCapture: true
            )
        )
    }

    private var capturePriority: [CaptureMethod] {
        var methods: [CaptureMethod] = []
        if permissions.contextSources.contains("browser") {
            methods.append(.browserDOM)
            methods.append(.browserTranscript)
        }
        if permissions.contextSources.contains("app") {
            methods.append(.appMetadata)
        }
        methods.append(.selectedText)
        methods.append(.screenshot)
        return Array(NSOrderedSet(array: methods).compactMap { $0 as? CaptureMethod })
    }
}
