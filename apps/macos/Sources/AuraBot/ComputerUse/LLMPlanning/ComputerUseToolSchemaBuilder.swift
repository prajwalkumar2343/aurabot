import Foundation

struct ComputerUseToolDefinition: Equatable {
    let name: String
    let skillID: String
    let actionName: String
    let description: String
    let payload: [String: Any]

    static func == (lhs: ComputerUseToolDefinition, rhs: ComputerUseToolDefinition) -> Bool {
        lhs.name == rhs.name &&
        lhs.skillID == rhs.skillID &&
        lhs.actionName == rhs.actionName &&
        lhs.description == rhs.description
    }
}

struct ComputerUseToolSchemaBuilder {
    func buildTools(from skills: [AppSkillManifest]) -> [ComputerUseToolDefinition] {
        skills.flatMap { skill in
            skill.actions.map { action in
                makeTool(skill: skill, action: action)
            }
        }
    }

    func toolName(skillID: String, actionName: String) -> String {
        sanitize("\(skillID)__\(actionName)")
    }

    func selection(from toolName: String, arguments: [String: Any]) -> ComputerUseToolSelection? {
        let pieces = toolName.split(separator: "__", maxSplits: 1).map(String.init)
        guard pieces.count == 2 else { return nil }

        return selection(
            skillID: pieces[0],
            actionName: pieces[1],
            arguments: arguments
        )
    }

    func selection(from tool: ComputerUseToolDefinition, arguments: [String: Any]) -> ComputerUseToolSelection {
        selection(
            skillID: tool.skillID,
            actionName: tool.actionName,
            arguments: arguments
        )
    }

    private func selection(
        skillID: String,
        actionName: String,
        arguments: [String: Any]
    ) -> ComputerUseToolSelection {
        let confidence = parseDouble(arguments["confidence"]) ?? 0.75
        let reason = (arguments["reason"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let reasons = [reason, "openrouter_tool_call"].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }

        return ComputerUseToolSelection(
            skillID: skillID,
            actionName: actionName,
            confidence: confidence,
            reasons: reasons
        )
    }

    private func makeTool(skill: AppSkillManifest, action: SkillActionDefinition) -> ComputerUseToolDefinition {
        let name = toolName(skillID: skill.id, actionName: action.name)
        let description = """
        \(skill.appName): \(action.description) Preferred worker: \(action.preferredWorker.rawValue). \
        Requires focus: \(action.requiresFocus.rawValue). Requires confirmation: \(action.requiresConfirmation || action.destructive). \
        Destructive: \(action.destructive). Intents: \(action.intents.joined(separator: ", ")).
        """

        let parameters: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "reason": [
                    "type": "string",
                    "description": "Short reason this tool is the best action for the user's command."
                ],
                "confidence": [
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "Confidence that this action matches the user's request."
                ],
                "parameters": [
                    "type": "object",
                    "description": "Optional action-specific parameters inferred from the command.",
                    "additionalProperties": [
                        "type": "string"
                    ]
                ]
            ],
            "required": ["reason", "confidence"]
        ]

        let payload: [String: Any] = [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": parameters
            ]
        ]

        return ComputerUseToolDefinition(
            name: name,
            skillID: skill.id,
            actionName: action.name,
            description: description,
            payload: payload
        )
    }

    private func sanitize(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
        return String(value.map { character in
            character.unicodeScalars.allSatisfy { allowed.contains($0) } ? character : "_"
        })
    }

    private func parseDouble(_ value: Any?) -> Double? {
        switch value {
        case let number as Double:
            return number
        case let number as Int:
            return Double(number)
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string)
        default:
            return nil
        }
    }
}
