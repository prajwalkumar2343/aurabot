import Foundation

struct ComputerUseConfirmationPolicy: Sendable {
    func requiresConfirmation(_ request: ComputerUseWorkerRequest) -> Bool {
        request.plan.requiresConfirmation || request.plan.destructive
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
