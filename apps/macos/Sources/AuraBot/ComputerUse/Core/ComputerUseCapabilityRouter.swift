import Foundation

struct ComputerUseCapabilityRouter {
    private let skills: [AppSkillManifest]

    init(skills: [AppSkillManifest]) {
        self.skills = skills
    }

    static func bundled() throws -> ComputerUseCapabilityRouter {
        let skills = try AppSkillLoader().loadBundledSkills()
        return ComputerUseCapabilityRouter(skills: skills)
    }

    func plan(for selection: ComputerUseToolSelection) -> ComputerUseExecutionPlan? {
        guard let skill = skills.first(where: { $0.id == selection.skillID }),
              let action = skill.actions.first(where: { $0.name == selection.actionName }) else {
            return nil
        }

        return makePlan(
            skill: skill,
            action: action,
            confidence: selection.confidence,
            reasons: selection.reasons.isEmpty ? ["llm_tool_selection"] : selection.reasons
        )
    }

    func fallbackPlan(for context: ComputerUseCommandContext) -> ComputerUseExecutionPlan? {
        guard let genericSkill = skills.first(where: { $0.id == "generic-native-app" }),
              let inspectAction = genericSkill.actions.first(where: { $0.name == "inspect_ui" }) else {
            return nil
        }

        return makePlan(
            skill: genericSkill,
            action: inspectAction,
            confidence: context.bundleIdentifier == nil ? 0.25 : 0.45,
            reasons: ["generic_fallback"]
        )
    }

    private func makePlan(
        skill: AppSkillManifest,
        action: SkillActionDefinition,
        confidence: Double,
        reasons: [String]
    ) -> ComputerUseExecutionPlan {
        return ComputerUseExecutionPlan(
            skillID: skill.id,
            appName: skill.appName,
            actionName: action.name,
            worker: action.preferredWorker,
            fallbackWorkers: action.fallbackWorkers,
            parallelSafe: action.parallelSafe,
            requiresFocus: action.requiresFocus,
            requiresForegroundLock: action.requiresFocus.requiresForegroundLock,
            requiresConfirmation: action.requiresConfirmation || action.destructive,
            destructive: action.destructive,
            permissions: action.permissions,
            confidence: min(max(confidence, 0), 1),
            matchReasons: reasons
        )
    }
}
