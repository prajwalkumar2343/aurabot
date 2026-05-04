import CuaDriverServer
import Foundation
import MCP

protocol ComputerUseToolCalling: Sendable {
    var toolNames: [String] { get }

    func call(
        _ name: String,
        arguments: [String: ComputerUseArgument]
    ) async throws -> ComputerUseToolResult
}

struct CuaToolRegistryAdapter: ComputerUseToolCalling {
    private let registry: ToolRegistry

    init(registry: ToolRegistry = .default) {
        self.registry = registry
    }

    var toolNames: [String] {
        registry.allTools.map(\.name)
    }

    func call(
        _ name: String,
        arguments: [String: ComputerUseArgument]
    ) async throws -> ComputerUseToolResult {
        let result = try await registry.call(name, arguments: arguments.mapValues(\.mcpValue))
        let textOutput = result.content.compactMap { item -> String? in
            guard case .text(let text, _, _) = item else { return nil }
            return text
        }.joined(separator: "\n")
        let imageData = result.content.compactMap { item -> Data? in
            guard case .image(let base64, _, _, _) = item else { return nil }
            return Data(base64Encoded: base64)
        }.first
        let structured = result.structuredContent.map(ComputerUseArgument.init(mcpValue:))
        let output = textOutput.isEmpty
            ? structured?.jsonString ?? ""
            : textOutput

        return ComputerUseToolResult(
            exitCode: result.isError == true ? 1 : 0,
            output: output,
            errorOutput: result.isError == true ? output : "",
            imageData: imageData,
            structuredContent: structured
        )
    }
}

private extension ComputerUseArgument {
    var mcpValue: Value {
        switch self {
        case .null:
            return .null
        case .bool(let value):
            return .bool(value)
        case .int(let value):
            return .int(value)
        case .double(let value):
            return .double(value)
        case .string(let value):
            return .string(value)
        case .array(let values):
            return .array(values.map(\.mcpValue))
        case .object(let values):
            return .object(values.mapValues(\.mcpValue))
        }
    }

    init(mcpValue: Value) {
        switch mcpValue {
        case .null:
            self = .null
        case .bool(let value):
            self = .bool(value)
        case .int(let value):
            self = .int(value)
        case .double(let value):
            self = .double(value)
        case .string(let value):
            self = .string(value)
        case .data(_, let data):
            self = .string(data.base64EncodedString())
        case .array(let values):
            self = .array(values.map(ComputerUseArgument.init(mcpValue:)))
        case .object(let values):
            self = .object(values.mapValues(ComputerUseArgument.init(mcpValue:)))
        }
    }

    var jsonString: String? {
        let value = jsonValue
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
}
