import Foundation

enum AppSkillLoaderError: Error, Equatable {
    case directoryNotFound(String)
    case noSkillFiles(String)
}

struct AppSkillLoader {
    private let decoder: JSONDecoder

    init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    func loadBundledSkills() throws -> [AppSkillManifest] {
        #if SWIFT_PACKAGE
        let baseURL = Bundle.module.resourceURL?
            .appendingPathComponent("ComputerUseSkills", isDirectory: true)
        #else
        let baseURL = Bundle.main.resourceURL?
            .appendingPathComponent("ComputerUseSkills", isDirectory: true)
        #endif

        guard let baseURL else {
            throw AppSkillLoaderError.directoryNotFound("ComputerUseSkills")
        }

        return try loadSkills(from: baseURL)
    }

    func loadSkills(from directory: URL) throws -> [AppSkillManifest] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            throw AppSkillLoaderError.directoryNotFound(directory.path)
        }

        let files = try skillFiles(in: directory)
        guard !files.isEmpty else {
            throw AppSkillLoaderError.noSkillFiles(directory.path)
        }

        let skills = try files.map { url in
            let data = try Data(contentsOf: url)
            return try decoder.decode(AppSkillManifest.self, from: data)
        }

        return skills.sorted {
            if $0.priority == $1.priority {
                return $0.id < $1.id
            }
            return $0.priority > $1.priority
        }
    }

    private func skillFiles(in directory: URL) throws -> [URL] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var files: [URL] = []

        for url in contents {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                files.append(contentsOf: try skillFiles(in: url))
            } else if url.lastPathComponent == "skill.json" {
                files.append(url)
            }
        }

        return files
    }
}
