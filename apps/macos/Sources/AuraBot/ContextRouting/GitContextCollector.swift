import Foundation

actor GitContextCollector {
    func collect() async -> GitContext? {
        let cwd = FileManager.default.currentDirectoryPath
        guard let rootPath = runGit(["rev-parse", "--show-toplevel"], in: cwd), !rootPath.isEmpty else {
            return nil
        }

        let branch = runGit(["branch", "--show-current"], in: rootPath)
        let status = runGit(["status", "--short"], in: rootPath) ?? ""
        let dirtyFiles = status
            .split(separator: "\n")
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return String(trimmed.dropFirst(min(3, trimmed.count)))
            }

        return GitContext(
            rootPath: rootPath,
            branch: branch?.isEmpty == true ? nil : branch,
            dirtyFiles: dirtyFiles
        )
    }

    private func runGit(_ arguments: [String], in directory: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", directory] + arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
