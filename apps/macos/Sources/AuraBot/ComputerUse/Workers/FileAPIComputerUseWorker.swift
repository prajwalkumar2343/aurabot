import Foundation

struct FileAPIComputerUseWorker: ComputerUseWorker {
    let kind: ComputerUseWorkerKind = .fileAPI

    private let confirmationPolicy: ComputerUseConfirmationPolicy

    init(
        confirmationPolicy: ComputerUseConfirmationPolicy = ComputerUseConfirmationPolicy()
    ) {
        self.confirmationPolicy = confirmationPolicy
    }

    func execute(_ request: ComputerUseWorkerRequest) async -> ComputerUseWorkerResult {
        if confirmationPolicy.shouldBlock(request) {
            return ComputerUseWorkerResult(
                status: .requiresConfirmation,
                worker: kind,
                summary: "Confirmation required before \(request.plan.appName).\(request.plan.actionName)",
                requiresConfirmation: true,
                metadata: baseMetadata(for: request)
            )
        }

        switch (request.plan.skillID, request.plan.actionName) {
        case ("finder", "move_files"):
            return moveFiles(request)
        case ("finder", "delete_files"):
            return ComputerUseWorkerResult(
                status: .requiresConfirmation,
                worker: kind,
                summary: "Delete is intentionally blocked until destructive confirmation UI is implemented.",
                requiresConfirmation: true,
                metadata: baseMetadata(for: request).merging(["blocked_reason": "destructive_action"]) { current, _ in current }
            )
        default:
            return unavailable(request, reason: "unsupported_file_api_action")
        }
    }

    private func moveFiles(_ request: ComputerUseWorkerRequest) -> ComputerUseWorkerResult {
        let fileManager = FileManager.default
        let sources = sourcePaths(from: request.parameters)
        guard !sources.isEmpty else {
            return failed(request, summary: "No source paths were provided for file move.")
        }

        guard let destinationPath = request.parameters["destination_path"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !destinationPath.isEmpty else {
            return failed(request, summary: "No destination path was provided for file move.")
        }

        var metadata = baseMetadata(for: request)
        metadata["source_count"] = String(sources.count)
        metadata["destination_path"] = destinationPath

        let operations: [MoveOperation]
        do {
            operations = try validatedMoveOperations(
                sources: sources,
                destinationPath: destinationPath,
                fileManager: fileManager
            )
            metadata["planned_destination_paths"] = operations
                .map { $0.destination.path }
                .joined(separator: "\n")
        } catch {
            return failed(request, summary: error.localizedDescription)
        }

        let dryRun = request.parameters["dry_run"]?.lowercased() != "false"
        if dryRun {
            metadata["dry_run"] = "true"
            return ComputerUseWorkerResult(
                status: .success,
                worker: kind,
                summary: "Dry run: would move \(sources.count) file(s) to \(destinationPath).",
                requiresConfirmation: false,
                metadata: metadata
            )
        }

        do {
            for operation in operations {
                try fileManager.moveItem(at: operation.source, to: operation.destination)
            }

            metadata["dry_run"] = "false"
            return ComputerUseWorkerResult(
                status: .success,
                worker: kind,
                summary: "Moved \(sources.count) file(s) to \(destinationPath).",
                requiresConfirmation: false,
                metadata: metadata
            )
        } catch {
            return failed(request, summary: "Failed to move files: \(error.localizedDescription)")
        }
    }

    private func validatedMoveOperations(
        sources: [String],
        destinationPath: String,
        fileManager: FileManager
    ) throws -> [MoveOperation] {
        var isDestinationDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: destinationPath, isDirectory: &isDestinationDirectory) else {
            throw FileAPIWorkerError.destinationMissing(destinationPath)
        }

        guard isDestinationDirectory.boolValue else {
            throw FileAPIWorkerError.destinationNotDirectory(destinationPath)
        }

        let destinationDirectory = URL(fileURLWithPath: destinationPath, isDirectory: true)
        var plannedDestinations = Set<String>()

        return try sources.map { sourcePath in
            guard fileManager.fileExists(atPath: sourcePath) else {
                throw FileAPIWorkerError.sourceMissing(sourcePath)
            }

            let sourceURL = URL(fileURLWithPath: sourcePath)
            let destinationURL = destinationDirectory.appendingPathComponent(sourceURL.lastPathComponent)
            let destinationFilePath = destinationURL.path

            guard plannedDestinations.insert(destinationFilePath).inserted else {
                throw FileAPIWorkerError.duplicateDestination(destinationFilePath)
            }

            guard !fileManager.fileExists(atPath: destinationFilePath) else {
                throw FileAPIWorkerError.destinationExists(destinationFilePath)
            }

            return MoveOperation(source: sourceURL, destination: destinationURL)
        }
    }

    private func sourcePaths(from parameters: [String: String]) -> [String] {
        if let json = parameters["source_paths_json"],
           let data = json.data(using: .utf8),
           let paths = try? JSONDecoder().decode([String].self, from: data) {
            return paths.map(cleanPath).filter { !$0.isEmpty }
        }

        if let sourcePaths = parameters["source_paths"] {
            return sourcePaths
                .components(separatedBy: CharacterSet(charactersIn: "\n;"))
                .map(cleanPath)
                .filter { !$0.isEmpty }
        }

        if let sourcePath = parameters["source_path"] {
            let clean = cleanPath(sourcePath)
            return clean.isEmpty ? [] : [clean]
        }

        return []
    }

    private func cleanPath(_ path: String) -> String {
        path.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func unavailable(_ request: ComputerUseWorkerRequest, reason: String) -> ComputerUseWorkerResult {
        ComputerUseWorkerResult(
            status: .unavailable,
            worker: kind,
            summary: "File API worker does not support \(request.plan.skillID).\(request.plan.actionName).",
            requiresConfirmation: false,
            metadata: baseMetadata(for: request).merging(["reason": reason]) { current, _ in current }
        )
    }

    private func failed(_ request: ComputerUseWorkerRequest, summary: String) -> ComputerUseWorkerResult {
        ComputerUseWorkerResult(
            status: .failed,
            worker: kind,
            summary: summary,
            requiresConfirmation: false,
            metadata: baseMetadata(for: request)
        )
    }

    private func baseMetadata(for request: ComputerUseWorkerRequest) -> [String: String] {
        [
            "skill_id": request.plan.skillID,
            "action": request.plan.actionName,
            "worker": kind.rawValue
        ]
    }
}

private struct MoveOperation {
    let source: URL
    let destination: URL
}

private enum FileAPIWorkerError: LocalizedError {
    case destinationMissing(String)
    case destinationNotDirectory(String)
    case sourceMissing(String)
    case destinationExists(String)
    case duplicateDestination(String)

    var errorDescription: String? {
        switch self {
        case .destinationMissing(let path):
            return "Destination does not exist: \(path)"
        case .destinationNotDirectory(let path):
            return "Destination is not a directory: \(path)"
        case .sourceMissing(let path):
            return "Source does not exist: \(path)"
        case .destinationExists(let path):
            return "Destination file already exists: \(path)"
        case .duplicateDestination(let path):
            return "Multiple sources resolve to the same destination: \(path)"
        }
    }
}
