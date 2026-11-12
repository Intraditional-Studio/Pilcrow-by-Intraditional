import Foundation

// MARK: - Report insights

/// Everything Reports 2.0 needs, derived from one week of sessions. Keeping the
/// maths here means the views stay declarative and the numbers are testable.
struct ReportInsights {
    struct HourCell: Identifiable {
        var id: String { "\(weekday)-\(block)" }
        let weekday: Int   // 0 = Monday
        let block: Int     // 0..<hourBlocks
        let seconds: TimeInterval
    }

    struct LengthBucket: Identifiable {
        var id: String { label }
        let label: String
        let detail: String
        let count: Int
        let seconds: TimeInterval
    }

    struct ScatterPoint: Identifiable {
        var id: UUID
        let minutes: Double
        let commits: Int
    }

    struct TagSummary: Identifiable {
        var id: String { tag }
        let tag: String
        let sessions: Int
        let seconds: TimeInterval
    }

    struct Delta {
        let label: String
        let current: Double
        let previous: Double
        var change: Double? {
            guard previous > 0 else { return nil }
            return (current - previous) / previous
        }
        var isCount: Bool = false
        var displayCurrent: String {
            isCount ? "\(Int(current))" : TimeInterval(current).focusLabel
        }
        var displayPrevious: String {
            isCount ? "\(Int(previous))" : TimeInterval(previous).focusLabel
        }
    }

    static let hourBlocks = 12
    static let blockHours = 2
    static let weekdayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    static let weekdayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    let sessions: [Session]
    let heatmap: [HourCell]
    let hourTotals: [TimeInterval]
    let peakBlock: (weekday: Int, block: Int)?
    let buckets: [LengthBucket]
    let points: [ScatterPoint]
    let correlation: Double?
    let tags: [TagSummary]
    let deltas: [Delta]

    init(sessions: [Session], previous: [Session]) {
        let completed = sessions.filter(\.isCompleted)
        let previousCompleted = previous.filter(\.isCompleted)
        self.sessions = completed

        // Heatmap: spread each session across the two-hour blocks it touches so
        // a 90 minute sitting at 09:10 lands in both the 8–10 and 10–12 cells.
        let calendar = Calendar.current
        var cells: [String: TimeInterval] = [:]
        var totals = Array(repeating: TimeInterval(0), count: 24)

        for session in completed {
            let seconds = max(0, session.accumulatedSeconds)
            guard seconds > 0 else { continue }
            let start = session.startedAt
            let weekdayIndex = Self.mondayIndex(for: start, calendar: calendar)
            let startHour = calendar.component(.hour, from: start)
            let startMinute = calendar.component(.minute, from: start)
            var offset = TimeInterval(0)
            while offset < seconds {
                let absoluteMinute = Double(startHour * 60 + startMinute) + offset / 60
                let hour = min(23, max(0, Int(absoluteMinute / 60) % 24))
                let block = hour / Self.blockHours
                let secondsToNextHour = 3600 - (absoluteMinute * 60).truncatingRemainder(dividingBy: 3600)
                let step = max(1, min(seconds - offset, secondsToNextHour))
                let key = "\(weekdayIndex)-\(block)"
                cells[key, default: 0] += step
                totals[hour] += step
                offset += step
            }
        }

        var heat: [HourCell] = []
        for weekday in 0..<7 {
            for block in 0..<Self.hourBlocks {
                heat.append(HourCell(
                    weekday: weekday,
                    block: block,
                    seconds: cells["\(weekday)-\(block)", default: 0]
                ))
            }
        }
        heatmap = heat
        hourTotals = totals

        // Peak block, for the annotation line.
        let peak = heat.max { $0.seconds < $1.seconds }
        if let peak, peak.seconds > 0 {
            peakBlock = (peak.weekday, peak.block)
        } else {
            peakBlock = nil
        }

        // Length distribution.
        let definitions: [(String, String, Range<Double>)] = [
            ("Under 25", "< 25 min", 0.0..<25.0),
            ("25–49", "one short block", 25.0..<50.0),
            ("50–89", "a proper sitting", 50.0..<90.0),
            ("90+", "deep water", 90.0..<Double.infinity)
        ]
        buckets = definitions.map { label, detail, range in
            let matching = completed.filter {
                let minutes = $0.accumulatedSeconds / 60
                return range.contains(minutes)
            }
            return LengthBucket(
                label: label,
                detail: detail,
                count: matching.count,
                seconds: matching.reduce(0) { $0 + $1.accumulatedSeconds }
            )
        }

        // Focus vs commits. The y axis is capped for readability; the
        // correlation itself uses the real values.
        points = completed.map {
            ScatterPoint(id: $0.id, minutes: $0.accumulatedSeconds / 60, commits: $0.commits)
        }
        correlation = Self.pearson(
            points.map(\.minutes),
            points.map { Double($0.commits) }
        )

        // Tag summary.
        var tagCounts: [String: (Int, TimeInterval)] = [:]
        for session in completed {
            for tag in session.tags {
                let existing = tagCounts[tag] ?? (0, 0)
                tagCounts[tag] = (existing.0 + 1, existing.1 + session.accumulatedSeconds)
            }
        }
        tags = tagCounts.map { TagSummary(tag: $0.key, sessions: $0.value.0, seconds: $0.value.1) }
            .sorted { $0.seconds > $1.seconds }

        deltas = [
            Delta(
                label: "focus",
                current: completed.reduce(0) { $0 + $1.accumulatedSeconds },
                previous: previousCompleted.reduce(0) { $0 + $1.accumulatedSeconds }
            ),
            Delta(
                label: "sessions",
                current: Double(completed.count),
                previous: Double(previousCompleted.count),
                isCount: true
            ),
            Delta(
                label: "commits",
                current: Double(completed.reduce(0) { $0 + $1.commits }),
                previous: Double(previousCompleted.reduce(0) { $0 + $1.commits }),
                isCount: true
            ),
            Delta(
                label: "coins",
                current: Double(completed.reduce(0) { $0 + $1.coinsEarned }),
                previous: Double(previousCompleted.reduce(0) { $0 + $1.coinsEarned }),
                isCount: true
            )
        ]
    }

    // MARK: Helpers

    private static func mondayIndex(for date: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday
        return (weekday + 5) % 7
    }

    private static func pearson(_ xs: [Double], _ ys: [Double]) -> Double? {
        guard xs.count == ys.count, xs.count >= 3 else { return nil }
        let n = Double(xs.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n
        var numerator = 0.0
        var sumX = 0.0
        var sumY = 0.0
        for index in xs.indices {
            let dx = xs[index] - meanX
            let dy = ys[index] - meanY
            numerator += dx * dy
            sumX += dx * dx
            sumY += dy * dy
        }
        guard sumX > 0, sumY > 0 else { return nil }
        return numerator / (sumX * sumY).squareRoot()
    }

    var hasData: Bool { !sessions.isEmpty }
}
