import AppKit
import CoreGraphics
import Foundation

@MainActor
final class ActiveAppCollector {
    func collect() -> ActiveAppSnapshot? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        return ActiveAppSnapshot(
            name: app.localizedName ?? "Unknown App",
            bundleIdentifier: app.bundleIdentifier,
            processIdentifier: app.processIdentifier,
            windowTitle: frontmostWindowTitle(processIdentifier: app.processIdentifier),
            timestamp: Date()
        )
    }

    private func frontmostWindowTitle(processIdentifier: pid_t) -> String? {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        let window = windowList.first { info in
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == processIdentifier,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0 else {
                return false
            }
            return true
        }

        return (window?[kCGWindowName as String] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
