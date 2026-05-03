import Foundation

struct CuaDriverInstallationManager {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    var applicationSupportDirectory: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("AuraBot", isDirectory: true)
            .appendingPathComponent("ComputerUse", isDirectory: true)
    }

    var installedAppURL: URL {
        applicationSupportDirectory.appendingPathComponent("CuaDriver.app", isDirectory: true)
    }

    var socketURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
            .appendingPathComponent("AuraBot", isDirectory: true)
            .appendingPathComponent("ComputerUse", isDirectory: true)
            .appendingPathComponent("aurabot-computer-use.sock")
    }

    var recordingDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Recordings", isDirectory: true)
    }

    func loadManifest() throws -> CuaDriverVendorManifest {
        let candidates = manifestCandidates()
        for url in candidates where fileManager.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(CuaDriverVendorManifest.self, from: data)
        }
        throw CuaDriverError.manifestMissing
    }

    func bundledVersion() -> String? {
        try? loadManifest().version
    }

    func bundledAppURL() throws -> URL {
        let manifest = try loadManifest()
        let architecture = currentArchitecture()
        guard let artifact = manifest.artifacts.first(where: {
            $0.platform == "darwin" && $0.architecture == architecture
        }) else {
            throw CuaDriverError.artifactUnavailable(architecture)
        }

        for base in vendorRootCandidates() {
            let candidate = base.appendingPathComponent(artifact.appPath, isDirectory: true)
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        throw CuaDriverError.bundledAppMissing(artifact.appPath)
    }

    func installedExecutableURL() throws -> URL {
        let executable = installedAppURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent("cua-driver")

        guard fileManager.isExecutableFile(atPath: executable.path) else {
            throw CuaDriverError.executableMissing(executable.path)
        }

        return executable
    }

    func installedVersion() -> String? {
        bundleVersion(for: installedAppURL)
    }

    func installIfNeeded() throws -> URL {
        if fileManager.fileExists(atPath: installedAppURL.path),
           try validateBundle(at: installedAppURL) {
            return installedAppURL
        }

        return try repairInstall()
    }

    func repairInstall() throws -> URL {
        let source = try bundledAppURL()
        return try installApp(from: source)
    }

    func installApp(from source: URL) throws -> URL {
        try fileManager.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
        let staging = applicationSupportDirectory
            .appendingPathComponent("CuaDriver-\(UUID().uuidString).app", isDirectory: true)

        if fileManager.fileExists(atPath: staging.path) {
            try fileManager.removeItem(at: staging)
        }

        try fileManager.copyItem(at: source, to: staging)
        guard try validateBundle(at: staging) else {
            try? fileManager.removeItem(at: staging)
            throw CuaDriverError.invalidBundleIdentifier(bundleIdentifier(for: staging) ?? "missing")
        }

        let backup = applicationSupportDirectory
            .appendingPathComponent("CuaDriver.previous.app", isDirectory: true)
        if fileManager.fileExists(atPath: backup.path) {
            try fileManager.removeItem(at: backup)
        }
        if fileManager.fileExists(atPath: installedAppURL.path) {
            try fileManager.moveItem(at: installedAppURL, to: backup)
        }
        try fileManager.moveItem(at: staging, to: installedAppURL)
        return installedAppURL
    }

    func validateBundle(at url: URL) throws -> Bool {
        bundleIdentifier(for: url) == "com.trycua.driver" &&
            fileManager.isExecutableFile(
                atPath: url
                    .appendingPathComponent("Contents/MacOS/cua-driver")
                    .path
            )
    }

    func bundleVersion(for url: URL) -> String? {
        infoValue(for: "CFBundleShortVersionString", in: url)
    }

    private func bundleIdentifier(for url: URL) -> String? {
        infoValue(for: "CFBundleIdentifier", in: url)
    }

    private func infoValue(for key: String, in appURL: URL) -> String? {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ) as? [String: Any] else {
            return nil
        }
        return plist[key] as? String
    }

    private func manifestCandidates() -> [URL] {
        vendorRootCandidates().map {
            $0.appendingPathComponent("manifest.json")
        }
    }

    private func vendorRootCandidates() -> [URL] {
        var candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("CuaDriver", isDirectory: true),
            Bundle.module.resourceURL?.appendingPathComponent("CuaDriver", isDirectory: true)
        ].compactMap { $0 }

        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        candidates.append(
            sourceRoot
                .appendingPathComponent("Vendor", isDirectory: true)
                .appendingPathComponent("CuaDriver", isDirectory: true)
        )
        return candidates
    }

    private func currentArchitecture() -> String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x64"
        #endif
    }
}
