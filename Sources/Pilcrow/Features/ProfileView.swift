import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.theme) private var theme
    @Environment(\.openSettings) private var openSettings
    @Binding var selection: AppSection
    @State private var editing = false
    @State private var confirmingReset = false

    private var contributionDays: [ContributionDay] {
        let calendar = Calendar.current
        let today = Date().startOfDay()
        var monday = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        monday.weekday = 2
        let weekStart = calendar.date(from: monday) ?? today
        let start = calendar.date(byAdding: .day, value: -13 * 7, to: weekStart) ?? today
        var result: [ContributionDay] = []
        var day = start
        while day.timeIntervalSince(today) <= 0 {
            result.append(ContributionDay(date: day, seconds: store.focusSeconds(on: day)))
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? today.adding(days: 1)
        }
        return result
    }

    private var activeDays: Int {
        contributionDays.filter { $0.seconds > 0 }.count
    }

    private var recentFocus: TimeInterval {
        contributionDays.reduce(0) { $0 + $1.seconds }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    kicker: "SECTION 05 / OPERATOR",
                    title: "Profile",
                    subtitle: "A record of time spent on purpose. Customize the desk, not the work."
                ) {
                    HStack(spacing: 8) {
                        GFIconButton(icon: "gearshape", label: "Settings") {
                            openSettings()
                        }
                        GFButton("Edit profile", icon: "pencil", kind: .outline, compact: true) {
                            editing = true
                        }
                        GFButton("Shop", icon: "bag", kind: .dark, compact: true) {
                            withAnimation(.easeOut(duration: 0.15)) { selection = .shop }
                        }
                    }
                    .padding(.top, 14)
                }
                .reveal()

                identityCard
                    .reveal(delay: 0.04)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        shelfPanel
                        wearingPanel.frame(width: 330)
                    }
                    VStack(spacing: 16) {
                        shelfPanel
                        wearingPanel
                    }
                }
                .reveal(delay: 0.08)

                achievementsPanel
                    .reveal(delay: 0.12)

                contributionPanel
                    .reveal(delay: 0.16)

                HStack(spacing: 12) {
                    Text("Your data lives in ~/Library/Application Support/Pilcrow. No account, no upload.")
                        .font(Typeface.mono(8))
                        .foregroundStyle(theme.secondary.opacity(0.7))
                    Spacer()
                    Button("Start over") {
                        confirmingReset = true
                    }
                    .buttonStyle(.plain)
                    .font(Typeface.mono(8, weight: .medium))
                    .foregroundStyle(theme.accent)
                }
                .padding(.bottom, 14)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .frame(maxWidth: 1180)
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $editing) {
            ProfileEditSheet()
                .environmentObject(store)
                .environment(\.theme, store.theme)
                .preferredColorScheme(store.theme.isDark ? .dark : .light)
        }
        .confirmationDialog("Start over with a clean ledger?", isPresented: $confirmingReset) {
            Button("Reset everything", role: .destructive) {
                store.startOver()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Coins, sessions, achievements, and purchased cosmetics are cleared. Your GitHub connection stays. Setup will reopen.")
        }
    }

    // MARK: Identity

    private var identityCard: some View {
        Panel(padding: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 24) {
                    identityLeft
                    Spacer(minLength: 16)
                    levelBlock.frame(width: 300)
                }
                VStack(alignment: .leading, spacing: 20) {
                    identityLeft
                    Hairline()
                    levelBlock
                }
            }
            .padding(24)
            .background(alignment: .topLeading) {
                HStack(spacing: 0) {
                    Rectangle().fill(theme.accent).frame(width: 3)
                    Spacer()
                }
            }
        }
    }

    private var identityLeft: some View {
        HStack(alignment: .center, spacing: 18) {
            AvatarView(item: store.equippedAvatar, size: 88, showStatus: true)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(store.profile.name)
                        .font(Typeface.display(34, weight: .semibold))
                        .tracking(-1)
                        .foregroundStyle(theme.ink)
                    if let badge = store.equippedBadge {
                        BadgeView(item: badge)
                    }
                }
                Text("@\(store.profile.handle)")
                    .font(Typeface.mono(10))
                    .foregroundStyle(theme.secondary)
                Text(store.profile.bio.isEmpty ? "No bio yet. A mystery." : store.profile.bio)
                    .font(Typeface.body(12.5))
                    .foregroundStyle(theme.secondary)
                    .lineLimit(2)
                HStack(spacing: 10) {
                    StatusTag(text: "member since \(store.profile.joinedAt.formatted(.dateTime.month(.abbreviated).year()))")
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.accent)
                        Text("\(store.profile.streak) \(store.profile.streak == 1 ? "day" : "days") streak")
                            .font(Typeface.mono(8))
                            .foregroundStyle(theme.secondary)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private var levelBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%02d", store.level.level))
                    .font(Typeface.display(36, weight: .semibold))
                    .tracking(-1.2)
                    .foregroundStyle(theme.ink)
                VStack(alignment: .leading, spacing: 1) {
                    Text("LEVEL")
                        .font(Typeface.mono(7, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(theme.secondary)
                    Text(store.rank)
                        .font(Typeface.body(11, weight: .medium))
                        .foregroundStyle(theme.ink)
                }
                Spacer()
                Text("\(store.nextLevelXP) XP to go")
                    .font(Typeface.mono(9))
                    .foregroundStyle(theme.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.ink.opacity(0.09))
                    Capsule()
                        .fill(theme.accent)
                        .frame(width: max(6, geo.size.width * store.level.progress))
                }
            }
            .frame(height: 5)

            HStack(spacing: 0) {
                profileStat("\(store.completedSessions.count)", "sessions")
                profileStat("\(store.totalCommits)", "commits")
                profileStat("\(store.profile.coins)", "coins")
                profileStat(store.totalFocus.focusLabel, "focused")
            }
        }
    }

    private func profileStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Typeface.mono(12, weight: .medium))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
            Text(label)
                .font(Typeface.mono(7))
                .textCase(.uppercase)
                .tracking(0.7)
                .foregroundStyle(theme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Shelf

    private var shelfPanel: some View {
        Panel(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SectionHeading(label: "on the shelf", title: nil, index: "01")
                    Spacer()
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { selection = .shop }
                    } label: {
                        Text("Edit shelf")
                            .font(Typeface.body(10.5, weight: .medium))
                            .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                }
                Hairline()

                HStack(alignment: .bottom, spacing: 18) {
                    ForEach(0..<3) { index in
                        if index < store.equippedDecor.count {
                            let item = store.equippedDecor[index]
                            VStack(spacing: 5) {
                                Image(systemName: item.payload)
                                    .font(.system(size: index == 1 ? 34 : 28, weight: .light))
                                    .foregroundStyle(index == 1 ? theme.accent : theme.ink.opacity(0.8))
                                    .frame(height: 42, alignment: .bottom)
                                Text(item.name)
                                    .font(Typeface.mono(8))
                                    .foregroundStyle(theme.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Button {
                                withAnimation(.easeOut(duration: 0.15)) { selection = .shop }
                            } label: {
                                VStack(spacing: 5) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 13, weight: .light))
                                        .foregroundStyle(theme.secondary)
                                        .frame(height: 42)
                                    Text("empty")
                                        .font(Typeface.mono(8))
                                        .foregroundStyle(theme.secondary.opacity(0.7))
                                }
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 64)

                VStack(spacing: 3) {
                    Rectangle().fill(theme.ink.opacity(0.55)).frame(height: 1.5)
                    Rectangle().fill(theme.ink.opacity(0.15)).frame(height: 4)
                }

                Text(store.equippedDecor.isEmpty
                     ? "A shelf is a promise to buy one small, useless, perfect thing."
                     : "\(store.equippedDecor.count) of 3 spots filled. Replace or add from the shop.")
                    .font(Typeface.body(11))
                    .foregroundStyle(theme.secondary)
                    .padding(.top, 2)
            }
        }
        .frame(minWidth: 360, maxWidth: .infinity)
    }

    // MARK: Wearing / rhythm

    private var wearingPanel: some View {
        Panel(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(label: "wearing", title: nil, index: "02")
                Hairline()

                themeRow
                loadoutRow(category: "Avatar", item: store.equippedAvatar, kind: .avatars)
                loadoutRow(category: "Badge", item: store.equippedBadge, kind: .badges)

                Hairline()

                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        MonoLabel(text: "daily rhythm")
                        Spacer()
                        Text("\(store.profile.dailyGoalMinutes) min")
                            .font(Typeface.mono(9, weight: .medium))
                            .foregroundStyle(theme.ink)
                    }
                    HStack(spacing: 6) {
                        ForEach([60, 90, 120, 180], id: \.self) { minutes in
                            Button {
                                withAnimation(.easeOut(duration: 0.15)) { store.updateGoal(minutes) }
                            } label: {
                                Text("\(minutes)")
                                    .font(Typeface.mono(9, weight: .medium))
                                    .foregroundStyle(store.profile.dailyGoalMinutes == minutes ? theme.background : theme.secondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 26)
                                    .background(store.profile.dailyGoalMinutes == minutes ? theme.ink : theme.raised.opacity(0.4))
                                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 2))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                    Text("A goal you can actually keep. Adjust it any time.")
                        .font(Typeface.body(10))
                        .foregroundStyle(theme.secondary)
                }
            }
        }
        .frame(minWidth: 280, maxWidth: .infinity)
    }

    private var themeRow: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { selection = .shop }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.raised.opacity(0.5))
                        .frame(width: 36, height: 32)
                    themeSwatch(store.theme)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("THEME")
                        .font(Typeface.mono(7))
                        .tracking(0.8)
                        .foregroundStyle(theme.secondary)
                    Text(store.themeDisplayName)
                        .font(Typeface.body(11, weight: .medium))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(theme.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func loadoutRow(category: String, item: ShopItem?, kind: ShopCategory) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { selection = .shop }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.raised.opacity(0.5))
                        .frame(width: 36, height: 32)
                    if let item {
                        ShopPreview(item: item, size: 26)
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "minus")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(category)
                        .font(Typeface.mono(7))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(theme.secondary)
                    Text(item?.name ?? "Nothing on")
                        .font(Typeface.body(11, weight: .medium))
                        .foregroundStyle(theme.ink)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(theme.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func themeSwatch(_ swatch: AppTheme) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(swatch.background)
            .frame(width: 28, height: 22)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(swatch.raised)
                    .frame(width: 7)
            }
            .overlay(alignment: .topLeading) {
                Rectangle()
                    .fill(swatch.accent)
                    .frame(width: 7, height: 2)
                    .padding(4)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(swatch.ink.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    // MARK: Achievements

    private var achievementsPanel: some View {
        Panel(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    SectionHeading(label: "achievements", title: nil, index: "03")
                    Spacer()
                    Text("\(store.achievementDates.count) / \(AchievementCatalog.all.count) unlocked")
                        .font(Typeface.mono(9))
                        .foregroundStyle(theme.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)
                Hairline()

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 0)], spacing: 0) {
                    ForEach(AchievementCatalog.all) { achievement in
                        AchievementCell(achievement: achievement)
                    }
                }
                .padding(.bottom, 6)
            }
        }
    }

    // MARK: Contribution

    private var contributionPanel: some View {
        Panel(padding: 20) {
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(label: "the long view", title: "A season of small sessions", index: "04")
                    ContributionGrid(days: contributionDays)
                }
                Spacer(minLength: 12)
                VStack(alignment: .leading, spacing: 10) {
                    KeyValue(key: "active days", value: "\(activeDays)")
                    KeyValue(key: "focus, 14 weeks", value: recentFocus.focusLabel)
                    KeyValue(key: "longest streak", value: "\(store.profile.longestStreak) days")
                    Hairline()
                    StreakFreezeControl()
                    Hairline()
                    HStack(spacing: 5) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.green)
                        Text("Slow and steady is a strategy.")
                            .font(Typeface.body(10))
                            .foregroundStyle(theme.secondary)
                    }
                }
                .frame(width: 190)
            }
        }
    }
}

// MARK: - Achievement cell

struct AchievementCell: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.theme) private var theme
    var achievement: Achievement

    private var unlocked: Bool { store.isUnlocked(achievement) }
    private var progress: (value: Int, label: String) { store.progress(for: achievement) }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(unlocked ? theme.accent.opacity(0.12) : theme.raised.opacity(0.5))
                    .frame(width: 34, height: 34)
                Image(systemName: achievement.glyph)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(unlocked ? theme.accent : theme.secondary.opacity(0.65))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(achievement.title)
                        .font(Typeface.body(12, weight: .semibold))
                        .foregroundStyle(unlocked ? theme.ink : theme.secondary)
                    if unlocked {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.green)
                    }
                }
                Text(achievement.detail)
                    .font(Typeface.body(10))
                    .foregroundStyle(theme.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if unlocked {
                    Text("Unlocked \(store.achievementDates[achievement.id]?.formatted(.dateTime.month(.abbreviated).day()) ?? "")")
                        .font(Typeface.mono(7))
                        .foregroundStyle(theme.green)
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(theme.ink.opacity(0.08))
                                Capsule().fill(theme.accent.opacity(0.6))
                                    .frame(width: max(2, geo.size.width * min(1, Double(progress.value) / Double(max(1, achievement.goal)))))
                            }
                        }
                        .frame(height: 2)
                        Text(progress.label)
                            .font(Typeface.mono(7))
                            .foregroundStyle(theme.secondary.opacity(0.85))
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.line).frame(height: 1).padding(.leading, 65)
        }
        .opacity(unlocked ? 1 : 0.82)
    }
}

// MARK: - Edit profile

struct ProfileEditSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var bio = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    MonoLabel(text: "profile settings", dot: true)
                    Text("Edit your card")
                        .font(Typeface.display(24, weight: .semibold))
                        .tracking(-0.6)
                        .foregroundStyle(theme.ink)
                }
                Spacer()
                GFIconButton(icon: "xmark", label: "Close") { dismiss() }
            }

            Hairline()

            VStack(alignment: .leading, spacing: 6) {
                Text("NAME")
                    .font(Typeface.mono(8, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(theme.secondary)
                TextField("Your name", text: $name)
                    .textFieldStyle(.plain)
                    .font(Typeface.body(13))
                    .foregroundStyle(theme.ink)
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(theme.raised.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("BIO")
                    .font(Typeface.mono(8, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(theme.secondary)
                TextEditor(text: $bio)
                    .font(Typeface.body(12))
                    .foregroundStyle(theme.ink)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(height: 74)
                    .background(theme.raised.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }

            HStack {
                Text("This stays on your Mac.")
                    .font(Typeface.mono(8))
                    .foregroundStyle(theme.secondary)
                Spacer()
                GFButton("Cancel", kind: .outline, compact: true) { dismiss() }
                GFButton("Save changes", kind: .primary, compact: true) {
                    if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        store.updateIdentity(name: name, bio: bio)
                    }
                    dismiss()
                }
            }
        }
        .padding(24)
        .frame(width: 430)
        .background(theme.background)
        .onAppear {
            name = store.profile.name
            bio = store.profile.bio
        }
    }
}
