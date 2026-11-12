import Foundation

// MARK: - GitHub

struct Repository: Identifiable, Codable, Hashable {
    var id: String
    var owner: String
    var name: String
    var language: String
    var symbol: String
    var isPrivate: Bool
    var githubID: Int?
    var isDemo: Bool?
    var isArchived: Bool?
    var defaultBranch: String?
    var htmlURL: String?
    var localPath: String?
    var remoteURL: String?

    var fullName: String { "\(owner)/\(name)" }
    var isActive: Bool { isArchived != true }
    var isLocal: Bool { localPath != nil }
    var isGitHubLinked: Bool { remoteURL?.contains("github.com") == true }

    static func github(
        id: Int,
        owner: String,
        name: String,
        language: String?,
        isPrivate: Bool,
        defaultBranch: String?,
        htmlURL: String?
    ) -> Repository {
        Repository(
            id: "gh:\(id)",
            owner: owner,
            name: name,
            language: language ?? "Plain text",
            symbol: "chevron.left.forwardslash.chevron.right",
            isPrivate: isPrivate,
            githubID: id,
            isDemo: false,
            isArchived: false,
            defaultBranch: defaultBranch,
            htmlURL: htmlURL
        )
    }
}

struct GitHubAccountInfo: Codable, Hashable {
    var login: String
    var name: String?
    var avatarURL: String?
}

struct GitHubConnectionRecord: Codable, Hashable {
    var account: GitHubAccountInfo
    var connectedAt: Date
}

enum GitHubEventKind: String, Codable, CaseIterable {
    case commit, pullRequest, review, issue, release

    var label: String {
        switch self {
        case .commit: "commit"
        case .pullRequest: "pull request"
        case .review: "review"
        case .issue: "issue"
        case .release: "release"
        }
    }

    var glyph: String {
        switch self {
        case .commit: "arrow.triangle.branch"
        case .pullRequest: "arrow.triangle.pull"
        case .review: "eye"
        case .issue: "exclamationmark.circle"
        case .release: "shippingbox"
        }
    }
}

struct ActivityEvent: Identifiable, Codable, Hashable {
    var id = UUID()
    var kind: GitHubEventKind
    var title: String
    var repoID: String
    var timestamp: Date
    var additions: Int = 0
    var deletions: Int = 0
    var filesChanged: Int = 0
    var commitSHA: String?
    var htmlURL: String?
    var authorLogin: String?
}

// MARK: - Sessions

struct Session: Identifiable, Codable, Hashable {
    var id = UUID()
    var startedAt: Date
    var accumulatedSeconds: Double
    var runningSince: Date?
    var endedAt: Date?
    var repoIDs: [String]
    var events: [ActivityEvent]
    var coinsEarned: Int
    var xpEarned: Int
    var note: String
    var coinBreakdown: CoinBreakdown? = nil
    /// One line written before the clock starts, e.g. "fix auth redirect".
    var intent: String = ""
    /// Closed-vocabulary labels such as #deep or #refactor.
    var tags: [String] = []
    /// Target length in minutes. `nil` or `0` means open-ended.
    var presetMinutes: Int? = nil
    /// Commits found in other local repositories during this window. The
    /// report offers to fold them in rather than silently changing the ledger.
    var unclaimedEvents: [ActivityEvent] = []

    var isRunning: Bool { endedAt == nil && runningSince != nil }
    var isPaused: Bool { endedAt == nil && runningSince == nil }
    var isCompleted: Bool { endedAt != nil }

    func duration(at now: Date = Date()) -> TimeInterval {
        if let runningSince {
            return accumulatedSeconds + max(0, now.timeIntervalSince(runningSince))
        }
        return accumulatedSeconds
    }

    var targetSeconds: TimeInterval? {
        guard let presetMinutes, presetMinutes > 0 else { return nil }
        return TimeInterval(presetMinutes * 60)
    }

    /// Seconds left against the preset, or nil when the session is open-ended.
    func remaining(at now: Date = Date()) -> TimeInterval? {
        guard let targetSeconds else { return nil }
        return max(0, targetSeconds - duration(at: now))
    }

    var commits: Int { events.filter { $0.kind == .commit }.count }
    var additions: Int { events.reduce(0) { $0 + $1.additions } }
    var deletions: Int { events.reduce(0) { $0 + $1.deletions } }
    var filesChanged: Int { events.reduce(0) { $0 + $1.filesChanged } }
    var hasTags: Bool { !tags.isEmpty }

    /// Explicit decoding keeps pre-toolkit `state.json` files loading. New
    /// fields fall back to their defaults instead of failing the whole file.
    enum CodingKeys: String, CodingKey {
        case id, startedAt, accumulatedSeconds, runningSince, endedAt, repoIDs
        case events, coinsEarned, xpEarned, note, coinBreakdown
        case intent, tags, presetMinutes, unclaimedEvents
    }

    init(
        id: UUID = UUID(),
        startedAt: Date,
        accumulatedSeconds: Double,
        runningSince: Date?,
        endedAt: Date?,
        repoIDs: [String],
        events: [ActivityEvent],
        coinsEarned: Int,
        xpEarned: Int,
        note: String,
        coinBreakdown: CoinBreakdown? = nil,
        intent: String = "",
        tags: [String] = [],
        presetMinutes: Int? = nil,
        unclaimedEvents: [ActivityEvent] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.accumulatedSeconds = accumulatedSeconds
        self.runningSince = runningSince
        self.endedAt = endedAt
        self.repoIDs = repoIDs
        self.events = events
        self.coinsEarned = coinsEarned
        self.xpEarned = xpEarned
        self.note = note
        self.coinBreakdown = coinBreakdown
        self.intent = intent
        self.tags = tags
        self.presetMinutes = presetMinutes
        self.unclaimedEvents = unclaimedEvents
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        accumulatedSeconds = try container.decodeIfPresent(Double.self, forKey: .accumulatedSeconds) ?? 0
        runningSince = try container.decodeIfPresent(Date.self, forKey: .runningSince)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        repoIDs = try container.decodeIfPresent([String].self, forKey: .repoIDs) ?? []
        events = try container.decodeIfPresent([ActivityEvent].self, forKey: .events) ?? []
        coinsEarned = try container.decodeIfPresent(Int.self, forKey: .coinsEarned) ?? 0
        xpEarned = try container.decodeIfPresent(Int.self, forKey: .xpEarned) ?? 0
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        coinBreakdown = try container.decodeIfPresent(CoinBreakdown.self, forKey: .coinBreakdown)
        intent = try container.decodeIfPresent(String.self, forKey: .intent) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        presetMinutes = try container.decodeIfPresent(Int.self, forKey: .presetMinutes)
        unclaimedEvents = try container.decodeIfPresent([ActivityEvent].self, forKey: .unclaimedEvents) ?? []
    }
}

// MARK: - Profile

struct UserProfile: Codable {
    var name: String
    var handle: String
    var bio: String
    var joinedAt: Date
    var xp: Int
    var coins: Int
    var streak: Int
    var longestStreak: Int
    var dailyGoalMinutes: Int
    var equippedThemeID: String
    var equippedAvatarID: String
    var equippedBadgeID: String?
    var equippedDecorIDs: [String]
}

struct LevelStatus {
    let level: Int
    let xpIntoLevel: Int
    let xpForNextLevel: Int
    let progress: Double

    static func from(xp: Int) -> LevelStatus {
        var level = 1
        var remaining = max(0, xp)
        while true {
            let needed = 120 + (level - 1) * 90
            if remaining < needed {
                return LevelStatus(level: level, xpIntoLevel: remaining, xpForNextLevel: needed,
                                   progress: Double(remaining) / Double(needed))
            }
            remaining -= needed
            level += 1
        }
    }
}

// MARK: - Achievements

struct Achievement: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let glyph: String
    let goal: Int
}

enum AchievementCatalog {
    static let all: [Achievement] = [
        Achievement(id: "first_light", title: "First Light", detail: "Finish your first focus session.", glyph: "sunrise.fill", goal: 1),
        Achievement(id: "deep_work", title: "Deep Work", detail: "Stay focused for 90 minutes straight.", glyph: "mountain.2.fill", goal: 90),
        Achievement(id: "night_shift", title: "Night Shift", detail: "Ship something after 10pm.", glyph: "moon.stars.fill", goal: 1),
        Achievement(id: "ship_it", title: "Ship It", detail: "Land 5 commits in a single session.", glyph: "shippingbox.fill", goal: 5),
        Achievement(id: "triple_digits", title: "Triple Digits", detail: "Track 100 commits in total.", glyph: "number.circle.fill", goal: 100),
        Achievement(id: "streak_3", title: "Three in a Row", detail: "Keep a 3 day focus streak.", glyph: "flame.fill", goal: 3),
        Achievement(id: "streak_7", title: "Seven Days", detail: "Keep a 7 day focus streak.", glyph: "calendar.badge.checkmark", goal: 7),
        Achievement(id: "curator", title: "Curator", detail: "Add 4 things to your collection.", glyph: "sparkles", goal: 4),
        Achievement(id: "regular", title: "A Regular", detail: "Complete 10 sessions.", glyph: "cup.and.saucer.fill", goal: 10)
    ]

    static func find(_ id: String) -> Achievement? { all.first { $0.id == id } }
}

// MARK: - Shop

enum ShopCategory: String, Codable, CaseIterable, Identifiable {
    case themes, avatars, badges, decor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .themes: "Themes"
        case .avatars: "Avatars"
        case .badges: "Badges"
        case .decor: "Shelf"
        }
    }

    var glyph: String {
        switch self {
        case .themes: "paintpalette"
        case .avatars: "person.crop.circle"
        case .badges: "seal"
        case .decor: "books.vertical"
        }
    }
}

enum Rarity: String, Codable {
    case common, rare, legendary

    var label: String { rawValue.capitalized }
}

struct ShopItem: Identifiable, Hashable {
    let id: String
    let category: ShopCategory
    let name: String
    let tagline: String
    let price: Int
    let rarity: Rarity
    let payload: String

    static let all: [ShopItem] = [
        ShopItem(id: "theme_paper", category: .themes, name: "Paper", tagline: "Light. Warm paper, honest ink.", price: 0, rarity: .common, payload: "paper"),
        ShopItem(id: "theme_midnight", category: .themes, name: "Midnight", tagline: "Dark. For the quiet hours.", price: 0, rarity: .common, payload: "midnight"),
        ShopItem(id: "theme_blueprint", category: .themes, name: "Blueprint", tagline: "Graph paper for serious play.", price: 320, rarity: .rare, payload: "blueprint"),
        ShopItem(id: "theme_oxide", category: .themes, name: "Oxide", tagline: "Warm clay and an orange edge.", price: 280, rarity: .rare, payload: "oxide"),
        ShopItem(id: "theme_sage", category: .themes, name: "Sage", tagline: "Quiet green-grey. Studio daylight.", price: 340, rarity: .rare, payload: "sage"),
        ShopItem(id: "theme_graphite", category: .themes, name: "Graphite", tagline: "Cool charcoal for late builds.", price: 460, rarity: .legendary, payload: "graphite"),
        ShopItem(id: "theme_plum", category: .themes, name: "Plum", tagline: "A dark room with the lamp on.", price: 540, rarity: .legendary, payload: "plum"),

        ShopItem(id: "avatar_maker", category: .avatars, name: "The Maker", tagline: "Hammer in hand.", price: 0, rarity: .common, payload: "hammer.fill|circle"),
        ShopItem(id: "avatar_terminal", category: .avatars, name: "Terminal Kid", tagline: "One more command.", price: 180, rarity: .common, payload: "chevron.left.forwardslash.chevron.right|hexagon"),
        ShopItem(id: "avatar_sprout", category: .avatars, name: "Slow Sprout", tagline: "Grow a little every day.", price: 220, rarity: .rare, payload: "leaf.fill|squircle"),
        ShopItem(id: "avatar_owl", category: .avatars, name: "Night Owl", tagline: "Awake when the build is green.", price: 320, rarity: .rare, payload: "bird.fill|circle"),
        ShopItem(id: "avatar_moth", category: .avatars, name: "Moth", tagline: "Drawn to the screen light.", price: 420, rarity: .legendary, payload: "moonphase.first.quarter|diamond"),

        ShopItem(id: "badge_early", category: .badges, name: "Early Bird", tagline: "Earn it: finish your first session.", price: 0, rarity: .common, payload: "sunrise.fill"),
        ShopItem(id: "badge_mono", category: .badges, name: "Mono", tagline: "Earn it: complete 10 sessions.", price: 0, rarity: .common, payload: "textformat"),
        ShopItem(id: "badge_ship", category: .badges, name: "Ship Happens", tagline: "Earn it: land 5 commits in one session.", price: 0, rarity: .rare, payload: "paperplane.fill"),
        ShopItem(id: "badge_bug", category: .badges, name: "Zero Bug", tagline: "Earn it: hold a 7 day streak.", price: 0, rarity: .rare, payload: "ladybug.fill"),
        ShopItem(id: "badge_ghost", category: .badges, name: "Ghost Commit", tagline: "Earn it: track 100 commits.", price: 0, rarity: .legendary, payload: "theatermasks.fill"),

        ShopItem(id: "decor_mug", category: .decor, name: "Dented Mug", tagline: "Coffee, then code.", price: 90, rarity: .common, payload: "cup.and.saucer.fill"),
        ShopItem(id: "decor_plant", category: .decor, name: "Desk Fern", tagline: "Low maintenance, high morale.", price: 140, rarity: .common, payload: "leaf.fill"),
        ShopItem(id: "decor_duck", category: .decor, name: "Debug Duck", tagline: "It already knows the answer.", price: 200, rarity: .rare, payload: "bird.fill"),
        ShopItem(id: "decor_lamp", category: .decor, name: "Task Lamp", tagline: "A small pool of focus.", price: 240, rarity: .rare, payload: "lamp.desk.fill"),
        ShopItem(id: "decor_crt", category: .decor, name: "Tiny CRT", tagline: "Runs your first game.", price: 460, rarity: .legendary, payload: "desktopcomputer")
    ]

    static func find(_ id: String) -> ShopItem? { all.first { $0.id == id } }
    static func items(in category: ShopCategory) -> [ShopItem] { all.filter { $0.category == category } }

    /// Badges are earned through achievement milestones, never bought.
    var isEarnable: Bool { category == .badges }

    var earnedByAchievementID: String? {
        switch id {
        case "badge_early": "first_light"
        case "badge_mono": "regular"
        case "badge_ship": "ship_it"
        case "badge_bug": "streak_7"
        case "badge_ghost": "triple_digits"
        default: nil
        }
    }

    var earnHint: String {
        switch id {
        case "badge_early": "Finish your first session"
        case "badge_mono": "Complete 10 sessions"
        case "badge_ship": "Land 5 commits in one session"
        case "badge_bug": "Hold a 7 day streak"
        case "badge_ghost": "Track 100 commits"
        default: "Earn it"
        }
    }
}

// MARK: - Persistence

struct PersistedState: Codable {
    var profile: UserProfile
    var repositories: [Repository]
    var sessions: [Session]
    var activity: [ActivityEvent]
    var ownedItemIDs: Set<String>
    var achievements: [String: Date]
    var draftRepoIDs: [String]
    var lastSyncedAt: Date?
    var githubConnection: GitHubConnectionRecord? = nil
    var onboardingCompleted: Bool? = nil
    var settings: AppSettings? = nil
    /// Toolkit state. Optional so files written before the toolkit still load.
    var streakFreezes: Int? = nil
    var frozenDays: [String]? = nil
    var questClaims: [String: Date]? = nil
}

// MARK: - Toasts

struct Notice: Identifiable, Equatable {
    enum Kind { case info, achievement, error }
    let id = UUID()
    var kind: Kind
    var title: String
    var message: String
}

// MARK: - Date helpers

extension Date {
    func startOfDay(_ calendar: Calendar = .current) -> Date { calendar.startOfDay(for: self) }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    /// Stable local-day identity used by streaks and quests.
    var dayKey: String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: self)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    /// ISO week identity, e.g. 2026-W46.
    var weekKey: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return String(format: "%04d-W%02d", components.yearForWeekOfYear ?? 0, components.weekOfYear ?? 0)
    }
}

extension TimeInterval {
    /// 1h 24m / 42m / 12s
    var focusLabel: String {
        let total = Int(self)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return "\(hours)h \(String(format: "%02d", minutes))m" }
        if minutes > 0 { return "\(minutes)m" }
        return "\(seconds)s"
    }

    var clockLabel: String {
        let total = max(0, Int(self))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    var shortClock: String {
        let total = max(0, Int(self))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
