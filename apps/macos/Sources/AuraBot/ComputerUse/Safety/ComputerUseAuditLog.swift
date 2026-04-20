import Foundation

struct ComputerUseAuditRecord: Codable, Equatable, Sendable {
    enum Phase: String, Codable, Sendable {
        case requested
        case blocked
        case started
        case completed
    }

    let phase: Phase
    let timestamp: Date
    let skillID: String
    let appName: String
    let actionName: String
    let worker: ComputerUseWorkerKind
    let status: ComputerUseWorkerResult.Status?
    let requiresConfirmation: Bool
    let destructive: Bool
    let requiresForegroundLock: Bool
    let command: String
    let metadata: [String: String]
}

protocol ComputerUseAuditLogging: Sendable {
    func record(_ record: ComputerUseAuditRecord) async
}

actor InMemoryComputerUseAuditLog: ComputerUseAuditLogging {
    private var records: [ComputerUseAuditRecord] = []

    func record(_ record: ComputerUseAuditRecord) {
        records.append(record)
    }

    func allRecords() -> [ComputerUseAuditRecord] {
        records
    }
}

struct NoOpComputerUseAuditLog: ComputerUseAuditLogging {
    func record(_ record: ComputerUseAuditRecord) async {}
}
