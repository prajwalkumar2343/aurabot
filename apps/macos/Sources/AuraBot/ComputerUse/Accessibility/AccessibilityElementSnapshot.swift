import Foundation

struct AccessibilityElementFrame: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct AccessibilityRawElementSnapshot: Codable, Equatable, Sendable {
    let role: String?
    let title: String?
    let label: String?
    let value: String?
    let elementDescription: String?
    let identifier: String?
    let actions: [String]
    let frame: AccessibilityElementFrame?
    let children: [AccessibilityRawElementSnapshot]

    init(
        role: String? = nil,
        title: String? = nil,
        label: String? = nil,
        value: String? = nil,
        elementDescription: String? = nil,
        identifier: String? = nil,
        actions: [String] = [],
        frame: AccessibilityElementFrame? = nil,
        children: [AccessibilityRawElementSnapshot] = []
    ) {
        self.role = role
        self.title = title
        self.label = label
        self.value = value
        self.elementDescription = elementDescription
        self.identifier = identifier
        self.actions = actions
        self.frame = frame
        self.children = children
    }
}

struct AccessibilityNormalizedElementSnapshot: Codable, Equatable, Sendable {
    let role: String
    let name: String?
    let value: String?
    let identifier: String?
    let path: String
    let actions: [String]
    let frame: AccessibilityElementFrame?
    let children: [AccessibilityNormalizedElementSnapshot]

    var compactSummaryLines: [String] {
        var lines = [compactLine]
        for child in children {
            lines.append(contentsOf: child.compactSummaryLines)
        }
        return lines
    }

    private var compactLine: String {
        var parts = ["\(path): \(role)"]
        if let name, !name.isEmpty {
            parts.append("name=\(name)")
        }
        if let value, !value.isEmpty {
            parts.append("value=\(value)")
        }
        if !actions.isEmpty {
            parts.append("actions=\(actions.joined(separator: ","))")
        }
        return parts.joined(separator: " | ")
    }
}
