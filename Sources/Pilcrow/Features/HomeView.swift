import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.theme) private var theme
    @Binding var selection: AppSection

    private var greeting: String {
        "\(Date().greetingPart), \(store.profile.name)."
    }

    private var subtitle: String {
        if store.todayFocus <= 0 {
            return "A fresh page. Start a session and make the day count."
        }
        if store.dailyProgress >= 1 {
            return "Daily goal cleared. Everything after this is a bonus."
        }
        let remaining = max(0, store.profile.dailyGoalMinutes - Int(store.todayFocus / 60))
        return "\(store.todayFocus.focusLabel) logged today. \(remaining) focused minutes to hit your goal."
    }

    private var bestDay: DayFocus? {
        guard let best = store.days().max(by: { $0.seconds < $1.seconds }), best.seconds > 0 else { return nil }
        return best
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    kicker: "SECTION 01 / \(Date().formatted(.dateTime.weekday(.wide)).uppercased()) \(Date().formatted(.dateTime.month(.abbreviated).day()).uppercased())",
                    title: greeting,
                    subtitle: subtitle
                ) {
                    VStack(alignment: .trailing, spacing: 8) {
                        HStack(spacing: 10) {
                            Button {
                                store.openGitHubConnection()
                            } label: {
                                StatusTag(text: store.githubStatusLabel,
                                          color: store.isGitHubConnected ? theme.green : theme.accent)
                            }
                            .buttonStyle(.plain)
                            .help("Manage GitHub connection")
                            if !store.isGitHubConnected {
                                Button {
                                    store.openGitHubConnection()
                                } label: {
                                    HStack(spacing: 3) {
                                        Text("Connect")
                                            .font(Typeface.mono(8, weight: .medium))
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 7, weight: .semibold))
                                    }
                                    .foregroundStyle(theme.accent)
                                }
                                .buttonStyle(.plain)
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(theme.accent)
                                Text("\(store.profile.streak) \(store.profile.streak == 1 ? "day" : "days") streak")
                                    .font(Typeface.mono(9, weight: .medium))
                                    .foregroundStyle(theme.secondary)
                            }
                        }
                        Text("\(store.profile.coins) coins · Lv \(store.level.level)")
                            .font(Typeface.mono(9))
                            .foregroundStyle(theme.secondary)
                    }
                    .padding(.top, 14)
                }
                .reveal()

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        SessionControlCard()
                            .frame(minWidth: 440, maxWidth: .infinity)
                        todayPanel.frame(width: 296)
                    }
                    VStack(spacing: 16) {
                        SessionControlCard()
                        todayPanel
                    }
                }
                .reveal(delay: 0.04)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        weekPanel
                        rewardPanel.frame(width: 296)
                    }
                    VStack(spacing: 16) {
                        weekPanel
                        rewardPanel
                    }
                }
                .reveal(delay: 0.08)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        QuestsPanel()
                        DailyStripPanel()
                    }
                    VStack(spacing: 16) {
                        QuestsPanel()
                        DailyStripPanel()
                    }
                }
                .reveal(delay: 0.10)

                activityPanel
                    .reveal(delay: 0.12)

                HStack(spacing: 6) {
                    Rectangle().fill(theme.accent).frame(width: 18, height: 1)
                    Text("Made carefully. Small tools, long sessions.")
                        .font(Typeface.mono(8))
                        .tracking(0.8)
                        .foregroundStyle(theme.secondary)
                    Spacer()
                    Text("REV \(store.level.level).\(store.profile.streak) / 2026")
                        .font(Typeface.mono(8))
                        .tracking(0.8)
                        .foregroundStyle(theme.secondary.opacity(0.6))
                }
                .padding(.top, 2)
                .padding(.bottom, 10)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .frame(maxWidth: 1180)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Today

    private var todayPanel: some View {
        DarkPanel(padding: 18) { dark in
            TimelineView(.periodic(from: .now, by: 5)) { _ in
                todayPanelContent(dark)
            }
        }
    }

    private func todayPanelContent(_ theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                MonoLabel(text: "today", dot: true)
                Spacer()
                Text(Date().formatted(.dateTime.month(.abbreviated).day()).uppercased())
                    .font(Typeface.mono(8))
                    .tracking(1)
                    .foregroundStyle(theme.secondary)
            }

            HStack(spacing: 14) {
                GoalRing(progress: store.dailyProgress, size: 76, lineWidth: 6) {
                    VStack(spacing: 0) {
                        Text("\(Int(store.todayFocus / 60))")
                            .font(Typeface.display(20, weight: .semibold))
                            .foregroundStyle(theme.ink)
                        Text("min")
                            .font(Typeface.mono(7))
                            .foregroundStyle(theme.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.todayFocus > 0 ? store.todayFocus.focusLabel : "0m")
                        .font(Typeface.display(22, weight: .semibold))
                        .tracking(-0.6)
                        .foregroundStyle(theme.ink)
                    Text("of \(store.profile.dailyGoalMinutes)m goal")
                        .font(Typeface.mono(8))
                        .foregroundStyle(theme.secondary)
                    if store.dailyProgress >= 1 {
                        Text("Goal met")
                            .font(Typeface.mono(8, weight: .medium))
                            .foregroundStyle(theme.green)
                    }
                }
                Spacer(minLength: 0)
            }

            Hairline()

            HStack(spacing: 0) {
                miniStat(theme, value: "\(store.todaySessions.count)", label: "sessions")
                Rectangle().fill(theme.line).frame(width: 1, height: 26)
                miniStat(theme, value: "\(store.todayCommits)", label: "commits")
                Rectangle().fill(theme.line).frame(width: 1, height: 26)
                HStack(spacing: 5) {
                    CoinMark(size: 13)
                    Text("\(store.todayCoins)")
                        .font(Typeface.mono(12, weight: .medium))
                        .foregroundStyle(theme.ink)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    private func miniStat(_ theme: AppTheme, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Typeface.display(15, weight: .semibold))
                .foregroundStyle(theme.ink)
            Text(label)
                .font(Typeface.mono(7))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(theme.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Week

    private var weekPanel: some View {
        let week = store.week()
        return Panel(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeading(
                    label: "this week",
                    title: week.focus > 0 ? "\(week.focus.focusLabel) of quiet work" : "The week is still a blank page",
                    detail: bestDay.map { "best: \($0.date.formatted(.dateTime.weekday(.abbreviated))) · \($0.seconds.focusLabel)" } ?? "",
                    index: "02"
                )
                Hairline()
                FocusChart(days: store.days(), goalSeconds: store.dailyGoalSeconds, height: 118)
                HStack(spacing: 18) {
                    footerStat("\(week.sessions.count)", week.sessions.count == 1 ? "session" : "sessions")
                    footerStat("\(week.commits)", week.commits == 1 ? "commit" : "commits")
                    footerStat("\(week.files)", week.files == 1 ? "file" : "files")
                    Spacer()
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { selection = .reports }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Full report")
                                .font(Typeface.body(11, weight: .medium))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(minWidth: 390, maxWidth: .infinity)
    }

    private var activityEmptyMessage: String {
        if store.activeRepositories.isEmpty {
            return "Add a project folder containing a .git directory to start tracking."
        }
        if !store.isGitHubConnected {
            return "Connect GitHub to read commits from your local repositories."
        }
        return "Commit something and sync GitHub. We'll keep the receipts."
    }

    private var activityEmptyActionTitle: String {
        if store.activeRepositories.isEmpty { return "Add local repository" }
        if !store.isGitHubConnected { return "Connect GitHub" }
        return "Sync now"
    }

    private var activityEmptyAction: () -> Void {
        if store.activeRepositories.isEmpty {
            return { _ = store.addLocalRepositories(at: LocalRepositoryPicker.chooseFolders()) }
        }
        if !store.isGitHubConnected {
            return { store.openGitHubConnection() }
        }
        return { store.syncGitHub() }
    }

    private func footerStat(_ value: String, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(Typeface.mono(12, weight: .medium))
                .foregroundStyle(theme.ink)
            Text(label)
                .font(Typeface.mono(8))
                .foregroundStyle(theme.secondary)
        }
    }

    // MARK: Reward teaser

    private var rewardItem: ShopItem? {
        let unowned = ShopItem.all.filter { !store.owns($0) && $0.price > 0 }
        return unowned.filter { $0.price <= store.profile.coins }.max { $0.price < $1.price }
            ?? unowned.min { $0.price < $1.price }
    }

    private var rewardPanel: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { selection = .shop }
        } label: {
            Panel(padding: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        MonoLabel(text: "next reward", dot: true)
                        Spacer()
                        CoinAmount(amount: store.profile.coins, size: 9, muted: true)
                    }
                    if let item = rewardItem {
                        HStack(alignment: .center, spacing: 14) {
                            ShopPreview(item: item, size: 66)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(Typeface.display(18, weight: .medium))
                                    .foregroundStyle(theme.ink)
                                Text(item.tagline)
                                    .font(Typeface.body(10.5))
                                    .foregroundStyle(theme.secondary)
                                    .lineLimit(2)
                                HStack(spacing: 5) {
                                    CoinMark(size: 11)
                                    Text("\(item.price)")
                                        .font(Typeface.mono(10, weight: .medium))
                                        .foregroundStyle(theme.ink)
                                    Text(item.price <= store.profile.coins ? "· ready" : "· \(item.price - store.profile.coins) to go")
                                        .font(Typeface.mono(8))
                                        .foregroundStyle(item.price <= store.profile.coins ? theme.green : theme.secondary)
                                }
                                .padding(.top, 2)
                            }
                            Spacer(minLength: 0)
                        }
                    } else {
                        Text("You own the whole shop. Rare behaviour.")
                            .font(Typeface.body(12))
                            .foregroundStyle(theme.secondary)
                    }
                    Hairline()
                    HStack {
                        Text("The shop")
                            .font(Typeface.body(10.5, weight: .medium))
                            .foregroundStyle(theme.secondary)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(theme.accent)
                    }
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: Activity

    private var activityPanel: some View {
        Panel(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    SectionHeading(label: "recent activity", title: nil, index: "05")
                    Spacer()
                    StatusTag(text: store.lastSyncedAt.map { "synced \($0.relativeLabel)" } ?? "not synced")
                    GFIconButton(icon: "arrow.triangle.2.circlepath", label: "Sync GitHub") {
                        store.syncGitHub()
                    }
                    .rotationEffect(.degrees(store.isSyncing ? 360 : 0))
                    .animation(store.isSyncing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: store.isSyncing)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Hairline()

                let events = Array(store.recentActivity.prefix(5))
                if events.isEmpty {
                    EmptyState(
                        glyph: store.activeRepositories.isEmpty ? "folder.badge.plus" : "arrow.triangle.branch",
                        title: store.activeRepositories.isEmpty ? "No local repositories" : "No activity yet",
                        message: activityEmptyMessage,
                        actionTitle: activityEmptyActionTitle,
                        action: activityEmptyAction
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            ActivityRow(event: event, repo: store.repository(withID: event.repoID))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                            if index < events.count - 1 {
                                Hairline().padding(.leading, 57)
                            }
                        }
                    }
                }

                Hairline()
                HStack {
                    Text(store.activitySourceLabel)
                        .font(Typeface.mono(8))
                        .foregroundStyle(theme.secondary)
                    Spacer()
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { selection = .sessions }
                    } label: {
                        HStack(spacing: 4) {
                            Text("All sessions")
                                .font(Typeface.body(10.5, weight: .medium))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
            }
        }
    }
}
