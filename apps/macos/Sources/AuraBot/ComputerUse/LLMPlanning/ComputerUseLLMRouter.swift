import Foundation

actor ComputerUseLLMRouter {
    private let skills: [AppSkillManifest]
    private let planner: OpenRouterComputerUsePlanner
    private let capabilityRouter: ComputerUseCapabilityRouter

    init(skills: [AppSkillManifest], planner: OpenRouterComputerUsePlanner) {
        self.skills = skills
        self.planner = planner
        self.capabilityRouter = ComputerUseCapabilityRouter(skills: skills)
    }

    static func bundled(config: LLMConfig) throws -> ComputerUseLLMRouter {
        let skills = try AppSkillLoader().loadBundledSkills()
        return ComputerUseLLMRouter(
            skills: skills,
            planner: OpenRouterComputerUsePlanner(config: config)
        )
    }

    func route(_ context: ComputerUseCommandContext) async throws -> ComputerUseExecutionPlan {
        let selection = try await planner.plan(context: context, skills: skills)
        if let plan = capabilityRouter.plan(for: selection) {
            return plan
        }

        throw ComputerUsePlannerError.invalidToolSelection("\(selection.skillID).\(selection.actionName)")
    }

    func fallbackPlan(for context: ComputerUseCommandContext) -> ComputerUseExecutionPlan? {
        capabilityRouter.fallbackPlan(for: context)
    }
}
