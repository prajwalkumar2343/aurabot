import Foundation

actor ComputerUseService {
    private var config: ComputerUseConfig
    private let tools: any ComputerUseToolCalling
    private let recordingDirectory: URL

    init(
        config: ComputerUseConfig,
        tools: any ComputerUseToolCalling = CuaToolRegistryAdapter(),
        recordingDirectory: URL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("AuraBot", isDirectory: true)
            .appendingPathComponent("ComputerUseTrajectories", isDirectory: true)
            ?? FileManager.default.temporaryDirectory
                .appendingPathComponent("AuraBot", isDirectory: true)
                .appendingPathComponent("ComputerUseTrajectories", isDirectory: true)
    ) {
        self.config = config
        self.tools = tools
        self.recordingDirectory = recordingDirectory
    }

    func updateConfig(_ config: ComputerUseConfig) {
        self.config = config
    }

    func refreshStatus() async -> ComputerUseStatus {
        guard config.enabled else {
            return .disabled
        }

        let configResult = await syncConfiguration()
        guard configResult.succeeded else {
            return failedStatus(ComputerUseError.toolFailed(auraMessage(for: configResult)))
        }

        let permissions: ComputerUsePermissionStatus
        do {
            permissions = try await checkPermissions(prompt: false)
        } catch {
            return failedStatus(error)
        }

        if permissions.isReady {
            return ComputerUseStatus(
                state: .ready,
                permissions: permissions,
                message: "Computer Use is ready."
            )
        }

        return ComputerUseStatus(
            state: .needsPermission,
            permissions: permissions,
            message: "AuraBot needs Accessibility and Screen Recording permission for Computer Use."
        )
    }

    func checkPermissions(prompt: Bool) async throws -> ComputerUsePermissionStatus {
        let result = await callTool(
            "check_permissions",
            arguments: ["prompt": .bool(prompt)]
        )
        guard result.succeeded else {
            throw ComputerUseError.toolFailed(auraMessage(for: result))
        }
        return parsePermissions(from: result)
    }

    func listApps() async -> ComputerUseToolResult {
        await callTool("list_apps", arguments: [:])
    }

    func listWindows() async -> ComputerUseToolResult {
        await callTool("list_windows", arguments: [:])
    }

    func getWindowState(pid: Int, windowID: Int, maxImageDimension: Int? = nil) async -> ComputerUseToolResult {
        let configResult = await syncConfiguration(maxImageDimension: maxImageDimension)
        guard configResult.succeeded else {
            return configResult
        }

        let args: [String: ComputerUseArgument] = [
            "pid": .int(pid),
            "window_id": .int(windowID),
        ]
        return await callTool("get_window_state", arguments: args)
    }

    func click(
        pid: Int,
        windowID: Int? = nil,
        elementIndex: Int? = nil,
        x: Double? = nil,
        y: Double? = nil
    ) async -> ComputerUseToolResult {
        var args: [String: ComputerUseArgument] = ["pid": .int(pid)]
        if let windowID { args["window_id"] = .int(windowID) }
        if let elementIndex { args["element_index"] = .int(elementIndex) }
        if let x { args["x"] = .double(x) }
        if let y { args["y"] = .double(y) }
        return await callTool("click", arguments: args)
    }

    func typeText(pid: Int, text: String, windowID: Int? = nil, elementIndex: Int? = nil) async -> ComputerUseToolResult {
        var args: [String: ComputerUseArgument] = [
            "pid": .int(pid),
            "text": .string(text),
        ]
        if let windowID { args["window_id"] = .int(windowID) }
        if let elementIndex { args["element_index"] = .int(elementIndex) }
        return await callTool("type_text", arguments: args)
    }

    func hotkey(pid: Int, key: String, modifiers: [String] = []) async -> ComputerUseToolResult {
        await callTool(
            "hotkey",
            arguments: [
                "pid": .int(pid),
                "key": .string(key),
                "modifiers": .array(modifiers.map(ComputerUseArgument.string)),
            ]
        )
    }

    func screenshot(windowID: Int, outputURL: URL) async -> ComputerUseToolResult {
        let configResult = await syncConfiguration()
        guard configResult.succeeded else {
            return configResult
        }

        let result = await callTool(
            "screenshot",
            arguments: [
                "window_id": .int(windowID),
                "format": .string("png"),
            ]
        )
        guard result.succeeded else {
            return result
        }
        guard let imageData = result.imageData else {
            return .failure(auraMessage(for: ComputerUseError.screenshotDataMissing))
        }

        do {
            try imageData.write(to: outputURL)
            var saved = result
            saved.output = outputURL.path
            return saved
        } catch {
            return .failure(auraMessage(for: error))
        }
    }

    func startRecording() async -> ComputerUseToolResult {
        do {
            try FileManager.default.createDirectory(at: recordingDirectory, withIntermediateDirectories: true)
        } catch {
            return .failure(auraMessage(for: error))
        }

        return await callTool(
            "set_recording",
            arguments: [
                "enabled": .bool(true),
                "output_dir": .string(recordingDirectory.path),
            ]
        )
    }

    func stopRecording() async -> ComputerUseToolResult {
        await callTool("set_recording", arguments: ["enabled": .bool(false)])
    }

    func runSafeSmokeTest() async -> ComputerUseStatus {
        guard config.enabled else {
            return .disabled
        }

        let configResult = await syncConfiguration()
        guard configResult.succeeded else {
            return failedStatus(ComputerUseError.toolFailed(auraMessage(for: configResult)))
        }

        let permissions: ComputerUsePermissionStatus
        do {
            permissions = try await checkPermissions(prompt: false)
        } catch {
            return failedStatus(error)
        }

        guard permissions.isReady else {
            return ComputerUseStatus(
                state: .needsPermission,
                permissions: permissions,
                message: "AuraBot needs Accessibility and Screen Recording permission for Computer Use."
            )
        }

        let result = await listWindows()
        if result.succeeded {
            return ComputerUseStatus(
                state: .ready,
                permissions: permissions,
                message: "Computer Use test passed."
            )
        }

        return failedStatus(ComputerUseError.toolFailed(auraMessage(for: result)))
    }

    private func syncConfiguration(maxImageDimension override: Int? = nil) async -> ComputerUseToolResult {
        let modeResult = await callTool(
            "set_config",
            arguments: [
                "key": .string("capture_mode"),
                "value": .string(config.captureMode.rawValue),
            ]
        )
        guard modeResult.succeeded else {
            return modeResult
        }

        return await callTool(
            "set_config",
            arguments: [
                "key": .string("max_image_dimension"),
                "value": .int(override ?? config.maxImageDimension),
            ]
        )
    }

    private func callTool(
        _ name: String,
        arguments: [String: ComputerUseArgument]
    ) async -> ComputerUseToolResult {
        do {
            let result = try await tools.call(name, arguments: arguments)
            if result.succeeded {
                return result
            }
            return .failure(auraMessage(for: result))
        } catch {
            return .failure(auraMessage(for: error))
        }
    }

    private func parsePermissions(from result: ComputerUseToolResult) -> ComputerUsePermissionStatus {
        if case .object(let structured)? = result.structuredContent {
            return ComputerUsePermissionStatus(
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

        return ComputerUsePermissionStatus(
            accessibility: permissionLineValue(label: "Accessibility", in: result.output),
            screenRecording: permissionLineValue(label: "Screen Recording", in: result.output)
        )
    }

    private func permissionLineValue(label: String, in text: String) -> Bool {
        let label = label.lowercased()
        for line in text.components(separatedBy: .newlines) {
            let lower = line.lowercased()
            guard lower.contains(label) else { continue }
            if lower.contains("not granted") || lower.contains("denied") || lower.contains("missing") {
                return false
            }
            if lower.contains("granted") || lower.contains("authorized") || lower.contains("allowed") {
                return true
            }
        }
        return false
    }

    private func boolValue(_ value: ComputerUseArgument?) -> Bool {
        switch value {
        case .bool(let bool):
            return bool
        case .string(let string):
            return ["true", "granted", "authorized", "allowed", "yes"].contains(string.lowercased())
        case .int(let int):
            return int != 0
        case .double(let double):
            return double != 0
        default:
            return false
        }
    }

    private func failedStatus(_ error: Error) -> ComputerUseStatus {
        ComputerUseStatus(
            state: .failed,
            permissions: ComputerUsePermissionStatus(accessibility: false, screenRecording: false),
            message: auraMessage(for: error)
        )
    }

    private func auraMessage(for result: ComputerUseToolResult) -> String {
        auraMessage(for: result.errorOutput.isEmpty ? result.output : result.errorOutput)
    }

    private func auraMessage(for error: Error) -> String {
        auraMessage(for: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
    }

    private func auraMessage(for raw: String) -> String {
        let message = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            return "Computer Use could not complete the request."
        }
        return message
            .replacingOccurrences(of: "Cua Driver", with: "AuraBot Computer Use")
            .replacingOccurrences(of: "CuaDriver", with: "AuraBot Computer Use")
            .replacingOccurrences(of: "cua-driver", with: "AuraBot Computer Use")
            .replacingOccurrences(of: "com.trycua.driver", with: "AuraBot")
    }
}
