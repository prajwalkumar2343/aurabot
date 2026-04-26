import CryptoKit
import Foundation

actor EmbeddedMemoryStore {
    static let shared = EmbeddedMemoryStore()

    private struct PersistedState: Codable, Sendable {
        var schemaVersion: String
        var events: [Memory]
    }

    private let fileURL: URL
    private let fileManager: FileManager
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var state: PersistedState?

    init(
        fileURL: URL = EmbeddedMemoryStore.defaultFileURL,
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.decoder = MemoryV2JSON.makeDecoder()

        let encoder = MemoryV2JSON.makeEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
    }

    func add(_ input: RecentContextEventInput) async throws -> Memory {
        try loadStateIfNeeded()
        try pruneExpiredEvents()

        let id = eventID(for: input.idempotencyKey)
        if let existing = state?.events.first(where: { $0.id == id }) {
            return existing
        }

        guard let occurredAt = MemoryV2JSON.parseDate(input.occurredAt) else {
            throw EmbeddedMemoryStoreError.invalidTimestamp(input.occurredAt)
        }

        let createdAt = Date()
        let memory = Memory(
            id: id,
            content: input.content,
            userID: input.userID,
            metadata: input.metadata,
            createdAt: createdAt,
            agentID: normalizedAgentID(input.agentID),
            source: input.source,
            contentHash: contentHash(for: input.content, metadata: input.metadata, occurredAt: occurredAt),
            occurredAt: occurredAt,
            ttlSeconds: input.ttlSeconds,
            importance: input.importance
        )

        state?.events.append(memory)
        try persistState()
        return memory
    }

    func search(
        query: String,
        userID: String,
        agentID: String?,
        limit: Int
    ) async throws -> [SearchResult] {
        try loadStateIfNeeded()
        try pruneExpiredEvents()

        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return []
        }

        let queryTerms = tokenize(normalizedQuery)
        let now = Date()

        let matches = filteredEvents(userID: userID, agentID: agentID)
            .compactMap { memory -> SearchResult? in
                let searchableText = [
                    memory.content,
                    memory.metadata.context,
                    memory.metadata.userIntent,
                    memory.metadata.activities.joined(separator: " "),
                    memory.metadata.keyElements.joined(separator: " "),
                    memory.metadata.browser,
                    memory.metadata.url,
                    memory.metadata.captureReason,
                    memory.metadata.pageTextSummary
                ]
                .compactMap { $0 }
                .joined(separator: " ")
                .lowercased()

                let keywordScore = score(queryTerms: queryTerms, searchableText: searchableText)
                guard keywordScore > 0 else { return nil }

                let age = max(0, now.timeIntervalSince(memory.createdAt))
                let recency = max(0, 1 - (age / (24 * 60 * 60)))
                let totalScore = (keywordScore * 0.85) + (recency * 0.15)

                return SearchResult(
                    id: memory.id,
                    source: .recentContext,
                    content: memory.content,
                    userID: memory.userID,
                    entityIDs: [],
                    relations: [],
                    evidence: [
                        Evidence(
                            source: .recentContext,
                            sourceID: memory.id,
                            excerpt: String(memory.content.prefix(240)),
                            contentHash: memory.contentHash,
                            createdAt: memory.createdAt,
                            metadata: nil
                        )
                    ],
                    score: totalScore,
                    scores: MemoryScoreBreakdown(vector: 0, keyword: keywordScore, graph: 0, recency: recency),
                    createdAt: memory.createdAt,
                    metadata: resultMetadata(for: memory)
                )
            }
            .sorted { left, right in
                if left.score == right.score {
                    return left.createdAt > right.createdAt
                }
                return left.score > right.score
            }

        return Array(matches.prefix(max(limit, 1)))
    }

    func recent(userID: String, agentID: String?, limit: Int) async throws -> [Memory] {
        try loadStateIfNeeded()
        try pruneExpiredEvents()
        return Array(filteredEvents(userID: userID, agentID: agentID).prefix(max(limit, 1)))
    }

    func currentContext(
        userID: String,
        agentID: String?,
        recentEventsLimit: Int = 10,
        hours: Double = 6
    ) async throws -> CurrentContextPacket {
        try loadStateIfNeeded()
        try pruneExpiredEvents()

        let now = Date()
        let windowStart = now.addingTimeInterval(-(hours * 60 * 60))
        let windowEvents = filteredEvents(userID: userID, agentID: agentID)
            .filter { $0.createdAt >= windowStart }

        let recentEvents = Array(windowEvents.prefix(max(recentEventsLimit, 1)))
        let apps = uniqueStrings(windowEvents.compactMap { $0.metadata.browser })
        let websites = uniqueStrings(windowEvents.compactMap { domain(from: $0.metadata.url) })
        let latestFocus = recentEvents.first?.metadata.userIntent.isEmpty == false
            ? recentEvents.first?.metadata.userIntent
            : recentEvents.first?.content

        var summary = "No recent activity captured in this window."
        if !windowEvents.isEmpty {
            let appPhrase = apps.isEmpty ? "" : " using \(apps.prefix(3).joined(separator: ", "))"
            let websitePhrase = websites.isEmpty ? "" : " across \(websites.prefix(3).joined(separator: ", "))"
            let latestPhrase = latestFocus?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? latestFocus!
                : "recent work"
            summary = "Recent context includes \(windowEvents.count) event\(windowEvents.count == 1 ? "" : "s")\(appPhrase)\(websitePhrase). Latest focus: \(latestPhrase)."
        }

        return CurrentContextPacket(
            schemaVersion: MemoryV2JSON.schemaVersion,
            userID: userID,
            agentID: normalizedAgentID(agentID),
            generatedAt: now,
            window: TimeWindow(startedAt: windowStart, endedAt: now),
            summary: summary,
            recentEvents: recentEvents,
            activeEntities: [],
            metadata: [
                "generated_by": .string("embedded_memory_store"),
                "persisted": .bool(true)
            ]
        )
    }

    func delete(userID: String, agentID: String?, memoryID: String, source: MemorySource) async throws -> Bool {
        guard source == .recentContext else {
            return false
        }

        try loadStateIfNeeded()
        try pruneExpiredEvents()

        let beforeCount = state?.events.count ?? 0
        state?.events.removeAll {
            $0.id == memoryID &&
            $0.userID == userID &&
            $0.agentID == normalizedAgentID(agentID)
        }

        let deleted = (state?.events.count ?? 0) != beforeCount
        if deleted {
            try persistState()
        }
        return deleted
    }

    func checkHealth() async -> Bool {
        do {
            try loadStateIfNeeded()
            try pruneExpiredEvents()
            return true
        } catch {
            return false
        }
    }

    private func filteredEvents(userID: String, agentID: String?) -> [Memory] {
        let normalizedAgentID = normalizedAgentID(agentID)
        return (state?.events ?? [])
            .filter { memory in
                memory.userID == userID && memory.agentID == normalizedAgentID
            }
            .sorted { left, right in
                if left.createdAt == right.createdAt {
                    return left.id > right.id
                }
                return left.createdAt > right.createdAt
            }
    }

    private func loadStateIfNeeded() throws {
        guard state == nil else { return }

        guard fileManager.fileExists(atPath: fileURL.path) else {
            state = PersistedState(schemaVersion: MemoryV2JSON.schemaVersion, events: [])
            return
        }

        let data = try Data(contentsOf: fileURL)
        state = try decoder.decode(PersistedState.self, from: data)
    }

    private func pruneExpiredEvents() throws {
        guard var state else { return }

        let now = Date()
        let originalCount = state.events.count
        state.events.removeAll { memory in
            let ttl = TimeInterval(memory.ttlSeconds ?? 6 * 60 * 60)
            return memory.createdAt.addingTimeInterval(ttl) <= now
        }

        self.state = state
        if state.events.count != originalCount {
            try persistState()
        }
    }

    private func persistState() throws {
        guard let state else { return }

        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func contentHash(for content: String, metadata: Metadata, occurredAt: Date) -> String {
        let digestInput = [
            content,
            metadata.context,
            metadata.userIntent,
            metadata.activities.joined(separator: "|"),
            metadata.keyElements.joined(separator: "|"),
            ISO8601DateFormatter().string(from: occurredAt)
        ].joined(separator: "\n")

        return sha256Hex(digestInput)
    }

    private func eventID(for idempotencyKey: String) -> String {
        "recent_\(sha256Hex(idempotencyKey).prefix(24))"
    }

    private func sha256Hex(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func normalizedAgentID(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func tokenize(_ value: String) -> [String] {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }
    }

    private func score(queryTerms: [String], searchableText: String) -> Double {
        guard !queryTerms.isEmpty else { return 0 }

        let searchableTerms = Set(tokenize(searchableText))
        let matches = queryTerms.filter { term in
            searchableTerms.contains(term) || searchableText.contains(term)
        }

        guard !matches.isEmpty else { return 0 }

        let overlap = Double(matches.count) / Double(queryTerms.count)
        let exactBoost = searchableText.contains(queryTerms.joined(separator: " ")) ? 0.15 : 0
        return min(1, overlap + exactBoost)
    }

    private func resultMetadata(for memory: Memory) -> [String: JSONValue] {
        var metadata: [String: JSONValue] = [
            "context": .string(memory.displayContext),
            "source": .string(memory.source.rawValue)
        ]

        if let browser = memory.metadata.browser, !browser.isEmpty {
            metadata["browser"] = .string(browser)
        }
        if let url = memory.metadata.url, !url.isEmpty {
            metadata["url"] = .string(url)
        }
        if let captureReason = memory.metadata.captureReason, !captureReason.isEmpty {
            metadata["capture_reason"] = .string(captureReason)
        }

        return metadata
    }

    private func uniqueStrings(_ values: [String]) -> [String] {
        Array(NSOrderedSet(array: values.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        })) as? [String] ?? []
    }

    private func domain(from urlString: String?) -> String? {
        guard let urlString, let url = URL(string: urlString), let host = url.host else {
            return nil
        }
        return host.replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
    }

    private static var defaultFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".aurabot", isDirectory: true)
            .appendingPathComponent("memory", isDirectory: true)
            .appendingPathComponent("recent-context.json")
    }
}

enum EmbeddedMemoryStoreError: LocalizedError {
    case invalidTimestamp(String)

    var errorDescription: String? {
        switch self {
        case .invalidTimestamp(let value):
            return "Invalid memory timestamp: \(value)"
        }
    }
}
