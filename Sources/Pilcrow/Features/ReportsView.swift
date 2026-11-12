import SwiftUI

struct ReportsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.theme) private var theme
    @State private var weekOffset = 0
    @State private var expandedSession: Session?
    @State private var showingReceipt = false

    private var days: [DayFocus] { store.days(offset: weekOffset) }
    private var week: WeekSummary { store.week(offset: weekOffset) }
    private var previousWeek: WeekSummary { store.week(offset: weekOffset - 1) }

    private var insights: ReportInsights {
        ReportInsights(sessions: week.sessions, previous: previousWeek.sessions)
    }

    private var dateRange: String {
        guard let first = days.first?.date, let last = days.last?.date else { return "" }
        return "\(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private var focusDelta: Double? {
        guard previousWeek.focus > 0 else { return nil }
        return (week.focus - previousWeek.focus) / previousWeek.focus
    }

    private var bestDay: DayFocus? {
        guard let best = days.max(by: { $0.seconds < $1.seconds }), best.seconds > 0 else { return nil }
        return best
    }
    private var longestSession: Session? { week.sessions.max { $0.accumulatedSeconds < $1.accumulatedSeconds } }

    private var repoCommits: [(repo: Repository, commits: Int)] {
        var counts: [String: Int] = [:]
        for session in week.sessions {
            for event in session.events where event.kind == .commit {
                counts[event.repoID, default: 0] += 1
            }
        }
        return counts.compactMap { id, count in
            store.repository(withID: id).map { ($0, count) }
        }.sorted { $0.1 > $1.1 }
    }

    private var timelineEvents: [ActivityEvent] {
        week.sessions.flatMap(\.events).sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    kicker: "SECTION 03 / WEEKLY REVIEW",
                    title: "Reports",
                    subtitle: "The shape of your week, told in time, commits, and small wins."
                ) {
                    HStack(spacing: 10) {
                        Button {
                            showingReceipt = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 8, weight: .semibold))
                                Text("Receipt")
                                    .font(Typeface.mono(8.5, weight: .medium))
                                    .tracking(0.6)
                                    .textCase(.uppercase)
                            }
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, 9)
                            .frame(height: 30)
                            .overlay(Rectangle().strokeBorder(theme.accent.opacity(0.35), lineWidth: 1))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableButtonStyle())
                        .help("Export this week as a designed receipt")
                        weekSwitcher
                    }
                    .padding(.top, 10)
                }
                .reveal()

                summary
                    .reveal(delay: 0.04)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        chartPanel
                        repoPanel.frame(width: 290)
                    }
                    VStack(spacing: 16) {
                        chartPanel
                        repoPanel
                    }
                }
                .reveal(delay: 0.08)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        timelinePanel
                        sessionPanel.frame(width: 340)
                    }
                    VStack(spacing: 16) {
                        timelinePanel
                        sessionPanel
                    }
                }
                .reveal(delay: 0.12)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        BestHoursPanel(insights: insights)
                        FocusCommitsPanel(insights: insights)
                    }
                    VStack(spacing: 16) {
                        BestHoursPanel(insights: insights)
                        FocusCommitsPanel(insights: insights)
                    }
                }
                .reveal(delay: 0.14)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        LengthDistributionPanel(insights: insights)
                        TagSummaryPanel(insights: insights)
                        WeekOverWeekPanel(deltas: insights.deltas)
                    }
                    VStack(spacing: 16) {
                        LengthDistributionPanel(insights: insights)
                        TagSummaryPanel(insights: insights)
                        WeekOverWeekPanel(deltas: insights.deltas)
                    }
                }
                .reveal(delay: 0.16)

                annotationStrip
                    .reveal(delay: 0.18)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 16)
            .frame(maxWidth: 1180)
            .frame(maxWidth: .infinity)
        }
        .sheet(item: $expandedSession) { session in
            SessionReportView(session: session)
                .environmentObject(store)
                .environment(\.theme, store.theme)
                .preferredColorScheme(store.theme.isDark ? .dark : .light)
        }
        .sheet(isPresented: $showingReceipt) {
            WeeklyReceiptView(weekOffset: weekOffset)
                .environmentObject(store)
                .environment(\.theme, store.theme)
                .preferredColorScheme(store.theme.isDark ? .dark : .light)
        }
    }

    private var weekSwitcher: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) { weekOffset -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.secondary)
                    .frame(width: 28, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(spacing: 0) {
                Text(weekOffset == 0 ? "THIS WEEK" : weekOffset == -1 ? "LAST WEEK" : "WEEK \(weekOffset)")
                    .font(Typeface.mono(9, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(theme.ink)
                Text(dateRange)
                    .font(Typeface.mono(8))
                    .foregroundStyle(theme.secondary)
            }
            .frame(minWidth: 112)

            Button {
                guard weekOffset < 0 else { return }
                withAnimation(.easeOut(duration: 0.15)) { weekOffset += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(weekOffset < 0 ? theme.secondary : theme.secondary.opacity(0.25))
                    .frame(width: 28, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(weekOffset >= 0)
        }
        .background(theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    // MARK: Summary

    private var summary: some View {
        DarkPanel(padding: 22) { dark in
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 28) {
                    focusBlock(dark)
                    Rectangle().fill(dark.line).frame(width: 1, height: 86)
                    summaryStats(dark)
                }
                VStack(alignment: .leading, spacing: 18) {
                    focusBlock(dark)
                    Rectangle().fill(dark.line).frame(height: 1)
                    summaryStats(dark)
                }
            }
        }
    }

    private func focusBlock(_ theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MonoLabel(text: "total focused", dot: true)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(week.focus.focusLabel)
                    .font(Typeface.display(42, weight: .semibold))
                    .tracking(-1.4)
                    .foregroundStyle(theme.ink)
                if let delta = focusDelta {
                    HStack(spacing: 2) {
                        Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 8, weight: .bold))
                        Text(abs(week.focus - previousWeek.focus).focusLabel)
                            .font(Typeface.mono(9, weight: .medium))
                    }
                    .foregroundStyle(delta >= 0 ? theme.green : theme.accent)
                }
            }
            Text("\(week.sessions.filter(\.isCompleted).count) \(week.sessions.filter(\.isCompleted).count == 1 ? "session" : "sessions") · vs previous week")
                .font(Typeface.mono(9))
                .foregroundStyle(theme.secondary)
        }
        .frame(minWidth: 210, alignment: .leading)
    }

    private func summaryStats(_ theme: AppTheme) -> some View {
        HStack(spacing: 0) {
            summaryStat(theme, "\(week.commits)", "commits")
            summaryStat(theme, "\(week.files)", "files changed")
            summaryStat(theme, "\(week.additions + week.deletions)", "lines touched")
            HStack(spacing: 6) {
                CoinMark(size: 15)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(week.coins)")
                        .font(Typeface.display(18, weight: .semibold))
                        .foregroundStyle(theme.ink)
                    Text("coins earned")
                        .font(Typeface.mono(7))
                        .textCase(.uppercase)
                        .tracking(0.7)
                        .foregroundStyle(theme.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func summaryStat(_ theme: AppTheme, _ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(Typeface.display(18, weight: .semibold))
                .foregroundStyle(theme.ink)
            Text(label)
                .font(Typeface.mono(7))
                .textCase(.uppercase)
                .tracking(0.7)
                .foregroundStyle(theme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Chart

    private var chartPanel: some View {
        Panel(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeading(label: "focus by day", title: nil,
                               detail: bestDay.map { "peak \($0.date.formatted(.dateTime.weekday(.wide))) · \($0.seconds.focusLabel)" } ?? "",
                               index: "01")
                Hairline()
                FocusChart(days: days, goalSeconds: store.dailyGoalSeconds, height: 158)
                HStack(spacing: 16) {
                    TagLabel(text: "goal \(store.profile.dailyGoalMinutes)m", icon: "target")
                    TagLabel(text: "\(week.sessions.count) \(week.sessions.count == 1 ? "session" : "sessions")", icon: "timer")
                    Spacer()
                }
            }
        }
        .frame(minWidth: 390, maxWidth: .infinity)
    }

    // MARK: Repos

    private var repoPanel: some View {
        Panel(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(label: "where it went", title: nil, index: "02")
                Hairline()
                if repoCommits.isEmpty {
                    EmptyState(glyph: "arrow.triangle.branch", title: "No commits here",
                               message: "A week without commits is still a week of thinking.")
                } else {
                    let maxCommits = max(1, repoCommits.map(\.commits).max() ?? 1)
                    VStack(spacing: 13) {
                        ForEach(repoCommits, id: \.repo.id) { entry in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Image(systemName: entry.repo.symbol)
                                        .font(.system(size: 9))
                                        .foregroundStyle(theme.secondary)
                                    Text(entry.repo.name)
                                        .font(Typeface.body(11, weight: .medium))
                                        .foregroundStyle(theme.ink)
                                    Spacer()
                                    Text("\(entry.commits)")
                                        .font(Typeface.mono(9, weight: .medium))
                                        .foregroundStyle(theme.secondary)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(theme.ink.opacity(0.07))
                                        Capsule()
                                            .fill(entry.repo.id == repoCommits.first?.repo.id ? theme.accent : theme.green.opacity(0.65))
                                            .frame(width: geo.size.width * CGFloat(entry.commits) / CGFloat(maxCommits))
                                    }
                                }
                                .frame(height: 3)
                            }
                        }
                    }
                }
                Hairline()
                KeyValue(key: "longest session", value: longestSession?.accumulatedSeconds.focusLabel ?? "—")
                KeyValue(key: "avg / session", value: week.sessions.isEmpty ? "—" : (week.focus / Double(week.sessions.count)).focusLabel)
            }
        }
        .frame(minWidth: 260, maxWidth: .infinity)
    }

    // MARK: Timeline

    private var timelinePanel: some View {
        Panel(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeading(label: "activity timeline", title: nil, index: "03")
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                Hairline()
                if timelineEvents.isEmpty {
                    EmptyState(
                        glyph: "clock.arrow.circlepath",
                        title: "A quiet week",
                        message: store.activeRepositories.isEmpty
                            ? "Add a local project folder containing a .git directory to bring sessions and commits into your reports."
                            : "No GitHub activity landed in this window. Start a session to change that.",
                        actionTitle: store.activeRepositories.isEmpty ? "Add local repository" : "Start a session",
                        action: store.activeRepositories.isEmpty
                            ? { _ = store.addLocalRepositories(at: LocalRepositoryPicker.chooseFolders()) }
                            : { store.startSession() }
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(timelineEvents.prefix(9).enumerated()), id: \.element.id) { index, event in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(event.timestamp.formatted(.dateTime.hour().minute()))
                                        .font(Typeface.mono(9, weight: .medium))
                                        .foregroundStyle(theme.ink)
                                    Text(event.timestamp.formatted(.dateTime.month(.abbreviated).day()))
                                        .font(Typeface.mono(8))
                                        .foregroundStyle(theme.secondary)
                                }
                                .frame(width: 52, alignment: .trailing)

                                VStack(spacing: 0) {
                                    Circle()
                                        .fill(event.kind == .commit ? theme.accent : theme.green)
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 3)
                                    Rectangle()
                                        .fill(theme.line)
                                        .frame(width: 1)
                                        .frame(maxHeight: .infinity)
                                }
                                .frame(width: 7)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(event.title)
                                        .font(Typeface.body(12, weight: .medium))
                                        .foregroundStyle(theme.ink)
                                        .lineLimit(1)
                                    HStack(spacing: 6) {
                                        RepoTag(repo: store.repository(withID: event.repoID))
                                        Text(event.kind.label)
                                            .font(Typeface.mono(8))
                                            .foregroundStyle(theme.secondary)
                                        if event.additions + event.deletions > 0 {
                                            Text("+\(event.additions) −\(event.deletions)")
                                                .font(Typeface.mono(8))
                                                .foregroundStyle(theme.green)
                                        }
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(minWidth: 400, maxWidth: .infinity)
    }

    // MARK: Sessions

    private var sessionPanel: some View {
        Panel(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeading(label: "session reports", title: nil, index: "04")
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                Hairline()
                let completed = week.sessions.filter(\.isCompleted).sorted { $0.startedAt > $1.startedAt }
                if completed.isEmpty {
                    EmptyState(glyph: "doc.text.magnifyingglass", title: "No reports",
                               message: "Completed sessions in this window will appear here.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(completed.enumerated()), id: \.element.id) { index, session in
                            Button {
                                expandedSession = session
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(session.startedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                            .font(Typeface.mono(9))
                                            .foregroundStyle(theme.secondary)
                                        Text(session.repoIDs.compactMap(store.repository(withID:)).map(\.name).joined(separator: " / "))
                                            .font(Typeface.body(11, weight: .medium))
                                            .foregroundStyle(theme.ink)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 3) {
                                        Text(session.accumulatedSeconds.focusLabel)
                                            .font(Typeface.mono(10, weight: .medium))
                                            .foregroundStyle(theme.ink)
                                        CoinAmount(amount: session.coinsEarned, size: 8, muted: true)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundStyle(theme.secondary)
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if index < completed.count - 1 { Hairline().padding(.leading, 18) }
                        }
                    }
                    .padding(.bottom, 6)
                }
                Hairline()
                Text("Click a session to reopen its report.")
                    .font(Typeface.mono(8))
                    .foregroundStyle(theme.secondary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
        }
        .frame(minWidth: 300, maxWidth: .infinity)
    }

    // MARK: Annotation

    private var annotationStrip: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle().fill(theme.accent).frame(width: 2, height: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(insight)
                    .font(Typeface.body(12.5, weight: .medium))
                    .foregroundStyle(theme.ink)
                Text("PILCROW / WEEKLY NOTE / \(dateRange.uppercased())")
                    .font(Typeface.mono(8))
                    .tracking(0.9)
                    .foregroundStyle(theme.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var insight: String {
        if week.sessions.isEmpty { return "A quiet week. Rest counts too — come back when the clock feels right." }
        if let bestDay, bestDay.seconds > 0 {
            return "Your best stretch was \(bestDay.date.formatted(.dateTime.weekday(.wide))), \(bestDay.seconds.focusLabel). \(bestDay.commits) commits landed that day."
        }
        return "\(week.sessions.count) sessions logged. The work is in the log, even when it felt small."
    }
}
