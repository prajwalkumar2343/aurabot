import Foundation

struct Memory: Codable, Identifiable {
    let id: String
    let content: String
    let userID: String
    let metadata: Metadata
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case content
        case userID = "user_id"
        case metadata
        case createdAt = "created_at"
    }
}

struct Metadata: Codable {
    let timestamp: String
    let context: String
    let activities: [String]
    let keyElements: [String]
    let userIntent: String
    let displayNum: Int
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case context
        case activities
        case keyElements = "key_elements"
        case userIntent = "user_intent"
        case displayNum = "display_num"
    }
}

struct SearchResult: Codable {
    let memory: Memory
    let score: Double
    let distance: Double
}

struct EnhancementResult {
    let originalPrompt: String
    let enhancedPrompt: String
    let memoriesUsed: [String]
    let memoryCount: Int
    let enhancementType: String
}

struct MemoryInfo: Codable {
    let id: String
    let content: String
    let context: String
    let score: Double
    let date: Date
}
