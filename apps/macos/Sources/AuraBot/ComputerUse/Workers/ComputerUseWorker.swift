import Foundation

struct ComputerUseWorkerRequest: Sendable {
    let plan: ComputerUseExecutionPlan
    let command: String
    let parameters: [String: String]

    init(
        plan: ComputerUseExecutionPlan,
        command: String,
        parameters: [String: String] = [:]
    ) {
        self.plan = plan
        self.command = command
        self.parameters = parameters
    }
}

struct ComputerUseWorkerResult: Equatable, Sendable {
    enum Status: String, Equatable, Sendable {
        case success
        case skipped
        case requiresConfirmation = "requires_confirmation"
        case unavailable
        case failed
    }

    let status: Status
    let worker: ComputerUseWorkerKind
    let summary: String
    let requiresConfirmation: Bool
    let metadata: [String: String]

    static func dryRun(for request: ComputerUseWorkerRequest, worker: ComputerUseWorkerKind) -> ComputerUseWorkerResult {
        ComputerUseWorkerResult(
            status: request.plan.requiresConfirmation ? .requiresConfirmation : .skipped,
            worker: worker,
            summary: "Dry run for \(request.plan.appName).\(request.plan.actionName) using \(worker.rawValue)",
            requiresConfirmation: request.plan.requiresConfirmation,
            metadata: [
                "skill_id": request.plan.skillID,
                "action": request.plan.actionName,
                "parallel_safe": String(request.plan.parallelSafe),
                "requires_focus": request.plan.requiresFocus.rawValue
            ]
        )
    }
}

protocol ComputerUseWorker: Sendable {
    var kind: ComputerUseWorkerKind { get }

    func execute(_ request: ComputerUseWorkerRequest) async -> ComputerUseWorkerResult
}

struct DryRunComputerUseWorker: ComputerUseWorker {
    let kind: ComputerUseWorkerKind

    func execute(_ request: ComputerUseWorkerRequest) async -> ComputerUseWorkerResult {
        ComputerUseWorkerResult.dryRun(for: request, worker: kind)
    }
}

struct ComputerUseWorkerRegistry: Sendable {
    private let workers: [ComputerUseWorkerKind: any ComputerUseWorker]

    init(workers: [any ComputerUseWorker]) {
        self.workers = Dictionary(uniqueKeysWithValues: workers.map { ($0.kind, $0) })
    }

    static func dryRunDefault() -> ComputerUseWorkerRegistry {
        ComputerUseWorkerRegistry(
            workers: ComputerUseWorkerKind.allCases.map {
                DryRunComputerUseWorker(kind: $0)
            }
        )
    }

    static func localDefault(
        accessibilityPermissionChecker: (any AccessibilityPermissionChecking)? = nil,
        accessibilityTreeReader: (any AccessibilityTreeReading)? = nil,
        browserContextProvider: (any BrowserContextProviding)? = nil
    ) -> ComputerUseWorkerRegistry {
        var workers: [any ComputerUseWorker] = ComputerUseWorkerKind.allCases.map {
            DryRunComputerUseWorker(kind: $0)
        }

        workers.removeAll {
            $0.kind == .accessibility ||
            $0.kind == .appleEvents ||
                $0.kind == .browserExtension ||
                $0.kind == .fileAPI
        }
        workers.append(
            AccessibilityComputerUseWorker(
                permissionChecker: accessibilityPermissionChecker ?? SystemAccessibilityPermissionChecker(),
                treeReader: accessibilityTreeReader ?? AXAccessibilityTreeReader()
            )
        )
        workers.append(AppleEventsComputerUseWorker())
        workers.append(
            BrowserExtensionComputerUseWorker(
                contextProvider: browserContextProvider ?? EmptyBrowserContextProvider()
            )
        )
        workers.append(FileAPIComputerUseWorker())

        return ComputerUseWorkerRegistry(workers: workers)
    }

    func worker(for kind: ComputerUseWorkerKind) -> (any ComputerUseWorker)? {
        workers[kind]
    }

    func worker(for plan: ComputerUseExecutionPlan) -> (any ComputerUseWorker)? {
        worker(for: plan.worker)
    }
}
