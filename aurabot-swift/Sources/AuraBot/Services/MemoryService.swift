import Foundation

actor MemoryService {
    private let config: MemoryConfig
    private let session: URLSession
    
    init(config: MemoryConfig) {
        self.config = config
        self.session = URLSession.shared
    }
    
    func add(content: String, metadata: Metadata) async throws -> Memory {
        guard let url = URL(string: "\(config.baseURL)/v1/memories/") else {
            throw URLError(.badURL)
        }
        
        let payload: [String: Any] = [
            "messages": [
                ["role": "user", "content": content]
            ],
            "user_id": config.userID,
            "metadata": [
                "timestamp": metadata.timestamp,
                "context": metadata.context,
                "activities": metadata.activities,
                "key_elements": metadata.keyElements,
                "user_intent": metadata.userIntent,
                "display_num": metadata.displayNum
            ],
            "agent_id": config.collectionName
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, _) = try await session.data(for: request)
        
        return Memory(
            id: UUID().uuidString,
            content: content,
            userID: config.userID,
            metadata: metadata,
            createdAt: Date()
        )
    }
    
    func search(query: String, limit: Int = 10) async throws -> [SearchResult] {
        guard let url = URL(string: "\(config.baseURL)/v1/memories/search/") else {
            throw URLError(.badURL)
        }
        
        let payload: [String: Any] = [
            "query": query,
            "user_id": config.userID,
            "agent_id": config.collectionName,
            "limit": limit
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, _) = try await session.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            return []
        }
        
        return results.compactMap { result -> SearchResult? in
            guard let memoryText = result["memory"] as? String,
                  let id = result["id"] as? String,
                  let score = result["score"] as? Double else { return nil }
            
            let memory = Memory(
                id: id,
                content: memoryText,
                userID: self.config.userID,
                metadata: Metadata(
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    context: "",
                    activities: [],
                    keyElements: [],
                    userIntent: "",
                    displayNum: 0
                ),
                createdAt: Date()
            )
            
            return SearchResult(
                memory: memory,
                score: score,
                distance: result["distance"] as? Double ?? 0
            )
        }
    }
    
    func getRecent(limit: Int = 10) async throws -> [Memory] {
        var urlComponents = URLComponents(string: "\(config.baseURL)/v1/memories/")
        urlComponents?.queryItems = [
            URLQueryItem(name: "user_id", value: config.userID),
            URLQueryItem(name: "agent_id", value: config.collectionName),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        guard let url = urlComponents?.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, _) = try await session.data(for: request)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Memory].self, from: data)) ?? []
    }
    
    func delete(memoryID: String) async throws {
        guard let url = URL(string: "\(config.baseURL)/v1/memories/\(memoryID)/") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        _ = try await session.data(for: request)
    }
    
    func checkHealth() async -> Bool {
        guard let url = URL(string: "\(config.baseURL)/health") else { return false }
        
        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
