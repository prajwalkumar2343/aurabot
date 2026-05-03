import Foundation

actor CuaDriverService {
    private var config: ComputerUseConfig
    private let installationManager: CuaDriverInstallationManager
    private let runner: any CuaDriverProcessRunning
    private let session: URLSession

    init(
        config: ComputerUseConfig,
        installationManager: CuaDriverInstallationManager = CuaDriverInstallationManager(),
        runner: any CuaDriverProcessRunning = CuaDriverProcessRunner(),
        session: URLSession = .shared
    ) {
        self.config = config
        self.installationManager = installationManager
        self.runner = runner
        self.session = session
    }

    func updateConfig(_ config: ComputerUseConfig) {
        self.config = config
    }

    func refreshStatus() async -> CuaDriverStatus {
        guard config.enabled else {
            return .disabled
        }

        let bundledVersion = installationManager.bundledVersion()
        guard FileManager.default.fileExists(atPath: installationManager.installedAppURL.path) else {
            return CuaDriverStatus(
                state: .notInstalled,
                installedVersion: nil,
                bundledVersion: bundledVersion,
                updateVersion: nil,
                daemonRunning: false,
                permissions: CuaDriverPermissionStatus(accessibility: false, screenRecording: false),
                message: "Computer Use is ready to install."
            )
        }

        let permissions = await checkPermissions(prompt: false)
        let daemon = await daemonStatus()
        let state: CuaDriverStatus.State = permissions.isReady
            ? (daemon.succeeded ? .ready : .installed)
            : .needsPermission

        return CuaDriverStatus(
            state: state,
            installedVersion: installationManager.installedVersion(),
            bundledVersion: bundledVersion,
            updateVersion: nil,
            daemonRunning: daemon.succeeded,
            permissions: permissions,
            message: state == .ready
                ? "Computer Use is ready."
                : "AuraBot needs Accessibility and Screen Recording permission for Computer Use."
        )
    }

    func installIfNeeded() async -> CuaDriverStatus {
        do {
            _ = try installationManager.installIfNeeded()
            if config.autoStart {
                _ = await startDaemon()
            }
            return await refreshStatus()
        } catch {
            return failedStatus(error)
        }
    }

    func repair() async -> CuaDriverStatus {
        do {
            _ = try installationManager.repairInstall()
            if config.autoStart {
                _ = await startDaemon()
            }
            return await refreshStatus()
        } catch {
            return failedStatus(error)
        }
    }

    func startDaemon() async -> CuaDriverToolResult {
        do {
            _ = try installationManager.installIfNeeded()
            try FileManager.default.createDirectory(
                at: installationManager.socketURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let executable = try installationManager.installedExecutableURL()
            try runner.launch(
                executableURL: executable,
                arguments: ["serve", "--socket", installationManager.socketURL.path, "--no-relaunch"],
                environment: environment(),
                currentDirectoryURL: installationManager.installedAppURL.deletingLastPathComponent()
            )

            return CuaDriverToolResult(exitCode: 0, output: "starting", errorOutput: "")
        } catch {
            return CuaDriverToolResult(
                exitCode: 1,
                output: "",
                errorOutput: auraMessage(for: error)
            )
        }
    }

    func stopDaemon() async -> CuaDriverToolResult {
        await runDriver(arguments: ["stop", "--socket", installationManager.socketURL.path], timeoutSeconds: 5)
    }

    func daemonStatus() async -> CuaDriverToolResult {
        await runDriver(arguments: ["status", "--socket", installationManager.socketURL.path], timeoutSeconds: 5)
    }

    func checkPermissions(prompt: Bool) async -> CuaDriverPermissionStatus {
        let result = await callTool(
            "check_permissions",
            arguments: ["prompt": prompt],
            timeoutSeconds: 10
        )

        guard let data = result.output.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return CuaDriverPermissionStatus(accessibility: false, screenRecording: false)
        }

        let structured = object["structuredContent"] as? [String: Any] ?? object
        return CuaDriverPermissionStatus(
            accessibility: boolValue(
                structured["accessibility"] ??
                structured["accessibility_granted"] ??
                structured["accessibilityTrusted"]
            ),
            screenRecording: boolValue(
                structured["screen_recording"] ??
                structured["screenRecording"] ??
                structured["screen_recording_granted"]
            )
        )
    }

    func listApps() async -> CuaDriverToolResult {
        await callTool("list_apps", arguments: [:])
    }

    func listWindows() async -> CuaDriverToolResult {
        await callTool("list_windows", arguments: [:])
    }

    func getWindowState(pid: Int, windowID: Int, maxImageDimension: Int? = nil) async -> CuaDriverToolResult {
        var args: [String: Any] = ["pid": pid, "window_id": windowID]
        if let maxImageDimension {
            args["max_image_dimension"] = maxImageDimension
        }
        return await callTool("get_window_state", arguments: args, timeoutSeconds: 30)
    }

    func click(pid: Int, windowID: Int? = nil, elementIndex: Int? = nil, x: Double? = nil, y: Double? = nil) async -> CuaDriverToolResult {
        var args: [String: Any] = ["pid": pid]
        if let windowID { args["window_id"] = windowID }
        if let elementIndex { args["element_index"] = elementIndex }
        if let x { args["x"] = x }
        if let y { args["y"] = y }
        return await callTool("click", arguments: args)
    }

    func typeText(pid: Int, text: String, windowID: Int? = nil, elementIndex: Int? = nil) async -> CuaDriverToolResult {
        var args: [String: Any] = ["pid": pid, "text": text]
        if let windowID { args["window_id"] = windowID }
        if let elementIndex { args["element_index"] = elementIndex }
        return await callTool("type_text", arguments: args)
    }

    func hotkey(pid: Int, key: String, modifiers: [String] = []) async -> CuaDriverToolResult {
        await callTool("hotkey", arguments: ["pid": pid, "key": key, "modifiers": modifiers])
    }

    func screenshot(windowID: Int, outputURL: URL) async -> CuaDriverToolResult {
        await runDriver(
            arguments: [
                "call",
                "screenshot",
                "{\"window_id\":\(windowID),\"format\":\"png\"}",
                "--raw",
                "--compact",
                "--screenshot-out-file",
                outputURL.path,
                "--socket",
                installationManager.socketURL.path
            ],
            timeoutSeconds: 30
        )
    }

    func startRecording() async -> CuaDriverToolResult {
        await callTool(
            "set_recording",
            arguments: [
                "enabled": true,
                "output_dir": installationManager.recordingDirectory.path
            ]
        )
    }

    func stopRecording() async -> CuaDriverToolResult {
        await callTool("set_recording", arguments: ["enabled": false])
    }

    func runSafeSmokeTest() async -> CuaDriverStatus {
        _ = await installIfNeeded()
        let permissions = await checkPermissions(prompt: false)
        guard permissions.isReady else {
            return CuaDriverStatus(
                state: .needsPermission,
                installedVersion: installationManager.installedVersion(),
                bundledVersion: installationManager.bundledVersion(),
                updateVersion: nil,
                daemonRunning: false,
                permissions: permissions,
                message: "AuraBot needs Accessibility and Screen Recording permission for Computer Use."
            )
        }

        let result = await listWindows()
        if result.succeeded {
            return await refreshStatus()
        }
        return failedStatus(CuaDriverError.processFailed(auraMessage(for: result)))
    }

    func checkForUpdates() async -> CuaDriverStatus {
        guard config.allowUpdateChecks else {
            var status = await refreshStatus()
            status.message = "Computer Use update checks are disabled."
            return status
        }

        do {
            guard let update = try await latestUpdateInfo() else {
                var status = await refreshStatus()
                status.message = "Computer Use is up to date."
                return status
            }

            var status = await refreshStatus()
            status.state = .updateAvailable
            status.updateVersion = update.version
            status.message = "An AuraBot computer-use engine update is available."
            return status
        } catch {
            return failedStatus(error)
        }
    }

    func installUpdate() async -> CuaDriverStatus {
        do {
            guard let update = try await latestUpdateInfo() else {
                throw CuaDriverError.updateUnavailable
            }

            let (archiveURL, _) = try await session.download(from: URL(string: update.downloadURL)!)
            let actual = try sha256Hex(for: archiveURL)
            guard actual == update.sha256 else {
                throw CuaDriverError.checksumMismatch(expected: update.sha256, actual: actual)
            }

            let extractDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("aurabot-cua-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: extractDirectory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: extractDirectory) }

            let tarResult = await CuaDriverProcessRunner().run(
                executableURL: URL(fileURLWithPath: "/usr/bin/tar"),
                arguments: ["-xzf", archiveURL.path, "-C", extractDirectory.path],
                environment: ProcessInfo.processInfo.environment,
                currentDirectoryURL: nil,
                timeoutSeconds: 30
            )
            guard tarResult.succeeded else {
                throw CuaDriverError.processFailed(auraMessage(for: tarResult))
            }

            let appURL = extractDirectory.appendingPathComponent("CuaDriver.app", isDirectory: true)
            _ = try installationManager.installApp(from: appURL)
            if config.autoStart {
                _ = await startDaemon()
            }

            var status = await refreshStatus()
            status.message = "AuraBot Computer Use was updated."
            return status
        } catch {
            return failedStatus(error)
        }
    }

    private func callTool(
        _ name: String,
        arguments: [String: Any],
        timeoutSeconds: TimeInterval = 15
    ) async -> CuaDriverToolResult {
        let json = (try? JSONSerialization.data(withJSONObject: arguments))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return await runDriver(
            arguments: [
                "call",
                name,
                json,
                "--raw",
                "--compact",
                "--socket",
                installationManager.socketURL.path
            ],
            timeoutSeconds: timeoutSeconds
        )
    }

    private func runDriver(arguments: [String], timeoutSeconds: TimeInterval) async -> CuaDriverToolResult {
        do {
            let executable = try installationManager.installedExecutableURL()
            let result = await runner.run(
                executableURL: executable,
                arguments: arguments,
                environment: environment(),
                currentDirectoryURL: installationManager.installedAppURL.deletingLastPathComponent(),
                timeoutSeconds: timeoutSeconds
            )
            if result.succeeded {
                return result
            }
            return CuaDriverToolResult(
                exitCode: result.exitCode,
                output: result.output,
                errorOutput: auraMessage(for: result)
            )
        } catch {
            return CuaDriverToolResult(exitCode: 1, output: "", errorOutput: auraMessage(for: error))
        }
    }

    private func latestUpdateInfo() async throws -> CuaDriverUpdateInfo? {
        guard let url = URL(string: "https://api.github.com/repos/trycua/cua/releases") else {
            throw URLError(.badURL)
        }

        let (data, _) = try await session.data(from: url)
        guard let releases = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }

        let installed = installationManager.installedVersion() ?? config.installedVersion
        for release in releases {
            guard let tag = release["tag_name"] as? String,
                  tag.hasPrefix("cua-driver-v"),
                  let body = release["body"] as? String,
                  let assets = release["assets"] as? [[String: Any]] else {
                continue
            }
            let version = tag.replacingOccurrences(of: "cua-driver-v", with: "")
            guard version.compare(installed, options: .numeric) == .orderedDescending else {
                return nil
            }

            let architecture = currentArchitecture()
            let assetName = "cua-driver-\(version)-darwin-\(architecture).tar.gz"
            guard let asset = assets.first(where: { ($0["name"] as? String) == assetName }),
                  let downloadURL = asset["browser_download_url"] as? String,
                  let sha = sha256(for: assetName, in: body) else {
                continue
            }
            return CuaDriverUpdateInfo(version: version, tag: tag, downloadURL: downloadURL, sha256: sha)
        }

        return nil
    }

    private func sha256(for assetName: String, in body: String) -> String? {
        body.components(separatedBy: .newlines).compactMap { line in
            let pieces = line.split(separator: " ").map(String.init)
            guard pieces.count >= 2, pieces.last == assetName else { return nil }
            return pieces.first
        }.first
    }

    private func sha256Hex(for url: URL) throws -> String {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shasum")
        process.arguments = ["-a", "256", url.path]
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return output.split(separator: " ").first.map(String.init) ?? ""
    }

    private func boolValue(_ value: Any?) -> Bool {
        switch value {
        case let bool as Bool:
            return bool
        case let string as String:
            return ["true", "granted", "authorized", "yes"].contains(string.lowercased())
        case let number as NSNumber:
            return number.boolValue
        default:
            return false
        }
    }

    private func failedStatus(_ error: Error) -> CuaDriverStatus {
        CuaDriverStatus(
            state: .failed,
            installedVersion: installationManager.installedVersion(),
            bundledVersion: installationManager.bundledVersion(),
            updateVersion: nil,
            daemonRunning: false,
            permissions: CuaDriverPermissionStatus(accessibility: false, screenRecording: false),
            message: auraMessage(for: error)
        )
    }

    private func auraMessage(for result: CuaDriverToolResult) -> String {
        auraMessage(for: result.errorOutput.isEmpty ? result.output : result.errorOutput)
    }

    private func auraMessage(for error: Error) -> String {
        auraMessage(for: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
    }

    private func auraMessage(for raw: String) -> String {
        let message = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            return "AuraBot Computer Use could not complete the request."
        }
        return message
            .replacingOccurrences(of: "Cua Driver", with: "AuraBot Computer Use")
            .replacingOccurrences(of: "CuaDriver", with: "AuraBot Computer Use")
            .replacingOccurrences(of: "cua-driver", with: "AuraBot Computer Use")
            .replacingOccurrences(of: "com.trycua.driver", with: "AuraBot")
    }

    private func environment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["CUA_DRIVER_NO_RELAUNCH"] = "1"
        let executableDirectory = (try? installationManager.installedExecutableURL().deletingLastPathComponent().path)
        environment["PATH"] = [
            executableDirectory,
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            environment["PATH"] ?? ""
        ].compactMap { $0 }.joined(separator: ":")
        return environment
    }

    private func currentArchitecture() -> String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x64"
        #endif
    }
}
