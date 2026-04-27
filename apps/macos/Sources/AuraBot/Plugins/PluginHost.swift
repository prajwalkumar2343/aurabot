import Foundation

final class PluginHost: @unchecked Sendable {
    private let lock = NSLock()
    private var workspacePlugin: WorkspacePluginDescriptor?

    var activeWorkspacePlugin: WorkspacePluginDescriptor? {
        lock.withLock { workspacePlugin }
    }

    var activeAppPresentation: AppPresentationPolicy {
        lock.withLock {
            guard let workspacePlugin,
                  workspacePlugin.takeover.ui == .replace,
                  workspacePlugin.appBehavior.navigation == .pluginWorkspace
            else {
                return .hostDefault
            }

            return AppPresentationPolicy(
                mode: .pluginWorkspace(
                    pluginID: workspacePlugin.pluginID,
                    name: workspacePlugin.name
                )
            )
        }
    }

    var activeCapturePolicy: CapturePolicy {
        lock.withLock {
            guard let workspacePlugin,
                  workspacePlugin.takeover.capture == .replace
            else {
                return .hostDefault
            }

            return workspacePlugin.capturePolicy
        }
    }

    var activeWindowPolicy: WindowPolicy {
        lock.withLock {
            guard let workspacePlugin,
                  workspacePlugin.takeover.window == .replace
            else {
                return .hostDefault
            }

            return workspacePlugin.windowPolicy
        }
    }

    func activateWorkspace(_ descriptor: WorkspacePluginDescriptor) throws {
        guard descriptor.takeover.requiresActivation else {
            throw PluginHostError.takeoverActivationRequired
        }

        lock.withLock {
            workspacePlugin = descriptor
        }
    }

    func deactivateWorkspace(pluginID: String? = nil) {
        lock.withLock {
            if let pluginID, workspacePlugin?.pluginID != pluginID {
                return
            }
            workspacePlugin = nil
        }
    }
}

enum PluginHostError: Error, Equatable {
    case takeoverActivationRequired
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
