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

        var request = makeRequest(url: url, method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let data = try await perform(request, expectedStatus: 200...299)
        return try decoder().decode(Memory.self, from: data)
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

        var request = makeRequest(url: url, method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let data = try await perform(request)
        let decoder = decoder()

        if let envelope = try? decoder.decode(SearchResultsEnvelope.self, from: data) {
            return envelope.results
        }

        if let results = try? decoder.decode([SearchResult].self, from: data) {
            return results
        }

        if let legacyEnvelope = try? decoder.decode(LegacySearchResultsEnvelope.self, from: data) {
            return legacyEnvelope.results.map { $0.asSearchResult(userID: config.userID) }
        }

        if let legacyResults = try? decoder.decode([LegacySearchResult].self, from: data) {
            return legacyResults.map { $0.asSearchResult(userID: config.userID) }
        }

        throw MemoryServiceError.invalidResponse("Unable to decode search results")
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

        let data = try await perform(makeRequest(url: url))
        return try decoder().decode([Memory].self, from: data)
    }

    func delete(memoryID: String) async throws {
        guard let url = URL(string: "\(config.baseURL)/v1/memories/\(memoryID)/") else {
            throw URLError(.badURL)
        }

        let request = makeRequest(url: url, method: "DELETE")
        let data = try await perform(request)

        if let response = try? decoder().decode(DeleteResponse.self, from: data), response.deleted {
            return
        }

        throw MemoryServiceError.invalidResponse("Delete was not acknowledged by the server")
    }

    func checkHealth() async -> Bool {
        guard let url = URL(string: "\(config.baseURL)/health") else { return false }

        do {
            let (_, response) = try await session.data(for: makeRequest(url: url))
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private func makeRequest(url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func perform(
        _ request: URLRequest,
        expectedStatus: ClosedRange<Int> = 200...299
    ) async throws -> Data {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard expectedStatus.contains(httpResponse.statusCode) else {
            if let errorResponse = try? decoder().decode(ErrorResponse.self, from: data) {
                throw MemoryServiceError.server(errorResponse.error)
            }

            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw MemoryServiceError.server(message)
        }

        return data
    }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = Self.iso8601Formatter.date(from: value) ?? Self.iso8601FractionalFormatter.date(from: value) {
                return date
            }

            for formatter in Self.legacyDateFormatters {
                if let date = formatter.date(from: value) {
                    return date
                }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(value)"
            )
        }
        return decoder
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let iso8601FractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let legacyDateFormatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss"
        ]

        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            return formatter
        }
    }()
}

private struct SearchResultsEnvelope: Decodable {
    let results: [SearchResult]
}

private struct LegacySearchResultsEnvelope: Decodable {
    let results: [LegacySearchResult]
}

private struct LegacySearchResult: Decodable {
    let id: String
    let memory: String
    let metadata: Metadata?
    let createdAt: Date?
    let score: Double
    let distance: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case memory
        case metadata
        case createdAt = "created_at"
        case score
        case distance
    }

    func asSearchResult(userID: String) -> SearchResult {
        SearchResult(
            memory: Memory(
                id: id,
                content: memory,
                userID: userID,
                metadata: metadata ?? Metadata.empty,
                createdAt: createdAt ?? Date()
            ),
            score: score,
            distance: distance ?? 0
        )
    }
}

private struct DeleteResponse: Decodable {
    let deleted: Bool
}

private struct ErrorResponse: Decodable {
    let error: String
}

private enum MemoryServiceError: LocalizedError {
    case server(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .server(let message), .invalidResponse(let message):
            return message
        }
    }
}

private extension Metadata {
    static let empty = Metadata(
        timestamp: ISO8601DateFormatter().string(from: Date()),
        context: "",
        activities: [],
        keyElements: [],
        userIntent: "",
        displayNum: 0
    )
}
