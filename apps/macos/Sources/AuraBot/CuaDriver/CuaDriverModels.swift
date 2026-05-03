import Foundation

struct CuaDriverVendorManifest: Codable, Equatable {
    let name: String
    let upstream: String
    let version: String
    let tag: String
    let bundleIdentifier: String
    let minimumMacOS: String
    let license: String
    let sourceURL: String
    let releaseURL: String
    let artifacts: [CuaDriverArtifact]
}

struct CuaDriverArtifact: Codable, Equatable {
    let platform: String
    let architecture: String
    let archivePath: String
    let appPath: String
    let sha256: String
    let downloadURL: String
}

struct CuaDriverStatus: Equatable, Sendable {
    enum State: String, Equatable, Sendable {
        case disabled
        case notInstalled
        case installed
        case starting
        case ready
        case needsPermission
        case repairNeeded
        case updateAvailable
        case failed
    }

    var state: State
    var installedVersion: String?
    var bundledVersion: String?
    var updateVersion: String?
    var daemonRunning: Bool
    var permissions: CuaDriverPermissionStatus
    var message: String

    static let disabled = CuaDriverStatus(
        state: .disabled,
        installedVersion: nil,
        bundledVersion: nil,
        updateVersion: nil,
        daemonRunning: false,
        permissions: CuaDriverPermissionStatus(accessibility: false, screenRecording: false),
        message: "Computer Use is disabled."
    )
}

struct CuaDriverPermissionStatus: Codable, Equatable, Sendable {
    var accessibility: Bool
    var screenRecording: Bool

    var isReady: Bool {
        accessibility && screenRecording
    }
}

struct CuaDriverToolResult: Equatable, Sendable {
    var exitCode: Int32
    var output: String
    var errorOutput: String

    var succeeded: Bool {
        exitCode == 0
    }
}

struct CuaDriverUpdateInfo: Equatable, Sendable {
    var version: String
    var tag: String
    var downloadURL: String
    var sha256: String
}

enum CuaDriverError: LocalizedError, Equatable {
    case manifestMissing
    case artifactUnavailable(String)
    case bundledAppMissing(String)
    case installedAppMissing
    case executableMissing(String)
    case invalidBundleIdentifier(String)
    case checksumMismatch(expected: String, actual: String)
    case processFailed(String)
    case updateUnavailable

    var errorDescription: String? {
        switch self {
        case .manifestMissing:
            return "AuraBot Computer Use manifest is missing."
        case .artifactUnavailable(let architecture):
            return "AuraBot Computer Use is not bundled for \(architecture)."
        case .bundledAppMissing:
            return "AuraBot Computer Use needs repair because its bundled engine is missing."
        case .installedAppMissing:
            return "AuraBot Computer Use is not installed yet."
        case .executableMissing:
            return "AuraBot Computer Use needs repair because its executable is missing."
        case .invalidBundleIdentifier:
            return "AuraBot Computer Use update failed verification."
        case .checksumMismatch:
            return "AuraBot Computer Use update failed checksum verification."
        case .processFailed(let message):
            return message
        case .updateUnavailable:
            return "No AuraBot Computer Use update is available."
        }
    }
}
