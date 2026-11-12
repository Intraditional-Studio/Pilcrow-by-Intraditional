import Foundation

/// User preferences. Every field is optional on disk so older `state.json`
/// files keep loading after a new setting is introduced.
struct AppSettings: Codable, Equatable {
    var soundEnabled: Bool = true
    var soundVolume: Double = 0.6
    var soundOnSessionStart: Bool = true
    var soundOnSessionEnd: Bool = true
    var soundOnReward: Bool = true
    var soundOnPurchase: Bool = true
    var soundOnAchievement: Bool = true

    var reduceMotion: Bool = false
    var showSessionReport: Bool = true
    var dockBadge: Bool = false

    var menuBarTimer: Bool = true
    var liveCommitWatch: Bool = true
    var idleAutoPause: Bool = true
    var idleThresholdMinutes: Int = 5
    var defaultPresetMinutes: Int = 0
    var autoEndAtPreset: Bool = true

    init() {}

    var clampedVolume: Double { min(1, max(0, soundVolume)) }
    var clampedIdleThreshold: Int { min(30, max(1, idleThresholdMinutes)) }

    enum CodingKeys: String, CodingKey {
        case soundEnabled
        case soundVolume
        case soundOnSessionStart
        case soundOnSessionEnd
        case soundOnReward
        case soundOnPurchase
        case soundOnAchievement
        case reduceMotion
        case showSessionReport
        case dockBadge
        case menuBarTimer
        case liveCommitWatch
        case idleAutoPause
        case idleThresholdMinutes
        case defaultPresetMinutes
        case autoEndAtPreset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppSettings()
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? fallback.soundEnabled
        soundVolume = try container.decodeIfPresent(Double.self, forKey: .soundVolume) ?? fallback.soundVolume
        soundOnSessionStart = try container.decodeIfPresent(Bool.self, forKey: .soundOnSessionStart) ?? fallback.soundOnSessionStart
        soundOnSessionEnd = try container.decodeIfPresent(Bool.self, forKey: .soundOnSessionEnd) ?? fallback.soundOnSessionEnd
        soundOnReward = try container.decodeIfPresent(Bool.self, forKey: .soundOnReward) ?? fallback.soundOnReward
        soundOnPurchase = try container.decodeIfPresent(Bool.self, forKey: .soundOnPurchase) ?? fallback.soundOnPurchase
        soundOnAchievement = try container.decodeIfPresent(Bool.self, forKey: .soundOnAchievement) ?? fallback.soundOnAchievement
        reduceMotion = try container.decodeIfPresent(Bool.self, forKey: .reduceMotion) ?? fallback.reduceMotion
        showSessionReport = try container.decodeIfPresent(Bool.self, forKey: .showSessionReport) ?? fallback.showSessionReport
        dockBadge = try container.decodeIfPresent(Bool.self, forKey: .dockBadge) ?? fallback.dockBadge
        menuBarTimer = try container.decodeIfPresent(Bool.self, forKey: .menuBarTimer) ?? fallback.menuBarTimer
        liveCommitWatch = try container.decodeIfPresent(Bool.self, forKey: .liveCommitWatch) ?? fallback.liveCommitWatch
        idleAutoPause = try container.decodeIfPresent(Bool.self, forKey: .idleAutoPause) ?? fallback.idleAutoPause
        idleThresholdMinutes = try container.decodeIfPresent(Int.self, forKey: .idleThresholdMinutes) ?? fallback.idleThresholdMinutes
        defaultPresetMinutes = try container.decodeIfPresent(Int.self, forKey: .defaultPresetMinutes) ?? fallback.defaultPresetMinutes
        autoEndAtPreset = try container.decodeIfPresent(Bool.self, forKey: .autoEndAtPreset) ?? fallback.autoEndAtPreset
    }
}
