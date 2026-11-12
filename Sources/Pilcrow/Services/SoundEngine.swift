import AppKit

/// The small set of moments that make a sound. Each one maps to a macOS system
/// sound so there are no audio assets to ship.
enum SoundCue {
    case sessionStart
    case sessionEnd
    case reward
    case purchase
    case achievement

    var systemName: String {
        switch self {
        case .sessionStart: "Pop"
        case .sessionEnd: "Glass"
        case .reward: "Tink"
        case .purchase: "Purr"
        case .achievement: "Hero"
        }
    }

    var title: String {
        switch self {
        case .sessionStart: "Session starts"
        case .sessionEnd: "Session ends"
        case .reward: "Coins are earned"
        case .purchase: "Something is bought"
        case .achievement: "Achievement unlocked"
        }
    }

    func isAllowed(in settings: AppSettings) -> Bool {
        guard settings.soundEnabled else { return false }
        switch self {
        case .sessionStart: return settings.soundOnSessionStart
        case .sessionEnd: return settings.soundOnSessionEnd
        case .reward: return settings.soundOnReward
        case .purchase: return settings.soundOnPurchase
        case .achievement: return settings.soundOnAchievement
        }
    }
}

/// Plays short system sounds, honouring the user's settings. Silent while
/// snapshotting or running the self-test so automation never makes noise.
@MainActor
final class SoundEngine {
    static let shared = SoundEngine()

    private var cache: [String: NSSound] = [:]
    private let isQuietRun = ProcessInfo.processInfo.arguments.contains { argument in
        argument == "--selftest" || argument == "--snapshot" || argument == "--git-probe"
    }

    func play(_ cue: SoundCue, settings: AppSettings) {
        guard !isQuietRun,
              cue.isAllowed(in: settings),
              settings.clampedVolume > 0.001 else { return }
        playNamed(cue.systemName, volume: settings.clampedVolume)
    }

    /// Used by the Settings window so the user can hear each cue on demand.
    func preview(_ cue: SoundCue, volume: Double) {
        guard !isQuietRun, volume > 0.001 else { return }
        playNamed(cue.systemName, volume: volume)
    }

    private func playNamed(_ name: String, volume: Double) {
        let sound: NSSound
        if let cached = cache[name] {
            sound = cached
        } else if let created = NSSound(named: NSSound.Name(name)) {
            cache[name] = created
            sound = created
        } else {
            return
        }
        sound.stop()
        sound.volume = Float(volume)
        sound.play()
    }
}
