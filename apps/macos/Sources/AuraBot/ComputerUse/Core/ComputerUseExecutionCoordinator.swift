import Foundation

struct ComputerUseExecutionCoordinator: Sendable {
    private let registry: ComputerUseWorkerRegistry
    private let confirmationPolicy: ComputerUseConfirmationPolicy
    private let foregroundLock: ComputerUseForegroundInteractionLock
    private let auditLog: any ComputerUseAuditLogging
    private let now: @Sendable () -> Date

    init(
        registry: ComputerUseWorkerRegistry,
        confirmationPolicy: ComputerUseConfirmationPolicy = ComputerUseConfirmationPolicy(),
        foregroundLock: ComputerUseForegroundInteractionLock = ComputerUseForegroundInteractionLock(),
        auditLog: any ComputerUseAuditLogging = NoOpComputerUseAuditLog(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.registry = registry
        self.confirmationPolicy = confirmationPolicy
        self.foregroundLock = foregroundLock
        self.auditLog = auditLog
        self.now = now
    }

    func execute(_ request: ComputerUseWorkerRequest) async -> ComputerUseWorkerResult {
        await record(.requested, request: request)

        guard !confirmationPolicy.shouldBlock(request) else {
            let result = ComputerUseWorkerResult(
                status: .requiresConfirmation,
                worker: request.plan.worker,
                summary: "Confirmation required before \(request.plan.appName).\(request.plan.actionName)",
                requiresConfirmation: true,
                metadata: baseMetadata(for: request, extra: ["reason": "confirmation_required"])
            )
            await record(.blocked, request: request, result: result)
            return result
        }

        guard let worker = registry.worker(for: request.plan) else {
            let result = ComputerUseWorkerResult(
                status: .unavailable,
                worker: request.plan.worker,
                summary: "No worker is registered for \(request.plan.worker.rawValue).",
                requiresConfirmation: false,
                metadata: baseMetadata(for: request, extra: ["reason": "worker_unavailable"])
            )
            await record(.completed, request: request, result: result)
            return result
        }

        await record(.started, request: request)
        let result = await foregroundLock.withLock(required: request.plan.requiresForegroundLock) {
            await worker.execute(request)
        }
        await record(.completed, request: request, result: result)
        return result
    }

    private func record(
        _ phase: ComputerUseAuditRecord.Phase,
        request: ComputerUseWorkerRequest,
        result: ComputerUseWorkerResult? = nil
    ) async {
        await auditLog.record(
            ComputerUseAuditRecord(
                phase: phase,
                timestamp: now(),
                skillID: request.plan.skillID,
                appName: request.plan.appName,
                actionName: request.plan.actionName,
                worker: result?.worker ?? request.plan.worker,
                status: result?.status,
                requiresConfirmation: confirmationPolicy.requiresConfirmation(request),
                destructive: confirmationPolicy.isDestructive(request),
                requiresForegroundLock: request.plan.requiresForegroundLock,
                command: request.command,
                metadata: result?.metadata ?? baseMetadata(for: request)
            )
        )
    }

    private func baseMetadata(
        for request: ComputerUseWorkerRequest,
        extra: [String: String] = [:]
    ) -> [String: String] {
        [
            "skill_id": request.plan.skillID,
            "action": request.plan.actionName,
            "worker": request.plan.worker.rawValue
        ].merging(extra) { current, _ in current }
    }
}
