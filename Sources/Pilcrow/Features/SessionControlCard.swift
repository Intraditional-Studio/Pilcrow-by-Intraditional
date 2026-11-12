import SwiftUI

struct SessionControlCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmingDiscard = false
    @State private var pulse = false

    var body: some View {
        Panel(padding: 22) {
            if store.isFinalizingSession {
                finalizing
            } else if let session = store.activeSession {
                active(session)
            } else {
                idle
            }
        }
    }

    // MARK: Finalizing

    private var finalizing: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                MonoLabel(text: "wrapping up", dot: true)
                Spacer()
                TagLabel(text: store.isGitHubConnected ? "GitHub" : "demo", icon: store.isGitHubConnected ? "link" : "sparkles")
            }
            HStack(spacing: 16) {
                ProgressView()
                    .controlSize(.small)
                    .tint(theme.accent)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Finishing the session.")
                        .font(Typeface.display(20, weight: .medium))
                        .foregroundStyle(theme.ink)
                    Text(store.isGitHubConnected
                         ? "Collecting your commits from GitHub. The clock is already stopped."
                         : "Adding the session to your log. The clock is already stopped.")
                        .font(Typeface.body(11.5))
                        .foregroundStyle(theme.secondary)
                }
                Spacer()
            }
            .frame(minHeight: 150)
            HStack(spacing: 6) {
                Rectangle().fill(theme.accent).frame(width: 16, height: 1)
                Text("Focus time and base coins are saved before any network call.")
                    .font(Typeface.mono(8))
                    .foregroundStyle(theme.secondary)
            }
        }
    }

    // MARK: Idle

    private var idle: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                MonoLabel(text: "new session", dot: true)
                Spacer()
                Text("⌘⇧S")
                    .font(Typeface.mono(9))
                    .foregroundStyle(theme.secondary.opacity(0.7))
            }

            if store.isOnBreak {
                breakBanner
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("00:00:00")
                        .font(Typeface.mono(52, weight: .regular))
                        .tracking(-2)
                        .foregroundStyle(theme.ink.opacity(0.24))
                        .monospacedDigit()
                    Text(store.draftIntent.isEmpty ? "Ready when you are." : store.draftIntent)
                        .font(Typeface.display(18, weight: .medium))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("≈ 2 coins")
                        .font(Typeface.mono(12, weight: .medium))
                        .foregroundStyle(theme.accent)
                    Text("per focused minute")
                        .font(Typeface.mono(8))
                        .foregroundStyle(theme.secondary)
                }
                .padding(.bottom, 3)
            }

            presetRow

            intentBlock

            Hairline()

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 10) {
                    Text("Work in")
                        .font(Typeface.body(11, weight: .medium))
                        .foregroundStyle(theme.secondary)
                    Spacer()
                    Button {
                        addLocalRepositories()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 8, weight: .bold))
                            Text("Add repo")
                                .font(Typeface.body(10, weight: .medium))
                        }
                        .foregroundStyle(theme.accent)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Add a local folder containing a .git directory")
                    Text("\(store.draftRepoIDs.count) selected")
                        .font(Typeface.mono(9))
                        .foregroundStyle(theme.secondary)
                }
                if store.activeRepositories.isEmpty {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No local repositories yet.")
                                .font(Typeface.body(11, weight: .medium))
                                .foregroundStyle(theme.ink)
                            Text("Add a project folder containing a .git directory.")
                                .font(Typeface.body(10))
                                .foregroundStyle(theme.secondary)
                        }
                        Spacer()
                        GFButton("Add local repository", icon: "folder.badge.plus", kind: .outline, compact: true) {
                            addLocalRepositories()
                        }
                    }
                    .padding(12)
                    .background(theme.raised.opacity(0.35))
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                } else if store.activeRepositories.count > 8 {
                    ScrollView {
                        RepoPicker(
                            repositories: store.activeRepositories,
                            selected: store.draftRepoIDs,
                            onToggle: { store.toggleRepo($0) },
                            onRemove: { store.removeLocalRepository($0) }
                        )
                        .padding(.vertical, 1)
                    }
                    .frame(height: 118)
                    .scrollIndicators(.hidden)
                } else {
                    RepoPicker(
                        repositories: store.activeRepositories,
                        selected: store.draftRepoIDs,
                        onToggle: { store.toggleRepo($0) },
                        onRemove: { store.removeLocalRepository($0) }
                    )
                }
            }

            HStack(spacing: 10) {
                GFButton("Start session", icon: "play.fill", kind: .primary,
                         isEnabled: !store.activeRepositories.isEmpty) {
                    store.startSession()
                }
                Text(startHint)
                    .font(Typeface.body(10.5))
                    .foregroundStyle(theme.secondary)
                    .lineLimit(2)
                Spacer()
            }
        }
    }

    private var breakBanner: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = store.breakRemaining(at: context.date) ?? 0
            HStack(spacing: 10) {
                Image(systemName: "cup.and.saucer")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("ON A BREAK")
                        .font(Typeface.mono(7.5, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(theme.accent)
                    Text("\(remaining.shortClock) left · nothing is being logged")
                        .font(Typeface.body(10.5))
                        .foregroundStyle(theme.secondary)
                }
                Spacer()
                Button {
                    store.endBreak()
                } label: {
                    Text("Skip")
                        .font(Typeface.mono(8, weight: .medium))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(theme.ink)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .overlay(Rectangle().strokeBorder(theme.line, lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(10)
            .background(theme.accentSoft.opacity(0.6))
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.accent.opacity(0.22), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }

    private var startHint: String {
        if store.activeRepositories.isEmpty { return "Add a local repository to begin." }
        if let preset = FocusPreset.find(minutes: store.draftPresetMinutes), !preset.isOpen {
            return store.settings.autoEndAtPreset
                ? "\(preset.minutes) minute target. Pilcrow ends it for you."
                : "\(preset.minutes) minute target. The clock keeps going when you reach it."
        }
        return "The clock starts now. You can pause any time."
    }

    // MARK: Presets and intent

    private var presetRow: some View {
        HStack(spacing: 7) {
            Text("TARGET")
                .font(Typeface.mono(8, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(theme.secondary)
            ForEach(FocusPreset.all) { preset in
                let selected = store.draftPresetMinutes == preset.minutes
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { store.draftPresetMinutes = preset.minutes }
                } label: {
                    Text(preset.isOpen ? "OPEN" : "\(preset.minutes)M")
                        .font(Typeface.mono(9, weight: .medium))
                        .tracking(0.7)
                        .foregroundStyle(selected ? theme.background : theme.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 27)
                        .background(selected ? theme.ink : theme.raised.opacity(0.35))
                        .overlay(Rectangle().strokeBorder(selected ? .clear : theme.line, lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .help(preset.detail)
            }
            Spacer(minLength: 2)
            if let preset = FocusPreset.find(minutes: store.draftPresetMinutes), !preset.isOpen {
                Text(preset.detail.uppercased())
                    .font(Typeface.mono(7.5))
                    .tracking(0.6)
                    .foregroundStyle(theme.secondary.opacity(0.8))
                    .lineLimit(1)
            }
        }
    }

    private var intentBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "text.quote")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.accent)
                TextField("Intent — what are you moving?", text: $store.draftIntent)
                    .textFieldStyle(.plain)
                    .font(Typeface.body(11.5))
                    .foregroundStyle(theme.ink)
                    .onSubmit { store.startSession() }
                if !store.draftIntent.isEmpty {
                    Button {
                        store.draftIntent = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(theme.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(theme.raised.opacity(0.35))
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 2))

            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(SessionTagCatalog.all, id: \.self) { tag in
                    let selected = store.draftTags.contains(tag)
                    Button {
                        withAnimation(.easeOut(duration: 0.12)) { store.toggleDraftTag(tag) }
                    } label: {
                        Text("#\(tag)")
                            .font(Typeface.mono(8.5, weight: .medium))
                            .foregroundStyle(selected ? theme.accent : theme.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(selected ? theme.accentSoft : .clear)
                            .overlay(
                                Rectangle().strokeBorder(
                                    selected ? theme.accent.opacity(0.45) : theme.line,
                                    lineWidth: 1
                                )
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }

    // MARK: Active

    private func active(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 7) {
                    liveDot(running: session.isRunning)
                    Text(session.isRunning ? "Session in progress" : "Session paused")
                        .font(Typeface.mono(10, weight: .medium))
                        .tracking(1.3)
                        .textCase(.uppercase)
                        .foregroundStyle(theme.ink)
                }
                Spacer()
                if !session.events.isEmpty {
                    HStack(spacing: 4) {
                        Circle().fill(theme.green).frame(width: 4, height: 4)
                        Text("\(session.events.count) captured live")
                            .font(Typeface.mono(8))
                            .foregroundStyle(theme.green)
                    }
                }
                Text("started \(session.startedAt.formatted(.dateTime.hour().minute()))")
                    .font(Typeface.mono(9))
                    .foregroundStyle(theme.secondary)
            }

            HStack(alignment: .center, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    SessionClock(session: session, size: 56)
                    HStack(spacing: 4) {
                        ForEach(session.repoIDs.compactMap(store.repository(withID:)), id: \.id) { repo in
                            Text(repo.name)
                                .font(Typeface.mono(9))
                                .foregroundStyle(theme.secondary)
                            if repo.id != session.repoIDs.compactMap(store.repository(withID:)).last?.id {
                                Text("/").font(Typeface.mono(9)).foregroundStyle(theme.line)
                            }
                        }
                    }
                }
                Spacer(minLength: 6)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let minutes = session.duration(at: context.date) / 60
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("\(10 + Int(minutes) * 2) coins")
                            .font(Typeface.mono(13, weight: .medium))
                            .foregroundStyle(theme.accent)
                            .contentTransition(.numericText())
                        Text("estimated so far")
                            .font(Typeface.mono(8))
                            .foregroundStyle(theme.secondary)
                    }
                    .opacity(session.isRunning ? 1 : 0.6)
                }
            }

            if !session.intent.isEmpty || session.hasTags {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if !session.intent.isEmpty {
                        Image(systemName: "text.quote")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(theme.accent)
                        Text(session.intent)
                            .font(Typeface.body(11.5, weight: .medium))
                            .foregroundStyle(theme.ink)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    ForEach(session.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(Typeface.mono(8, weight: .medium))
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(theme.accentSoft)
                    }
                }
            }

            if let target = session.targetSeconds {
                presetProgress(session, target: target)
            }

            // Daily goal progress
            VStack(alignment: .leading, spacing: 5) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.ink.opacity(0.08))
                        Capsule().fill(theme.accent)
                            .frame(width: max(4, geo.size.width * store.dailyProgress))
                    }
                }
                .frame(height: 3)
                HStack {
                    Text("Daily goal · \(store.profile.dailyGoalMinutes) min")
                        .font(Typeface.mono(8))
                        .foregroundStyle(theme.secondary)
                    Spacer()
                    Text("\(Int(store.dailyProgress * 100))%")
                        .font(Typeface.mono(8, weight: .medium))
                        .foregroundStyle(theme.secondary)
                }
            }

            HStack(spacing: 8) {
                if session.isRunning {
                    GFButton("Pause", icon: "pause.fill", kind: .dark, compact: true) {
                        store.pauseSession()
                    }
                } else {
                    GFButton("Resume", icon: "play.fill", kind: .primary, compact: true) {
                        store.resumeSession()
                    }
                }
                GFButton("End session", icon: "stop.fill", kind: .outline, compact: true) {
                    store.endSession()
                }
                Spacer()
                GFIconButton(icon: "trash", label: "Discard session") {
                    confirmingDiscard = true
                }
            }
        }
        .confirmationDialog("Discard this session?", isPresented: $confirmingDiscard) {
            Button("Discard session", role: .destructive) { store.discardActiveSession() }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("The timer stops and nothing is added to your log or coins.")
        }
    }

    private func presetProgress(_ session: Session, target: TimeInterval) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = session.duration(at: context.date)
            let progress = min(1, max(0, elapsed / max(1, target)))
            let remaining = max(0, target - elapsed)
            let over = max(0, elapsed - target)
            VStack(alignment: .leading, spacing: 5) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.ink.opacity(0.08))
                        Capsule()
                            .fill(progress >= 1 ? theme.green : theme.accent)
                            .frame(width: max(4, geo.size.width * progress))
                    }
                }
                .frame(height: 3)
                HStack {
                    Text("Target · \(Int(target / 60)) min")
                        .font(Typeface.mono(8))
                        .foregroundStyle(theme.secondary)
                    Spacer()
                    if over > 0 {
                        Text("+\(over.shortClock) over · \(store.settings.autoEndAtPreset ? "auto-end on" : "open end")")
                            .font(Typeface.mono(8, weight: .medium))
                            .foregroundStyle(theme.green)
                    } else {
                        Text("\(remaining.shortClock) left · \(store.settings.autoEndAtPreset ? "auto-end on" : "open end")")
                            .font(Typeface.mono(8, weight: .medium))
                            .foregroundStyle(theme.accent)
                    }
                }
            }
        }
    }

    private func addLocalRepositories() {
        let urls = LocalRepositoryPicker.chooseFolders()
        _ = store.addLocalRepositories(at: urls)
    }

    private func liveDot(running: Bool) -> some View {
        ZStack {
            if running && !reduceMotion {
                Circle()
                    .stroke(theme.accent.opacity(0.4), lineWidth: 1)
                    .frame(width: 12, height: 12)
                    .scaleEffect(pulse ? 1.6 : 0.6)
                    .opacity(pulse ? 0 : 0.8)
                    .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: pulse)
            }
            Circle()
                .fill(running ? theme.accent : theme.secondary)
                .frame(width: 6, height: 6)
        }
        .frame(width: 6, height: 6)
        .onAppear { pulse = true }
    }
}

struct SessionClock: View {
    @Environment(\.theme) private var theme
    var session: Session
    var size: CGFloat = 44
    var tint: Color?
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(session.duration(at: context.date).clockLabel)
                .font(Typeface.mono(size, weight: .regular))
                .tracking(-size * 0.035)
                .monospacedDigit()
                .foregroundStyle(tint ?? theme.ink)
                .accessibilityLabel("Elapsed \(session.duration(at: context.date).clockLabel)")
        }
    }
}
