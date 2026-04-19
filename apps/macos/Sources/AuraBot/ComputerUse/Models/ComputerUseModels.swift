import Foundation

enum ComputerUseWorkerKind: String, Codable, CaseIterable, Sendable {
    case nativeCommand = "native_command"
    case browserExtension = "browser_extension"
    case browserDevTools = "browser_devtools"
    case appleEvents = "apple_events"
    case shortcuts = "shortcuts"
    case accessibility = "accessibility"
    case screenObservation = "screen_observation"
    case foregroundInput = "foreground_input"
    case fileAPI = "file_api"
}

enum SkillFocusRequirement: String, Codable, Sendable {
    case never
    case appDependent = "app_dependent"
    case always

    var requiresForegroundLock: Bool {
        switch self {
        case .never:
            return false
        case .appDependent, .always:
            return true
        }
    }
}

struct AppSkillManifest: Codable, Equatable, Sendable {
    let id: String
    let appName: String
    let category: String
    let bundleIdentifiers: [String]
    let domains: [String]
    let aliases: [String]
    let priority: Int
    let actions: [SkillActionDefinition]

    enum CodingKeys: String, CodingKey {
        case id
        case appName = "app_name"
        case category
        case bundleIdentifiers = "bundle_ids"
        case domains
        case aliases
        case priority
        case actions
    }
}

struct SkillActionDefinition: Codable, Equatable, Sendable {
    let name: String
    let description: String
    let intents: [String]
    let preferredWorker: ComputerUseWorkerKind
    let fallbackWorkers: [ComputerUseWorkerKind]
    let parallelSafe: Bool
    let requiresFocus: SkillFocusRequirement
    let requiresConfirmation: Bool
    let destructive: Bool
    let permissions: [String]

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case intents
        case preferredWorker = "preferred_worker"
        case fallbackWorkers = "fallback_workers"
        case parallelSafe = "parallel_safe"
        case requiresFocus = "requires_focus"
        case requiresConfirmation = "requires_confirmation"
        case destructive
        case permissions
    }
}

struct ComputerUseCommandContext: Sendable {
    let command: String
    let activeAppName: String?
    let bundleIdentifier: String?
    let domain: String?
    let categoryHint: String?

    init(
        command: String,
        activeAppName: String? = nil,
        bundleIdentifier: String? = nil,
        domain: String? = nil,
        categoryHint: String? = nil
    ) {
        self.command = command
        self.activeAppName = activeAppName
        self.bundleIdentifier = bundleIdentifier
        self.domain = domain
        self.categoryHint = categoryHint
    }
}

struct ComputerUseToolSelection: Equatable, Sendable {
    let skillID: String
    let actionName: String
    let confidence: Double
    let reasons: [String]
}

struct ComputerUseExecutionPlan: Equatable, Sendable {
    let skillID: String
    let appName: String
    let actionName: String
    let worker: ComputerUseWorkerKind
    let fallbackWorkers: [ComputerUseWorkerKind]
    let parallelSafe: Bool
    let requiresFocus: SkillFocusRequirement
    let requiresForegroundLock: Bool
    let requiresConfirmation: Bool
    let destructive: Bool
    let permissions: [String]
    let confidence: Double
    let matchReasons: [String]
}
