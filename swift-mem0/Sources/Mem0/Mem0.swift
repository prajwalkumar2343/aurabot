import Foundation

/// Mem0 client for interacting with Mem0 memory API
public actor Mem0 {
    private let baseURL: String
    private let apiKey: String
    private let session: URLSession
    
    public init(baseURL: String, apiKey: String = "") {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = URLSession.shared
    }
    
    /// Add a memory
    public func add(
        content: String,
        userId: String,
        metadata: [String: Any] = [:],
        agentId: String? = nil
    ) async throws -> MemoryResponse {
        guard let url = URL(string: "\(baseURL)/v1/memories/") else {
            throw Mem0Error.invalidURL
        }
        
        var payload: [String: Any] = [
            "messages": [
                ["role": "user", "content": content]
            ],
            "user_id": userId,
            "metadata": metadata
        ]
        
        if let agentId = agentId {
            payload["agent_id"] = agentId
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Mem0Error.decodingError
        }

        let memory = try Self.parseMemory(object, fallbackUserId: userId)
        return MemoryResponse(
            id: memory.id,
            content: memory.content,
            userId: memory.userId,
            metadata: memory.metadata.mapValues(\.value),
            createdAt: memory.createdAt
        )
    }
    
    /// Search memories
    public func search(
        query: String,
        userId: String,
        agentId: String? = nil,
        limit: Int = 10
    ) async throws -> [SearchResult] {
        guard let url = URL(string: "\(baseURL)/v1/memories/search/") else {
            throw Mem0Error.invalidURL
        }
        
        var payload: [String: Any] = [
            "query": query,
            "user_id": userId,
            "limit": limit
        ]
        
        if let agentId = agentId {
            payload["agent_id"] = agentId
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            throw Mem0Error.decodingError
        }
        
        return try results.map { result -> SearchResult in
            let memoryObject: [String: Any]
            if let nested = result["memory"] as? [String: Any] {
                memoryObject = nested
            } else if let memoryText = result["memory"] as? String {
                memoryObject = [
                    "id": result["id"] as? String ?? UUID().uuidString,
                    "content": memoryText,
                    "user_id": userId,
                    "metadata": [:]
                ]
            } else {
                throw Mem0Error.decodingError
            }

            return SearchResult(
                memory: try Self.parseMemory(memoryObject, fallbackUserId: userId),
                score: Self.parseDouble(result["score"]) ?? 0,
                distance: Self.parseDouble(result["distance"]) ?? 0
            )
        }
    }
    
    /// Get recent memories
    public func getRecent(
        userId: String,
        agentId: String? = nil,
        limit: Int = 10
    ) async throws -> [Memory] {
        var urlComponents = URLComponents(string: "\(baseURL)/v1/memories/")
        var queryItems = [
            URLQueryItem(name: "user_id", value: userId),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let agentId = agentId {
            queryItems.append(URLQueryItem(name: "agent_id", value: agentId))
        }
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            throw Mem0Error.invalidURL
        }
        
        var request = URLRequest(url: url)
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        guard let objects = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw Mem0Error.decodingError
        }

        return try objects.map { try Self.parseMemory($0, fallbackUserId: userId) }
    }
    
    /// Delete a memory
    public func delete(memoryId: String) async throws {
        guard let encodedID = memoryId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(baseURL)/v1/memories/\(encodedID)/") else {
            throw Mem0Error.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }
    
    /// Check health
    public func checkHealth() async -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else { return false }
        
        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Mem0Error.apiError("Invalid response")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = object["error"] as? String {
                throw Mem0Error.apiError(message)
            }
            throw Mem0Error.apiError("Request failed with status \(httpResponse.statusCode)")
        }
    }

    private static func parseMemory(_ object: [String: Any], fallbackUserId: String) throws -> Memory {
        guard let id = object["id"] as? String else {
            throw Mem0Error.decodingError
        }

        let metadata = object["metadata"] as? [String: Any] ?? [:]
        let createdAtString = object["created_at"] as? String
        return Memory(
            id: id,
            content: object["content"] as? String ?? object["memory"] as? String ?? "",
            userId: object["user_id"] as? String ?? fallbackUserId,
            metadata: metadata,
            createdAt: createdAtString.flatMap(parseDate) ?? Date()
        )
    }

    private static func parseDouble(_ value: Any?) -> Double? {
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

    private static func parseDate(_ value: String) -> Date? {
        if let date = iso8601Fractional.date(from: value) {
            return date
        }
        if let date = iso8601.date(from: value) {
            return date
        }
        if let date = pythonDateFormatter.date(from: value) {
            return date
        }
        return pythonDateFormatterNoFraction.date(from: value)
    }

    private static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601 = ISO8601DateFormatter()

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

// MARK: - Types

public enum Mem0Error: Error {
    case invalidURL
    case apiError(String)
    case decodingError
}

public struct Memory: Codable, Identifiable, Sendable {
    public let id: String
    public let content: String
    public let userId: String
    public let metadata: [String: AnyCodable]
    public let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case content
        case userId = "user_id"
        case metadata
        case createdAt = "created_at"
    }
    
    public init(
        id: String,
        content: String,
        userId: String,
        metadata: [String: Any] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.userId = userId
        self.metadata = metadata.mapValues { AnyCodable($0) }
        self.createdAt = createdAt
    }
}

public struct MemoryResponse: @unchecked Sendable {
    public let id: String
    public let content: String
    public let userId: String
    public let metadata: [String: Any]
    public let createdAt: Date
}

public struct SearchResult: Sendable {
    public let memory: Memory
    public let score: Double
    public let distance: Double
}

// MARK: - AnyCodable helper

public struct AnyCodable: Codable, @unchecked Sendable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = ""
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else {
            try container.encode(String(describing: value))
        }
    }
}
