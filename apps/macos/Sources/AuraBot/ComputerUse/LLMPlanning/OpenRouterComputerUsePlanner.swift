import Foundation

enum ComputerUsePlannerError: Error, Equatable {
    case missingAPIKey
    case noToolSelected
    case invalidToolSelection(String)
    case invalidResponse
    case apiError(String)
}

actor OpenRouterComputerUsePlanner {
    private let config: LLMConfig
    private let session: URLSession
    private let toolBuilder: ComputerUseToolSchemaBuilder

    init(
        config: LLMConfig,
        session: URLSession? = nil,
        toolBuilder: ComputerUseToolSchemaBuilder = ComputerUseToolSchemaBuilder()
    ) {
        self.config = config
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = TimeInterval(config.timeoutSeconds)
        self.session = session ?? URLSession(configuration: sessionConfiguration)
        self.toolBuilder = toolBuilder
    }

    func plan(
        context: ComputerUseCommandContext,
        skills: [AppSkillManifest]
    ) async throws -> ComputerUseToolSelection {
        guard !config.openRouterAPIKey.isEmpty else {
            throw ComputerUsePlannerError.missingAPIKey
        }

        let tools = toolBuilder.buildTools(from: skills)
        let body: [String: Any] = [
            "model": config.openRouterChatModel,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": userPrompt(context: context)
                ]
            ],
            "tools": tools.map(\.payload),
            "tool_choice": "auto",
            "temperature": 0.1,
            "max_tokens": min(config.maxTokens, 512)
        ]

        let response = try await makeRequest(body: body)
        guard let toolCall = firstToolCall(in: response) else {
            throw ComputerUsePlannerError.noToolSelected
        }

        guard let tool = tools.first(where: { $0.name == toolCall.name }) else {
            throw ComputerUsePlannerError.invalidToolSelection(toolCall.name)
        }

        return toolBuilder.selection(from: tool, arguments: toolCall.arguments)
    }

    private var systemPrompt: String {
        """
        You are a local macOS computer-use planner. Choose exactly one provided tool for the user's command.
        Prefer app APIs, browser tools, Apple Events, file APIs, and Accessibility over foreground input.
        Do not invent tools. If the action is risky, still choose the right tool; the app enforces confirmation and safety metadata.
        Return a tool call only.
        """
    }

    private func userPrompt(context: ComputerUseCommandContext) -> String {
        """
        User command: \(context.command)
        Active app: \(context.activeAppName ?? "unknown")
        Bundle ID: \(context.bundleIdentifier ?? "unknown")
        Domain: \(context.domain ?? "none")
        Category hint: \(context.categoryHint ?? "none")
        """
    }

    private func makeRequest(body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: "\(config.baseURL)/chat/completions") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.openRouterAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ComputerUsePlannerError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["error"] as? [String: Any] }
                .flatMap { $0["message"] as? String }
                ?? String(data: data, encoding: .utf8)
                ?? "OpenRouter request failed with status \(httpResponse.statusCode)"
            throw ComputerUsePlannerError.apiError(message)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ComputerUsePlannerError.invalidResponse
        }

        return json
    }

    private func firstToolCall(in response: [String: Any]) -> (name: String, arguments: [String: Any])? {
        guard let choices = response["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let toolCalls = message["tool_calls"] as? [[String: Any]],
              let toolCall = toolCalls.first,
              let function = toolCall["function"] as? [String: Any],
              let name = function["name"] as? String else {
            return nil
        }

        let argumentsString = function["arguments"] as? String ?? "{}"
        let argumentsData = Data(argumentsString.utf8)
        let arguments = (try? JSONSerialization.jsonObject(with: argumentsData) as? [String: Any]) ?? [:]

        return (name, arguments)
    }
}
