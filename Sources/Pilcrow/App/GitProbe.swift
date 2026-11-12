import Foundation

/// Development helper: `--git-probe <folder>` prints what Pilcrow reads from a
/// local repository. Useful when a session isn't picking up commits.
@MainActor
enum GitProbe {
    static func run(path: String) async {
        let url = URL(fileURLWithPath: path)
        do {
            let repo = try LocalRepositoryImporter.makeRepository(from: url)
            let now = Date()
            let commits = await LocalGitService.commits(
                in: repo,
                since: now.addingTimeInterval(-30 * 86_400),
                until: now.addingTimeInterval(3_600)
            )
            print("GIT PROBE \(repo.fullName) local=\(repo.localPath ?? "-") github=\(repo.isGitHubLinked)")
            print("GIT PROBE commits=\(commits.count)")
            for commit in commits {
                print("  \(commit.sha.prefix(8))  \(commit.date.formatted(.iso8601))  +\(commit.additions) -\(commit.deletions)  \(commit.filesChanged) files  \(commit.message)")
            }
            exit(0)
        } catch {
            print("GIT PROBE FAIL: \(error.localizedDescription)")
            exit(1)
        }
    }
}
