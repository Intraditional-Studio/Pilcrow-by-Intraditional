import Foundation
import CoreGraphics

// MARK: - Focus presets

/// A target length for a session. `open` has no target, so the clock just runs.
struct FocusPreset: Identifiable, Hashable {
    let id: String
    let minutes: Int
    let name: String
    let detail: String

    var seconds: TimeInterval { TimeInterval(minutes * 60) }
    var isOpen: Bool { minutes == 0 }

    static let open = FocusPreset(id: "open", minutes: 0, name: "Open", detail: "Run until you stop")
    static let all: [FocusPreset] = [
        open,
        FocusPreset(id: "25", minutes: 25, name: "25", detail: "One short block"),
        FocusPreset(id: "50", minutes: 50, name: "50", detail: "A proper sitting"),
        FocusPreset(id: "90", minutes: 90, name: "90", detail: "Deep work")
    ]

    static func find(minutes: Int) -> FocusPreset? {
        all.first { $0.minutes == minutes }
    }
}

// MARK: - Session tags

/// A small, closed vocabulary. Tags are for looking back, not for filing.
enum SessionTagCatalog {
    static let all: [String] = ["deep", "refactor", "fix", "ship", "learn", "review"]

    static func label(_ tag: String) -> String { "#\(tag)" }
}

// MARK: - Quests

enum QuestPeriod: String, Codable, CaseIterable, Identifiable {
    case daily, weekly

    var id: String { rawValue }
    var title: String { self == .daily ? "Today" : "This week" }
    var shortTitle: String { self == .daily ? "daily" : "weekly" }
}

struct Quest: Identifiable, Hashable {
    let id: String
    let period: QuestPeriod
    let title: String
    let detail: String
    let glyph: String
    let goal: Int
    let rewardCoins: Int
    let rewardXP: Int
}

enum QuestCatalog {
    static let all: [Quest] = [
        Quest(id: "daily_focus", period: .daily, title: "One good hour", detail: "Focus for 60 minutes today.", glyph: "clock", goal: 60, rewardCoins: 30, rewardXP: 12),
        Quest(id: "daily_commits", period: .daily, title: "Land three", detail: "Record 3 commits today.", glyph: "arrow.triangle.branch", goal: 3, rewardCoins: 30, rewardXP: 12),
        Quest(id: "daily_sessions", period: .daily, title: "Two sittings", detail: "Finish 2 sessions today.", glyph: "timer", goal: 2, rewardCoins: 25, rewardXP: 10),
        Quest(id: "daily_early", period: .daily, title: "Before noon", detail: "Finish a session before 12pm.", glyph: "sunrise", goal: 1, rewardCoins: 20, rewardXP: 8),

        Quest(id: "weekly_deep", period: .weekly, title: "Deep water", detail: "Finish three 50 minute sessions.", glyph: "mountain.2", goal: 3, rewardCoins: 90, rewardXP: 40),
        Quest(id: "weekly_commits", period: .weekly, title: "Twenty shipped", detail: "Record 20 commits this week.", glyph: "shippingbox", goal: 20, rewardCoins: 110, rewardXP: 45),
        Quest(id: "weekly_days", period: .weekly, title: "Show up", detail: "Focus on 4 different days.", glyph: "calendar", goal: 4, rewardCoins: 80, rewardXP: 35)
    ]

    static func quests(for period: QuestPeriod) -> [Quest] {
        all.filter { $0.period == period }
    }

    static func find(_ id: String) -> Quest? { all.first { $0.id == id } }
}

// MARK: - Streak freeze

enum StreakFreeze {
    static let price = 200
    static let maximum = 3
}

// MARK: - Idle monitor

/// Seconds since the last keyboard, mouse, or tablet input. Used to pause a
/// session when the Mac is left alone. The all-events sentinel is the documented
/// way to ask CoreGraphics for any input type.
enum IdleMonitor {
    static func secondsSinceLastInput() -> TimeInterval {
        guard let anyEvent = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyEvent)
    }
}
