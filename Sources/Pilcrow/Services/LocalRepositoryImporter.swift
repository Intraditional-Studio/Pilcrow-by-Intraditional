import Foundation
import AppKit

enum LocalRepositoryError: LocalizedError {
    case notGitRepository(String)
    case unreadable(String)
    case duplicate(String)

    var errorDescription: String? {
        switch self {
        case .notGitRepository(let name):
            return "\(name) isn't a Git repository. Choose a folder containing a .git directory."
        case .unreadable(let name):
            return "Couldn't read the Git metadata in \(name)."
        case .duplicate(let name):
            return "\(name) is already in your repository list."
        }
    }
}

@MainActor
enum LocalRepositoryPicker {
    static func chooseFolders() -> [URL] {
        let panel = NSOpenPanel()
        panel.title = "Add local repositories"
        panel.message = "Choose Git repository folders. Only folders containing a .git directory are accepted."
        panel.prompt = "Add repositories"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true
        panel.canCreateDirectories = false
        return panel.runModal() == .OK ? panel.urls : []
    }
}

enum LocalRepositoryImporter {
    static func makeRepository(from folder: URL) throws -> Repository {
        let fileManager = FileManager.default
        let root = folder.standardizedFileURL
        guard fileManager.fileExists(atPath: root.path) else {
            throw LocalRepositoryError.unreadable(root.lastPathComponent)
        }

        let gitMetadata = root.appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: gitMetadata.path, isDirectory: &isDirectory) else {
            throw LocalRepositoryError.notGitRepository(root.lastPathComponent)
        }

        let gitDirectory: URL
        if isDirectory.boolValue {
            gitDirectory = gitMetadata
        } else {
            guard let pointer = try? String(contentsOf: gitMetadata, encoding: .utf8),
                  let line = pointer
                    .split(whereSeparator: \.isNewline)
                    .first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("gitdir:") }),
                  let target = line.split(separator: ":", maxSplits: 1).last
            else {
                throw LocalRepositoryError.notGitRepository(root.lastPathComponent)
            }
            let rawPath = target.trimmingCharacters(in: .whitespacesAndNewlines)
            gitDirectory = URL(fileURLWithPath: rawPath, relativeTo: root).standardizedFileURL
        }

        guard fileManager.fileExists(atPath: gitDirectory.appendingPathComponent("HEAD").path) else {
            throw LocalRepositoryError.notGitRepository(root.lastPathComponent)
        }

        let remote = readOriginURL(gitDirectory: gitDirectory)
        let github = parseGitHubRemote(remote)
        let language = detectLanguage(in: root)
        let localID = "local:\(root.path)"
        let name = github?.name ?? root.lastPathComponent
        let owner = github?.owner ?? "local"
        let remoteURL = github.map { "https://github.com/\($0.owner)/\($0.name)" }

        return Repository(
            id: localID,
            owner: owner,
            name: name,
            language: language,
            symbol: symbol(for: language),
            isPrivate: false,
            githubID: nil,
            isDemo: false,
            isArchived: false,
            defaultBranch: nil,
            htmlURL: remoteURL,
            localPath: root.path,
            remoteURL: remoteURL
        )
    }

    // MARK: - Git metadata

    private static func readOriginURL(gitDirectory: URL) -> String? {
        guard let config = try? String(contentsOf: gitDirectory.appendingPathComponent("config"), encoding: .utf8) else {
            return nil
        }
        var inOrigin = false
        for rawLine in config.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") {
                inOrigin = line.lowercased() == "[remote \"origin\"]"
                continue
            }
            guard inOrigin, line.lowercased().hasPrefix("url") else { continue }
            guard let equals = line.firstIndex(of: "=") else { continue }
            let value = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            if !value.isEmpty { return value }
        }
        return nil
    }

    static func parseGitHubRemote(_ remote: String?) -> (owner: String, name: String)? {
        guard let remote else { return nil }
        let trimmed = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = trimmed.lowercased().range(of: "github.com") else { return nil }
        var suffix = String(trimmed[range.upperBound...])
        suffix = suffix.trimmingCharacters(in: CharacterSet(charactersIn: ":/"))
        if suffix.hasSuffix(".git") { suffix.removeLast(4) }
        let parts = suffix.split(separator: "/").map(String.init).filter { !$0.isEmpty }
        guard parts.count >= 2 else { return nil }
        let owner = parts[parts.count - 2]
        let name = parts[parts.count - 1]
        guard !owner.isEmpty, !name.isEmpty else { return nil }
        return (owner, name)
    }

    // MARK: - Language

    private static func detectLanguage(in folder: URL) -> String {
        let fileManager = FileManager.default
        func exists(_ name: String) -> Bool {
            fileManager.fileExists(atPath: folder.appendingPathComponent(name).path)
        }
        if exists("Package.swift") { return "Swift" }
        if exists("Cargo.toml") { return "Rust" }
        if exists("go.mod") { return "Go" }
        if exists("tsconfig.json") { return "TypeScript" }
        if exists("package.json") { return "JavaScript" }
        if exists("pyproject.toml") || exists("requirements.txt") { return "Python" }
        if exists("Gemfile") { return "Ruby" }
        if exists("pom.xml") || exists("build.gradle") || exists("build.gradle.kts") { return "Kotlin" }
        if exists("CMakeLists.txt") { return "C++" }
        if let entries = try? fileManager.contentsOfDirectory(atPath: folder.path) {
            if entries.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }) {
                return "Swift"
            }
        }
        return "Git"
    }

    private static func symbol(for language: String) -> String {
        switch language {
        case "Swift": "swift"
        case "Rust": "gearshape.2"
        case "Go": "chevron.left.forwardslash.chevron.right"
        case "Python": "terminal"
        case "Ruby": "diamond"
        case "TypeScript", "JavaScript": "curlybraces"
        default: "folder"
        }
    }
}
