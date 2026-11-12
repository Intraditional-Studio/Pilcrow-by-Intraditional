import Foundation

/// Coins reward focus first, then craft. The formula is deliberately simple
/// enough to explain in one line and impossible to farm with empty sessions.
struct CoinBreakdown: Codable, Hashable {
    let focusMinutes: Int
    let base: Int
    let lengthBonus: Int
    let commitBonus: Int
    let changeBonus: Int
    let streakBonus: Int
    let total: Int
    let commits: Int
    let filesChanged: Int
    let streak: Int

    var lengthMultiplier: Double {
        CoinEngine.lengthMultiplier(for: focusMinutes)
    }
}

enum CoinEngine {
    /// 2 coins per focused minute. Longer blocks earn a small completion
    /// multiplier; commits and changed files add craft bonuses; a live streak
    /// adds a small consistency bonus. Everything is capped so marathons stay
    /// meaningful without breaking the shop economy.
    static func calculate(
        minutes: Double,
        commits: Int,
        filesChanged: Int,
        streak: Int
    ) -> CoinBreakdown {
        let focusedMinutes = max(0, Int(minutes.rounded(.down)))
        let base = focusedMinutes * 2
        let multiplier = lengthMultiplier(for: focusedMinutes)
        let boosted = Int((Double(base) * multiplier).rounded())
        let lengthBonus = max(0, boosted - base)
        let commitBonus = min(72, max(0, commits) * 6)
        let changeBonus = min(24, max(0, filesChanged) * 2)
        let streakBonus = min(30, max(0, streak) * 3)
        let rawTotal = boosted + commitBonus + changeBonus + streakBonus
        let total = min(500, rawTotal)

        return CoinBreakdown(
            focusMinutes: focusedMinutes,
            base: base,
            lengthBonus: lengthBonus,
            commitBonus: commitBonus,
            changeBonus: changeBonus,
            streakBonus: streakBonus,
            total: total,
            commits: max(0, commits),
            filesChanged: max(0, filesChanged),
            streak: max(0, streak)
        )
    }

    static func lengthMultiplier(for minutes: Int) -> Double {
        switch minutes {
        case 90...: 1.35
        case 50..<90: 1.20
        case 25..<50: 1.10
        default: 1.0
        }
    }

    static func breakdown(for session: Session, streak: Int) -> CoinBreakdown {
        calculate(
            minutes: session.accumulatedSeconds / 60,
            commits: session.commits,
            filesChanged: session.filesChanged,
            streak: streak
        )
    }
}
