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
