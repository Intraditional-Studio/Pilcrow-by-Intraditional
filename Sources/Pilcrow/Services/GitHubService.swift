import Foundation

/// The app talks to GitHub through this seam. A mock provider powers demo mode,
/// and `GitHubAPIService` can be swapped in once a token is connected.
protocol GitHubProviding: Sendable {
    func validateToken(_ token: String) async throws -> GitHubAccountInfo
    func fetchRepositories(token: String) async throws -> [Repository]
    func recentActivity(
        token: String,
        login: String,
        repositories: [Repository],
        since: Date,
        until: Date
    ) async throws -> [ActivityEvent]
    func sessionActivity(
        token: String,
        login: String,
        repositories: [Repository],
        since: Date,
        until: Date
    ) async throws -> [ActivityEvent]
}

struct MockGitHubService: GitHubProviding {
    func validateToken(_ token: String) async throws -> GitHubAccountInfo {
        try? await Task.sleep(nanoseconds: 220_000_000)
        return GitHubAccountInfo(login: "seb", name: "Seb", avatarURL: nil)
    }

    func fetchRepositories(token: String) async throws -> [Repository] {
        try? await Task.sleep(nanoseconds: 300_000_000)
        return SampleData.makeSeed().repositories
    }

    func recentActivity(
        token: String,
        login: String,
        repositories: [Repository],
        since: Date,
        until: Date
    ) async throws -> [ActivityEvent] {
        try? await Task.sleep(nanoseconds: 650_000_000)
        return MockActivityFactory.freshEvents(repositories: repositories, now: until)
    }

    func sessionActivity(
        token: String,
        login: String,
        repositories: [Repository],
        since: Date,
        until: Date
    ) async throws -> [ActivityEvent] {
        try? await Task.sleep(nanoseconds: 250_000_000)
        let minutes = max(1, until.timeIntervalSince(since) / 60)
        return MockActivityFactory.events(repoIDs: repositories.map(\.id), from: since, minutes: minutes)
    }
}
