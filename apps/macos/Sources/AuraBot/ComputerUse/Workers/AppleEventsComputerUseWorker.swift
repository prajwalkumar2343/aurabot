import Foundation

struct AppleEventsComputerUseWorker: ComputerUseWorker {
    let kind: ComputerUseWorkerKind = .appleEvents

    func execute(_ request: ComputerUseWorkerRequest) async -> ComputerUseWorkerResult {
        switch (request.plan.skillID, request.plan.actionName) {
        case ("finder", "list_selection"):
            return runScript(
                finderSelectionScript,
                request: request,
                successSummary: "Read Finder selection."
            )
        case ("safari", "get_current_page"):
            return runScript(
                safariCurrentPageScript,
                request: request,
                successSummary: "Read Safari current page."
            )
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
            return failed(request, summary: "Failed to run AppleScript: \(error.localizedDescription)")
        }

        let output = readString(from: outputPipe)
        let errorOutput = readString(from: errorPipe)

        guard process.terminationStatus == 0 else {
            return ComputerUseWorkerResult(
                status: .failed,
                worker: kind,
                summary: errorOutput.isEmpty ? "AppleScript failed." : errorOutput,
                requiresConfirmation: false,
                metadata: baseMetadata(for: request).merging(["exit_code": String(process.terminationStatus)]) { current, _ in current }
            )
        }

        var metadata = baseMetadata(for: request)
        metadata["output"] = output
        return ComputerUseWorkerResult(
            status: .success,
            worker: kind,
            summary: successSummary,
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

    private func readString(from pipe: Pipe) -> String {
        String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
