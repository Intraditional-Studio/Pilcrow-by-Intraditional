import SwiftUI

struct SessionReportView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    private let initialSession: Session

    @State private var note: String = ""
    @State private var editingTimes = false
    @State private var editStart = Date()
    @State private var editEnd = Date()

    init(session: Session) {
        self.initialSession = session
    }

    /// Always read the live copy so an edit inside this sheet is visible
    /// immediately without closing and reopening the report.
    private var session: Session { store.session(withID: initialSession.id) ?? initialSession }
    private var sessionRepos: [Repository] {
        session.repoIDs.compactMap(store.repository(withID:))
    }

    private var repoBreakdown: [(repo: Repository, commits: Int, additions: Int, deletions: Int)] {
        let commits = Dictionary(grouping: session.events.filter { $0.kind == .commit }, by: \.repoID)
        return session.repoIDs.compactMap { id in
            guard let repo = store.repository(withID: id) else { return nil }
            let events = session.events.filter { $0.repoID == id }
            return (repo, commits[id]?.count ?? 0,
                    events.reduce(0) { $0 + $1.additions },
                    events.reduce(0) { $0 + $1.deletions })
        }.sorted { $0.commits > $1.commits }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    hero
                    metaRow

                    if !session.unclaimedEvents.isEmpty {
                        unclaimedCard
                    }

                    if editingTimes {
                        timeEditor
                    }

                    if let syncError = store.lastSessionSyncError {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("GitHub activity unavailable")
                                    .font(Typeface.body(11, weight: .semibold))
                                    .foregroundStyle(theme.ink)
                                Text(syncError)
                                    .font(Typeface.body(10))
                                    .foregroundStyle(theme.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Button {
                                dismiss()
                                Task {
                                    try? await Task.sleep(nanoseconds: 220_000_000)
                                    store.openGitHubConnection()
                                }
                            } label: {
                                Text("Fix")
                                    .font(Typeface.body(10, weight: .medium))
                                    .foregroundStyle(theme.accent)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(11)
                        .background(theme.accentSoft)
                        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.accent.opacity(0.25), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                    Hairline()
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 24) {
                            timeline.frame(minWidth: 360, maxWidth: .infinity)
                            rightColumn.frame(width: 240)
                        }
                        VStack(spacing: 20) {
                            timeline
                            rightColumn
                        }
                    }
                }
                .padding(24)
            }

            Hairline()

            HStack(spacing: 10) {
                Text("Saved to your local log.")
                    .font(Typeface.mono(8))
                    .foregroundStyle(theme.secondary)
                Spacer()
                GFButton("Start another", icon: "play.fill", kind: .outline, compact: true) {
                    let repoIDs = session.repoIDs
                    dismiss()
                    Task {
                        try? await Task.sleep(nanoseconds: 180_000_000)
                        store.draftRepoIDs = repoIDs
                        store.startSession()
                    }
                }
                .disabled(store.activeSession != nil)
                GFButton("Done", kind: .primary, compact: true) {
                    saveNote()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(theme.background)
        }
        .frame(width: 780, height: 650)
        .background(theme.background)
        .onAppear { note = session.note }
        .onDisappear { saveNote() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                MonoLabel(text: "session report / \(session.id.uuidString.prefix(4))", dot: true)
                Text(session.startedAt.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(Typeface.display(25, weight: .semibold))
                    .tracking(-0.6)
                    .foregroundStyle(theme.ink)
                Text("\(session.startedAt.formatted(.dateTime.hour().minute())) – \(session.endedAt?.formatted(.dateTime.hour().minute()) ?? "now")")
                    .font(Typeface.mono(9))
                    .foregroundStyle(theme.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button {
                    beginTimeEdit()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 8, weight: .semibold))
                        Text("Edit times")
                            .font(Typeface.mono(8, weight: .medium))
                            .tracking(0.5)
                            .textCase(.uppercase)
                    }
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .overlay(Rectangle().strokeBorder(theme.accent.opacity(0.3), lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .help("Correct the start and end time if a session was left running")
                GFIconButton(icon: "xmark", label: "Close report") { saveNote(); dismiss() }
            }
        }
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Nice work.")
                    .font(Typeface.display(34, weight: .semibold))
                    .tracking(-1)
                    .foregroundStyle(theme.ink)
                Text(session.accumulatedSeconds.focusLabel)
                    .font(Typeface.mono(46, weight: .regular))
                    .tracking(-1.8)
                    .foregroundStyle(theme.ink)
                HStack(spacing: 6) {
                    ForEach(sessionRepos, id: \.id) { repo in
                        TagLabel(text: repo.name, icon: repo.symbol)
                    }
                }
                .padding(.top, 2)

                if !session.intent.isEmpty || session.hasTags {
                    HStack(spacing: 6) {
                        if !session.intent.isEmpty {
                            Text(session.intent)
                                .font(Typeface.body(11, weight: .medium))
                                .foregroundStyle(theme.ink)
                                .lineLimit(1)
                        }
                        ForEach(session.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(Typeface.mono(7.5, weight: .medium))
                                .foregroundStyle(theme.accent)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(theme.accentSoft)
                        }
                        if let preset = session.presetMinutes, preset > 0 {
                            Text("\(preset)m target")
                                .font(Typeface.mono(7.5))
                                .foregroundStyle(theme.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    Text("+\(session.xpEarned) XP · \(session.events.count) \(session.events.count == 1 ? "activity" : "activities")")
                        .font(Typeface.mono(8))
                        .foregroundStyle(theme.secondary)
                    if let level = store.pendingLevelUp {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 8, weight: .semibold))
                            Text("LEVEL \(level) REACHED")
                                .font(Typeface.mono(8, weight: .medium))
                                .tracking(0.8)
                        }
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    CoinMark(size: 22)
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(theme.accentInk.opacity(0.5))
                }
                Text("+\(session.coinsEarned)")
                    .font(Typeface.display(44, weight: .semibold))
                    .tracking(-1.4)
                    .foregroundStyle(theme.accentInk)
                    .contentTransition(.numericText())
                Text("COINS EARNED")
                    .font(Typeface.mono(8, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(theme.accentInk.opacity(0.65))
                Spacer(minLength: 8)
                Text("Balance \(store.profile.coins)")
                    .font(Typeface.mono(9, weight: .medium))
                    .foregroundStyle(theme.accentInk.opacity(0.7))
            }
            .padding(16)
            .frame(width: 200)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay(alignment: .topTrailing) {
                Circle()
                    .strokeBorder(theme.accentInk.opacity(0.14), lineWidth: 1)
                    .frame(width: 52, height: 52)
                    .offset(x: 16, y: -18)
            }
        }
        .frame(minHeight: 152)
        .padding(20)
        .background(theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    private var metaRow: some View {
        HStack(spacing: 0) {
            reportStat("\(session.commits)", "commits", "arrow.triangle.branch")
            Rectangle().fill(theme.line).frame(width: 1, height: 32)
            reportStat("\(session.filesChanged)", "files", "doc.on.doc")
            Rectangle().fill(theme.line).frame(width: 1, height: 32)
            reportStat("\(session.additions)", "lines added", "plus")
            Rectangle().fill(theme.line).frame(width: 1, height: 32)
            reportStat("\(session.deletions)", "lines removed", "minus")
            Rectangle().fill(theme.line).frame(width: 1, height: 32)
            reportStat("\(session.repoIDs.count)", "repos", "folder")
        }
        .padding(.vertical, 12)
        .background(theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    private func reportStat(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundStyle(theme.secondary)
                Text(value)
                    .font(Typeface.display(15, weight: .semibold))
                    .foregroundStyle(theme.ink)
            }
            Text(label)
                .font(Typeface.mono(7))
                .textCase(.uppercase)
                .tracking(0.7)
                .foregroundStyle(theme.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Unclaimed work & time edits

    private var unclaimedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Work found in other repositories")
                        .font(Typeface.body(11.5, weight: .semibold))
                        .foregroundStyle(theme.ink)
                    Text("These commits landed during this session but in repositories you did not select.")
                        .font(Typeface.body(10))
                        .foregroundStyle(theme.secondary)
                }
                Spacer(minLength: 8)
            }

            VStack(spacing: 0) {
                ForEach(session.unclaimedEvents) { event in
                    HStack(spacing: 8) {
                        Text(event.timestamp.formatted(.dateTime.hour().minute()))
                            .font(Typeface.mono(8))
                            .foregroundStyle(theme.secondary)
                            .frame(width: 40, alignment: .trailing)
                        RepoTag(repo: store.repository(withID: event.repoID))
                        Text(event.title)
                            .font(Typeface.body(10.5))
                            .foregroundStyle(theme.ink)
                            .lineLimit(1)
                        Spacer()
                        if event.additions + event.deletions > 0 {
                            Text("+\(event.additions) −\(event.deletions)")
                                .font(Typeface.mono(8))
                                .foregroundStyle(theme.green)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }

            HStack(spacing: 8) {
                GFButton("Add to this session", icon: "plus", kind: .primary, compact: true) {
                    _ = store.addUnclaimedEvents(sessionID: session.id)
                }
                GFButton("Leave out", kind: .quiet, compact: true) {
                    store.dismissUnclaimedEvents(sessionID: session.id)
                }
                Spacer()
                Text("Adding them updates the coin ledger.")
                    .font(Typeface.mono(7.5))
                    .foregroundStyle(theme.secondary)
            }
        }
        .padding(13)
        .background(theme.accentSoft.opacity(0.55))
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.accent.opacity(0.24), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    private var timeEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.accent)
                Text("Correct the session window")
                    .font(Typeface.body(11.5, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { editingTimes = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(theme.secondary)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 14) {
                DatePicker("Started", selection: $editStart, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.field)
                    .font(Typeface.mono(9))
                DatePicker("Ended", selection: $editEnd, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.field)
                    .font(Typeface.mono(9))
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                GFButton("Save times", icon: "checkmark", kind: .dark, compact: true) {
                    store.updateSessionTimes(sessionID: session.id, startedAt: editStart, endedAt: editEnd)
                    withAnimation(.easeOut(duration: 0.15)) { editingTimes = false }
                }
                GFButton("Cancel", kind: .quiet, compact: true) {
                    withAnimation(.easeOut(duration: 0.15)) { editingTimes = false }
                }
                Spacer()
                Text("Coins and XP are recalculated from the corrected window.")
                    .font(Typeface.mono(7.5))
                    .foregroundStyle(theme.secondary)
            }
        }
        .padding(13)
        .background(theme.raised.opacity(0.35))
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    private func beginTimeEdit() {
        editStart = session.startedAt
        editEnd = session.endedAt ?? Date()
        withAnimation(.easeOut(duration: 0.15)) { editingTimes = true }
    }

    // MARK: Timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(label: "what moved", title: nil,
                           detail: session.events.isEmpty ? "no activity captured" : "\(session.events.count) \(session.events.count == 1 ? "event" : "events")")
            if session.events.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(emptyActivityTitle)
                        .font(Typeface.body(12, weight: .medium))
                        .foregroundStyle(theme.ink)
                    Text(emptyActivityMessage)
                        .font(Typeface.body(11))
                        .foregroundStyle(theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.raised.opacity(0.35))
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 2))
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(session.events.sorted { $0.timestamp < $1.timestamp }.enumerated()), id: \.element.id) { index, event in
                        HStack(alignment: .top, spacing: 10) {
                            Text(event.timestamp.formatted(.dateTime.hour().minute()))
                                .font(Typeface.mono(8))
                                .foregroundStyle(theme.secondary)
                                .frame(width: 38, alignment: .trailing)
                                .padding(.top, 2)
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(index == session.events.count - 1 ? theme.accent : theme.ink.opacity(0.35))
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 3)
                                if index < session.events.count - 1 {
                                    Rectangle().fill(theme.line).frame(width: 1, height: 38)
                                }
                            }
                            .frame(width: 7)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.title)
                                    .font(Typeface.body(11.5, weight: .medium))
                                    .foregroundStyle(theme.ink)
                                    .lineLimit(2)
                                HStack(spacing: 6) {
                                    RepoTag(repo: store.repository(withID: event.repoID))
                                    Text(event.kind.label)
                                        .font(Typeface.mono(8))
                                        .foregroundStyle(theme.secondary)
                                    if event.commitSHA != nil {
                                        Text(String(event.commitSHA!))
                                            .font(Typeface.mono(8))
                                            .foregroundStyle(theme.secondary.opacity(0.7))
                                    }
                                    if event.additions + event.deletions > 0 {
                                        Text("+\(event.additions) −\(event.deletions)")
                                            .font(Typeface.mono(8))
                                            .foregroundStyle(theme.green)
                                    }
                                }
                            }
                            .padding(.bottom, 16)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Right column

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let breakdown = session.coinBreakdown {
                coinLedger(breakdown)
            }

            VStack(alignment: .leading, spacing: 9) {
                MonoLabel(text: "by repository")
                Hairline()
                if repoBreakdown.isEmpty {
                    Text("No repositories attached.")
                        .font(Typeface.body(10))
                        .foregroundStyle(theme.secondary)
                } else {
                    ForEach(repoBreakdown, id: \.repo.id) { entry in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(entry.repo.name)
                                    .font(Typeface.body(10.5, weight: .medium))
                                    .foregroundStyle(theme.ink)
                                Spacer()
                                Text("\(entry.commits)c")
                                    .font(Typeface.mono(8))
                                    .foregroundStyle(theme.secondary)
                            }
                            Text("+\(entry.additions) −\(entry.deletions)")
                                .font(Typeface.mono(7))
                                .foregroundStyle(theme.green)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                MonoLabel(text: "note to future you")
                ZStack(alignment: .topLeading) {
                    if note.isEmpty {
                        Text("What actually moved?")
                            .font(Typeface.body(10.5))
                            .foregroundStyle(theme.secondary.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $note)
                        .font(Typeface.body(11))
                        .foregroundStyle(theme.ink)
                        .scrollContentBackground(.hidden)
                        .padding(3)
                }
                .frame(height: 66)
                .background(theme.raised.opacity(0.4))
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 2))
                Button {
                    saveNote()
                } label: {
                    Text("Save note")
                        .font(Typeface.mono(8, weight: .medium))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyActivityTitle: String {
        if store.hasDemoWorkspace { return "A short session leaves a short trail." }
        return "No commits in this window."
    }

    private var emptyActivityMessage: String {
        if store.hasDemoWorkspace {
            return "This one ended before the demo activity threshold, so no sample events were invented. The focus time still counts."
        }
        return "Pilcrow read this folder's .git history and found no commits from you in the session window. The focus time still counts."
    }

    private func coinLedger(_ breakdown: CoinBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                MonoLabel(text: "coin ledger")
                Spacer()
                Text("\(String(format: "%.2f", breakdown.lengthMultiplier))× length")
                    .font(Typeface.mono(8))
                    .foregroundStyle(theme.secondary)
            }
            Hairline()
            KeyValue(key: "focus · \(breakdown.focusMinutes)m × 2", value: "\(breakdown.base)")
            if breakdown.lengthBonus > 0 {
                KeyValue(key: "length boost", value: "+\(breakdown.lengthBonus)")
            }
            if breakdown.commitBonus > 0 {
                KeyValue(key: "commits · \(breakdown.commits) × 6", value: "+\(breakdown.commitBonus)")
            }
            if breakdown.changeBonus > 0 {
                KeyValue(key: "files · \(breakdown.filesChanged) × 2", value: "+\(breakdown.changeBonus)")
            }
            if breakdown.streakBonus > 0 {
                KeyValue(key: "streak · \(breakdown.streak)d × 3", value: "+\(breakdown.streakBonus)")
            }
            Hairline()
            HStack {
                Text("TOTAL")
                    .font(Typeface.mono(8, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(theme.ink)
                Spacer()
                CoinAmount(amount: breakdown.total, size: 10)
            }
            Text("2 coins per focused minute. Longer sessions, commits, files, and streaks add small bonuses. Capped at 500.")
                .font(Typeface.body(9.5))
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func saveNote() {
        store.updateNote(sessionID: session.id, note: note)
    }
}
