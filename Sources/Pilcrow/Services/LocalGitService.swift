import Foundation

/// A commit read straight from the local `.git` directory. Local commits are
/// the source of truth for a focus session: they exist before a push, on any
/// branch, and without a GitHub connection.
struct LocalGitCommit: Sendable {
    var sha: String
    var message: String
    var authorName: String
    var authorEmail: String
    var date: Date
    var additions: Int
    var deletions: Int
    var filesChanged: Int
}

/// Reads commits from a local repository by shelling out to `git`. This keeps
/// Pilcrow accurate for work that hasn't been pushed yet.
enum LocalGitService {
    // MARK: - Public

    static func commits(
        in repository: Repository,
        since: Date,
        until: Date
    ) async -> [LocalGitCommit] {
        guard let path = repository.localPath else { return [] }
        return await Task.detached(priority: .userInitiated) {
            let all = rawCommits(at: path, since: since, until: until)
            guard !all.isEmpty else { return [] }
            let identity = authorIdentity(at: path)
            return attributed(all, identity: identity)
        }.value
    }

    static func events(
        for repositories: [Repository],
        since: Date,
        until: Date
    ) async -> [ActivityEvent] {
        var events: [ActivityEvent] = []
        for repo in repositories where repo.localPath != nil && repo.isDemo != true {
            let commits = await commits(in: repo, since: since, until: until)
            for commit in commits {
                events.append(event(for: commit, in: repo))
            }
        }
        return deduped(events)
    }

    private static func event(for commit: LocalGitCommit, in repo: Repository) -> ActivityEvent {
        let url = repo.isGitHubLinked
            ? "https://github.com/\(repo.owner)/\(repo.name)/commit/\(commit.sha)"
            : nil
        return ActivityEvent(
            kind: .commit,
            title: commit.message,
            repoID: repo.id,
            timestamp: commit.date,
            additions: commit.additions,
            deletions: commit.deletions,
            filesChanged: commit.filesChanged,
            commitSHA: commit.sha,
            htmlURL: url,
            authorLogin: commit.authorEmail
        )
    }

    private static func deduped(_ events: [ActivityEvent]) -> [ActivityEvent] {
        var seen = Set<String>()
        return events
            .sorted { $0.timestamp < $1.timestamp }
            .filter { event in
                guard let sha = event.commitSHA else { return true }
                return seen.insert(sha).inserted
            }
    }

    /// Commits are only counted when they belong to the person using Pilcrow.
    /// If the repository has no configured identity, or every commit in the
    /// window has the same author, the commits are still accepted.
    private static func attributed(
        _ commits: [LocalGitCommit],
        identity: (email: String?, name: String?)
    ) -> [LocalGitCommit] {
        let email = identity.email?.lowercased()
        let name = identity.name?.lowercased()
        guard email != nil || name != nil else { return commits }

        let matched = commits.filter { commit in
            let commitEmail = commit.authorEmail.lowercased()
            let commitName = commit.authorName.lowercased()
            if let email, commitEmail == email { return true }
            if let name, commitName == name { return true }
            return false
        }
        if !matched.isEmpty { return matched }

        let uniqueEmails = Set(commits.map { $0.authorEmail.lowercased() })
        let uniqueNames = Set(commits.map { $0.authorName.lowercased() })
        if uniqueEmails.count == 1 && uniqueNames.count == 1 {
            return commits
        }
        return []
    }

    // MARK: - Git

    private static var gitExecutable: String {
        GitEnvironment.current().executable ?? "/usr/bin/git"
    }

    private static func rawCommits(at path: String, since: Date, until: Date) -> [LocalGitCommit] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        // `git log --since` rounds to whole seconds. Fetch a slightly wider
        // window and filter precisely here so a commit made just before the
        // session started never leaks in (and one made during it never drops).
        let args = [
            "-C", path,
            "log",
            "--all",
            "--no-merges",
            "--date=iso-strict",
            "--since=\(formatter.string(from: since.addingTimeInterval(-2)))",
            "--until=\(formatter.string(from: until.addingTimeInterval(2)))",
            "--pretty=format:\u{01}%H%x1f%an%x1f%ae%x1f%aI%x1f%s",
            "--numstat"
        ]
        guard let output = runGit(args) else { return [] }
        let parsed = parse(output)
        // Compare as time intervals. `Date >= Date` resolves to a Foundation
        // symbol that is missing on some runtimes, which crashes at runtime.
        let lowerBound = since.timeIntervalSince1970
        let upperBound = until.timeIntervalSince1970 + 1
        var kept: [LocalGitCommit] = []
        kept.reserveCapacity(parsed.count)
        for commit in parsed {
            let timestamp = commit.date.timeIntervalSince1970
            if timestamp >= lowerBound && timestamp <= upperBound {
                kept.append(commit)
            }
        }
        return kept
    }

    private static func authorIdentity(at path: String) -> (email: String?, name: String?) {
        let email = runGit(["-C", path, "config", "--get", "user.email"])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let name = runGit(["-C", path, "config", "--get", "user.name"])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (
            email?.isEmpty == false ? email : nil,
            name?.isEmpty == false ? name : nil
        )
    }

    private static func parse(_ output: String) -> [LocalGitCommit] {
        var commits: [LocalGitCommit] = []
        var current: LocalGitCommit?

        func flush() {
            if let current { commits.append(current) }
            current = nil
        }

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            if line.hasPrefix("\u{01}") {
                flush()
                let body = line.dropFirst()
                let parts = body.split(separator: "\u{1f}", maxSplits: 4, omittingEmptySubsequences: false)
                guard parts.count >= 5,
                      let date = parseDate(String(parts[3])) else { continue }
                current = LocalGitCommit(
                    sha: String(parts[0]),
                    message: String(parts[4]),
                    authorName: String(parts[1]),
                    authorEmail: String(parts[2]),
                    date: date,
                    additions: 0,
                    deletions: 0,
                    filesChanged: 0
                )
            } else if line.contains("\t") {
                let numbers = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
                guard numbers.count == 3, current != nil else { continue }
                let additions = Int(numbers[0]) ?? 0
                let deletions = Int(numbers[1]) ?? 0
                current?.additions += additions
                current?.deletions += deletions
                current?.filesChanged += 1
            }
        }
        flush()
        return commits
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private static func runGit(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gitExecutable)
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            return nil
        }

        let collector = OutputCollector()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            collector.data = stdout.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            process.waitUntilExit()
            group.leave()
        }

        if group.wait(timeout: .now() + 12) == .timedOut {
            process.terminate()
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        return String(data: collector.data, encoding: .utf8)
    }

    private final class OutputCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var storage = Data()

        var data: Data {
            get {
                lock.lock(); defer { lock.unlock() }
                return storage
            }
            set {
                lock.lock(); defer { lock.unlock() }
                storage = newValue
            }
        }
    }
}
