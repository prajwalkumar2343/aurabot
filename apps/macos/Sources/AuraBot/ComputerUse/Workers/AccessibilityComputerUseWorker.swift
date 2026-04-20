import Foundation

struct AccessibilityComputerUseWorker: ComputerUseWorker {
    let kind: ComputerUseWorkerKind = .accessibility

    private let permissionChecker: any AccessibilityPermissionChecking
    private let treeReader: any AccessibilityTreeReading
    private let normalizer: AccessibilitySnapshotNormalizer

    init(
        permissionChecker: any AccessibilityPermissionChecking = SystemAccessibilityPermissionChecker(),
        treeReader: any AccessibilityTreeReading = AXAccessibilityTreeReader(),
        normalizer: AccessibilitySnapshotNormalizer = AccessibilitySnapshotNormalizer()
    ) {
        self.permissionChecker = permissionChecker
        self.treeReader = treeReader
        self.normalizer = normalizer
    }

    func execute(_ request: ComputerUseWorkerRequest) async -> ComputerUseWorkerResult {
        switch (request.plan.skillID, request.plan.actionName) {
        case ("generic-native-app", "inspect_ui"):
            return await inspectUI(request)
        default:
            return unavailable(request, reason: "unsupported_accessibility_action")
        }
    }

    private func inspectUI(_ request: ComputerUseWorkerRequest) async -> ComputerUseWorkerResult {
        guard permissionChecker.isTrusted(prompt: false) else {
            return unavailable(request, reason: "accessibility_permission_missing")
        }

        do {
            let rawSnapshot = try await treeReader.snapshot(parameters: request.parameters)
            let normalizedSnapshot = normalizer.normalize(rawSnapshot)
            let summary = normalizedSnapshot.compactSummaryLines
                .prefix(80)
                .joined(separator: "\n")

            var metadata = baseMetadata(for: request)
            metadata["root_role"] = normalizedSnapshot.role
            metadata["element_count"] = String(countElements(normalizedSnapshot))
            metadata["summary"] = summary

            if let encodedSnapshot = encodeSnapshot(normalizedSnapshot) {
                metadata["snapshot_json"] = encodedSnapshot
            }

            return ComputerUseWorkerResult(
                status: .success,
                worker: kind,
                summary: "Read Accessibility UI snapshot.",
                requiresConfirmation: false,
                metadata: metadata
            )
        } catch {
            var metadata = baseMetadata(for: request)
            metadata["reason"] = "accessibility_snapshot_failed"

            return ComputerUseWorkerResult(
                status: .failed,
                worker: kind,
                summary: error.localizedDescription,
                requiresConfirmation: false,
                metadata: metadata
            )
        }
    }

    private func unavailable(_ request: ComputerUseWorkerRequest, reason: String) -> ComputerUseWorkerResult {
        var metadata = baseMetadata(for: request)
        metadata["reason"] = reason
        metadata["fallback_workers"] = request.plan.fallbackWorkers.map(\.rawValue).joined(separator: ",")

        return ComputerUseWorkerResult(
            status: .unavailable,
            worker: kind,
            summary: "Accessibility worker cannot inspect \(request.plan.appName).\(request.plan.actionName).",
            requiresConfirmation: false,
            metadata: metadata
        )
    }

    private func encodeSnapshot(_ snapshot: AccessibilityNormalizedElementSnapshot) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(snapshot) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func countElements(_ snapshot: AccessibilityNormalizedElementSnapshot) -> Int {
        1 + snapshot.children.reduce(0) { count, child in
            count + countElements(child)
        }
    }

    private func baseMetadata(for request: ComputerUseWorkerRequest) -> [String: String] {
        [
            "skill_id": request.plan.skillID,
            "action": request.plan.actionName,
            "worker": kind.rawValue
        ]
    }
}
