import Foundation

actor EnhancerService {
    private let memoryService: MemoryService
    private let llmService: LLMService
    
    private var stats: EnhancerStats = .init()
    
    init(memoryService: MemoryService, llmService: LLMService) {
        self.memoryService = memoryService
        self.llmService = llmService
    }
    
    func enhance(prompt: String, pageContext: String = "", maxMemories: Int = 5) async throws -> EnhancementResult {
        let results = try await memoryService.search(query: prompt, limit: maxMemories)
        
        let memories = results.map { result in
            MemoryInfo(
                id: result.memory.id,
                content: result.memory.content,
                context: result.memory.metadata.context,
                score: result.score,
                date: result.memory.createdAt
            )
        }
        
        let result = try await llmService.enhancePrompt(prompt: prompt, memories: memories)
        
        await updateStats()
        return result
    }
    
    func searchMemories(query: String, limit: Int = 5) async throws -> [MemoryInfo] {
        let results = try await memoryService.search(query: query, limit: limit)
        return results.map { result in
            MemoryInfo(
                id: result.memory.id,
                content: result.memory.content,
                context: result.memory.metadata.context,
                score: result.score,
                date: result.memory.createdAt
            )
        }
    }
    
    func getRecentMemories(limit: Int = 10) async throws -> [MemoryInfo] {
        let memories = try await memoryService.getRecent(limit: limit)
        return memories.map { memory in
            MemoryInfo(
                id: memory.id,
                content: memory.content,
                context: memory.metadata.context,
                score: 1.0,
                date: memory.createdAt
            )
        }
    }
    
    func getStats() -> EnhancerStats {
        stats
    }
    
    private func updateStats() {
        stats.enhancementsMade += 1
        stats.lastEnhancement = Date()
    }
}

struct EnhancerStats {
    var enhancementsMade: Int = 0
    var lastEnhancement: Date?
}
