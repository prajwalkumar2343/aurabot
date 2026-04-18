import Foundation

struct TerminalContext: Sendable {
    let appName: String
    let windowTitle: String?

    var fingerprint: String {
        "\(appName)|\(windowTitle ?? "")"
    }

    var summary: String {
        if let windowTitle, !windowTitle.isEmpty {
            return "User is working in \(appName): \(windowTitle)"
        }
        return "User is working in \(appName)"
    }
}

struct TerminalContextCollector {
    func collect(from activeApp: ActiveAppSnapshot) -> TerminalContext {
        TerminalContext(appName: activeApp.name, windowTitle: activeApp.windowTitle)
    }
}
