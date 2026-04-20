import Foundation

struct AppleScriptRunResult: Sendable {
    let terminationStatus: Int32
    let output: String
    let errorOutput: String
}

protocol AppleScriptRunning: Sendable {
    func run(_ script: String) -> AppleScriptRunResult
}

struct ProcessAppleScriptRunner: AppleScriptRunning {
    func run(_ script: String) -> AppleScriptRunResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return AppleScriptRunResult(
                terminationStatus: 1,
                output: "",
                errorOutput: "Failed to run AppleScript: \(error.localizedDescription)"
            )
        }

        return AppleScriptRunResult(
            terminationStatus: process.terminationStatus,
            output: readString(from: outputPipe),
            errorOutput: readString(from: errorPipe)
        )
    }

    private func readString(from pipe: Pipe) -> String {
        String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

struct StaticAppleScriptRunner: AppleScriptRunning {
    let result: AppleScriptRunResult

    func run(_ script: String) -> AppleScriptRunResult {
        result
    }
}

struct AppleEventsComputerUseWorker: ComputerUseWorker {
    let kind: ComputerUseWorkerKind = .appleEvents

    private let runner: any AppleScriptRunning

    init(runner: any AppleScriptRunning = ProcessAppleScriptRunner()) {
        self.runner = runner
    }

    func execute(_ request: ComputerUseWorkerRequest) async -> ComputerUseWorkerResult {
        switch (request.plan.skillID, request.plan.actionName) {
        case ("finder", "list_selection"):
            return runScript(
                finderSelectionScript,
                request: request,
                successSummary: "Read Finder selection."
            )
        case ("safari", "get_current_page"):
            return readSafariCurrentPage(request)
        default:
            return ComputerUseWorkerResult(
                status: .unavailable,
                worker: kind,
                summary: "Apple Events worker does not support \(request.plan.skillID).\(request.plan.actionName).",
                requiresConfirmation: false,
                metadata: baseMetadata(for: request).merging(["reason": "unsupported_apple_events_action"]) { current, _ in current }
            )
        }
    }

    private func runScript(
        _ script: String,
        request: ComputerUseWorkerRequest,
        successSummary: String
    ) -> ComputerUseWorkerResult {
        let result = runner.run(script)
        guard result.terminationStatus == 0 else {
            return scriptFailed(request, result: result)
        }

        var metadata = baseMetadata(for: request)
        metadata["output"] = result.output
        return ComputerUseWorkerResult(
            status: .success,
            worker: kind,
            summary: successSummary,
            requiresConfirmation: false,
            metadata: metadata
        )
    }

    private func readSafariCurrentPage(_ request: ComputerUseWorkerRequest) -> ComputerUseWorkerResult {
        let result = runner.run(safariCurrentPageScript)
        guard result.terminationStatus == 0 else {
            return scriptFailed(request, result: result)
        }

        let lines = result.output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let url = lines.first.flatMap { $0.isEmpty ? nil : $0 }
        let title = lines.dropFirst().joined(separator: "\n")

        var metadata = baseMetadata(for: request)
        metadata["output"] = result.output

        if let url {
            metadata["url"] = url
            if let components = URLComponents(string: url) {
                metadata["page_id"] = BrowserContextService.normalizedPageID(for: components)
            }
        }
        if !title.isEmpty {
            metadata["title"] = title
        }

        return ComputerUseWorkerResult(
            status: .success,
            worker: kind,
            summary: "Read Safari current page.",
            requiresConfirmation: false,
            metadata: metadata
        )
    }

    private var finderSelectionScript: String {
        """
        tell application "Finder"
            set selectedItems to selection
            set output to ""
            repeat with itemRef in selectedItems
                try
                    set output to output & POSIX path of (itemRef as alias) & linefeed
                end try
            end repeat
            return output
        end tell
        """
    }

    private var safariCurrentPageScript: String {
        """
        tell application "Safari"
            if not (exists front document) then return ""
            set pageURL to URL of front document
            set pageTitle to name of front document
            return pageURL & linefeed & pageTitle
        end tell
        """
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

    private func scriptFailed(
        _ request: ComputerUseWorkerRequest,
        result: AppleScriptRunResult
    ) -> ComputerUseWorkerResult {
        ComputerUseWorkerResult(
            status: .failed,
            worker: kind,
            summary: result.errorOutput.isEmpty ? "AppleScript failed." : result.errorOutput,
            requiresConfirmation: false,
            metadata: baseMetadata(for: request).merging(["exit_code": String(result.terminationStatus)]) { current, _ in current }
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
