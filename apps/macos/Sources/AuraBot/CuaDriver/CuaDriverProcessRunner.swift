import Foundation

protocol CuaDriverProcessRunning: Sendable {
    func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        currentDirectoryURL: URL?,
        timeoutSeconds: TimeInterval
    ) async -> CuaDriverToolResult

    func launch(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        currentDirectoryURL: URL?
    ) throws
}

struct CuaDriverProcessRunner: CuaDriverProcessRunning, Sendable {
    func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        currentDirectoryURL: URL? = nil,
        timeoutSeconds: TimeInterval = 15
    ) async -> CuaDriverToolResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryURL = currentDirectoryURL

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            return CuaDriverToolResult(
                exitCode: 1,
                output: "",
                errorOutput: "AuraBot Computer Use could not start: \(error.localizedDescription)"
            )
        }

        let didExit = await waitForExit(process, timeoutSeconds: timeoutSeconds)
        if !didExit {
            process.terminate()
            return CuaDriverToolResult(
                exitCode: 124,
                output: readString(from: outputPipe),
                errorOutput: "AuraBot Computer Use timed out."
            )
        }

        return CuaDriverToolResult(
            exitCode: process.terminationStatus,
            output: readString(from: outputPipe),
            errorOutput: readString(from: errorPipe)
        )
    }

    func launch(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        currentDirectoryURL: URL? = nil
    ) throws {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryURL = currentDirectoryURL

        let logHandle = try makeLogHandle()
        process.standardOutput = logHandle
        process.standardError = logHandle
        try process.run()
    }

    private func waitForExit(_ process: Process, timeoutSeconds: TimeInterval) async -> Bool {
        if !process.isRunning {
            return true
        }

        return await withCheckedContinuation { continuation in
            let box = ProcessWaitContinuationBox(continuation)
            DispatchQueue.global(qos: .utility).async {
                process.waitUntilExit()
                box.resume(true)
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeoutSeconds) {
                box.resume(false)
            }
        }
    }

    private func readString(from pipe: Pipe) -> String {
        String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func makeLogHandle() throws -> FileHandle {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("AuraBot", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let logURL = directory.appendingPathComponent("computer-use.log")
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }

        let handle = try FileHandle(forWritingTo: logURL)
        try handle.seekToEnd()
        return handle
    }
}

private final class ProcessWaitContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Bool, Never>?

    init(_ continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: Bool) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: value)
    }
}
