import SwiftUI
import AppKit

// MARK: - Quests

struct QuestsPanel: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.theme) private var theme

    var body: some View {
        Panel(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    SectionHeading(label: "the brief", title: nil, index: "04")
                    Spacer()
                    Text("\(store.completedQuestCount) / \(QuestCatalog.all.count) claimed")
                        .font(Typeface.mono(8))
                        .foregroundStyle(theme.secondary)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Hairline()

                VStack(spacing: 0) {
                    questGroup(.daily)
                    Hairline().padding(.leading, 18)
                    questGroup(.weekly)
                }

                Hairline()

                HStack(spacing: 10) {
                    Image(systemName: "snowflake")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Streak freezes · \(store.streakFreezes) of \(StreakFreeze.maximum)")
                            .font(Typeface.body(10.5, weight: .medium))
                            .foregroundStyle(theme.ink)
                        Text("Covers one missed day automatically.")
                            .font(Typeface.mono(7.5))
                            .foregroundStyle(theme.secondary)
                    }
                    Spacer(minLength: 8)
                    Button {
                        store.buyStreakFreeze()
                    } label: {
                        HStack(spacing: 4) {
                            CoinMark(size: 10)
                            Text("\(StreakFreeze.price)")
                                .font(Typeface.mono(8.5, weight: .medium))
                            Text("BUY")
                                .font(Typeface.mono(8, weight: .medium))
                                .tracking(0.8)
                        }
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 8)
                        .frame(height: 25)
                        .overlay(Rectangle().strokeBorder(theme.accent.opacity(0.35), lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(store.streakFreezes >= StreakFreeze.maximum)
                    .opacity(store.streakFreezes >= StreakFreeze.maximum ? 0.4 : 1)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
            }
        }
        .frame(minWidth: 390, maxWidth: .infinity)
    }

    private func questGroup(_ period: QuestPeriod) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Text(period.title.uppercased())
                    .font(Typeface.mono(7.5, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(theme.secondary)
                Rectangle().fill(theme.line).frame(height: 1)
            }
            ForEach(QuestCatalog.quests(for: period)) { quest in
                QuestRow(quest: quest)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }
}

struct QuestRow: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.theme) private var theme
    var quest: Quest

    private var progress: (current: Int, goal: Int) { store.questProgress(quest) }
    private var claimed: Bool { store.isQuestClaimed(quest) }
    private var complete: Bool { progress.current >= progress.goal }

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(claimed ? theme.green.opacity(0.12) : theme.raised.opacity(0.5))
                    .frame(width: 26, height: 26)
                Image(systemName: claimed ? "checkmark" : quest.glyph)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(claimed ? theme.green : (complete ? theme.accent : theme.secondary))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(quest.title)
                        .font(Typeface.body(11, weight: .medium))
                        .foregroundStyle(claimed ? theme.secondary : theme.ink)
                        .lineLimit(1)
                    if claimed {
                        Text("CLAIMED")
                            .font(Typeface.mono(6.5, weight: .medium))
                            .tracking(0.7)
                            .foregroundStyle(theme.green)
                    }
                }
                Text(quest.detail)
                    .font(Typeface.mono(7.5))
                    .foregroundStyle(theme.secondary)
                    .lineLimit(1)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.ink.opacity(0.07))
                        Capsule()
                            .fill(claimed ? theme.green : theme.accent)
                            .frame(width: max(3, geo.size.width * CGFloat(progress.current) / CGFloat(max(1, progress.goal))))
                    }
                }
                .frame(height: 2)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    CoinMark(size: 8)
                    Text("\(quest.rewardCoins)")
                        .font(Typeface.mono(8.5, weight: .medium))
                        .foregroundStyle(theme.ink)
                }
                Text("\(progress.current)/\(progress.goal)")
                    .font(Typeface.mono(7.5))
                    .foregroundStyle(theme.secondary)
            }
        }
    }
}

// MARK: - Daily strip

struct DailyStripPanel: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.theme) private var theme
    @State private var copied = false

    private var intents: [String] {
        store.todaySessions.map(\.intent).filter { !$0.isEmpty }
    }

    private var tags: [String] {
        Set(store.todaySessions.flatMap(\.tags)).sorted()
    }

    var body: some View {
        DarkPanel(padding: 18) { dark in
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    MonoLabel(text: "daily strip", dot: true)
                    Spacer()
                    Text(Date().formatted(.dateTime.month(.abbreviated).day()).uppercased())
                        .font(Typeface.mono(8))
                        .tracking(1)
                        .foregroundStyle(dark.secondary)
                }

                Text(store.todayFocus > 0 ? store.todayFocus.focusLabel : "A fresh page.")
                    .font(Typeface.display(26, weight: .semibold))
                    .tracking(-0.8)
                    .foregroundStyle(dark.ink)

                HStack(spacing: 0) {
                    receiptStat(dark, "\(store.todaySessions.filter(\.isCompleted).count)", "sessions")
                    Rectangle().fill(dark.line).frame(width: 1, height: 26)
                    receiptStat(dark, "\(store.todayCommits)", "commits")
                    Rectangle().fill(dark.line).frame(width: 1, height: 26)
                    HStack(spacing: 5) {
                        CoinMark(size: 12)
                        Text("\(store.todayCoins)")
                            .font(Typeface.mono(11, weight: .medium))
                            .foregroundStyle(dark.ink)
                    }
                    .frame(maxWidth: .infinity)
                }

                if !intents.isEmpty || !tags.isEmpty {
                    Hairline()
                    VStack(alignment: .leading, spacing: 4) {
                        if let first = intents.first {
                            Text(first)
                                .font(Typeface.body(10.5))
                                .foregroundStyle(dark.ink.opacity(0.85))
                                .lineLimit(2)
                        }
                        if !tags.isEmpty {
                            Text(tags.map { "#\($0)" }.joined(separator: "  "))
                                .font(Typeface.mono(7.5))
                                .foregroundStyle(dark.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Hairline()

                HStack(spacing: 8) {
                    Button {
                        store.copyDailyStrip()
                        withAnimation(.easeOut(duration: 0.15)) { copied = true }
                        Task {
                            try? await Task.sleep(nanoseconds: 1_600_000_000)
                            withAnimation(.easeOut(duration: 0.2)) { copied = false }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 8, weight: .semibold))
                            Text(copied ? "Copied" : "Copy strip")
                                .font(Typeface.mono(8, weight: .medium))
                                .tracking(0.7)
                                .textCase(.uppercase)
                        }
                        .foregroundStyle(copied ? dark.green : dark.ink)
                        .padding(.horizontal, 8)
                        .frame(height: 26)
                        .overlay(Rectangle().strokeBorder(dark.line, lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())
                    Spacer()
                    if store.settings.menuBarTimer {
                        TagLabel(text: "menu bar on", icon: "menubar.rectangle")
                            .environment(\.theme, dark)
                    }
                }
            }
        }
        .frame(width: 296)
    }

    private func receiptStat(_ dark: AppTheme, _ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Typeface.display(15, weight: .semibold))
                .foregroundStyle(dark.ink)
            Text(label)
                .font(Typeface.mono(7))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(dark.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Reusable freeze control

struct StreakFreezeControl: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "snowflake")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("STREAK FREEZES")
                    .font(Typeface.mono(7))
                    .tracking(0.8)
                    .foregroundStyle(theme.secondary)
                Text("\(store.streakFreezes) of \(StreakFreeze.maximum) banked")
                    .font(Typeface.body(10.5, weight: .medium))
                    .foregroundStyle(theme.ink)
            }
            Spacer(minLength: 4)
            Button {
                store.buyStreakFreeze()
            } label: {
                HStack(spacing: 3) {
                    CoinMark(size: 9)
                    Text("\(StreakFreeze.price)")
                        .font(Typeface.mono(8, weight: .medium))
                }
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 7)
                .frame(height: 24)
                .overlay(Rectangle().strokeBorder(theme.accent.opacity(0.32), lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(store.streakFreezes >= StreakFreeze.maximum)
            .opacity(store.streakFreezes >= StreakFreeze.maximum ? 0.4 : 1)
        }
    }
}
