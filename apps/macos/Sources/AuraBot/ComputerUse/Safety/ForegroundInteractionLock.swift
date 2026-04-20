import Foundation

actor ComputerUseForegroundInteractionLock {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func withLock<T: Sendable>(
        required: Bool,
        operation: @Sendable () async -> T
    ) async -> T {
        guard required else {
            return await operation()
        }

        await acquire()
        let result = await operation()
        release()
        return result
    }

    private func acquire() async {
        if !isLocked {
            isLocked = true
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        guard !waiters.isEmpty else {
            isLocked = false
            return
        }

        let next = waiters.removeFirst()
        next.resume()
    }
}
