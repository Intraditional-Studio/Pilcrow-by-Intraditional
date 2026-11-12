import SwiftUI

// MARK: - Best hours heatmap

struct BestHoursPanel: View {
    @Environment(\.theme) private var theme
    var insights: ReportInsights

    private var maxSeconds: TimeInterval {
        max(1, insights.heatmap.map(\.seconds).max() ?? 1)
    }

    var body: some View {
        Panel(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(
                    label: "best hours",
                    title: nil,
                    detail: peakLabel,
                    index: "05"
                )
                Hairline()
                if !insights.hasData {
                    EmptyState(glyph: "clock", title: "No rhythm yet",
                               message: "Finish a session and your strongest hours appear here.")
                } else {
                    VStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { weekday in
                            HStack(spacing: 4) {
                                Text(ReportInsights.weekdayLabels[weekday])
                                    .font(Typeface.mono(7, weight: .medium))
                                    .foregroundStyle(theme.secondary)
                                    .frame(width: 12, alignment: .leading)
                                ForEach(0..<ReportInsights.hourBlocks, id: \.self) { block in
                                    cell(weekday: weekday, block: block)
                                }
                            }
                        }
                        HStack(spacing: 4) {
                            Spacer().frame(width: 12)
                            Text("00")
                            Spacer()
                            Text("12")
                            Spacer()
                            Text("24")
                        }
                        .font(Typeface.mono(6.5))
                        .foregroundStyle(theme.secondary.opacity(0.7))
                    }
                    HStack(spacing: 7) {
                        Text("LESS")
                        ForEach([0.06, 0.22, 0.42, 0.66, 1.0], id: \.self) { level in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(theme.accent.opacity(level))
                                .frame(width: 13, height: 7)
                        }
                        Text("MORE")
                        Spacer()
                        if let peak = insights.peakBlock {
                            Text("PEAK \(ReportInsights.weekdayNames[peak.weekday].uppercased()) \(blockLabel(peak.block))")
                                .font(Typeface.mono(7, weight: .medium))
                                .tracking(0.6)
                                .foregroundStyle(theme.accent)
                        }
                    }
                    .font(Typeface.mono(6.5))
                    .tracking(0.5)
                    .foregroundStyle(theme.secondary)
                    .padding(.top, 2)
                }
            }
        }
        .frame(minWidth: 300, maxWidth: .infinity)
    }

    private var peakLabel: String {
        guard let peak = insights.peakBlock else { return "" }
        return "strongest \(ReportInsights.weekdayNames[peak.weekday].lowercased()) \(blockLabel(peak.block))"
    }

    private func blockLabel(_ block: Int) -> String {
        let start = block * ReportInsights.blockHours
        return String(format: "%02d–%02d", start, start + ReportInsights.blockHours)
    }

    private func cell(weekday: Int, block: Int) -> some View {
        let seconds = insights.heatmap.first { $0.weekday == weekday && $0.block == block }?.seconds ?? 0
        let intensity = seconds / maxSeconds
        return RoundedRectangle(cornerRadius: 1)
            .fill(seconds > 0 ? theme.accent.opacity(0.10 + intensity * 0.85) : theme.ink.opacity(0.05))
            .frame(maxWidth: .infinity)
            .frame(height: 15)
            .help(seconds > 0 ? "\(ReportInsights.weekdayNames[weekday]) \(blockLabel(block)) · \(seconds.focusLabel)" : "")
    }
}

// MARK: - Focus vs commits

struct FocusCommitsPanel: View {
    @Environment(\.theme) private var theme
    var insights: ReportInsights

    private var maxMinutes: Double {
        max(30, insights.points.map(\.minutes).max() ?? 30)
    }

    private var maxCommits: Int {
        max(1, insights.points.map(\.commits).max() ?? 1)
    }

    private var correlationLabel: String {
        guard let value = insights.correlation else { return "not enough sessions yet" }
        let strength: String
        switch abs(value) {
        case 0..<0.2: strength = "barely linked"
        case 0.2..<0.45: strength = "loosely linked"
        case 0.45..<0.7: strength = "clearly linked"
        default: strength = "strongly linked"
        }
        return "\(strength) · r \(String(format: "%.2f", value))"
    }

    var body: some View {
        Panel(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(label: "focus vs commits", title: nil,
                               detail: insights.hasData ? correlationLabel : "", index: "06")
                Hairline()
                if !insights.hasData {
                    EmptyState(glyph: "chart.dots.scatter", title: "Nothing to plot",
                               message: "Each session becomes a dot: time on one axis, commits on the other.")
                } else {
                    GeometryReader { geo in
                        ZStack(alignment: .bottomLeading) {
                            // Grid
                            VStack(spacing: 0) {
                                ForEach(0..<4, id: \.self) { _ in
                                    Rectangle().fill(theme.line.opacity(0.6)).frame(height: 1)
                                    Spacer()
                                }
                            }
                            HStack(spacing: 0) {
                                ForEach(0..<4, id: \.self) { _ in
                                    Rectangle().fill(theme.line.opacity(0.45)).frame(width: 1)
                                    Spacer()
                                }
                            }
                            ForEach(insights.points) { point in
                                Circle()
                                    .fill(theme.accent.opacity(0.82))
                                    .frame(width: 7, height: 7)
                                    .overlay(Circle().strokeBorder(theme.surface, lineWidth: 1))
                                    .position(
                                        x: max(4, min(geo.size.width - 4, geo.size.width * point.minutes / maxMinutes)),
                                        y: max(4, min(geo.size.height - 4, geo.size.height * (1 - Double(point.commits) / Double(maxCommits))))
                                    )
                            }
                        }
                    }
                    .frame(height: 132)
                    HStack {
                        Text("0 min")
                        Spacer()
                        Text("\(Int(maxMinutes)) min focus")
                        Spacer()
                        Text("up to \(maxCommits) commits")
                    }
                    .font(Typeface.mono(7))
                    .foregroundStyle(theme.secondary)
                }
            }
        }
        .frame(minWidth: 300, maxWidth: .infinity)
    }
}

// MARK: - Session length distribution

struct LengthDistributionPanel: View {
    @Environment(\.theme) private var theme
    var insights: ReportInsights

    private var total: Int {
        max(1, insights.buckets.reduce(0) { $0 + $1.count })
    }

    var body: some View {
        Panel(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(label: "session lengths", title: nil, index: "07")
                Hairline()
                if !insights.hasData {
                    EmptyState(glyph: "chart.bar", title: "No sessions",
                               message: "Completed sessions land in four honest buckets.")
                } else {
                    VStack(spacing: 12) {
                        ForEach(insights.buckets) { bucket in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(bucket.label)
                                        .font(Typeface.body(11, weight: .medium))
                                        .foregroundStyle(theme.ink)
                                    Text(bucket.detail)
                                        .font(Typeface.mono(7.5))
                                        .foregroundStyle(theme.secondary)
                                    Spacer()
                                    Text("\(bucket.count)")
                                        .font(Typeface.mono(9, weight: .medium))
                                        .foregroundStyle(bucket.count > 0 ? theme.accent : theme.secondary)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(theme.ink.opacity(0.06))
                                        Capsule()
                                            .fill(bucket.count > 0 ? theme.accent : theme.ink.opacity(0.12))
                                            .frame(width: max(3, geo.size.width * CGFloat(bucket.count) / CGFloat(total)))
                                    }
                                }
                                .frame(height: 4)
                            }
                        }
                    }
                    Text("\(insights.sessions.count) sessions · \(insights.sessions.reduce(0) { $0 + $1.accumulatedSeconds }.focusLabel) focused")
                        .font(Typeface.mono(7.5))
                        .foregroundStyle(theme.secondary)
                }
            }
        }
        .frame(minWidth: 300, maxWidth: .infinity)
    }
}

// MARK: - Week over week

struct WeekOverWeekPanel: View {
    @Environment(\.theme) private var theme
    var deltas: [ReportInsights.Delta]

    var body: some View {
        Panel(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(label: "against last week", title: nil, index: "08")
                Hairline()
                HStack(spacing: 0) {
                    ForEach(Array(deltas.enumerated()), id: \.offset) { index, delta in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(delta.label.uppercased())
                                .font(Typeface.mono(7))
                                .tracking(0.8)
                                .foregroundStyle(theme.secondary)
                            Text(delta.displayCurrent)
                                .font(Typeface.display(17, weight: .semibold))
                                .foregroundStyle(theme.ink)
                            HStack(spacing: 2) {
                                if let change = delta.change {
                                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                        .font(.system(size: 7, weight: .bold))
                                    Text("\(Int((abs(change) * 100).rounded()))%")
                                        .font(Typeface.mono(7.5, weight: .medium))
                                } else {
                                    Text("new")
                                        .font(Typeface.mono(7.5, weight: .medium))
                                }
                            }
                            .foregroundStyle((delta.change ?? 0) >= 0 ? theme.green : theme.accent)
                            Text("was \(delta.displayPrevious)")
                                .font(Typeface.mono(6.5))
                                .foregroundStyle(theme.secondary.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if index < deltas.count - 1 {
                            Rectangle().fill(theme.line).frame(width: 1, height: 40)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 300, maxWidth: .infinity)
    }
}

// MARK: - Tags

struct TagSummaryPanel: View {
    @Environment(\.theme) private var theme
    var insights: ReportInsights

    var body: some View {
        Panel(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(label: "what you called it", title: nil, index: "09")
                Hairline()
                if insights.tags.isEmpty {
                    EmptyState(glyph: "number", title: "No tags yet",
                               message: "Tag a session before you start it to see where the week went.")
                } else {
                    VStack(spacing: 9) {
                        ForEach(insights.tags) { tag in
                            HStack(spacing: 8) {
                                Text("#\(tag.tag)")
                                    .font(Typeface.mono(9, weight: .medium))
                                    .foregroundStyle(theme.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(theme.accentSoft)
                                Spacer()
                                Text("\(tag.sessions) \(tag.sessions == 1 ? "session" : "sessions")")
                                    .font(Typeface.mono(8))
                                    .foregroundStyle(theme.secondary)
                                Text(tag.seconds.focusLabel)
                                    .font(Typeface.mono(9, weight: .medium))
                                    .foregroundStyle(theme.ink)
                                    .frame(width: 52, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 250, maxWidth: .infinity)
    }
}
