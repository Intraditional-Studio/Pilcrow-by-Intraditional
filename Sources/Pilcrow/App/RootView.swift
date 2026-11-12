import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.isSnapshotting) private var snapshotting
    @Binding var selection: AppSection

    private var reduceMotion: Bool { systemReduceMotion || store.settings.reduceMotion }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            if theme.showsGrid {
                GridPaper().ignoresSafeArea()
            }

            HStack(spacing: 0) {
                Sidebar(selection: $selection)
                Rectangle().fill(theme.line).frame(width: 1)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if !store.hasCompletedOnboarding {
                OnboardingView()
                    .environment(\.theme, AppTheme.resolve(.paper))
                    .preferredColorScheme(.light)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: store.hasCompletedOnboarding)
        .overlay(alignment: .top) {
            if let notice = store.notice {
                NoticeToast(notice: notice) { store.dismissNotice() }
                    .padding(.top, 14)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .sheet(item: $store.reportSession) { session in
            SessionReportView(session: session)
                .environmentObject(store)
                .environment(\.theme, store.theme)
                .preferredColorScheme(store.theme.isDark ? .dark : .light)
                .onDisappear {
                    store.evaluateAchievements()
                    store.pendingLevelUp = nil
                    store.lastSessionSyncError = nil
                }
        }
        .sheet(isPresented: $store.isGitHubSheetPresented) {
            GitHubConnectionSheet()
                .environmentObject(store)
                .environment(\.theme, store.theme)
                .preferredColorScheme(store.theme.isDark ? .dark : .light)
        }
        .task {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("--selftest") {
                try? await Task.sleep(nanoseconds: 400_000_000)
                await SelfTestRunner.run(store: store)
            } else if let index = args.firstIndex(of: "--snapshot"), args.count > index + 1 {
                try? await Task.sleep(nanoseconds: 700_000_000)
                await SnapshotRunner.run(store: store, folder: args[index + 1])
            } else if let index = args.firstIndex(of: "--git-probe"), args.count > index + 1 {
                await GitProbe.run(path: args[index + 1])
            } else {
                await store.repairRecentSessions()
            }
        }
    }

    @ViewBuilder private var content: some View {
        Group {
            switch selection {
            case .home:
                HomeView(selection: $selection)
            case .sessions:
                SessionsView()
            case .reports:
                ReportsView()
            case .shop:
                ShopView(selection: $selection)
            case .profile:
                ProfileView(selection: $selection)
            }
        }
        .id(selection)
        .transition(
            reduceMotion || snapshotting
                ? .identity
                : .asymmetric(insertion: .opacity.combined(with: .offset(y: 8)), removal: .opacity)
        )
        .animation(reduceMotion || snapshotting ? nil : .timingCurve(0.16, 0.84, 0.16, 1, duration: 0.26), value: selection)
    }
}

// MARK: - Sidebar

struct Sidebar: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.theme) private var theme
    @Environment(\.openSettings) private var openSettings
    @Binding var selection: AppSection

    private var sidebarBackground: Color {
        theme.isDark ? theme.background : theme.surface
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
                .padding(.top, 34)

            profileRow
                .padding(.horizontal, 14)
                .padding(.top, 20)

            nav
                .padding(.top, 20)

            Spacer(minLength: 12)

            if let active = store.activeSession {
                liveStrip(active)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }

            goalCard
                .padding(.horizontal, 14)

            footer
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 14)
        }
        .frame(width: 230)
        .background(sidebarBackground)
        .overlay(alignment: .trailing) {
            Rectangle().fill(theme.line).frame(width: 1)
        }
    }

    private var brand: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                PilcrowMark(size: 25)
                VStack(alignment: .leading, spacing: 1) {
                    Text("PILCROW")
                        .font(Typeface.display(16, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(theme.ink)
                    Text("BY INTRADITIONAL")
                        .font(Typeface.mono(6.5, weight: .medium))
                        .tracking(2.1)
                        .foregroundStyle(theme.secondary)
                }
                Spacer(minLength: 4)
                Text("No. 001")
                    .font(Typeface.mono(7, weight: .medium))
                    .tracking(0.8)
                    .foregroundStyle(theme.secondary.opacity(0.65))
            }

            HStack(spacing: 7) {
                Rectangle().fill(theme.accent).frame(width: 18, height: 1)
                Text("FIELD INSTRUMENT")
                    .font(Typeface.mono(6.5, weight: .medium))
                    .tracking(1.9)
                    .foregroundStyle(theme.secondary.opacity(0.8))
                Spacer()
            }
        }
        .padding(.horizontal, 18)
    }

    private var profileRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("OPERATOR")
                    .font(Typeface.mono(6.5, weight: .medium))
                    .tracking(1.6)
                    .foregroundStyle(theme.secondary.opacity(0.75))
                Rectangle().fill(theme.line).frame(height: 1)
            }
            .padding(.horizontal, 2)

            Button {
                withAnimation(.easeOut(duration: 0.15)) { selection = .profile }
            } label: {
                HStack(spacing: 9) {
                    AvatarView(item: store.equippedAvatar, size: 32, showStatus: false)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Text(store.profile.name)
                                .font(Typeface.body(12, weight: .semibold))
                                .foregroundStyle(theme.ink)
                            if let badge = store.equippedBadge {
                                BadgeView(item: badge, compact: true)
                            }
                        }
                        Text("LV \(store.level.level) / \(store.rank.uppercased())")
                            .font(Typeface.mono(7))
                            .tracking(0.7)
                            .foregroundStyle(theme.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 4)
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(theme.accent)
                        Text("\(store.profile.streak)")
                            .font(Typeface.mono(10, weight: .medium))
                            .foregroundStyle(theme.ink)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(theme.background.opacity(theme.isDark ? 0.35 : 0.55))
                .overlay(Rectangle().strokeBorder(theme.line, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private var nav: some View {
        VStack(alignment: .leading, spacing: 18) {
            navGroup(label: "Workspace", items: [.home, .sessions, .reports])
            navGroup(label: "Studio", items: [.shop, .profile])
        }
        .padding(.horizontal, 12)
    }

    private func navGroup(label: String, items: [AppSection]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 7) {
                Text(label)
                    .font(Typeface.mono(6.5, weight: .medium))
                    .tracking(1.9)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.secondary.opacity(0.7))
                Rectangle().fill(theme.line).frame(height: 1)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 4)

            ForEach(items) { section in
                NavRow(section: section, selected: selection == section) {
                    withAnimation(.easeOut(duration: 0.15)) { selection = section }
                }
            }
        }
    }

    private func liveStrip(_ active: Session) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { selection = .sessions }
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(active.isRunning ? theme.accent : theme.secondary)
                    .frame(width: 5, height: 5)
                Text(active.isRunning ? "Focusing" : "Paused")
                    .font(Typeface.mono(8, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(theme.secondary)
                Spacer()
                SessionClock(session: active, size: 11, tint: theme.ink)
                Image(systemName: "chevron.right")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(theme.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(theme.background.opacity(theme.isDark ? 0.35 : 0.5))
            .overlay(Rectangle().strokeBorder(theme.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var goalCard: some View {
        TimelineView(.periodic(from: .now, by: 5)) { _ in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    MonoLabel(text: "daily goal")
                    Spacer()
                    Text("\(Int(store.dailyProgress * 100))%")
                        .font(Typeface.mono(9, weight: .medium))
                        .foregroundStyle(store.dailyProgress >= 1 ? theme.green : theme.secondary)
                        .contentTransition(.numericText())
                }
                HStack(spacing: 12) {
                    GoalRing(progress: store.dailyProgress, size: 54, lineWidth: 5) {
                        Text("\(Int(store.todayFocus / 60))")
                            .font(Typeface.display(15, weight: .semibold))
                            .foregroundStyle(theme.ink)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.todayFocus > 0 ? store.todayFocus.focusLabel : "No focus yet")
                            .font(Typeface.body(12, weight: .medium))
                            .foregroundStyle(theme.ink)
                        Text("of \(store.profile.dailyGoalMinutes) minutes")
                            .font(Typeface.mono(8))
                            .foregroundStyle(theme.secondary)
                        if store.profile.streak > 0 {
                            Text("\(store.profile.streak) \(store.profile.streak == 1 ? "day" : "days") streak")
                                .font(Typeface.mono(8, weight: .medium))
                                .foregroundStyle(theme.accent)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(12)
            .background(theme.background.opacity(theme.isDark ? 0.3 : 0.6))
            .overlay(Rectangle().strokeBorder(theme.line, lineWidth: 1))
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                Button {
                    store.openGitHubConnection()
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(store.isSyncing ? theme.accent : (store.isGitHubConnected ? theme.green : theme.accent))
                            .frame(width: 5, height: 5)
                        Text(store.isSyncing ? "syncing github" : store.githubFooterLabel)
                            .font(Typeface.mono(8))
                            .foregroundStyle(theme.secondary)
                            .lineLimit(1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Manage GitHub connection")
                Spacer()
                GFIconButton(icon: "gearshape", label: "Settings") {
                    openSettings()
                }
                GFIconButton(icon: "arrow.triangle.2.circlepath", label: "Sync GitHub") {
                    store.syncGitHub()
                }
                .rotationEffect(.degrees(store.isSyncing ? 360 : 0))
                .animation(store.isSyncing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: store.isSyncing)
            }
            Button {
                withAnimation(.easeOut(duration: 0.15)) { selection = .shop }
            } label: {
                HStack(spacing: 7) {
                    CoinMark(size: 16)
                    Text("\(store.profile.coins)")
                        .font(Typeface.mono(11, weight: .medium))
                        .foregroundStyle(theme.ink)
                        .contentTransition(.numericText(value: Double(store.profile.coins)))
                    Text("coins")
                        .font(Typeface.mono(8))
                        .foregroundStyle(theme.secondary)
                    Spacer()
                    Text("SPEND")
                        .font(Typeface.mono(8, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(theme.accent)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(theme.background.opacity(theme.isDark ? 0.3 : 0.5))
                .overlay(Rectangle().strokeBorder(theme.line, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .animation(.easeOut(duration: 0.2), value: store.profile.coins)

            HStack {
                Text("REV 1.0 / LOCAL-FIRST")
                    .font(Typeface.mono(6.5, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(theme.secondary.opacity(0.55))
                Spacer()
                Text("⌘,")
                    .font(Typeface.mono(7))
                    .foregroundStyle(theme.secondary.opacity(0.45))
            }
            .padding(.top, 2)
        }
    }
}

struct NavRow: View {
    @Environment(\.theme) private var theme
    var section: AppSection
    var selected: Bool
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Text(section.number)
                    .font(Typeface.mono(7, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(selected ? theme.background.opacity(0.45) : theme.secondary.opacity(0.55))
                    .frame(width: 16, alignment: .leading)

                Image(systemName: selected ? "\(section.icon).fill" : section.icon)
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 16)
                    .foregroundStyle(selected ? theme.background : theme.secondary)

                Text(section.title)
                    .font(Typeface.body(12, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? theme.background : theme.ink)

                Spacer()

                Text(section.shortcut)
                    .font(Typeface.mono(7.5))
                    .foregroundStyle(selected ? theme.background.opacity(0.4) : theme.secondary.opacity(0.45))
                    .opacity(selected || hovering ? 1 : 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background(selected ? theme.ink : (hovering ? theme.ink.opacity(0.045) : .clear))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(selected ? theme.accent : .clear)
                    .frame(width: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.10), value: hovering)
        .accessibilityLabel("\(section.title)\(selected ? ", selected" : "")")
    }
}
