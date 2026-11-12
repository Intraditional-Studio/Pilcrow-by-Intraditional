import SwiftUI

struct SessionsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.theme) private var theme
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable, Identifiable {
        case all, week
        var id: String { rawValue }
        var title: String { self == .all ? "All time" : "This week" }
    }

    private var visibleSessions: [Session] {
        let base = store.sessions.sorted { $0.startedAt > $1.startedAt }
        guard filter == .week else { return base }
        let weekDays = store.days()
        return base.filter { session in weekDays.contains { $0.date.isSameDay(as: session.startedAt) } }
    }

    private var groups: [(Date, [Session])] {
        let grouped = Dictionary(grouping: visibleSessions) { $0.startedAt.startOfDay() }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0]?.sorted { $0.startedAt > $1.startedAt } ?? []) }
    }

    private var average: TimeInterval {
        let completed = store.completedSessions
        guard !completed.isEmpty else { return 0 }
        return completed.reduce(0) { $0 + $1.accumulatedSeconds } / Double(completed.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    kicker: "SECTION 02 / TIMELOG",
                    title: "Sessions",
                    subtitle: "Start with intent. End with a receipt. Small, honest blocks of work."
                ) {
                    HStack(spacing: 8) {
                        StatusTag(text: store.activeSession == nil ? "clock idle" : "clock running",
                                  color: store.activeSession == nil ? theme.secondary : theme.accent)
                        CoinAmount(amount: store.profile.coins, size: 11)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
                    }
                    .padding(.top, 14)
                }
                .reveal()

                SessionControlCard()
                    .reveal(delay: 0.04)

                HStack(spacing: 12) {
                    StatTile(label: "total focus", value: store.totalFocus.focusLabel, detail: "\(store.completedSessions.count) completed", icon: "clock")
                    StatTile(label: "average", value: average.focusLabel, detail: "per session", icon: "chart.line.uptrend.xyaxis")
                    StatTile(label: "commits", value: "\(store.totalCommits)", detail: "tracked in sessions", icon: "arrow.triangle.branch", accent: true)
                    StatTile(label: "earned", value: "\(store.completedSessions.reduce(0) { $0 + $1.coinsEarned })", detail: "coins from focus", icon: "circle.hexagongrid")
                }
                .reveal(delay: 0.08)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        SectionHeading(label: "the log", title: nil, index: "04")
                        Spacer()
                        HStack(spacing: 0) {
                            ForEach(Filter.allCases) { item in
                                Button {
                                    withAnimation(.easeOut(duration: 0.15)) { filter = item }
                                } label: {
                                    Text(item.title)
                                        .font(Typeface.body(10.5, weight: .medium))
                                        .foregroundStyle(filter == item ? theme.background : theme.secondary)
                                        .padding(.horizontal, 10)
                                        .frame(height: 26)
                                        .background(filter == item ? theme.ink : .clear)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(theme.raised.opacity(0.5))
                        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    }

                    Panel(padding: 0) {
                        if groups.isEmpty {                            EmptyState(
                                glyph: "timer",
                                title: filter == .week ? "Nothing this week, yet" : "The clock is waiting",
                                message: filter == .week
                                    ? "Switch to all time to see older sessions, or start a fresh one above."
                                    : store.activeRepositories.isEmpty
                                        ? "Add a local project folder containing a .git directory, then start your first session."
                                        : "Start your first session and it will show up here with its report.",
                                actionTitle: store.activeRepositories.isEmpty ? "Add local repository" : (store.activeSession == nil ? "Start a session" : nil),
                                action: store.activeRepositories.isEmpty
                                    ? { _ = store.addLocalRepositories(at: LocalRepositoryPicker.chooseFolders()) }
                                    : (store.activeSession == nil ? { store.startSession() } : nil)
                            )
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(groups.enumerated()), id: \.offset) { groupIndex, group in
                                    VStack(spacing: 0) {
                                        HStack(spacing: 8) {
                                            Text(dayLabel(group.0))
                                                .font(Typeface.mono(9, weight: .medium))
                                                .tracking(1)
                                                .foregroundStyle(theme.secondary)
                                            Rectangle().fill(theme.line).frame(height: 1)
                                            if group.1.contains(where: { !$0.isCompleted }) {
                                                StatusTag(text: "live", color: theme.accent)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.top, groupIndex == 0 ? 14 : 18)
                                        .padding(.bottom, 4)

                                        ForEach(Array(group.1.enumerated()), id: \.element.id) { index, session in
                                            SessionRow(
                                                session: session,
                                                repositories: store.repositories,
                                                action: session.isCompleted ? {
                                                    store.reportSession = session
                                                } : nil
                                            )
                                            if index < group.1.count - 1 {
                                                Hairline().padding(.leading, 16)
                                            }
                                        }
                                    }
                                    if groupIndex < groups.count - 1 {
                                        Hairline()
                                    }
                                }
                            }
                            .padding(.bottom, 6)
                        }
                    }
                }
                .reveal(delay: 0.12)

                Text("Sessions shorter than 90 seconds are logged without fabricated GitHub activity.")
                    .font(Typeface.mono(8))
                    .foregroundStyle(theme.secondary.opacity(0.75))
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .frame(maxWidth: 1180)
            .frame(maxWidth: .infinity)
        }
    }

    private func dayLabel(_ date: Date) -> String {
        if date.isSameDay(as: Date()) { return "TODAY" }
        if date.isSameDay(as: Date().adding(days: -1)) { return "YESTERDAY" }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).uppercased()
    }
}
