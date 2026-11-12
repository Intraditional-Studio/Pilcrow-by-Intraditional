import Foundation

enum SampleData {
    /// A brand new, production install. No invented sessions, repos, or history.
    static func makeFresh(now: Date = Date()) -> PersistedState {
        PersistedState(
            profile: UserProfile(
                name: "Maker",
                handle: "maker",
                bio: "",
                joinedAt: now,
                xp: 0,
                coins: 0,
                streak: 0,
                longestStreak: 0,
                dailyGoalMinutes: 90,
                equippedThemeID: "paper",
                equippedAvatarID: "avatar_maker",
                equippedBadgeID: nil,
                equippedDecorIDs: []
            ),
            repositories: [],
            sessions: [],
            activity: [],
            ownedItemIDs: ["theme_paper", "theme_midnight", "avatar_maker"],
            achievements: [:],
            draftRepoIDs: [],
            lastSyncedAt: nil,
            githubConnection: nil,
            onboardingCompleted: false
        )
    }

    static func makeSeed(now: Date = Date()) -> PersistedState {
        let calendar = Calendar.current
        let repos: [Repository] = [
            Repository(id: "demo:seb/tiny-tools", owner: "seb", name: "tiny-tools", language: "Swift", symbol: "wrench.and.screwdriver", isPrivate: false, isDemo: true, isArchived: false),
            Repository(id: "demo:seb/fieldnotes", owner: "seb", name: "fieldnotes", language: "Rust", symbol: "book.closed", isPrivate: true, isDemo: true, isArchived: false),
            Repository(id: "demo:studio/paper-trail", owner: "studio", name: "paper-trail", language: "TypeScript", symbol: "doc.text", isPrivate: false, isDemo: true, isArchived: false),
            Repository(id: "demo:seb/shelf", owner: "seb", name: "shelf", language: "CSS", symbol: "square.stack.3d.up", isPrivate: true, isDemo: true, isArchived: false)
        ]

        var sessions: [Session] = []
        var activity: [ActivityEvent] = []

        struct Seed {
            let daysAgo: Int
            let hour: Int
            let minute: Int
            let minutes: Double
            let repoIndices: [Int]
            let note: String
        }

        let seeds: [Seed] = [
            Seed(daysAgo: 0, hour: 14, minute: 20, minutes: 44, repoIndices: [0, 2], note: "Noodled on the timer edge cases."),
            Seed(daysAgo: 1, hour: 9, minute: 30, minutes: 112, repoIndices: [0, 1], note: "Deep pass on the sync layer."),
            Seed(daysAgo: 2, hour: 20, minute: 5, minutes: 36, repoIndices: [2], note: "Small type fixes. Left it cleaner."),
            Seed(daysAgo: 3, hour: 11, minute: 10, minutes: 74, repoIndices: [1, 3], note: "Sketching the shelf idea."),
            Seed(daysAgo: 5, hour: 15, minute: 45, minutes: 52, repoIndices: [0], note: "Chased a ghost in the build."),
            Seed(daysAgo: 6, hour: 10, minute: 0, minutes: 95, repoIndices: [0, 2, 3], note: "First real session with the new setup."),
            Seed(daysAgo: 7, hour: 17, minute: 25, minutes: 28, repoIndices: [2], note: "Quick cleanup before dinner.")
        ]

        for (seedIndex, seed) in seeds.enumerated() {
            let day = calendar.date(byAdding: .day, value: -seed.daysAgo, to: now) ?? now
            guard let start = calendar.date(bySettingHour: seed.hour, minute: seed.minute, second: 0, of: day) else { continue }
            let end = start.addingTimeInterval(seed.minutes * 60)
            let repoIDs = seed.repoIndices.map { repos[$0].id }
            let events = MockActivityFactory.events(repoIDs: repoIDs, from: start, minutes: seed.minutes)
            let commits = events.filter { $0.kind == .commit }.count
            let files = events.reduce(0) { $0 + $1.filesChanged }
            let breakdown = CoinEngine.calculate(minutes: seed.minutes, commits: commits, filesChanged: files, streak: 0)
            let xp = 20 + Int(seed.minutes) * 3 + commits * 4
            let intents = ["Tighten the timer edge cases", "Sync layer, properly", "Type and spacing pass", "Sketch the shelf idea", "Chase the build ghost", "New setup, first real run", "Small cleanup before dinner"]
            let tagSets: [[String]] = [["deep"], ["deep", "refactor"], ["fix"], ["deep"], ["fix", "review"], ["ship"], ["refactor"]]
            sessions.append(Session(
                startedAt: start,
                accumulatedSeconds: seed.minutes * 60,
                runningSince: nil,
                endedAt: end,
                repoIDs: repoIDs,
                events: events,
                coinsEarned: breakdown.total,
                xpEarned: xp,
                note: seed.note,
                coinBreakdown: breakdown,
                intent: intents[seedIndex % intents.count],
                tags: tagSets[seedIndex % tagSets.count],
                presetMinutes: seed.minutes >= 90 ? 90 : (seed.minutes >= 50 ? 50 : 25)
            ))
            activity.append(contentsOf: events)
        }

        var profile = UserProfile(
            name: "Seb",
            handle: "seb",
            bio: "Building small tools, slowly.",
            joinedAt: now.addingTimeInterval(-86_400 * 46),
            xp: 1180,
            coins: 860,
            streak: 4,
            longestStreak: 9,
            dailyGoalMinutes: 120,
            equippedThemeID: "paper",
            equippedAvatarID: "avatar_maker",
            equippedBadgeID: nil,
            equippedDecorIDs: ["decor_mug"]
        )
        profile.streak = computedStreak(sessions: sessions, now: now)

        let achievements: [String: Date] = [
            "first_light": now.addingTimeInterval(-86_400 * 46),
            "deep_work": now.addingTimeInterval(-86_400 * 1),
            "streak_3": now.addingTimeInterval(-86_400 * 4)
        ]

        return PersistedState(
            profile: profile,
            repositories: repos,
            sessions: sessions.sorted { $0.startedAt > $1.startedAt },
            activity: activity.sorted { $0.timestamp > $1.timestamp },
            ownedItemIDs: ["theme_paper", "theme_midnight", "avatar_maker", "decor_mug"],
            achievements: achievements,
            draftRepoIDs: [repos[0].id, repos[2].id],
            lastSyncedAt: now.addingTimeInterval(-540),
            onboardingCompleted: true
        )
    }

    static func computedStreak(sessions: [Session], frozenDays: Set<String> = [], now: Date = Date()) -> Int {
        var days = Set(sessions.filter(\.isCompleted).map { $0.startedAt.startOfDay().dayKey })
        days.formUnion(frozenDays)
        guard !days.isEmpty else { return 0 }
        let calendar = Calendar.current
        var cursor = now.startOfDay()
        if !days.contains(cursor.dayKey) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        var streak = 0
        while days.contains(cursor.dayKey) {
            streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return streak
    }
}

enum MockActivityFactory {
    private static let commitTitles = [
        "Tighten timer state transitions",
        "Add empty state for the shelf",
        "Fix off-by-one in streak calc",
        "Extract coin math into one place",
        "Polish the session report chart",
        "Cache fonts instead of reloading",
        "Handle a paused session on relaunch",
        "Simplify the repository picker",
        "Add keyboard shortcut for new session",
        "Refactor activity row into a component",
        "Use a spring for the coin counter",
        "Give the chart a proper baseline"
    ]

    static func events(repoIDs: [String], from start: Date, minutes: Double) -> [ActivityEvent] {
        guard let primary = repoIDs.first else { return [] }
        let commitCount = max(1, min(7, Int((minutes / 28).rounded(.up))))
        let extraCount = minutes > 45 ? 2 : 1
        var events: [ActivityEvent] = []
        let span = max(60, minutes * 60 - 120)

        for index in 0..<commitCount {
            let title = commitTitles[(index + Int(minutes) + repoIDs.count) % commitTitles.count]
            let timestamp = start.addingTimeInterval(span * (Double(index + 1) / Double(commitCount + 1)))
            events.append(ActivityEvent(
                kind: .commit,
                title: title,
                repoID: repoIDs[index % repoIDs.count],
                timestamp: timestamp,
                additions: 4 + (index * 13 + Int(minutes)) % 86,
                deletions: 1 + (index * 7 + Int(minutes / 3)) % 32,
                filesChanged: 1 + (index * 2 + 1) % 6,
                commitSHA: String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(7))
            ))
        }

        for index in 0..<extraCount {
            let kind: GitHubEventKind = index == 0 ? .pullRequest : .review
            let title = index == 0 ? "Open: calmer session controls" : "Reviewed: settings cleanup"
            events.append(ActivityEvent(
                kind: kind,
                title: title,
                repoID: repoIDs[(index + 1) % repoIDs.count],
                timestamp: start.addingTimeInterval(span * (Double(index + 2) / Double(extraCount + 3))),
                additions: kind == .pullRequest ? 38 : 0,
                deletions: kind == .pullRequest ? 12 : 0,
                filesChanged: kind == .pullRequest ? 4 : 0
            ))
        }
        _ = primary
        return events.sorted { $0.timestamp < $1.timestamp }
    }

    static func freshEvents(repositories: [Repository], now: Date) -> [ActivityEvent] {
        guard !repositories.isEmpty else { return [] }
        let repo = repositories[Int.random(in: 0..<repositories.count)]
        let count = Int.random(in: 1...3)
        return (0..<count).map { index in
            let kind: GitHubEventKind = index == count - 1 && Bool.random() ? .pullRequest : .commit
            return ActivityEvent(
                kind: kind,
                title: kind == .commit
                    ? commitTitles.randomElement() ?? "Small cleanup"
                    : "Open: polish pass",
                repoID: repo.id,
                timestamp: now.addingTimeInterval(Double(-index * 240)),
                additions: Int.random(in: 2...64),
                deletions: Int.random(in: 0...21),
                filesChanged: Int.random(in: 1...5),
                commitSHA: kind == .commit ? String(UUID().uuidString.prefix(7)) : nil
            )
        }
    }
}
