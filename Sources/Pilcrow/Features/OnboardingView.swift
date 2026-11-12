import SwiftUI
import AppKit
import Combine

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isSnapshotting) private var snapshotting

    @State private var step: Int
    @State private var name = ""
    @State private var goal = 90
    @State private var appeared = false
    @State private var gitInfo = GitEnvironment.current()

    private let steps = ["Welcome", "GitHub", "Repos", "Rhythm"]

    init(initialStep: Int = 0) {
        _step = State(initialValue: min(3, max(0, initialStep)))
    }

    var body: some View {
        HStack(spacing: 0) {
            introRail
            contentPanel
        }
        .background(theme.background)
        .ignoresSafeArea()
        .onAppear {
            name = store.profile.name == "Maker" ? "" : store.profile.name
            goal = store.profile.dailyGoalMinutes
            gitInfo = GitEnvironment.refresh()
            if snapshotting {
                appeared = true
            } else {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) { appeared = true }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if !gitInfo.isReady { gitInfo = GitEnvironment.refresh() }
        }
    }

    // MARK: Intro rail

    private var introRail: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: 0x1F1F1F)
            OnboardingGrid()
                .opacity(0.6)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 9) {
                    PilcrowMark(size: 25)
                        .environment(\.theme, AppTheme.resolve(.midnight))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("PILCROW")
                            .font(Typeface.display(15, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Color(hex: 0xF5EFEA))
                        Text("BY INTRADITIONAL")
                            .font(Typeface.mono(6.5, weight: .medium))
                            .tracking(1.6)
                            .foregroundStyle(Color(hex: 0xF5EFEA).opacity(0.5))
                    }
                }
                .padding(.top, 40)

                Spacer(minLength: 28)

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: 0xFF521B)).frame(width: 5, height: 5)
                        Text("A SMALL TOOL FOR BIG FOCUS")
                            .font(Typeface.mono(8, weight: .medium))
                            .tracking(1.7)
                            .foregroundStyle(Color(hex: 0xF5EFEA).opacity(0.55))
                    }
                    Text("Focus,\nwith receipts.")
                        .font(Typeface.display(48, weight: .semibold))
                        .tracking(-1.7)
                        .lineSpacing(-4)
                        .foregroundStyle(Color(hex: 0xF5EFEA))
                    Rectangle()
                        .fill(Color(hex: 0xFF521B))
                        .frame(width: 54, height: 2)
                    Text("A timer for people who make things. Time, commits, and coins in one quiet place.")
                        .font(Typeface.body(12.5))
                        .lineSpacing(3)
                        .foregroundStyle(Color(hex: 0xF5EFEA).opacity(0.62))
                        .frame(maxWidth: 270, alignment: .leading)
                }

                Spacer(minLength: 28)

                VStack(alignment: .leading, spacing: 12) {
                    railPoint("01", "Time that adds up")
                    railPoint("02", "Commits, when connected")
                    railPoint("03", "A desk worth keeping")
                    HStack {
                        Text("LOCAL-FIRST / MACOS")
                        Spacer()
                        Text("REV 1.0")
                    }
                    .font(Typeface.mono(7))
                    .tracking(1.2)
                    .foregroundStyle(Color(hex: 0xF5EFEA).opacity(0.35))
                    .padding(.top, 10)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 24)
        }
        .frame(width: 356)
    }

    private func railPoint(_ number: String, _ text: String) -> some View {
        HStack(spacing: 9) {
            Text(number)
                .font(Typeface.mono(7, weight: .medium))
                .foregroundStyle(Color(hex: 0xFF521B))
            Text(text)
                .font(Typeface.body(10.5, weight: .medium))
                .foregroundStyle(Color(hex: 0xF5EFEA).opacity(0.7))
        }
    }

    // MARK: Right content

    private var contentPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                    .padding(.top, 34)

                ZStack(alignment: .topLeading) {
                    Group {
                        switch step {
                        case 0: welcomeStep
                        case 1: githubStep
                        case 2: reposStep
                        default: rhythmStep
                        }
                    }
                    .id(step)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(insertion: .opacity.combined(with: .offset(y: 8)), removal: .opacity)
                    )
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: step)

                Spacer(minLength: 32)

                HStack(spacing: 6) {
                    Rectangle().fill(theme.accent).frame(width: 18, height: 1)
                    Text("Everything lives on your Mac. Disconnect whenever you like.")
                        .font(Typeface.mono(8))
                        .tracking(0.5)
                        .foregroundStyle(theme.secondary)
                }
                .padding(.top, 34)
            }
            .padding(.horizontal, 44)
            .padding(.bottom, 28)
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .opacity(appeared || snapshotting ? 1 : 0)
        .offset(y: appeared || snapshotting ? 0 : 6)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { index in
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(index == step ? theme.ink : (index < step ? theme.green : .clear))
                            .frame(width: 17, height: 17)
                        if index < step {
                            Image(systemName: "checkmark")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(theme.background)
                        } else {
                            Text("\(index + 1)")
                                .font(Typeface.mono(7, weight: .medium))
                                .foregroundStyle(index == step ? theme.background : theme.secondary)
                        }
                    }
                    Text(steps[index])
                        .font(Typeface.mono(8, weight: index == step ? .medium : .regular))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(index == step ? theme.ink : theme.secondary.opacity(0.7))
                }
                .overlay(alignment: .trailing) {
                    if index < 3 {
                        Rectangle()
                            .fill(theme.line)
                            .frame(width: 10, height: 1)
                            .offset(x: 10)
                    }
                }
                if index < 3 { Color.clear.frame(width: 4) }
            }
            Spacer()
            Text("SETUP / 4 STEPS")
                .font(Typeface.mono(7, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(theme.secondary.opacity(0.65))
        }
    }

    // MARK: Welcome

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                MonoLabel(text: "welcome / 01", dot: true)
                Text("A quieter way to work.")
                    .font(Typeface.display(38, weight: .semibold))
                    .tracking(-1.1)
                    .foregroundStyle(theme.ink)
                Text("Start a session, choose your repositories, and let Pilcrow keep the receipt. No dashboards shouting at you.")
                    .font(Typeface.body(13.5))
                    .lineSpacing(3)
                    .foregroundStyle(theme.secondary)
                    .frame(maxWidth: 490, alignment: .leading)
            }
            .padding(.top, 38)

            VStack(spacing: 0) {
                featureRow("timer", "Time that adds up", "Pause, resume, and end with a report that means something.")
                Hairline().padding(.leading, 45)
                featureRow("arrow.triangle.branch", "GitHub, when you want it", "Sign in to read commits from the local project folders you add.")
                Hairline().padding(.leading, 45)
                featureRow("circle.hexagongrid", "Small rewards", "Earn coins for focus and spend them on a desk that feels like yours.")
            }
            .background(theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .padding(.top, 2)

            HStack(spacing: 10) {
                GFButton("Set up Pilcrow", icon: "arrow.right", kind: .primary) {
                    goTo(1)
                }
                Text("Four short steps. Connect GitHub now or later.")
                    .font(Typeface.body(10))
                    .foregroundStyle(theme.secondary)
            }
            .padding(.top, 4)
        }
    }

    private func featureRow(_ glyph: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.raised)
                    .frame(width: 31, height: 31)
                Image(systemName: glyph)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.ink.opacity(0.75))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Typeface.body(12, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text(detail)
                    .font(Typeface.body(10.5))
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: GitHub

    private var githubStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                MonoLabel(text: "github / 02", dot: true)
                Text("Connect your work.")
                    .font(Typeface.display(38, weight: .semibold))
                    .tracking(-1.1)
                    .foregroundStyle(theme.ink)
                Text("Sign in once. Pilcrow reads commits from the local project folders you add yourself. Nothing is imported automatically.")
                    .font(Typeface.body(13.5))
                    .lineSpacing(3)
                    .foregroundStyle(theme.secondary)
                    .frame(maxWidth: 500, alignment: .leading)
            }
            .padding(.top, 38)

            Panel(padding: 18) {
                GitHubDeviceSignInView()
            }

            HStack(spacing: 0) {
                scopeItem("repo", "repositories")
                Rectangle().fill(theme.line).frame(width: 1, height: 26)
                scopeItem("read:user", "profile")
                Rectangle().fill(theme.line).frame(width: 1, height: 26)
                scopeItem("never", "your password")
            }
            .padding(.vertical, 9)
            .background(theme.raised.opacity(0.3))
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 2))

            HStack(spacing: 10) {
                if store.isGitHubConnected {
                    GFButton("Continue", icon: "arrow.right", kind: .primary) {
                        goTo(2)
                    }
                } else {
                    GFButton("I'll connect later", icon: "arrow.right", kind: .outline) {
                        goTo(2)
                    }
                }
                Spacer()
                Text("You can connect from the sidebar at any time.")
                    .font(Typeface.body(10))
                    .foregroundStyle(theme.secondary)
            }
        }
    }

    private func scopeItem(_ scope: String, _ meaning: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(scope)
                .font(Typeface.mono(9, weight: .medium))
                .foregroundStyle(scope == "never" ? theme.green : theme.ink)
            Text(meaning)
                .font(Typeface.mono(7))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(theme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
    }

    // MARK: Repositories

    private var reposStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                MonoLabel(text: "repos / 03", dot: true)
                Text("Point at your work.")
                    .font(Typeface.display(38, weight: .semibold))
                    .tracking(-1.1)
                    .foregroundStyle(theme.ink)
                Text("Add a project folder that already contains a .git directory. Pilcrow reads commits straight from it — local, unpushed, every branch. Nothing is uploaded.")
                    .font(Typeface.body(13.5))
                    .lineSpacing(3)
                    .foregroundStyle(theme.secondary)
                    .frame(maxWidth: 500, alignment: .leading)
            }
            .padding(.top, 38)

            if !gitInfo.isReady {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.accent)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Git isn't available yet")
                            .font(Typeface.body(11.5, weight: .medium))
                            .foregroundStyle(theme.ink)
                        Text(gitInfo.guidance)
                            .font(Typeface.body(10.5))
                            .foregroundStyle(theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    GFButton("Install", icon: "arrow.down.circle", kind: .outline, compact: true) {
                        GitEnvironment.promptInstall()
                    }
                }
                .padding(14)
                .background(theme.accentSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(theme.accent.opacity(0.35), lineWidth: 1)
                )
            }

            Panel(padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("LOCAL REPOSITORIES")
                            .font(Typeface.mono(7, weight: .medium))
                            .tracking(1.2)
                            .foregroundStyle(theme.secondary)
                        Spacer()
                        Text("\(store.draftRepoIDs.count) selected")
                            .font(Typeface.mono(7.5))
                            .foregroundStyle(theme.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)

                    Hairline()

                    if store.activeRepositories.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 9) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 14, weight: .light))
                                    .foregroundStyle(theme.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("No local repositories yet")
                                        .font(Typeface.body(11.5, weight: .medium))
                                        .foregroundStyle(theme.ink)
                                    Text("Choose a folder containing a .git directory.")
                                        .font(Typeface.body(10))
                                        .foregroundStyle(theme.secondary)
                                }
                                Spacer()
                            }
                            GFButton("Choose a repository", icon: "folder", kind: .outline, compact: true) {
                                addLocalRepositories()
                            }
                        }
                        .padding(16)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(store.activeRepositories.prefix(5).enumerated()), id: \.element.id) { index, repo in
                                let selected = store.draftRepoIDs.contains(repo.id)
                                Button {
                                    store.toggleRepo(repo.id)
                                } label: {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 1)
                                                .strokeBorder(selected ? theme.accent : theme.line, lineWidth: 1)
                                                .frame(width: 14, height: 14)
                                            if selected {
                                                RoundedRectangle(cornerRadius: 1)
                                                    .fill(theme.accent)
                                                    .frame(width: 8, height: 8)
                                            }
                                        }
                                        Image(systemName: repo.symbol)
                                            .font(.system(size: 10))
                                            .foregroundStyle(theme.secondary)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(repo.name)
                                                .font(Typeface.body(11.5, weight: .medium))
                                                .foregroundStyle(theme.ink)
                                            Text(repo.localPath ?? repo.fullName)
                                                .font(Typeface.mono(7.5))
                                                .foregroundStyle(theme.secondary)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 9)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if index < min(5, store.activeRepositories.count) - 1 {
                                    Hairline().padding(.leading, 40)
                                }
                            }
                        }
                        Hairline()
                        HStack {
                            Button {
                                addLocalRepositories()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 8, weight: .bold))
                                    Text("Add another folder")
                                        .font(Typeface.body(10, weight: .medium))
                                }
                                .foregroundStyle(theme.accent)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.green)
                Text("You can add or remove repositories any time. Board game folders and scratch projects are welcome.")
                    .font(Typeface.body(10.5))
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                GFButton("Back", kind: .quiet) { goTo(1) }
                GFButton(store.draftRepoIDs.isEmpty ? "Continue without a repo" : "Continue", icon: "arrow.right", kind: .primary) {
                    goTo(3)
                }
                Spacer()
            }
        }
    }

    private func addLocalRepositories() {
        let folders = LocalRepositoryPicker.chooseFolders()
        guard !folders.isEmpty else { return }
        _ = store.addLocalRepositories(at: folders)
        if store.draftRepoIDs.isEmpty, let first = store.activeRepositories.first {
            store.draftRepoIDs = [first.id]
        }
    }

    // MARK: Rhythm

    private var rhythmStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                MonoLabel(text: "rhythm / 04", dot: true)
                Text("Make it yours.")
                    .font(Typeface.display(38, weight: .semibold))
                    .tracking(-1.1)
                    .foregroundStyle(theme.ink)
                Text("A name, a realistic daily goal, and then you're in. You can change both later.")
                    .font(Typeface.body(13.5))
                    .lineSpacing(3)
                    .foregroundStyle(theme.secondary)
            }
            .padding(.top, 38)

            HStack(spacing: 16) {
                AvatarView(item: store.equippedAvatar, size: 56, showStatus: true)
                VStack(alignment: .leading, spacing: 5) {
                    Text("WHAT SHOULD WE CALL YOU?")
                        .font(Typeface.mono(7, weight: .medium))
                        .tracking(1.3)
                        .foregroundStyle(theme.secondary)
                    TextField(store.githubConnection?.account.name ?? "Your name", text: $name)
                        .textFieldStyle(.plain)
                        .font(Typeface.display(18, weight: .medium))
                        .foregroundStyle(theme.ink)
                        .padding(.horizontal, 11)
                        .frame(height: 38)
                        .background(theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("DAILY FOCUS GOAL")
                        .font(Typeface.mono(7, weight: .medium))
                        .tracking(1.3)
                        .foregroundStyle(theme.secondary)
                    Spacer()
                    Text("\(goal) minutes")
                        .font(Typeface.mono(9, weight: .medium))
                        .foregroundStyle(theme.ink)
                }
                HStack(spacing: 7) {
                    ForEach([60, 90, 120, 180], id: \.self) { minutes in
                        Button {
                            withAnimation(.easeOut(duration: 0.15)) { goal = minutes }
                        } label: {
                            VStack(spacing: 3) {
                                Text("\(minutes)")
                                    .font(Typeface.display(17, weight: .semibold))
                                    .foregroundStyle(goal == minutes ? theme.background : theme.ink)
                                Text("MIN")
                                    .font(Typeface.mono(6.5, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(goal == minutes ? theme.background.opacity(0.6) : theme.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(goal == minutes ? theme.ink : theme.surface)
                            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                Text("A goal you can actually keep beats an ambitious one you ignore.")
                    .font(Typeface.body(10))
                    .foregroundStyle(theme.secondary)
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.accent)
                Text("This starts a clean ledger: 0 coins, 0 sessions, level 1. Your GitHub account and local repositories stay.")
                    .font(Typeface.body(10.5))
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.accentSoft)
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.accent.opacity(0.22), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 2))

            HStack(spacing: 10) {
                GFButton("Back", kind: .quiet) { goTo(2) }
                GFButton("Start fresh", icon: "arrow.right", kind: .primary) {
                    store.completeOnboarding(name: name, dailyGoalMinutes: goal)
                }
                Spacer()
            }
            .padding(.top, 2)
        }
    }

    private func goTo(_ newStep: Int) {
        if newStep == 3, name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let account = store.githubConnection?.account {
            name = account.name?.isEmpty == false ? account.name! : account.login
        }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) { step = newStep }
    }
}

// MARK: - Decorative grid

private struct OnboardingGrid: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 30
            var path = Path()
            var x: CGFloat = 0
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = 0
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            context.stroke(path, with: .color(Color(hex: 0xF5EFEA).opacity(0.04)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}
