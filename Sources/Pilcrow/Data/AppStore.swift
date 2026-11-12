import Foundation
import SwiftUI
import AppKit
import ServiceManagement
import Combine
import CoreGraphics

struct DayFocus: Identifiable {
    var id: Date { date }
    let date: Date
    let seconds: TimeInterval
    let commits: Int
    let coins: Int
}

struct WeekSummary {
    let sessions: [Session]
    let focus: TimeInterval
    let commits: Int
    let files: Int
    let additions: Int
    let deletions: Int
    let coins: Int
}

@MainActor
final class AppStore: ObservableObject {
    @Published var profile: UserProfile
    @Published var repositories: [Repository]
    @Published var sessions: [Session]
    @Published var activity: [ActivityEvent]
    @Published var ownedItemIDs: Set<String>
    @Published var achievementDates: [String: Date]
    @Published var draftRepoIDs: [String]
    @Published var lastSyncedAt: Date?
    @Published var isSyncing = false
    @Published var notice: Notice?
    @Published var reportSession: Session?
    @Published var pendingLevelUp: Int?
    @Published var githubConnection: GitHubConnectionRecord?
    @Published var isConnectingGitHub = false
    @Published var githubConnectionError: String?
    @Published var isGitHubSheetPresented = false
    @Published var isFinalizingSession = false
    @Published var lastSessionSyncError: String?
    @Published var hasCompletedOnboarding: Bool
    @Published var settings: AppSettings

    // Focus toolkit
    @Published var draftIntent: String = ""
    @Published var draftTags: Set<String> = []
    @Published var draftPresetMinutes: Int = 0
    /// Only advanced while a session is running, so an idle app does not
    /// republish state (and re-render every screen) once a second.
    @Published var clockNow = Date()
    @Published var streakFreezes: Int = 0
    @Published var frozenDays: Set<String> = []
    @Published var questClaims: [String: Date] = [:]
    /// Ephemeral: a short break after an auto-ended preset session. Not part of
    /// the persisted ledger because it is just scaffolding for the next block.
    @Published var breakUntil: Date?

    private let liveGitHub = GitHubAPIService()
    private let mockGitHub = MockGitHubService()
    private var githubToken: String?
    private var noticeQueue: [Notice] = []
    private var isPresentingNotice = false
    private var ticker: AnyCancellable?
    private var liveWatchTask: Task<Void, Never>?
    private var lastLivePollAt: Date?
    private var warnedAboutMissingGit = false
    private var idlePauseStartedAt: Date?
    private var lastStreakDayKey = ""
    private var pendingAutoBreak = false

    init() {
        let loaded = Self.load()
        let state = loaded ?? SampleData.makeFresh()
        profile = state.profile
        repositories = Self.normalizedRepositories(state.repositories)
        sessions = state.sessions
        activity = state.activity
        ownedItemIDs = state.ownedItemIDs
        achievementDates = state.achievements
        draftRepoIDs = state.draftRepoIDs
        lastSyncedAt = state.lastSyncedAt
        githubConnection = state.githubConnection
        hasCompletedOnboarding = state.onboardingCompleted ?? false
        settings = state.settings ?? AppSettings()
        streakFreezes = min(StreakFreeze.maximum, max(0, state.streakFreezes ?? 0))
        frozenDays = Set(state.frozenDays ?? [])
        questClaims = state.questClaims ?? [:]
        draftPresetMinutes = settings.defaultPresetMinutes

        // Automation runs must never touch the real Keychain: an interactive
        // security prompt would block the process with no window to answer it.
        let storedToken = Self.isAutomationProcess ? nil : GitHubCredentialStore.load()
        if githubConnection != nil && storedToken == nil {
            // A record without a keychain item is not a usable connection.
            githubConnection = nil
        }
        githubToken = githubConnection == nil ? nil : storedToken

        lastStreakDayKey = Date().dayKey
        refreshStreak(consumeFreezeIfNeeded: true, notify: false)
        sanitizeDraftRepositories()
        // Light and dark are always free.
        ownedItemIDs.insert("theme_paper")
        ownedItemIDs.insert("theme_midnight")
        let badgesChanged = normalizeEarnedBadges()
        evaluateQuests(silent: true)
        // Persist once on first launch, or when an older file predates settings.
        if loaded == nil || loaded?.settings == nil || badgesChanged { save() }
        updateDockBadge()

        if !isAutomationRun {
            startTicker()
            if activeSession?.isRunning == true { startLiveCommitWatch() }
        }
    }

    private var isAutomationRun: Bool {
        ProcessInfo.processInfo.arguments.contains { argument in
            argument == "--selftest" || argument == "--snapshot" || argument == "--git-probe" || argument == "--device-check"
        }
    }

    static var isAutomationProcess: Bool {
        ProcessInfo.processInfo.arguments.contains { argument in
            argument == "--selftest" || argument == "--snapshot" || argument == "--git-probe" || argument == "--device-check"
        }
    }

    private static func normalizedRepositories(_ repos: [Repository]) -> [Repository] {
        repos.map { repo in
            var normalized = repo
            if normalized.isDemo == nil { normalized.isDemo = true }
            if normalized.isArchived == nil { normalized.isArchived = false }
            return normalized
        }
    }

    // MARK: - Derived

    var activeSession: Session? { sessions.first { !$0.isCompleted } }
    var completedSessions: [Session] { sessions.filter(\.isCompleted) }
    var level: LevelStatus { LevelStatus.from(xp: profile.xp) }

    /// Local folders are the source of truth. Demo repos only appear when the
    /// workspace has no local repositories at all (development/demo fallback).
    var activeRepositories: [Repository] {
        let active = repositories.filter(\.isActive)
        let local = active.filter { $0.localPath != nil }
        if !local.isEmpty { return local }
        return active.filter { $0.isDemo == true }
    }

    var isGitHubConnected: Bool { githubConnection != nil && githubToken != nil }
    var hasDemoWorkspace: Bool { activeRepositories.contains { $0.isDemo == true } }

    var githubAccountLogin: String {
        githubConnection?.account.login ?? profile.handle
    }

    var githubStatusLabel: String {
        if isGitHubConnected { return "GitHub connected" }
        return hasDemoWorkspace ? "Demo mode" : "GitHub not connected"
    }

    var githubFooterLabel: String {
        if isGitHubConnected { return "github / @\(githubAccountLogin)" }
        return hasDemoWorkspace ? "demo mode / @\(profile.handle)" : "GitHub not connected"
    }

    var activitySourceLabel: String {
        if isGitHubConnected { return "Live from GitHub · @\(githubAccountLogin)" }
        return hasDemoWorkspace ? "Demo activity · connect GitHub for the real thing" : "No GitHub account connected"
    }

    var rank: String {
        switch level.level {
        case 1...2: "Apprentice"
        case 3...4: "Tinkerer"
        case 5...7: "Studio Regular"
        case 8...11: "Craftsperson"
        default: "Old Guard"
        }
    }

    var theme: AppTheme { AppTheme.resolve(ThemeID(rawValue: profile.equippedThemeID) ?? .paper) }

    var themeDisplayName: String {
        ThemeID(rawValue: profile.equippedThemeID)?.displayName ?? theme.name
    }

    /// Light and dark are free; every other theme must be bought in the shop.
    func canUseTheme(_ reference: String) -> Bool {
        if reference == "paper" || reference == "midnight" { return true }
        return ownedItemIDs.contains("theme_\(reference)")
    }

    func equipTheme(_ reference: String) {
        guard canUseTheme(reference) else { return }
        withAnimation(.easeOut(duration: 0.22)) {
            profile.equippedThemeID = reference
        }
        save()
    }

    /// The themes shown in Settings: the free pair plus anything purchased.
    var ownedThemeItems: [ShopItem] {
        ShopItem.items(in: .themes).filter { $0.price == 0 || ownedItemIDs.contains($0.id) }
    }

    // MARK: Badges

    /// Badges are granted when their linked achievement unlocks. They are never
    /// sold, so the shop cannot add them to the collection.
    @discardableResult
    func grantEarnedBadges() -> Bool {
        var added = false
        for badge in ShopItem.items(in: .badges) {
            guard let achievementID = badge.earnedByAchievementID,
                  achievementDates[achievementID] != nil else { continue }
            if ownedItemIDs.insert(badge.id).inserted { added = true }
        }
        return added
    }

    /// Drop any badge that isn't backed by an unlocked achievement. This also
    /// cleans up badges bought before they became earn-only.
    @discardableResult
    func normalizeEarnedBadges() -> Bool {
        var changed = false
        for badge in ShopItem.items(in: .badges) {
            guard ownedItemIDs.contains(badge.id) else { continue }
            let earned = badge.earnedByAchievementID.map { achievementDates[$0] != nil } ?? false
            if !earned {
                ownedItemIDs.remove(badge.id)
                changed = true
            }
        }
        if grantEarnedBadges() { changed = true }
        if let equipped = profile.equippedBadgeID, !ownedItemIDs.contains(equipped) {
            profile.equippedBadgeID = nil
            changed = true
        }
        return changed
    }

    var equippedAvatar: ShopItem { ShopItem.find(profile.equippedAvatarID) ?? ShopItem.all[3] }
    var equippedBadge: ShopItem? { profile.equippedBadgeID.flatMap(ShopItem.find) }
    var equippedDecor: [ShopItem] { profile.equippedDecorIDs.compactMap(ShopItem.find) }
    var purchasedCount: Int { ownedItemIDs.compactMap(ShopItem.find).filter { $0.price > 0 }.count }
    var totalCommits: Int { completedSessions.reduce(0) { $0 + $1.commits } }
    var totalFocus: TimeInterval { completedSessions.reduce(0) { $0 + $1.accumulatedSeconds } }

    func session(withID id: UUID) -> Session? { sessions.first { $0.id == id } }
    func repository(withID id: String) -> Repository? { repositories.first { $0.id == id } }
    func repoName(_ id: String) -> String { repository(withID: id)?.name ?? "unknown" }

    private func sanitizeDraftRepositories() {
        let activeIDs = Set(activeRepositories.map(\.id))
        draftRepoIDs = draftRepoIDs.filter { activeIDs.contains($0) }
        if draftRepoIDs.isEmpty {
            draftRepoIDs = Array(activeRepositories.prefix(2).map(\.id))
        }
    }

    func sessions(on date: Date) -> [Session] {
        sessions.filter { $0.startedAt.isSameDay(as: date) }
    }

    func focusSeconds(on date: Date) -> TimeInterval {
        sessions(on: date).reduce(0) { $0 + $1.duration() }
    }

    func commits(on date: Date) -> Int {
        sessions(on: date).reduce(0) { $0 + $1.commits }
    }

    func coins(on date: Date) -> Int {
        sessions(on: date).reduce(0) { $0 + $1.coinsEarned }
    }

    var todayFocus: TimeInterval { focusSeconds(on: Date()) }
    var todaySessions: [Session] { sessions(on: Date()) }
    var todayCommits: Int { commits(on: Date()) }
    var todayCoins: Int { coins(on: Date()) }
    var dailyGoalSeconds: TimeInterval { Double(profile.dailyGoalMinutes) * 60 }
    var dailyProgress: Double {
        min(1, todayFocus / max(1, dailyGoalSeconds))
    }

    /// Seven days ending today. Offset -1 is last week, etc.
    func days(offset: Int = 0) -> [DayFocus] {
        let today = Date().startOfDay()
        return (0..<7).map { index in
            let day = Calendar.current.date(byAdding: .day, value: index - 6 + offset * 7, to: today) ?? today
            return DayFocus(date: day, seconds: focusSeconds(on: day), commits: commits(on: day), coins: coins(on: day))
        }
    }

    func week(offset: Int = 0) -> WeekSummary {
        let all = sessions.filter { session in
            days(offset: offset).contains { $0.date.isSameDay(as: session.startedAt) }
        }
        return WeekSummary(
            sessions: all,
            focus: all.reduce(0) { $0 + $1.duration() },
            commits: all.reduce(0) { $0 + $1.commits },
            files: all.reduce(0) { $0 + $1.filesChanged },
            additions: all.reduce(0) { $0 + $1.additions },
            deletions: all.reduce(0) { $0 + $1.deletions },
            coins: all.reduce(0) { $0 + $1.coinsEarned }
        )
    }

    var recentActivity: [ActivityEvent] {
        let activeIDs = Set(activeRepositories.map(\.id))
        return Array(
            activity
                .filter { activeIDs.contains($0.repoID) }
                .sorted { $0.timestamp > $1.timestamp }
                .prefix(40)
        )
    }

    var nextLevelXP: Int { max(0, level.xpForNextLevel - level.xpIntoLevel) }

    // MARK: - Session lifecycle

    func toggleRepo(_ id: String) {
        if let index = draftRepoIDs.firstIndex(of: id) {
            guard draftRepoIDs.count > 1 else { return }
            draftRepoIDs.remove(at: index)
        } else {
            draftRepoIDs.append(id)
        }
        save()
    }

    @discardableResult
    func addLocalRepositories(at urls: [URL]) -> Int {
        guard !urls.isEmpty else { return 0 }
        var added = 0
        var errors: [String] = []

        for url in urls {
            do {
                var repo = try LocalRepositoryImporter.makeRepository(from: url)
                if let index = repositories.firstIndex(where: { $0.localPath == repo.localPath }) {
                    repo.isArchived = false
                    repositories[index] = repo
                    added += 1
                    continue
                }
                if repo.isGitHubLinked,
                   repositories.contains(where: {
                       $0.isActive && $0.localPath != nil &&
                       $0.owner.caseInsensitiveCompare(repo.owner) == .orderedSame &&
                       $0.name.caseInsensitiveCompare(repo.name) == .orderedSame
                   }) {
                    throw LocalRepositoryError.duplicate(repo.fullName)
                }
                repositories.append(repo)
                added += 1
            } catch {
                errors.append(error.localizedDescription)
            }
        }

        if added > 0 {
            sanitizeDraftRepositories()
            save()
            var message = "\(added) local \(added == 1 ? "repository" : "repositories") ready."
            if let first = errors.first {
                message += " Skipped: \(first)"
            }
            if !GitEnvironment.current().isReady {
                message += " Git isn't available yet, so commits can't be captured. Install Apple's Command Line Tools, then reopen Pilcrow."
            }
            show(Notice(kind: .info, title: "Repository added", message: message))
        } else if let first = errors.first {
            show(Notice(
                kind: .error,
                title: "Couldn't add repository",
                message: errors.count > 1 ? "\(first) (+\(errors.count - 1) more)" : first
            ))
        }
        return added
    }

    func removeLocalRepository(_ id: String) {
        guard let index = repositories.firstIndex(where: { $0.id == id && $0.localPath != nil }) else { return }
        repositories[index].isArchived = true
        sanitizeDraftRepositories()
        save()
        show(Notice(kind: .info, title: "Removed from Pilcrow", message: "The folder is untouched on disk."))
    }

    func startSession() {
        guard activeSession == nil, !isFinalizingSession else { return }
        sanitizeDraftRepositories()
        guard !activeRepositories.isEmpty else {
            show(Notice(kind: .error, title: "No local repositories", message: "Add a project folder containing a .git directory before starting a session."))
            return
        }
        if draftRepoIDs.isEmpty, let first = activeRepositories.first { draftRepoIDs = [first.id] }
        if !warnedAboutMissingGit, !GitEnvironment.current().isReady {
            warnedAboutMissingGit = true
            show(Notice(
                kind: .info,
                title: "Commits won't be captured",
                message: "Pilcrow couldn't find git. Install Apple's Command Line Tools, then reopen Pilcrow to read local commits."
            ))
        }
        let preset = FocusPreset.find(minutes: draftPresetMinutes)
        let session = Session(
            startedAt: Date(),
            accumulatedSeconds: 0,
            runningSince: Date(),
            endedAt: nil,
            repoIDs: draftRepoIDs,
            events: [],
            coinsEarned: 0,
            xpEarned: 0,
            note: "",
            intent: draftIntent.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: draftTags.sorted(),
            presetMinutes: preset?.isOpen == false ? preset?.minutes : nil
        )
        withAnimation(.easeOut(duration: 0.28)) {
            sessions.insert(session, at: 0)
        }
        lastLivePollAt = Date()
        idlePauseStartedAt = nil
        breakUntil = nil
        save()
        playSound(.sessionStart)
        startLiveCommitWatch()
    }

    /// Used by the menu bar quick-start row.
    func startPresetSession(minutes: Int) {
        draftPresetMinutes = minutes
        startSession()
    }

    func toggleDraftTag(_ tag: String) {
        if draftTags.contains(tag) {
            draftTags.remove(tag)
        } else {
            draftTags.insert(tag)
        }
    }

    func pauseSession(isIdle: Bool = false) {
        guard let index = sessions.firstIndex(where: { !$0.isCompleted && $0.runningSince != nil }) else { return }
        let now = Date()
        if let runningSince = sessions[index].runningSince {
            sessions[index].accumulatedSeconds += max(0, now.timeIntervalSince(runningSince))
        }
        sessions[index].runningSince = nil
        if isIdle { idlePauseStartedAt = now }
        save()
    }

    func resumeSession() {
        guard let index = sessions.firstIndex(where: { !$0.isCompleted && $0.runningSince == nil }) else { return }
        sessions[index].runningSince = Date()
        idlePauseStartedAt = nil
        save()
    }

    func endSession() {
        guard !isFinalizingSession,
              let index = sessions.firstIndex(where: { !$0.isCompleted }) else {
            pendingAutoBreak = false
            return
        }
        let shouldStartBreak = pendingAutoBreak
        pendingAutoBreak = false
        stopLiveCommitWatch()
        idlePauseStartedAt = nil
        let now = Date()
        var session = sessions[index]
        if let runningSince = session.runningSince {
            session.accumulatedSeconds += max(0, now.timeIntervalSince(runningSince))
        }
        session.runningSince = nil
        session.endedAt = now
        let minutes = session.accumulatedSeconds / 60
        let repos = session.repoIDs.compactMap { repository(withID: $0) }

        // Provisional rewards are committed before any network work so a failed
        // request (or a quit) can never lose the focus time.
        let streak = SampleData.computedStreak(sessions: sessions, frozenDays: frozenDays)
        let provisional = CoinEngine.calculate(minutes: minutes, commits: 0, filesChanged: 0, streak: streak)
        session.coinsEarned = provisional.total
        session.coinBreakdown = provisional
        session.xpEarned = 20 + Int(minutes) * 3
        sessions[index] = session
        sessions.sort { $0.startedAt > $1.startedAt }

        let previousLevel = level.level
        profile.coins += session.coinsEarned
        profile.xp += session.xpEarned
        refreshStreak()
        draftRepoIDs = session.repoIDs
        pendingLevelUp = level.level > previousLevel ? level.level : nil
        save()
        playSound(.sessionEnd)
        if shouldStartBreak {
            startBreak()
        }

        isFinalizingSession = true
        let sessionID = session.id
        let startedAt = session.startedAt
        let selectedRepoIDs = session.repoIDs
        let demo = repos.contains(where: { $0.isDemo == true })
        let connected = isGitHubConnected
        let token = githubToken
        let login = githubAccountLogin

        Task {
            // Local `.git` is read first. It sees unpushed commits, every
            // branch, and works without GitHub. GitHub is only an enrichment.
            var events = await LocalGitService.events(for: repos, since: startedAt, until: now)
            var syncError: String?

            if connected, let token {
                do {
                    let remote = try await liveGitHub.sessionActivity(
                        token: token,
                        login: login,
                        repositories: repos,
                        since: startedAt,
                        until: now
                    )
                    events = Self.merge(local: events, remote: remote)
                } catch {
                    syncError = error.localizedDescription
                }
            } else if events.isEmpty && demo && session.accumulatedSeconds >= 90 {
                // Demo workspaces still get sample activity. A real local
                // repository never gets invented commits.
                events = MockActivityFactory.events(
                    repoIDs: repos.map(\.id),
                    from: startedAt,
                    minutes: minutes
                )
            }

            finalizeSession(id: sessionID, events: events, syncError: syncError)
            await scanUnclaimedCommits(sessionID: sessionID, since: startedAt, until: now, selectedRepoIDs: selectedRepoIDs)
            evaluateQuests()
            evaluateAchievements()
        }
    }

    /// Older builds skipped commit capture for sessions shorter than 90s, and
    /// GitHub-only capture missed unpushed work. Re-read local history for
    /// recent sessions that finished with no events recorded.
    func repairRecentSessions() async {
        let cutoff = Date().addingTimeInterval(-30 * 86_400)
        var changed = false

        for index in sessions.indices {
            var session = sessions[index]
            guard session.isCompleted,
                  session.events.isEmpty,
                  session.accumulatedSeconds > 0,
                  session.startedAt > cutoff,
                  let endedAt = session.endedAt else { continue }

            let repos = session.repoIDs.compactMap { repository(withID: $0) }
            guard repos.contains(where: { $0.localPath != nil }) else { continue }

            let events = await LocalGitService.events(
                for: repos,
                since: session.startedAt,
                until: endedAt
            )
            guard !events.isEmpty else { continue }

            let previousCoins = session.coinsEarned
            let previousXP = session.xpEarned
            session.events = events
            let streak = SampleData.computedStreak(sessions: sessions, frozenDays: frozenDays)
            let breakdown = CoinEngine.calculate(
                minutes: session.accumulatedSeconds / 60,
                commits: session.commits,
                filesChanged: session.filesChanged,
                streak: streak
            )
            session.coinBreakdown = breakdown
            session.coinsEarned = breakdown.total
            session.xpEarned = 20 + Int(session.accumulatedSeconds / 60) * 3 + session.commits * 4
            sessions[index] = session
            profile.coins += session.coinsEarned - previousCoins
            profile.xp += session.xpEarned - previousXP
            profile.streak = streak
            profile.longestStreak = max(profile.longestStreak, streak)
            _ = mergeActivity(events)
            changed = true
        }

        if changed {
            save()
            show(Notice(
                kind: .info,
                title: "Session history repaired",
                message: "Commits made during recent sessions were read from your local repositories."
            ))
        }
    }

    /// Prefer local commits (they carry file stats) and fill gaps with GitHub.
    private static func merge(local: [ActivityEvent], remote: [ActivityEvent]) -> [ActivityEvent] {
        var seen = Set(local.compactMap(\.commitSHA))
        var merged = local
        for event in remote {
            if let sha = event.commitSHA {
                guard seen.insert(sha).inserted else { continue }
            }
            merged.append(event)
        }
        return merged.sorted { $0.timestamp < $1.timestamp }
    }

    private func finalizeSession(id: UUID, events: [ActivityEvent], syncError: String?) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else {
            isFinalizingSession = false
            return
        }
        var session = sessions[index]
        let minutes = session.accumulatedSeconds / 60
        let previousCoins = session.coinsEarned
        let previousXP = session.xpEarned
        let previousLevel = level.level

        session.events = events
        let streak = SampleData.computedStreak(sessions: sessions, frozenDays: frozenDays)
        let breakdown = CoinEngine.calculate(
            minutes: minutes,
            commits: session.commits,
            filesChanged: session.filesChanged,
            streak: streak
        )
        session.coinBreakdown = breakdown
        session.coinsEarned = breakdown.total
        session.xpEarned = 20 + Int(minutes) * 3 + session.commits * 4
        sessions[index] = session

        if !events.isEmpty {
            mergeActivity(events)
        }
        profile.coins += session.coinsEarned - previousCoins
        profile.xp += session.xpEarned - previousXP
        refreshStreak()
        if level.level > previousLevel {
            pendingLevelUp = level.level
        }
        lastSessionSyncError = syncError
        if let syncError {
            githubConnectionError = syncError
        }
        isFinalizingSession = false
        reportSession = settings.showSessionReport ? session : nil
        save()
        if session.commits > 0 {
            playSound(.reward)
        }
    }

    func discardActiveSession() {
        guard let active = activeSession else { return }
        stopLiveCommitWatch()
        idlePauseStartedAt = nil
        sessions.removeAll { $0.id == active.id }
        save()
        show(Notice(kind: .info, title: "Session discarded", message: "Nothing was added to your log."))
    }

    // MARK: - Focus toolkit

    /// Recompute the live streak, optionally spending a freeze to cover a
    /// single missed day. The freeze is only spent when the day before the gap
    /// was part of the streak, so it never rescues an abandoned habit.
    func refreshStreak(consumeFreezeIfNeeded: Bool = false, notify: Bool = false) {
        if consumeFreezeIfNeeded { freezeMissedDayIfPossible(notify: notify) }
        let streak = SampleData.computedStreak(sessions: sessions, frozenDays: frozenDays)
        profile.streak = streak
        profile.longestStreak = max(profile.longestStreak, streak)
    }

    private func freezeMissedDayIfPossible(notify: Bool) {
        guard streakFreezes > 0 else { return }
        let today = Date().startOfDay()
        let focusKeys = Set(sessions.filter(\.isCompleted).map { $0.startedAt.startOfDay().dayKey })
        let covered = focusKeys.union(frozenDays)
        let todayKey = today.dayKey
        let yesterdayKey = today.adding(days: -1).dayKey
        let dayBeforeKey = today.adding(days: -2).dayKey

        guard !covered.contains(todayKey),
              !covered.contains(yesterdayKey),
              covered.contains(dayBeforeKey) else { return }

        frozenDays.insert(yesterdayKey)
        streakFreezes -= 1
        if notify {
            show(Notice(
                kind: .info,
                title: "Streak freeze used",
                message: "Yesterday was covered automatically. \(streakFreezes) \(streakFreezes == 1 ? "freeze" : "freezes") left."
            ))
        }
        save()
    }

    @discardableResult
    func buyStreakFreeze() -> Bool {
        guard streakFreezes < StreakFreeze.maximum else {
            show(Notice(kind: .info, title: "Already banked", message: "You can hold up to \(StreakFreeze.maximum) streak freezes."))
            return false
        }
        guard profile.coins >= StreakFreeze.price else {
            let short = StreakFreeze.price - profile.coins
            show(Notice(kind: .error, title: "Not quite there", message: "A streak freeze costs \(StreakFreeze.price) coins. You need \(short) more."))
            return false
        }
        profile.coins -= StreakFreeze.price
        streakFreezes += 1
        save()
        playSound(.purchase)
        show(Notice(
            kind: .info,
            title: "Streak freeze banked",
            message: "One missed day is covered. \(streakFreezes) of \(StreakFreeze.maximum) held."
        ))
        return true
    }

    // MARK: Breaks

    /// A short, optional break after an auto-ended preset. The timer is
    /// deliberately not a session: nothing is logged and no coins change.
    func startBreak(minutes: Int = 5) {
        breakUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        show(Notice(
            kind: .info,
            title: "Wrapped at target",
            message: "\(minutes) minute break. Stand up, look out a window, come back when you're ready."
        ))
    }

    func endBreak() {
        breakUntil = nil
    }

    func breakRemaining(at now: Date = Date()) -> TimeInterval? {
        guard let breakUntil else { return nil }
        let remaining = breakUntil.timeIntervalSince(now)
        return remaining > 0 ? remaining : 0
    }

    var isOnBreak: Bool {
        (breakRemaining() ?? 0) > 0
    }

    // MARK: Quests

    func questClaimKey(_ quest: Quest, now: Date = Date()) -> String {
        let period = quest.period == .daily ? now.dayKey : now.weekKey
        return "\(quest.id)@\(period)"
    }

    func isQuestClaimed(_ quest: Quest, now: Date = Date()) -> Bool {
        questClaims[questClaimKey(quest, now: now)] != nil
    }

    func questValue(_ quest: Quest) -> Int {
        switch quest.id {
        case "daily_focus":
            return Int(todayFocus / 60)
        case "daily_commits":
            return todayCommits
        case "daily_sessions":
            return todaySessions.filter(\.isCompleted).count
        case "daily_early":
            return todaySessions.contains { session in
                guard session.isCompleted else { return false }
                return Calendar.current.component(.hour, from: session.startedAt) < 12
            } ? 1 : 0
        case "weekly_deep":
            return week().sessions.filter { $0.accumulatedSeconds >= 50 * 60 }.count
        case "weekly_commits":
            return week().commits
        case "weekly_days":
            return days().filter { $0.seconds > 0 }.count
        default:
            return 0
        }
    }

    func questProgress(_ quest: Quest) -> (current: Int, goal: Int) {
        (min(quest.goal, max(0, questValue(quest))), quest.goal)
    }

    var completedQuestCount: Int {
        QuestCatalog.all.filter { isQuestClaimed($0) }.count
    }

    func evaluateQuests(silent: Bool = false) {
        let previousLevel = level.level
        var claimed: [Quest] = []
        for quest in QuestCatalog.all where !isQuestClaimed(quest) {
            guard questValue(quest) >= quest.goal else { continue }
            questClaims[questClaimKey(quest)] = Date()
            profile.coins += quest.rewardCoins
            profile.xp += quest.rewardXP
            claimed.append(quest)
        }
        guard !claimed.isEmpty else { return }
        if level.level > previousLevel { pendingLevelUp = level.level }
        refreshStreak()
        save()
        guard !silent else { return }
        playSound(.reward)
        if claimed.count == 1, let quest = claimed.first {
            show(Notice(
                kind: .achievement,
                title: "Quest complete — \(quest.title)",
                message: "+\(quest.rewardCoins) coins, +\(quest.rewardXP) XP."
            ))
        } else {
            let coins = claimed.reduce(0) { $0 + $1.rewardCoins }
            show(Notice(
                kind: .achievement,
                title: "\(claimed.count) quests complete",
                message: "\(claimed.map(\.title).joined(separator: ", ")) · +\(coins) coins."
            ))
        }
    }

    // MARK: Daily strip

    var dailyStripText: String {
        let date = Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
        var lines = [
            "Pilcrow — \(date)",
            "Focus: \(todayFocus.focusLabel)",
            "Sessions: \(todaySessions.filter(\.isCompleted).count)",
            "Commits: \(todayCommits)",
            "Coins: +\(todayCoins)",
            "Streak: \(profile.streak) \(profile.streak == 1 ? "day" : "days")"
        ]
        let intents = todaySessions.map(\.intent).filter { !$0.isEmpty }
        if let first = intents.first { lines.append("Intent: \(first)") }
        let tags = Set(todaySessions.flatMap(\.tags)).sorted()
        if !tags.isEmpty { lines.append("Tags: " + tags.map { "#\($0)" }.joined(separator: " ")) }
        return lines.joined(separator: "\n")
    }

    func copyDailyStrip() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(dailyStripText, forType: .string)
        show(Notice(kind: .info, title: "Daily strip copied", message: "Paste it into a standup or your notes."))
    }

    // MARK: Session editing

    /// Correct a session that was left running too long. Pauses are not
    /// modelled here: the edited window becomes the focused time.
    func updateSessionTimes(sessionID: UUID, startedAt: Date, endedAt: Date) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        guard endedAt.timeIntervalSince1970 > startedAt.timeIntervalSince1970 + 59 else {
            show(Notice(kind: .error, title: "Check the times", message: "A session needs to end at least a minute after it starts."))
            return
        }
        let previousCoins = sessions[index].coinsEarned
        let previousXP = sessions[index].xpEarned
        sessions[index].startedAt = startedAt
        sessions[index].endedAt = endedAt
        sessions[index].runningSince = nil
        sessions[index].accumulatedSeconds = endedAt.timeIntervalSince(startedAt)

        let streak = SampleData.computedStreak(sessions: sessions, frozenDays: frozenDays)
        let breakdown = CoinEngine.calculate(
            minutes: sessions[index].accumulatedSeconds / 60,
            commits: sessions[index].commits,
            filesChanged: sessions[index].filesChanged,
            streak: streak
        )
        sessions[index].coinBreakdown = breakdown
        sessions[index].coinsEarned = breakdown.total
        sessions[index].xpEarned = 20 + Int(sessions[index].accumulatedSeconds / 60) * 3 + sessions[index].commits * 4
        profile.coins += sessions[index].coinsEarned - previousCoins
        profile.xp += sessions[index].xpEarned - previousXP
        sessions.sort { $0.startedAt > $1.startedAt }
        if let updated = sessions.first(where: { $0.id == sessionID }), reportSession?.id == sessionID {
            reportSession = updated
        }
        refreshStreak()
        save()
        show(Notice(kind: .info, title: "Session updated", message: "The report and coin ledger now match the corrected window."))
    }

    private func recalculateSessionRewards(at index: Int) {
        let previousCoins = sessions[index].coinsEarned
        let previousXP = sessions[index].xpEarned
        let streak = SampleData.computedStreak(sessions: sessions, frozenDays: frozenDays)
        let breakdown = CoinEngine.calculate(
            minutes: sessions[index].accumulatedSeconds / 60,
            commits: sessions[index].commits,
            filesChanged: sessions[index].filesChanged,
            streak: streak
        )
        sessions[index].coinBreakdown = breakdown
        sessions[index].coinsEarned = breakdown.total
        sessions[index].xpEarned = 20 + Int(sessions[index].accumulatedSeconds / 60) * 3 + sessions[index].commits * 4
        profile.coins += sessions[index].coinsEarned - previousCoins
        profile.xp += sessions[index].xpEarned - previousXP
    }

    // MARK: Unclaimed work

    /// Commits made during the session window in local repositories that were
    /// not selected. They are held on the session so the report can offer them.
    func scanUnclaimedCommits(sessionID: UUID, since: Date, until: Date, selectedRepoIDs: [String]) async {
        let selected = Set(selectedRepoIDs)
        let candidates = activeRepositories.filter {
            $0.localPath != nil && $0.isDemo != true && !selected.contains($0.id)
        }
        guard !candidates.isEmpty else { return }
        let events = await LocalGitService.events(for: candidates, since: since, until: until)
        guard !events.isEmpty,
              let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        let existing = Set(sessions[index].events.compactMap(\.commitSHA))
        let fresh = events.filter { event in
            guard let sha = event.commitSHA else { return true }
            return !existing.contains(sha)
        }
        guard !fresh.isEmpty else { return }
        sessions[index].unclaimedEvents = fresh
        save()
        show(Notice(
            kind: .info,
            title: "Work found elsewhere",
            message: "\(fresh.count) \(fresh.count == 1 ? "commit" : "commits") landed in other local repositories. Open the report to add \(fresh.count == 1 ? "it" : "them")."
        ))
    }

    @discardableResult
    func addUnclaimedEvents(sessionID: UUID) -> Bool {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return false }
        let extras = sessions[index].unclaimedEvents
        guard !extras.isEmpty else { return false }
        var seen = Set(sessions[index].events.compactMap(\.commitSHA))
        var merged = sessions[index].events
        for event in extras {
            if let sha = event.commitSHA {
                guard seen.insert(sha).inserted else { continue }
            }
            merged.append(event)
        }
        sessions[index].events = merged.sorted { $0.timestamp < $1.timestamp }
        sessions[index].unclaimedEvents = []
        recalculateSessionRewards(at: index)
        if reportSession?.id == sessionID { reportSession = sessions[index] }
        _ = mergeActivity(extras)
        save()
        evaluateQuests()
        evaluateAchievements()
        show(Notice(kind: .info, title: "Added to the session", message: "\(extras.count) \(extras.count == 1 ? "commit now belongs" : "commits now belong") to this session's ledger."))
        return true
    }

    func dismissUnclaimedEvents(sessionID: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }),
              !sessions[index].unclaimedEvents.isEmpty else { return }
        sessions[index].unclaimedEvents = []
        if reportSession?.id == sessionID { reportSession = sessions[index] }
        save()
    }

    // MARK: Clock, idle and live commits

    private func startTicker() {
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.tick(date)
            }
        observeSystemAway()
    }

    private func observeSystemAway() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.pauseForSystemAway() }
        }
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.pauseForSystemAway() }
        }
    }

    private func pauseForSystemAway() {
        guard activeSession?.isRunning == true else { return }
        pauseSession(isIdle: true)
        show(Notice(
            kind: .info,
            title: "Session paused",
            message: "The Mac went away. Resume when you're back — the gap stays out of the ledger."
        ))
    }

    private func tick(_ now: Date) {
        if activeSession?.isRunning == true {
            clockNow = now
        }

        if now.dayKey != lastStreakDayKey {
            lastStreakDayKey = now.dayKey
            refreshStreak(consumeFreezeIfNeeded: true, notify: true)
            save()
        }

        guard let active = activeSession else { return }

        if active.isRunning,
           settings.autoEndAtPreset,
           let target = active.targetSeconds,
           active.duration(at: now) >= target {
            pendingAutoBreak = true
            endSession()
            return
        }

        if let until = breakUntil, now.timeIntervalSince1970 >= until.timeIntervalSince1970 {
            breakUntil = nil
            show(Notice(kind: .info, title: "Break over", message: "Five minutes away is enough. Start the next block when you're ready."))
        }

        guard settings.idleAutoPause else { return }
        let idleSeconds = IdleMonitor.secondsSinceLastInput()
        let threshold = TimeInterval(settings.clampedIdleThreshold * 60)

        if activeSession?.isRunning == true, idleSeconds >= threshold {
            pauseSession(isIdle: true)
        } else if activeSession?.isPaused == true,
                  idlePauseStartedAt != nil,
                  idleSeconds < 3 {
            let away = max(0, now.timeIntervalSince(idlePauseStartedAt ?? now))
            resumeSession()
            show(Notice(
                kind: .info,
                title: "Welcome back",
                message: "Paused while you were away. \(away.focusLabel) stayed out of the ledger."
            ))
        }
    }

    /// Polls local git every few seconds while a session runs, so a commit
    /// shows up in the live card instead of waiting for the final sweep.
    private func startLiveCommitWatch() {
        stopLiveCommitWatch()
        guard settings.liveCommitWatch else { return }
        liveWatchTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                guard !Task.isCancelled else { return }
                await self?.pollLiveCommits()
            }
        }
    }

    private func stopLiveCommitWatch() {
        liveWatchTask?.cancel()
        liveWatchTask = nil
        lastLivePollAt = nil
    }

    private func pollLiveCommits() async {
        guard settings.liveCommitWatch,
              let index = sessions.firstIndex(where: { !$0.isCompleted }),
              sessions[index].isRunning else { return }
        let selected = Set(sessions[index].repoIDs)
        let repos = activeRepositories.filter {
            selected.contains($0.id) && $0.localPath != nil && $0.isDemo != true
        }
        guard !repos.isEmpty else { return }

        let now = Date()
        let since = lastLivePollAt ?? sessions[index].startedAt
        let events = await LocalGitService.events(for: repos, since: since, until: now)
        lastLivePollAt = now
        guard !events.isEmpty,
              let freshIndex = sessions.firstIndex(where: { $0.id == sessions[index].id }) else { return }

        var seen = Set(sessions[freshIndex].events.compactMap(\.commitSHA))
        let fresh = events.filter { event in
            guard let sha = event.commitSHA else { return true }
            return seen.insert(sha).inserted
        }
        guard !fresh.isEmpty else { return }
        sessions[freshIndex].events.append(contentsOf: fresh)
        sessions[freshIndex].events.sort { $0.timestamp < $1.timestamp }
        _ = mergeActivity(fresh)
        save()
    }

    // MARK: - Shop & profile

    func owns(_ item: ShopItem) -> Bool { ownedItemIDs.contains(item.id) }
    func isEquipped(_ item: ShopItem) -> Bool {
        switch item.category {
        case .themes: profile.equippedThemeID == item.payload
        case .avatars: profile.equippedAvatarID == item.id
        case .badges: profile.equippedBadgeID == item.id
        case .decor: profile.equippedDecorIDs.contains(item.id)
        }
    }

    @discardableResult
    func buy(_ item: ShopItem) -> Bool {
        guard !item.isEarnable else {
            show(Notice(kind: .info, title: "Earned, not bought", message: "\(item.name) unlocks through \(item.earnHint.lowercased())."))
            return false
        }
        guard !owns(item) else { return false }
        guard profile.coins >= item.price else {
            let short = item.price - profile.coins
            show(Notice(kind: .error, title: "Not quite there", message: "You need \(short) more coins. A good session usually covers it."))
            return false
        }
        let shelfWasFull = item.category == .decor && profile.equippedDecorIDs.count >= 3
        withAnimation(.timingCurve(0.16, 0.84, 0.16, 1, duration: 0.36)) {
            profile.coins -= item.price
            ownedItemIDs.insert(item.id)
            if !shelfWasFull {
                applyEquip(item)
            }
        }
        save()
        show(Notice(
            kind: .info,
            title: "\(item.name) is yours",
            message: shelfWasFull ? "Tucked away for now — your shelf is full." : "Added to your collection."
        ))
        playSound(.purchase)
        evaluateAchievements()
        return true
    }

    func equip(_ item: ShopItem) {
        guard owns(item) else { return }
        if item.category == .decor && !isEquipped(item) && profile.equippedDecorIDs.count >= 3 {
            show(Notice(kind: .error, title: "Shelf is full", message: "Three things is the limit. Put one back first."))
            return
        }
        withAnimation(.easeOut(duration: 0.28)) {
            if item.category == .badges && isEquipped(item) {
                profile.equippedBadgeID = nil
            } else {
                applyEquip(item)
            }
        }
        save()
    }

    private func applyEquip(_ item: ShopItem) {
        switch item.category {
        case .themes: profile.equippedThemeID = item.payload
        case .avatars: profile.equippedAvatarID = item.id
        case .badges: profile.equippedBadgeID = item.id
        case .decor:
            if !profile.equippedDecorIDs.contains(item.id) {
                profile.equippedDecorIDs.append(item.id)
            }
        }
    }

    func removeDecor(_ item: ShopItem) {
        profile.equippedDecorIDs.removeAll { $0 == item.id }
        save()
    }

    func updateGoal(_ minutes: Int) {
        profile.dailyGoalMinutes = min(360, max(30, minutes))
        save()
    }

    func updateNote(sessionID: UUID, note: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        guard sessions[index].note != note else { return }
        sessions[index].note = note
        save()
    }

    func updateIdentity(name: String, bio: String) {
        profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    // MARK: - Settings

    func updateSettings(_ update: (inout AppSettings) -> Void) {
        var next = settings
        update(&next)
        next.soundVolume = next.clampedVolume
        // A no-op write must not publish or save: SwiftUI can re-apply a
        // binding's current value during scene setup, and publishing there
        // would rebuild the scene forever.
        guard next != settings else { return }
        settings = next
        save()
        updateDockBadge()
    }

    func playSound(_ cue: SoundCue) {
        SoundEngine.shared.play(cue, settings: settings)
    }

    func previewSound(_ cue: SoundCue) {
        guard settings.soundEnabled else { return }
        SoundEngine.shared.preview(cue, volume: settings.clampedVolume)
    }

    var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Login items are only reliable for a bundle installed in an
    /// Applications folder. Ad-hoc builds run from a checkout should not
    /// pretend the toggle works.
    var launchAtLoginSupported: Bool {
        let bundlePath = Bundle.main.bundlePath
        return bundlePath.hasPrefix("/Applications/")
            || bundlePath.hasPrefix(NSHomeDirectory() + "/Applications/")
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard launchAtLoginSupported else {
            show(Notice(
                kind: .info,
                title: "Move Pilcrow to Applications",
                message: "Launch at login needs the app to live in your Applications folder."
            ))
            return
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            objectWillChange.send()
        } catch {
            show(Notice(
                kind: .error,
                title: "Couldn't update login item",
                message: error.localizedDescription
            ))
        }
    }

    func updateDockBadge() {
        let minutes = Int(todayFocus / 60)
        let label: String? = settings.dockBadge && minutes > 0 ? "\(minutes)" : nil
        NSApplication.shared.dockTile.badgeLabel = label
    }

    /// Onboarding is a clean start: progress is reset, while a GitHub account
    /// connected during setup (and its active repositories) is kept.
    func completeOnboarding(name: String, dailyGoalMinutes: Int) {
        applyFreshLedger(name: name, dailyGoalMinutes: dailyGoalMinutes)
        hasCompletedOnboarding = true
        save()
        show(Notice(
            kind: .info,
            title: "Fresh ledger",
            message: githubConnection == nil
                ? "0 coins, 0 sessions. Add a local repository whenever you're ready."
                : "0 coins, 0 sessions. Add a local repository to start tracking."
        ))
    }

    /// Deliberate restart from Profile. Resets progress immediately and reopens
    /// onboarding; the GitHub account stays connected.
    func startOver() {
        applyFreshLedger(name: profile.name, dailyGoalMinutes: profile.dailyGoalMinutes)
        hasCompletedOnboarding = false
        save()
    }

    private func applyFreshLedger(name: String, dailyGoalMinutes: Int) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName: String
        if !trimmed.isEmpty {
            resolvedName = trimmed
        } else if let accountName = githubConnection?.account.name, !accountName.isEmpty {
            resolvedName = accountName
        } else {
            resolvedName = "Maker"
        }

        let login = githubConnection?.account.login
        let retainedRepos = repositories.filter { $0.isActive && $0.localPath != nil }
        let retainedConnection = githubConnection

        profile = UserProfile(
            name: resolvedName,
            handle: login ?? "maker",
            bio: "",
            joinedAt: Date(),
            xp: 0,
            coins: 0,
            streak: 0,
            longestStreak: 0,
            dailyGoalMinutes: min(360, max(30, dailyGoalMinutes)),
            equippedThemeID: "paper",
            equippedAvatarID: "avatar_maker",
            equippedBadgeID: nil,
            equippedDecorIDs: []
        )
        repositories = retainedRepos
        draftRepoIDs = Array(retainedRepos.prefix(2).map(\.id))
        sessions = []
        activity = []
        ownedItemIDs = ["theme_paper", "theme_midnight", "avatar_maker"]
        achievementDates = [:]
        githubConnection = retainedConnection
        lastSyncedAt = nil
        pendingLevelUp = nil
        reportSession = nil
        lastSessionSyncError = nil
        githubConnectionError = nil
        streakFreezes = 0
        frozenDays = []
        questClaims = [:]
        draftIntent = ""
        draftTags = []
        draftPresetMinutes = settings.defaultPresetMinutes
        idlePauseStartedAt = nil
        breakUntil = nil
        pendingAutoBreak = false
        stopLiveCommitWatch()
    }

    // MARK: - Achievements

    func isUnlocked(_ achievement: Achievement) -> Bool {
        achievementDates[achievement.id] != nil
    }

    func progress(for achievement: Achievement) -> (value: Int, label: String) {
        switch achievement.id {
        case "first_light":
            let count = completedSessions.count
            return (count, "\(min(count, 1)) / 1 session")
        case "deep_work":
            let maxMinutes = Int(completedSessions.map { $0.accumulatedSeconds / 60 }.max() ?? 0)
            return (maxMinutes, "\(maxMinutes) / 90 min")
        case "night_shift":
            let count = completedSessions.filter {
                guard let end = $0.endedAt else { return false }
                let hour = Calendar.current.component(.hour, from: end)
                return hour >= 22 || hour < 4
            }.count
            return (count, count > 0 ? "Done" : "After 10pm")
        case "ship_it":
            let maxCommits = completedSessions.map(\.commits).max() ?? 0
            return (maxCommits, "\(maxCommits) / 5 commits")
        case "triple_digits":
            return (totalCommits, "\(totalCommits) / 100 commits")
        case "streak_3", "streak_7":
            return (profile.streak, "\(profile.streak) / \(achievement.goal) days")
        case "curator":
            return (purchasedCount, "\(purchasedCount) / 4 items")
        case "regular":
            return (completedSessions.count, "\(completedSessions.count) / 10 sessions")
        default:
            return (0, "")
        }
    }

    func evaluateAchievements() {
        var unlocked: [Achievement] = []
        for achievement in AchievementCatalog.all where !isUnlocked(achievement) {
            let value = progress(for: achievement).value
            if value >= achievement.goal {
                achievementDates[achievement.id] = Date()
                unlocked.append(achievement)
            }
        }
        guard !unlocked.isEmpty else {
            if grantEarnedBadges() { save() }
            return
        }
        _ = grantEarnedBadges()
        save()
        playSound(.achievement)
        if unlocked.count == 1, let first = unlocked.first {
            show(Notice(kind: .achievement, title: "Achievement — \(first.title)", message: first.detail))
        } else {
            let names = unlocked.map(\.title).joined(separator: ", ")
            show(Notice(kind: .achievement, title: "\(unlocked.count) achievements unlocked", message: names))
        }
    }

    // MARK: - GitHub

    func openGitHubConnection() {
        guard hasCompletedOnboarding else { return }
        isGitHubSheetPresented = true
    }

    func connectGitHub(token: String) {
        Task { _ = await connectGitHubAndWait(token: token) }
    }

    /// Validates a token, imports repositories, and persists the connection.
    /// Returns `true` only once the account is fully ready.
    @discardableResult
    func connectGitHubAndWait(token rawToken: String) async -> Bool {
        guard !isConnectingGitHub else { return isGitHubConnected }
        guard activeSession == nil, !isFinalizingSession else {
            githubConnectionError = "End the current session before changing your GitHub connection."
            return false
        }
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            githubConnectionError = "Paste a GitHub personal access token first."
            return false
        }

        isConnectingGitHub = true
        githubConnectionError = nil
        do {
            let account = try await liveGitHub.validateToken(token)
            try GitHubCredentialStore.save(token)

            githubToken = token
            githubConnection = GitHubConnectionRecord(account: account, connectedAt: Date())
            // Local folders are added explicitly. Connecting an account never
            // imports remote repositories on its own.
            for index in repositories.indices where repositories[index].isDemo == true {
                repositories[index].isArchived = true
            }
            sanitizeDraftRepositories()
            lastSyncedAt = nil
            isConnectingGitHub = false
            save()
            show(Notice(
                kind: .info,
                title: "Connected as @\(account.login)",
                message: "Add a local repository folder to start tracking commits."
            ))
            if activeRepositories.contains(where: { $0.isGitHubLinked }) {
                syncGitHub()
            }
            return true
        } catch {
            isConnectingGitHub = false
            githubConnectionError = error.localizedDescription
            return false
        }
    }

    func disconnectGitHub() {
        guard activeSession == nil, !isFinalizingSession else {
            githubConnectionError = "End the current session before disconnecting GitHub."
            return
        }
        GitHubCredentialStore.delete()
        githubToken = nil
        githubConnection = nil
        githubConnectionError = nil
        lastSyncedAt = nil
        sanitizeDraftRepositories()
        save()
        show(Notice(kind: .info, title: "Disconnected from GitHub", message: "Local repositories stay available for focus sessions."))
    }

    func syncGitHub() {
        guard !isSyncing else { return }
        guard !activeRepositories.isEmpty else {
            show(Notice(kind: .info, title: "No local repositories", message: "Add a project folder containing a .git directory first."))
            return
        }
        isSyncing = true
        let until = Date()
        let since = lastSyncedAt ?? until.addingTimeInterval(-7 * 86_400)
        // Always rescan a week of local history. It is cheap, and it catches
        // commits that were never pushed (so GitHub sync could never see them).
        let localSince = until.addingTimeInterval(-7 * 86_400)
        let repos = activeRepositories
        let connected = isGitHubConnected
        let token = githubToken
        let demo = hasDemoWorkspace
        let login = githubAccountLogin

        Task {
            var events = await LocalGitService.events(for: repos, since: localSince, until: until)
            var syncError: String?

            if connected, let token {
                do {
                    let remote = try await liveGitHub.recentActivity(
                        token: token,
                        login: login,
                        repositories: repos,
                        since: since,
                        until: until
                    )
                    events = Self.merge(local: events, remote: remote)
                } catch {
                    syncError = error.localizedDescription
                }
            } else if demo {
                if let mock = try? await mockGitHub.recentActivity(
                    token: "demo",
                    login: profile.handle,
                    repositories: repos,
                    since: since,
                    until: until
                ) {
                    events = Self.merge(local: events, remote: mock)
                }
            }

            let added = mergeActivity(events)
            lastSyncedAt = until
            githubConnectionError = syncError
            isSyncing = false
            save()

            if let syncError {
                show(Notice(
                    kind: .error,
                    title: "GitHub sync failed",
                    message: "\(syncError) Local commits were still read from disk."
                ))
            } else if added == 0 {
                show(Notice(kind: .info, title: "Up to date", message: "No new commits since the last sync."))
            } else {
                show(Notice(
                    kind: .info,
                    title: "Synced",
                    message: "\(added) new \(added == 1 ? "commit" : "commits") from your local repositories."
                ))
            }
        }
    }

    @discardableResult
    private func mergeActivity(_ events: [ActivityEvent]) -> Int {
        var seen = Set(activity.compactMap(\.commitSHA))
        var fresh: [ActivityEvent] = []
        for event in events {
            if let sha = event.commitSHA {
                guard !seen.contains(sha) else { continue }
                seen.insert(sha)
            }
            fresh.append(event)
        }
        guard !fresh.isEmpty else { return 0 }
        activity.insert(contentsOf: fresh, at: 0)
        return fresh.count
    }

    // MARK: - Notices

    func show(_ notice: Notice) {
        noticeQueue.append(notice)
        presentNextNoticeIfIdle()
    }

    func dismissNotice() {
        withAnimation(.easeOut(duration: 0.16)) { notice = nil }
        isPresentingNotice = false
        presentNextNoticeIfIdle()
    }

    private func presentNextNoticeIfIdle() {
        guard !isPresentingNotice, !noticeQueue.isEmpty else { return }
        isPresentingNotice = true
        let next = noticeQueue.removeFirst()
        withAnimation(.timingCurve(0.16, 0.84, 0.16, 1, duration: 0.34)) {
            notice = next
        }
        Task {
            try? await Task.sleep(nanoseconds: 3_400_000_000)
            guard notice?.id == next.id else {
                isPresentingNotice = false
                presentNextNoticeIfIdle()
                return
            }
            withAnimation(.easeOut(duration: 0.18)) { notice = nil }
            try? await Task.sleep(nanoseconds: 220_000_000)
            isPresentingNotice = false
            presentNextNoticeIfIdle()
        }
    }

    // MARK: - Persistence

    private static var stateDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["PILCROW_STATE_DIR"]
            ?? ProcessInfo.processInfo.environment["GITFLOW_STATE_DIR"] {
            let base = URL(fileURLWithPath: override, isDirectory: true)
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            return base
        }

        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let base = support.appendingPathComponent("Pilcrow", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        migrateLegacyState(into: base, support: support)
        return base
    }

    /// One-time carry-over from the pre-rebrand `GitFlowSwift` folder so coins,
    /// sessions, repositories and settings survive the rename.
    private static func migrateLegacyState(into base: URL, support: URL) {
        let destination = base.appendingPathComponent("state.json")
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }

        let legacy = support
            .appendingPathComponent("GitFlowSwift", isDirectory: true)
            .appendingPathComponent("state.json")
        guard FileManager.default.fileExists(atPath: legacy.path) else { return }
        try? FileManager.default.copyItem(at: legacy, to: destination)
    }

    var stateFileURL: URL {
        Self.stateDirectory.appendingPathComponent("state.json")
    }

    func save() {
        // The GitHub token is intentionally absent; it lives in Keychain only.
        let state = PersistedState(
            profile: profile,
            repositories: repositories,
            sessions: sessions,
            activity: activity,
            ownedItemIDs: ownedItemIDs,
            achievements: achievementDates,
            draftRepoIDs: draftRepoIDs,
            lastSyncedAt: lastSyncedAt,
            githubConnection: githubConnection,
            onboardingCompleted: hasCompletedOnboarding,
            settings: settings,
            streakFreezes: streakFreezes,
            frozenDays: Array(frozenDays).sorted(),
            questClaims: questClaims
        )
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(state)
            try data.write(to: stateFileURL, options: .atomic)
        } catch {
            print("Pilcrow save failed: \(error)")
        }
        updateDockBadge()
    }

    private static func load() -> PersistedState? {
        let url = stateDirectory.appendingPathComponent("state.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PersistedState.self, from: data)
    }

    func resetDemoData() {
        let seed = SampleData.makeSeed()
        GitHubCredentialStore.delete()
        githubToken = nil
        githubConnection = nil
        githubConnectionError = nil
        lastSessionSyncError = nil
        hasCompletedOnboarding = true
        withAnimation(.easeInOut(duration: 0.2)) {
            profile = seed.profile
            repositories = seed.repositories
            sessions = seed.sessions
            activity = seed.activity
            ownedItemIDs = seed.ownedItemIDs
            achievementDates = seed.achievements
            draftRepoIDs = seed.draftRepoIDs
            lastSyncedAt = seed.lastSyncedAt
            reportSession = nil
            streakFreezes = 1
            frozenDays = []
            questClaims = [:]
            draftIntent = ""
            draftTags = []
            draftPresetMinutes = 50
            idlePauseStartedAt = nil
            breakUntil = nil
            pendingAutoBreak = false
        }
        _ = normalizeEarnedBadges()
        refreshStreak()
        save()
        show(Notice(kind: .info, title: "Fresh paper", message: "Demo data has been restored."))
    }
}
