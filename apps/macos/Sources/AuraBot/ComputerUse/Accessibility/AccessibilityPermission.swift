import ApplicationServices
import Foundation

protocol AccessibilityPermissionChecking: Sendable {
    func isTrusted(prompt: Bool) -> Bool
}

struct SystemAccessibilityPermissionChecker: AccessibilityPermissionChecking {
    func isTrusted(prompt: Bool = false) -> Bool {
        let options: CFDictionary = [
            "AXTrustedCheckOptionPrompt": prompt
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(options)
    }
}

struct StaticAccessibilityPermissionChecker: AccessibilityPermissionChecking {
    let trusted: Bool

    func isTrusted(prompt: Bool = false) -> Bool {
        trusted
    }
}
