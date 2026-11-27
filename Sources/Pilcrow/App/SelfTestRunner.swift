import Foundation
import AppKit
import SwiftUI

@MainActor
enum SelfTestRunner {
    static func run(store: AppStore) async {
        var failures: [String] = []
        func check(_ condition: Bool, _ label: String) {
            if condition { print("PASS  \(label)") } else { failures.append(label); print("FAIL  \(label)") }
        }

        store.resetDemoData()
        try? await Task.sleep(nanoseconds: 100_000_000)

        let realState = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Pilcrow/state.json")
        check(store.stateFileURL.path != realState?.path, "automation runs never touch the real state file")

        let startCoins = store.profile.coins
        let startSessions = store.sessions.count
        store.startSession()
        check(store.activeSession != nil, "starting a session creates a live session")
        check(store.activeSession?.repoIDs.isEmpty == false, "a live session has repositories")

        store.pauseSession()
        check(store.activeSession?.isPaused == true, "pause stops the clock")
        store.resumeSession()
        check(store.activeSession?.isRunning == true, "resume restarts the clock")

        try? await Task.sleep(nanoseconds: 1_300_000_000)
        // Look the session up by id: demo data can hold a session later today,
        // which would sort ahead of the one just ended.
        let endedID = store.activeSession?.id
        store.endSession()
        try? await Task.sleep(nanoseconds: 900_000_000)
        check(store.sessions.count == startSessions + 1, "ending a session adds one completed session")
        check(store.activeSession == nil, "ended session is no longer active")
        check(store.reportSession != nil, "ending a session opens a report")
        check(store.profile.coins > startCoins, "a session earns coins")
        let ended = store.completedSessions.first { $0.id == endedID }
        check(ended?.note == "", "short session is logged without invented events")

        store.reportSession = nil
        store.evaluateAchievements()
        check(store.isUnlocked(AchievementCatalog.find("first_light")!), "first-light achievement is held")
        check(store.owns(ShopItem.find("badge_early")!), "a badge is earned with its achievement")

        if let avatar = ShopItem.find("avatar_terminal") {
            let before = store.profile.coins
            let bought = store.buy(avatar)
            check(bought, "buying an affordable item succeeds")
            check(store.owns(avatar), "bought item is owned")
            check(store.profile.coins == before - avatar.price, "purchase deducts the right coins")
            check(store.isEquipped(avatar), "bought avatar is equipped")
        }

        if let theme = ShopItem.find("theme_blueprint") {
            let savedCoins = store.profile.coins
            store.profile.coins = 10
            let bought = store.buy(theme)
            check(!bought, "unaffordable item is declined")
            check(!store.owns(theme), "declined item stays locked")
            store.profile.coins = savedCoins
        }

        if let session = store.completedSessions.first {
            store.updateNote(sessionID: session.id, note: "Self test note")
            check(store.session(withID: session.id)?.note == "Self test note", "session notes persist in memory")
        }

        check(FileManager.default.fileExists(atPath: store.stateFileURL.path), "state file is written")
        store.completeOnboarding(name: "Test Maker", dailyGoalMinutes: 60)
        check(store.hasCompletedOnboarding, "onboarding completion is recorded")
        check(store.profile.dailyGoalMinutes == 60, "onboarding applies the daily goal")
        check(store.profile.coins == 0, "onboarding resets coins to zero")
        check(store.profile.xp == 0 && store.level.level == 1, "onboarding resets level and XP")
        check(store.profile.streak == 0 && store.profile.longestStreak == 0, "onboarding resets streaks")
        check(store.sessions.isEmpty && store.activity.isEmpty, "onboarding clears sessions and activity")
        check(store.achievementDates.isEmpty, "onboarding clears achievements")
        check(store.ownedItemIDs == Set(["theme_paper", "theme_midnight", "avatar_maker"]), "onboarding resets the collection")
        check(store.profile.name == "Test Maker", "onboarding applies the chosen name")
        let stateText = (try? String(contentsOf: store.stateFileURL, encoding: .utf8)) ?? ""
        check(!stateText.contains("access_token") && !stateText.contains("ghp_"), "GitHub token is never written to disk")

        store.updateSettings { settings in
            settings.soundEnabled = false
            settings.soundVolume = 0.35
            settings.dockBadge = true
        }
        check(store.settings.soundEnabled == false, "settings update in memory")
        check(store.settings.soundVolume == 0.35, "sound volume is clamped and stored")
        if let data = try? Data(contentsOf: store.stateFileURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let reloaded = try? decoder.decode(PersistedState.self, from: data)
            check(reloaded?.settings?.soundEnabled == false, "settings survive a reload")
            check(reloaded?.settings?.dockBadge == true, "dock badge preference is persisted")
        } else {
            check(false, "state file is readable for settings")
        }
        store.updateSettings { settings in
            settings.soundEnabled = true
            settings.soundVolume = 0.6
            settings.dockBadge = false
        }

        // MARK: Themes and badges

        check(store.canUseTheme("paper"), "light theme is free")
        check(store.canUseTheme("midnight"), "dark theme is free")
        check(!store.canUseTheme("blueprint"), "a premium theme still needs the shop")

        store.profile.coins = 2_000
        if let oxide = ShopItem.find("theme_oxide") {
            let before = store.profile.coins
            let bought = store.buy(oxide)
            check(bought, "a premium theme can be bought")
            check(store.owns(oxide), "the bought theme is owned")
            check(store.profile.equippedThemeID == "oxide", "the bought theme is equipped")
            check(store.profile.coins == before - oxide.price, "a theme purchase deducts coins")
            check(store.themeDisplayName == "Oxide", "the bought theme resolves by name")
        }
        store.equipTheme("paper")
        check(store.profile.equippedThemeID == "paper", "switching back to a free theme works")

        if let badge = ShopItem.find("badge_mono") {
            let before = store.profile.coins
            let bought = store.buy(badge)
            check(!bought, "badges cannot be bought")
            check(!store.owns(badge), "a locked badge stays earned-only")
            check(store.profile.coins == before, "a declined badge costs nothing")
        }

        store.resetDemoData()
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("pilcrow-selftest-\(UUID().uuidString)")
        let validRepo = tempRoot.appendingPathComponent("sample-project")
        let invalidRepo = tempRoot.appendingPathComponent("not-a-repo")
        do {
            try FileManager.default.createDirectory(at: validRepo.appendingPathComponent(".git"), withIntermediateDirectories: true)
            try "ref: refs/heads/main\n".write(to: validRepo.appendingPathComponent(".git/HEAD"), atomically: true, encoding: .utf8)
            try "[remote \"origin\"]\n\turl = https://github.com/example/sample-project.git\n"
                .write(to: validRepo.appendingPathComponent(".git/config"), atomically: true, encoding: .utf8)
            try FileManager.default.createDirectory(at: invalidRepo, withIntermediateDirectories: true)
        } catch {
            print("FAIL  could not prepare local repository fixtures")
            failures.append("local repo fixtures")
        }
        let added = store.addLocalRepositories(at: [validRepo])
        check(added == 1, "a folder with .git is accepted")
        check(store.activeRepositories.first?.owner == "example", "the GitHub origin is parsed")
        check(store.activeRepositories.first?.name == "sample-project", "the remote repository name is used")
        check(store.activeRepositories.first?.isGitHubLinked == true, "local repo is linked to GitHub")
        let rejected = store.addLocalRepositories(at: [invalidRepo])
        check(rejected == 0, "a folder without .git is rejected")

        // Real repository: `git log` must surface the commit even when it has
        // never been pushed and GitHub is not connected.
        let committedRepoDir = tempRoot.appendingPathComponent("committed-project")
        var fixtureReady = false
        do {
            try FileManager.default.createDirectory(at: committedRepoDir, withIntermediateDirectories: true)
            try "hello\n".write(to: committedRepoDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
            fixtureReady = runGit(["init", "-q", committedRepoDir.path])
                && runGit(["-C", committedRepoDir.path, "config", "user.name", "Selftest"])
                && runGit(["-C", committedRepoDir.path, "config", "user.email", "selftest@example.com"])
                && runGit(["-C", committedRepoDir.path, "add", "."])
                && runGit(["-C", committedRepoDir.path, "commit", "-q", "-m", "Selftest commit"])
        } catch {
            fixtureReady = false
        }
        if fixtureReady, let localRepo = try? LocalRepositoryImporter.makeRepository(from: committedRepoDir) {
            let now = Date()
            let commits = await LocalGitService.commits(
                in: localRepo,
                since: now.addingTimeInterval(-3_600),
                until: now.addingTimeInterval(3_600)
            )
            check(commits.count == 1, "local .git commits are read without GitHub")
            check(commits.first?.message == "Selftest commit", "local commit message is parsed")
            check(commits.first?.filesChanged == 1, "local commit file stats are parsed")
            check(commits.first?.additions == 1, "local commit line counts are parsed")

            // End-to-end: a commit made during a live session must land in
            // that session without GitHub being connected.
            _ = store.addLocalRepositories(at: [committedRepoDir])
            store.sessions.removeAll()
            store.activity.removeAll()
            store.draftRepoIDs = [localRepo.id]
            store.startSession()
            check(store.activeSession != nil, "a local repository starts a session")
            // Commits have whole-second timestamps; cross a second boundary so
            // the fixture commit made before the session cannot fall inside it.
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            try? "hello again\n".write(
                to: committedRepoDir.appendingPathComponent("README.md"),
                atomically: true,
                encoding: .utf8
            )
            let committed = runGit(["-C", committedRepoDir.path, "add", "."])
                && runGit(["-C", committedRepoDir.path, "commit", "-q", "-m", "Session commit"])
            check(committed, "a commit is made during the session")
            store.endSession()
            for _ in 0..<60 {
                if !store.isFinalizingSession, store.sessions.first?.isCompleted == true { break }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            let finished = store.sessions.first { $0.isCompleted }
            check(finished?.commits == 1, "a session registers the local commit")
            check(finished?.events.first?.title == "Session commit", "the session keeps the commit message")
            check(finished?.events.first?.filesChanged == 1, "the session keeps changed files")
            check(store.activity.contains { $0.commitSHA != nil }, "the commit reaches the activity feed")
        } else {
            print("FAIL  could not prepare a real git fixture")
            failures.append("real git fixture")
        }

        // MARK: Focus toolkit

        store.resetDemoData()
        try? await Task.sleep(nanoseconds: 100_000_000)

        store.draftPresetMinutes = 25
        store.draftIntent = "Selftest intent"
        store.draftTags = ["deep"]
        store.startSession()
        check(store.activeSession?.presetMinutes == 25, "a preset is stored on the live session")
        check(store.activeSession?.targetSeconds == 1_500, "a preset produces a countdown target")
        check(store.activeSession?.remaining() != nil, "a preset session exposes remaining time")
        check(store.activeSession?.intent == "Selftest intent", "session intent is captured")
        check(store.activeSession?.tags == ["deep"], "session tags are captured")
        store.discardActiveSession()

        if let session = store.completedSessions.first {
            let target = session.startedAt.addingTimeInterval(30 * 60)
            store.updateSessionTimes(sessionID: session.id, startedAt: session.startedAt, endedAt: target)
            let updated = store.session(withID: session.id)
            check(updated?.accumulatedSeconds == 1_800, "session time editing rewrites the focused window")
            check(updated?.endedAt?.timeIntervalSince1970 == target.timeIntervalSince1970, "session time editing keeps the new end time")
        }

        if var session = store.completedSessions.first {
            let extra = ActivityEvent(
                kind: .commit,
                title: "Elsewhere commit",
                repoID: session.repoIDs.first ?? "local",
                timestamp: session.startedAt.addingTimeInterval(60),
                additions: 4,
                deletions: 1,
                filesChanged: 1,
                commitSHA: "selftest\(UUID().uuidString.prefix(6))"
            )
            let before = session.commits
            session.unclaimedEvents = [extra]
            if let index = store.sessions.firstIndex(where: { $0.id == session.id }) {
                store.sessions[index] = session
            }
            check(store.session(withID: session.id)?.unclaimedEvents.count == 1, "unclaimed commits are held on the session")
            _ = store.addUnclaimedEvents(sessionID: session.id)
            let merged = store.session(withID: session.id)
            check(merged?.unclaimedEvents.isEmpty == true, "adding unclaimed commits clears the tray")
            check(merged?.commits == before + 1, "adding unclaimed commits raises the commit count")
        }

        let startFreezeCoins = store.profile.coins
        store.streakFreezes = 0
        store.profile.coins = 1_000
        let froze = store.buyStreakFreeze()
        check(froze, "a streak freeze can be bought")
        check(store.profile.coins == 800, "a streak freeze costs 200 coins")
        check(store.streakFreezes == 1, "a bought freeze is banked")
        store.profile.coins = startFreezeCoins

        store.startBreak(minutes: 5)
        check(store.isOnBreak, "a break starts after a targeted session")
        check((store.breakRemaining() ?? 0) > 0, "the break has a countdown")
        store.endBreak()
        check(!store.isOnBreak, "a break can be skipped")

        store.evaluateQuests(silent: true)
        check(store.completedQuestCount > 0, "quests are evaluated and claimed")
        check(!store.dailyStripText.isEmpty && store.dailyStripText.contains("Pilcrow —"), "the daily strip can be copied as text")

        let insightSessions = store.completedSessions
        let insights = ReportInsights(sessions: insightSessions, previous: [])
        check(insights.buckets.count == 4, "session length insights expose four buckets")
        check(insights.deltas.count == 4, "week-over-week insights expose four deltas")
        check(insights.heatmap.count == 7 * ReportInsights.hourBlocks, "best-hours heatmap covers the week")
        check(insights.hasData == !insightSessions.isEmpty, "insights agree with the session ledger")

        store.updateSettings { settings in
            settings.menuBarTimer = false
            settings.liveCommitWatch = false
            settings.idleThresholdMinutes = 12
            settings.defaultPresetMinutes = 90
        }
        if let data = try? Data(contentsOf: store.stateFileURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let reloaded = try? decoder.decode(PersistedState.self, from: data)
            check(reloaded?.settings?.menuBarTimer == false, "menu bar preference survives a reload")
            check(reloaded?.settings?.liveCommitWatch == false, "live watch preference survives a reload")
            check(reloaded?.settings?.idleThresholdMinutes == 12, "idle threshold survives a reload")
            check(reloaded?.settings?.defaultPresetMinutes == 90, "default preset survives a reload")
        }
        store.updateSettings { settings in
            settings.menuBarTimer = true
            settings.liveCommitWatch = true
            settings.idleThresholdMinutes = 5
            settings.defaultPresetMinutes = 0
        }

        try? FileManager.default.removeItem(at: tempRoot)
        store.resetDemoData()

        print(failures.isEmpty ? "SELFTEST PASSED" : "SELFTEST FAILED: \(failures.joined(separator: ", "))")
        exit(0)
    }

    @discardableResult
    private static func runGit(_ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
