import AppKit
import ApplicationServices
import Foundation

protocol AccessibilityTreeReading: Sendable {
    func snapshot(parameters: [String: String]) async throws -> AccessibilityRawElementSnapshot
}

struct StaticAccessibilityTreeReader: AccessibilityTreeReading {
    let snapshot: AccessibilityRawElementSnapshot

    func snapshot(parameters: [String: String]) async throws -> AccessibilityRawElementSnapshot {
        snapshot
    }
}

struct AXAccessibilityTreeReader: AccessibilityTreeReading {
    let maxDepth: Int
    let maxChildrenPerElement: Int

    init(maxDepth: Int = 5, maxChildrenPerElement: Int = 40) {
        self.maxDepth = maxDepth
        self.maxChildrenPerElement = maxChildrenPerElement
    }

    func snapshot(parameters: [String: String]) async throws -> AccessibilityRawElementSnapshot {
        let processIdentifier = try targetProcessIdentifier(from: parameters)
        let element = AXUIElementCreateApplication(processIdentifier)
        return readElement(element, depth: 0)
    }

    private func targetProcessIdentifier(from parameters: [String: String]) throws -> pid_t {
        if let rawPID = parameters["pid"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           let processIdentifier = pid_t(rawPID) {
            return processIdentifier
        }

        if let bundleIdentifier = parameters["bundle_id"] ?? parameters["bundleIdentifier"],
           let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            return app.processIdentifier
        }

        if let app = NSWorkspace.shared.frontmostApplication {
            return app.processIdentifier
        }

        throw AccessibilityTreeReaderError.targetApplicationUnavailable
    }

    private func readElement(_ element: AXUIElement, depth: Int) -> AccessibilityRawElementSnapshot {
        let children: [AccessibilityRawElementSnapshot]
        if depth >= maxDepth {
            children = []
        } else {
            children = childElements(for: element)
                .prefix(maxChildrenPerElement)
                .map { readElement($0, depth: depth + 1) }
        }

        return AccessibilityRawElementSnapshot(
            role: stringAttribute(kAXRoleAttribute, from: element),
            title: stringAttribute(kAXTitleAttribute, from: element),
            label: stringAttribute(kAXDescriptionAttribute, from: element),
            value: stringAttribute(kAXValueAttribute, from: element),
            elementDescription: stringAttribute(kAXHelpAttribute, from: element),
            identifier: stringAttribute(kAXIdentifierAttribute, from: element),
            actions: actionNames(for: element),
            frame: frame(for: element),
            children: children
        )
    }

    private func childElements(for element: AXUIElement) -> [AXUIElement] {
        guard let children = copyAttribute(kAXChildrenAttribute, from: element) as? [AXUIElement] else {
            return []
        }
        return children
    }

    private func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        guard let value = copyAttribute(attribute, from: element) else {
            return nil
        }

        if let string = value as? String {
            return string
        }

        return String(describing: value)
    }

    private func actionNames(for element: AXUIElement) -> [String] {
        var copiedActions: CFArray?
        let error = AXUIElementCopyActionNames(element, &copiedActions)
        guard error == .success, let actions = copiedActions as? [String] else {
            return []
        }
        return actions
    }

    private func frame(for element: AXUIElement) -> AccessibilityElementFrame? {
        guard let rawPositionValue = copyAttribute(kAXPositionAttribute, from: element),
              let rawSizeValue = copyAttribute(kAXSizeAttribute, from: element),
              CFGetTypeID(rawPositionValue) == AXValueGetTypeID(),
              CFGetTypeID(rawSizeValue) == AXValueGetTypeID() else {
            return nil
        }

        let positionValue = rawPositionValue as! AXValue
        let sizeValue = rawSizeValue as! AXValue
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &point),
              AXValueGetValue(sizeValue, .cgSize, &size) else {
            return nil
        }

        return AccessibilityElementFrame(
            x: point.x,
            y: point.y,
            width: size.width,
            height: size.height
        )
    }

    private func copyAttribute(_ attribute: String, from element: AXUIElement) -> AnyObject? {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else {
            return nil
        }
        return value
    }
}

enum AccessibilityTreeReaderError: LocalizedError {
    case targetApplicationUnavailable

    var errorDescription: String? {
        switch self {
        case .targetApplicationUnavailable:
            return "No target application is available for Accessibility inspection."
        }
    }
}
