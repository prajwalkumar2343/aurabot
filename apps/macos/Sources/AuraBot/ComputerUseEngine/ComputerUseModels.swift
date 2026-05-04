import Foundation

enum ComputerUseArgument: Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([ComputerUseArgument])
    case object([String: ComputerUseArgument])

    var jsonValue: Any {
        switch self {
        case .null:
            return NSNull()
        case .bool(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .string(let value):
            return value
        case .array(let values):
            return values.map(\.jsonValue)
        case .object(let values):
            return values.mapValues(\.jsonValue)
        }
    }
}

struct ComputerUseStatus: Equatable, Sendable {
    enum State: String, Equatable, Sendable {
        case disabled
        case starting
        case ready
        case needsPermission
        case failed
    }

    var state: State
    var permissions: ComputerUsePermissionStatus
    var message: String

    static let disabled = ComputerUseStatus(
        state: .disabled,
        permissions: ComputerUsePermissionStatus(accessibility: false, screenRecording: false),
        message: "Computer Use is disabled."
    )
}

struct ComputerUsePermissionStatus: Codable, Equatable, Sendable {
    var accessibility: Bool
    var screenRecording: Bool

    var isReady: Bool {
        accessibility && screenRecording
    }
}

struct ComputerUseToolResult: Equatable, Sendable {
    var exitCode: Int32
    var output: String
    var errorOutput: String
    var imageData: Data?
    var structuredContent: ComputerUseArgument?

    var succeeded: Bool {
        exitCode == 0
    }

    static func success(
        output: String = "",
        imageData: Data? = nil,
        structuredContent: ComputerUseArgument? = nil
    ) -> ComputerUseToolResult {
        ComputerUseToolResult(
            exitCode: 0,
            output: output,
            errorOutput: "",
            imageData: imageData,
            structuredContent: structuredContent
        )
    }

    static func failure(_ message: String) -> ComputerUseToolResult {
        ComputerUseToolResult(
            exitCode: 1,
            output: "",
            errorOutput: message,
            imageData: nil,
            structuredContent: nil
        )
    }
}

enum ComputerUseError: LocalizedError, Equatable {
    case toolFailed(String)
    case screenshotDataMissing

    var errorDescription: String? {
        switch self {
        case .toolFailed(let message):
            return message
        case .screenshotDataMissing:
            return "Computer Use did not return a screenshot."
        }
    }
}
