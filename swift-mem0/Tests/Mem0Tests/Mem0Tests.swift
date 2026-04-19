import Foundation
import XCTest
@testable import Mem0

final class Mem0ModelTests: XCTestCase {
    func testMemoryEncodesAndDecodesMetadata() throws {
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let memory = Memory(
            id: "mem-1",
            content: "Ship the release notes",
            userId: "user-1",
            metadata: [
                "context": "Work",
                "priority": 2,
                "pinned": true
            ],
            createdAt: createdAt
        )

        let encoded = try JSONEncoder().encode(memory)
        let decoded = try JSONDecoder().decode(Memory.self, from: encoded)

        XCTAssertEqual(decoded.id, "mem-1")
        XCTAssertEqual(decoded.content, "Ship the release notes")
        XCTAssertEqual(decoded.userId, "user-1")
        XCTAssertEqual(decoded.metadata["context"]?.value as? String, "Work")
        XCTAssertEqual(decoded.metadata["priority"]?.value as? Int, 2)
        XCTAssertEqual(decoded.metadata["pinned"]?.value as? Bool, true)
        XCTAssertEqual(decoded.createdAt.timeIntervalSince1970, createdAt.timeIntervalSince1970)
    }

    func testAnyCodableDecodesNestedServerMetadata() throws {
        let payload = """
        {
          "topic": "launch",
          "score": 0.82,
          "tags": ["release", "notes"],
          "flags": {
            "reviewed": true
          }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: payload)

        XCTAssertEqual(decoded["topic"]?.value as? String, "launch")
        XCTAssertEqual(decoded["score"]?.value as? Double, 0.82)
        XCTAssertEqual(decoded["tags"]?.value as? [String], ["release", "notes"])

        let flags = decoded["flags"]?.value as? [String: Any]
        XCTAssertEqual(flags?["reviewed"] as? Bool, true)
    }
}
