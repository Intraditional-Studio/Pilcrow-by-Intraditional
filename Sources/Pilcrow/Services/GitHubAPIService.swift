import Foundation

enum GitHubAPIError: LocalizedError {
    case invalidToken
    case rateLimited(reset: Date?)
    case forbidden(String)
    case notFound
    case http(Int, String)
    case network(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "GitHub rejected this token. Check that it hasn't expired."
        case .rateLimited(let reset):
            if let reset {
                return "GitHub rate limit reached. Try again after \(reset.formatted(date: .omitted, time: .shortened))."
            }
            return "GitHub rate limit reached. Try again in a little while."
        case .forbidden(let message):
            return message.isEmpty
                ? "GitHub refused the request. Make sure the token has repo and read:user access."
                : message
        case .notFound:
            return "GitHub couldn't find that resource. Check the token's repository access."
        case .http(let code, let message):
            return "GitHub returned \(code). \(message)".trimmingCharacters(in: .whitespaces)
        case .network(let message):
            return "Couldn't reach GitHub. \(message)"
        case .decoding:
            return "GitHub sent a response Pilcrow couldn't read."
        }
    }
}

/// Minimal, token-authenticated GitHub REST client. Reads repos and authored
/// commits only; no backend or OAuth secret is involved.
struct GitHubAPIService: GitHubProviding, @unchecked Sendable {
    private let session: URLSession
    private let baseURL = URL(string: "https://api.github.com")!

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 45
        configuration.httpAdditionalHeaders = [
            "Accept": "application/vnd.github+json",
            "User-Agent": "Pilcrow/1.0"
        ]
        session = URLSession(configuration: configuration)
    }

    // MARK: - Account

    func validateToken(_ token: String) async throws -> GitHubAccountInfo {
        let user: UserDTO = try await request(path: "/user", token: token)
        return GitHubAccountInfo(login: user.login, name: user.name, avatarURL: user.avatarURL)
    }

    func fetchRepositories(token: String) async throws -> [Repository] {
        let repos: [RepoDTO] = try await request(
            path: "/user/repos",
            query: [
                URLQueryItem(name: "per_page", value: "100"),
                URLQueryItem(name: "sort", value: "pushed"),
                URLQueryItem(name: "affiliation", value: "owner,collaborator,organization_member")
            ],
            token: token
        )
        return repos
            .filter { !$0.archived }
            .prefix(40)
            .map { repo in
                Repository.github(
                    id: repo.id,
                    owner: repo.owner.login,
                    name: repo.name,
                    language: repo.language,
                    isPrivate: repo.isPrivate,
                    defaultBranch: repo.defaultBranch,
                    htmlURL: repo.htmlURL
                )
            }
    }

    // MARK: - Activity

    func recentActivity(
        token: String,
        login: String,
        repositories: [Repository],
        since: Date,
        until: Date
    ) async throws -> [ActivityEvent] {
        try await activity(token: token, login: login, repositories: repositories,
                           since: since, until: until, maxCommits: 10)
    }

    func sessionActivity(
        token: String,
        login: String,
        repositories: [Repository],
        since: Date,
        until: Date
    ) async throws -> [ActivityEvent] {
        try await activity(token: token, login: login, repositories: repositories,
                           since: since, until: until, maxCommits: 14)
    }

    private func activity(
        token: String,
        login: String,
        repositories: [Repository],
        since: Date,
        until: Date,
        maxCommits: Int
    ) async throws -> [ActivityEvent] {
        let liveRepos = repositories
            .filter { $0.isDemo != true && $0.localPath != nil && $0.isGitHubLinked }
            .prefix(5)
        guard !liveRepos.isEmpty else { return [] }

        let dateFormatter = ISO8601DateFormatter()
        let sinceString = dateFormatter.string(from: since)
        let untilString = dateFormatter.string(from: until)

        var candidates: [(repo: Repository, commit: CommitListDTO)] = []
        for repo in liveRepos {
            do {
                let commits: [CommitListDTO] = try await request(
                    path: "/repos/\(repo.owner)/\(repo.name)/commits",
                    query: [
                        URLQueryItem(name: "author", value: login),
                        URLQueryItem(name: "since", value: sinceString),
                        URLQueryItem(name: "until", value: untilString),
                        URLQueryItem(name: "per_page", value: "30")
                    ],
                    token: token
                )
                for commit in commits {
                    candidates.append((repo, commit))
                }
            } catch let error as GitHubAPIError {
                // A single inaccessible or empty repository shouldn't blank the whole session.
                if case .notFound = error { continue }
                if case .http(409, _) = error { continue }
                throw error
            }
        }

        candidates.sort { commitDate($0.commit) > commitDate($1.commit) }
        var seenSHAs = Set<String>()
        var events: [ActivityEvent] = []

        for candidate in candidates.prefix(maxCommits) where !seenSHAs.contains(candidate.commit.sha) {
            seenSHAs.insert(candidate.commit.sha)
            var event = baseEvent(repo: candidate.repo, commit: candidate.commit, fallbackDate: until)
            if let detail: CommitDetailDTO = try? await request(
                path: "/repos/\(candidate.repo.owner)/\(candidate.repo.name)/commits/\(candidate.commit.sha)",
                token: token
            ) {
                event.additions = detail.stats?.additions ?? event.additions
                event.deletions = detail.stats?.deletions ?? event.deletions
                event.filesChanged = detail.files?.count ?? event.filesChanged
            }
            events.append(event)
        }

        return events.sorted { $0.timestamp < $1.timestamp }
    }

    private func baseEvent(repo: Repository, commit: CommitListDTO, fallbackDate: Date) -> ActivityEvent {
        let message = commit.commit.message?
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? "Commit \(commit.sha.prefix(7))"
        return ActivityEvent(
            kind: .commit,
            title: message,
            repoID: repo.id,
            timestamp: parseDate(commit.commit.author?.date) ?? fallbackDate,
            additions: 0,
            deletions: 0,
            filesChanged: 0,
            commitSHA: commit.sha,
            htmlURL: commit.htmlURL,
            authorLogin: commit.author?.login
        )
    }

    private func commitDate(_ commit: CommitListDTO) -> Date {
        parseDate(commit.commit.author?.date) ?? .distantPast
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    // MARK: - Transport

    private func request<T: Decodable>(
        path: String,
        query: [URLQueryItem] = [],
        token: String
    ) async throws -> T {
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GitHubAPIError.invalidToken
        }
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw GitHubAPIError.http(-1, "Invalid URL") }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw GitHubAPIError.network(error.localizedDescription)
        } catch {
            throw GitHubAPIError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw GitHubAPIError.network("No response from GitHub.")
        }

        switch http.statusCode {
        case 200..<300:
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw GitHubAPIError.decoding(error.localizedDescription)
            }
        case 401:
            throw GitHubAPIError.invalidToken
        case 403:
            if http.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0" {
                let reset = http.value(forHTTPHeaderField: "X-RateLimit-Reset")
                    .flatMap(TimeInterval.init)
                    .map { Date(timeIntervalSince1970: $0) }
                throw GitHubAPIError.rateLimited(reset: reset)
            }
            throw GitHubAPIError.forbidden(errorMessage(from: data))
        case 404:
            throw GitHubAPIError.notFound
        default:
            throw GitHubAPIError.http(http.statusCode, errorMessage(from: data))
        }
    }

    private func errorMessage(from data: Data) -> String {
        guard let payload = try? JSONDecoder().decode(ErrorDTO.self, from: data) else { return "" }
        return payload.message ?? ""
    }
}

// MARK: - GitHub DTOs

private struct ErrorDTO: Decodable {
    let message: String?
}

private struct UserDTO: Decodable {
    let login: String
    let name: String?
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case login, name
        case avatarURL = "avatar_url"
    }
}

private struct RepoDTO: Decodable {
    struct Owner: Decodable { let login: String }

    let id: Int
    let name: String
    let owner: Owner
    let isPrivate: Bool
    let language: String?
    let defaultBranch: String?
    let htmlURL: String
    let archived: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, owner, language, archived
        case isPrivate = "private"
        case defaultBranch = "default_branch"
        case htmlURL = "html_url"
    }
}

private struct CommitListDTO: Decodable {
    struct CommitInfo: Decodable {
        struct Author: Decodable {
            let date: String?
        }
        let message: String?
        let author: Author?
    }
    struct Author: Decodable {
        let login: String?
    }

    let sha: String
    let htmlURL: String?
    let commit: CommitInfo
    let author: Author?

    enum CodingKeys: String, CodingKey {
        case sha, commit, author
        case htmlURL = "html_url"
    }
}

private struct CommitDetailDTO: Decodable {
    struct Stats: Decodable {
        let additions: Int?
        let deletions: Int?
    }
    struct File: Decodable {
        let filename: String
    }

    let stats: Stats?
    let files: [File]?
}
