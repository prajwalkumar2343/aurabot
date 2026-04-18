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

        var metadataPayload: [String: Any] = [
            "timestamp": metadata.timestamp,
            "context": metadata.context,
            "activities": metadata.activities,
            "key_elements": metadata.keyElements,
            "user_intent": metadata.userIntent,
            "display_num": metadata.displayNum
        ]

        if let browser = metadata.browser {
            metadataPayload["browser"] = browser
        }
        if let url = metadata.url {
            metadataPayload["url"] = url
        }
        if let captureReason = metadata.captureReason {
            metadataPayload["capture_reason"] = captureReason
        }

        let payload: [String: Any] = [
            "messages": [
                ["role": "user", "content": content]
            ],
            "user_id": config.userID,
            "metadata": metadataPayload,
            "agent_id": config.collectionName
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let data = try await performRequest(request)
        return try decodeMemory(from: data)
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
        
        let data = try await performRequest(request)
        return try decodeSearchResults(from: data)
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
        
        let data = try await performRequest(request)
        return try decodeMemories(from: data)
    }
    
    func delete(memoryID: String) async throws {
        guard let url = URL(string: "\(config.baseURL)/v1/memories/\(memoryID)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        _ = try await performRequest(request)
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

    private func performRequest(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let apiError = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = apiError["error"] as? String {
                throw MemoryServiceError.apiError(message)
            }
            throw URLError(.badServerResponse)
        }

        return data
    }

    private func decodeMemory(from data: Data) throws -> Memory {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        return try parseMemory(object)
    }

    private func decodeMemories(from data: Data) throws -> [Memory] {
        guard let objects = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }

        return try objects.map(parseMemory)
    }

    private func decodeSearchResults(from data: Data) throws -> [SearchResult] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = object["results"] as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }

        return try results.compactMap { result in
            guard let memoryObject = result["memory"] as? [String: Any] else {
                return nil
            }

            return SearchResult(
                memory: try parseMemory(memoryObject),
                score: parseDouble(result["score"]) ?? 0,
                distance: parseDouble(result["distance"]) ?? 0
            )
        }
    }

    private func parseMemory(_ object: [String: Any]) throws -> Memory {
        let metadataObject = object["metadata"] as? [String: Any] ?? [:]
        let createdAtString = object["created_at"] as? String ?? ""

        return Memory(
            id: object["id"] as? String ?? UUID().uuidString,
            content: object["content"] as? String ?? object["memory"] as? String ?? "",
            userID: object["user_id"] as? String ?? config.userID,
            metadata: Metadata(
                timestamp: metadataObject["timestamp"] as? String ?? createdAtString,
                context: metadataObject["context"] as? String ?? "General",
                activities: metadataObject["activities"] as? [String] ?? [],
                keyElements: metadataObject["key_elements"] as? [String] ?? [],
                userIntent: metadataObject["user_intent"] as? String ?? "",
                displayNum: parseInt(metadataObject["display_num"]) ?? 0,
                browser: metadataObject["browser"] as? String,
                url: metadataObject["url"] as? String,
                captureReason: metadataObject["capture_reason"] as? String
            ),
            createdAt: parseDate(createdAtString) ?? Date()
        )
    }

    private func parseDate(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }

        if let date = Self.iso8601Fractional.date(from: value) {
            return date
        }

        if let date = Self.iso8601.date(from: value) {
            return date
        }

        if let date = Self.pythonDateFormatter.date(from: value) {
            return date
        }

        return Self.pythonDateFormatterNoFraction.date(from: value)
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

    private func parseInt(_ value: Any?) -> Int? {
        switch value {
        case let number as Int:
            return number
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string)
        default:
            return nil
        }
    }

    private static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601: ISO8601DateFormatter = {
        ISO8601DateFormatter()
    }()

    private static let pythonDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return formatter
    }()

    private static let pythonDateFormatterNoFraction: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
}

enum MemoryServiceError: LocalizedError {
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .apiError(let message):
            return message
        }
    }
}
