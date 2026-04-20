import Foundation

struct ComputerUseConfirmationPolicy: Sendable {
    private let destructiveActionDetector: ComputerUseDestructiveActionDetector

    init(destructiveActionDetector: ComputerUseDestructiveActionDetector = ComputerUseDestructiveActionDetector()) {
        self.destructiveActionDetector = destructiveActionDetector
    }

    func requiresConfirmation(_ request: ComputerUseWorkerRequest) -> Bool {
        request.plan.requiresConfirmation || isDestructive(request)
    }

    func isDestructive(_ request: ComputerUseWorkerRequest) -> Bool {
        destructiveActionDetector.isDestructive(request)
    }

    func isConfirmed(_ request: ComputerUseWorkerRequest) -> Bool {
        let value = request.parameters["confirmed"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return value == "true" || value == "yes" || value == "1"
    }

    func shouldBlock(_ request: ComputerUseWorkerRequest) -> Bool {
        requiresConfirmation(request) && !isConfirmed(request)
    }
}

struct ComputerUseDestructiveActionDetector: Sendable {
    private let destructiveActionNames: Set<String> = [
        "delete",
        "delete_files",
        "erase",
        "remove",
        "remove_files",
        "trash"
    ]

    private let destructiveCommandTokens: Set<String> = [
        "delete",
        "destroy",
        "erase",
        "remove",
        "rm",
        "trash",
        "wipe"
    ]

    func isDestructive(_ request: ComputerUseWorkerRequest) -> Bool {
        if request.plan.destructive {
            return true
        }

        if destructiveActionNames.contains(request.plan.actionName.lowercased()) {
            return true
        }

        let commandTokens = request.command
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)

        return commandTokens.contains { destructiveCommandTokens.contains($0) }
    }
}
