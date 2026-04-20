import Foundation

struct AccessibilitySnapshotNormalizer: Sendable {
    let maxDepth: Int
    let maxChildrenPerElement: Int
    let maxTextLength: Int

    init(
        maxDepth: Int = 5,
        maxChildrenPerElement: Int = 40,
        maxTextLength: Int = 160
    ) {
        self.maxDepth = maxDepth
        self.maxChildrenPerElement = maxChildrenPerElement
        self.maxTextLength = maxTextLength
    }

    func normalize(_ snapshot: AccessibilityRawElementSnapshot) -> AccessibilityNormalizedElementSnapshot {
        normalize(snapshot, path: "0", depth: 0)
    }

    private func normalize(
        _ snapshot: AccessibilityRawElementSnapshot,
        path: String,
        depth: Int
    ) -> AccessibilityNormalizedElementSnapshot {
        let children: [AccessibilityNormalizedElementSnapshot]
        if depth >= maxDepth {
            children = []
        } else {
            children = snapshot.children
                .prefix(maxChildrenPerElement)
                .enumerated()
                .map { index, child in
                    normalize(child, path: "\(path).\(index)", depth: depth + 1)
                }
        }

        return AccessibilityNormalizedElementSnapshot(
            role: clean(snapshot.role) ?? "AXUnknown",
            name: preferredName(for: snapshot),
            value: clean(snapshot.value),
            identifier: clean(snapshot.identifier),
            path: path,
            actions: normalizedActions(snapshot.actions),
            frame: snapshot.frame,
            children: children
        )
    }

    private func preferredName(for snapshot: AccessibilityRawElementSnapshot) -> String? {
        clean(snapshot.label) ??
            clean(snapshot.title) ??
            clean(snapshot.elementDescription) ??
            clean(snapshot.value)
    }

    private func normalizedActions(_ actions: [String]) -> [String] {
        actions
            .compactMap(clean)
            .sorted()
    }

    private func clean(_ value: String?) -> String? {
        guard let value else { return nil }

        let collapsed = value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsed.isEmpty else { return nil }

        if collapsed.count <= maxTextLength {
            return collapsed
        }

        let endIndex = collapsed.index(collapsed.startIndex, offsetBy: maxTextLength)
        return String(collapsed[..<endIndex])
    }
}
