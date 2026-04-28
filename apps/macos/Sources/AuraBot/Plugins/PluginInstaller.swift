import CryptoKit
import Foundation

struct PluginRegistryStore {
    private let fileManager: FileManager
    let pluginsDirectory: URL
    let registryURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.pluginsDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".aurabot", isDirectory: true)
            .appendingPathComponent("plugins", isDirectory: true)
        self.registryURL = pluginsDirectory.appendingPathComponent("registry.json")
    }

    func load() -> [InstalledPluginRecord] {
        guard let data = try? Data(contentsOf: registryURL) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([InstalledPluginRecord].self, from: data)) ?? []
    }

    func save(_ records: [InstalledPluginRecord]) throws {
        try fileManager.createDirectory(at: pluginsDirectory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(records)
        try data.write(to: registryURL, options: [.atomic])
    }
}

final class PluginInstaller: @unchecked Sendable {
    static let catalogURLString = "https://prajwalkumar2343.github.io/aurabot/plugins/catalog.json"

    private let session: URLSession
    private let fileManager: FileManager
    private let registryStore: PluginRegistryStore

    init(
        session: URLSession = .shared,
        fileManager: FileManager = .default,
        registryStore: PluginRegistryStore = PluginRegistryStore()
    ) {
        self.session = session
        self.fileManager = fileManager
        self.registryStore = registryStore
    }

    var installedPlugins: [InstalledPluginRecord] {
        registryStore.load()
    }

    func refreshCatalog() async throws -> [WorkspacePluginCatalogItem] {
        let trimmed = Self.catalogURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let catalogURL = URL(string: trimmed) else {
            return WorkspacePluginCatalog.developmentFallback
        }

        let (data, response) = try await session.data(from: catalogURL)
        try validateHTTPResponse(response)

        let decoder = JSONDecoder()
        let catalog = try decoder.decode(RemotePluginCatalog.self, from: data)

        let baseURL = catalogURL.deletingLastPathComponent()
        var items: [WorkspacePluginCatalogItem] = []

        for entry in catalog.plugins {
            let manifestURL = resolvedURL(entry.manifestURL, relativeTo: baseURL)
            let manifest = try await fetchManifest(from: manifestURL)
            let packageURL = entry.packageURL.map { resolvedURL($0, relativeTo: baseURL) }
            items.append(
                WorkspacePluginCatalog.item(
                    from: manifest,
                    manifestURL: manifestURL,
                    packageURL: packageURL,
                    sha256: entry.sha256
                )
            )
        }

        return items
    }

    func install(_ plugin: WorkspacePluginCatalogItem) async throws -> InstalledPluginRecord {
        let manifest: PluginManifest

        switch plugin.source {
        case .bundled:
            manifest = PluginManifest.developmentManifest(for: plugin)
        case let .remote(manifestURL, packageURL, sha256):
            manifest = try await fetchManifest(from: manifestURL)
            if let packageURL {
                try await downloadPackage(from: packageURL, pluginID: plugin.id, sha256: sha256)
            }
        }

        try validate(manifest)

        let installDirectory = registryStore.pluginsDirectory
            .appendingPathComponent(manifest.pluginID, isDirectory: true)
            .appendingPathComponent(manifest.version, isDirectory: true)
        try fileManager.createDirectory(at: installDirectory, withIntermediateDirectories: true)

        let manifestData = try JSONEncoder.pluginEncoder.encode(manifest)
        try manifestData.write(to: installDirectory.appendingPathComponent("aurabot.plugin.json"), options: [.atomic])

        var records = registryStore.load().filter { $0.pluginID != manifest.pluginID }
        let record = InstalledPluginRecord(
            pluginID: manifest.pluginID,
            name: manifest.name,
            version: manifest.version,
            installedAt: Date(),
            onboardingCompleted: !manifest.onboarding.required,
            installDirectory: installDirectory.path,
            manifest: manifest
        )
        records.append(record)
        try registryStore.save(records.sorted { $0.name < $1.name })
        return record
    }

    func markOnboardingCompleted(pluginID: String) throws -> InstalledPluginRecord? {
        var records = registryStore.load()
        guard let index = records.firstIndex(where: { $0.pluginID == pluginID }) else {
            return nil
        }

        records[index].onboardingCompleted = true
        try registryStore.save(records)
        return records[index]
    }

    private func fetchManifest(from url: URL) async throws -> PluginManifest {
        let (data, response) = try await session.data(from: url)
        try validateHTTPResponse(response)
        return try JSONDecoder().decode(PluginManifest.self, from: data)
    }

    private func downloadPackage(from url: URL, pluginID: String, sha256: String?) async throws {
        let (downloadedURL, response) = try await session.download(from: url)
        try validateHTTPResponse(response)

        if let expectedDigest = normalizedSHA256(sha256) {
            let actualDigest = try sha256Digest(for: downloadedURL)
            guard actualDigest == expectedDigest else {
                throw PluginInstallError.checksumMismatch(expected: expectedDigest, actual: actualDigest)
            }
        }

        let cacheDirectory = registryStore.pluginsDirectory
            .appendingPathComponent(pluginID, isDirectory: true)
            .appendingPathComponent("downloads", isDirectory: true)
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        let destination = cacheDirectory.appendingPathComponent(url.lastPathComponent.isEmpty ? "plugin.package" : url.lastPathComponent)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: downloadedURL, to: destination)
    }

    private func normalizedSHA256(_ value: String?) -> String? {
        let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard let normalized, !normalized.isEmpty else { return nil }
        return normalized.hasPrefix("sha256:") ? String(normalized.dropFirst("sha256:".count)) : normalized
    }

    private func sha256Digest(for fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        return SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func validate(_ manifest: PluginManifest) throws {
        guard manifest.schemaVersion == "aurabot-plugin-v1" else {
            throw PluginInstallError.unsupportedSchema
        }
        guard manifest.pluginID.range(of: #"^[a-z0-9]+(\.[a-z0-9-]+)+$"#, options: .regularExpression) != nil else {
            throw PluginInstallError.invalidPluginID
        }
    }

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw PluginInstallError.downloadFailed(statusCode: http.statusCode)
        }
    }

    private func resolvedURL(_ url: URL, relativeTo baseURL: URL) -> URL {
        if url.scheme != nil {
            return url
        }
        return URL(string: url.relativeString, relativeTo: baseURL)?.absoluteURL ?? url
    }
}

private extension JSONEncoder {
    static var pluginEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension PluginManifest {
    static func developmentManifest(for plugin: WorkspacePluginCatalogItem) -> PluginManifest {
        PluginManifest(
            schemaVersion: "aurabot-plugin-v1",
            pluginID: plugin.id,
            name: plugin.name,
            version: plugin.version,
            description: plugin.summary,
            icon: plugin.icon,
            compatibility: PluginCompatibility(hostAPI: "^1.0.0", memoryAPI: "memory-v2"),
            entrypoints: PluginEntrypoints(ui: nil, context: nil, memory: nil, agent: nil, tools: nil),
            permissions: PluginPermissionManifest(
                hostPermissions: plugin.onboarding.requiredHostPermissions,
                contextSources: ["browser", "app"],
                memory: ["read_core", "write_plugin_namespace", "search_core"],
                networkDomains: []
            ),
            onboarding: plugin.onboarding,
            install: PluginInstallManifest(defaultEnabled: true, requiresHostRelaunch: false),
            presentation: PluginPresentationManifest(
                workspaceTitle: plugin.name,
                workspaceIcon: plugin.icon,
                workspaceSections: ["Workspace", "Context", "Actions"]
            )
        )
    }
}
