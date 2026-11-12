import SwiftUI

// MARK: - Page header

struct PageHeader<Trailing: View>: View {
    @Environment(\.theme) private var theme
    var kicker: String
    var title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    init(kicker: String, title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.kicker = kicker
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Text("PILCROW / FIELD NOTES")
                    .font(Typeface.mono(7, weight: .medium))
                    .tracking(1.9)
                    .foregroundStyle(theme.secondary.opacity(0.85))
                Rectangle().fill(theme.line).frame(height: 1)
                Text(kicker)
                    .font(Typeface.mono(7, weight: .medium))
                    .tracking(1.9)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.secondary.opacity(0.85))
                Rectangle().fill(theme.line).frame(width: 14, height: 1)
                Text("REV 2026.11")
                    .font(Typeface.mono(7, weight: .medium))
                    .tracking(1.9)
                    .foregroundStyle(theme.secondary.opacity(0.55))
                    .layoutPriority(1)
            }

            HStack(alignment: .top, spacing: 24) {
                HStack(alignment: .top, spacing: 14) {
                    Rectangle()
                        .fill(theme.accent)
                        .frame(width: 3, height: 34)
                        .padding(.top, 6)
                    Text(title)
                        .font(Typeface.display(38, weight: .semibold))
                        .tracking(-1.5)
                        .foregroundStyle(theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                trailing
            }

            if let subtitle {
                Text(subtitle)
                    .font(Typeface.body(13.5))
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
                    .frame(maxWidth: 620, alignment: .leading)
                    .padding(.leading, 17)
            }
        }
    }
}

extension PageHeader where Trailing == EmptyView {
    init(kicker: String, title: String, subtitle: String? = nil) {
        self.init(kicker: kicker, title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct SectionHeading: View {
    @Environment(\.theme) private var theme
    var label: String
    var title: String?
    var detail: String?
    var index: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let index {
                    Text(index)
                        .font(Typeface.mono(8, weight: .medium))
                        .tracking(0.6)
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .overlay(Rectangle().strokeBorder(theme.accent.opacity(0.38), lineWidth: 1))
                } else {
                    Circle().fill(theme.accent).frame(width: 5, height: 5)
                }
                MonoLabel(text: label)
                Spacer()
                if let detail {
                    Text(detail)
                        .font(Typeface.mono(9))
                        .foregroundStyle(theme.secondary)
                }
            }
            if let title {
                Text(title)
                    .font(Typeface.display(19, weight: .medium))
                    .tracking(-0.5)
                    .foregroundStyle(theme.ink)
            }
        }
    }
}

// MARK: - Repository picker

struct RepoChip: View {
    @Environment(\.theme) private var theme
    var repo: Repository
    var selected: Bool
    var action: () -> Void
    var onRemove: (() -> Void)?

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: repo.symbol)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(selected ? theme.accent : theme.secondary)
                    .frame(width: 20, height: 20)
                    .background(selected ? theme.accent.opacity(0.12) : theme.raised)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                VStack(alignment: .leading, spacing: 0) {
                    Text(repo.name)
                        .font(Typeface.body(12, weight: .medium))
                        .foregroundStyle(theme.ink)
                    Text(repo.owner)
                        .font(Typeface.mono(8))
                        .foregroundStyle(theme.secondary)
                }
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(theme.accent)
                        .padding(.leading, 2)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(selected ? theme.accentSoft : .clear)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(selected ? theme.accent.opacity(0.5) : theme.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(repo.fullName), \(selected ? "selected" : "not selected")")
        .contextMenu {
            if let onRemove, repo.isLocal {
                Button("Remove from Pilcrow", role: .destructive, action: onRemove)
            }
        }
    }
}

struct RepoPicker: View {
    @Environment(\.theme) private var theme
    var repositories: [Repository]
    var selected: [String]
    var onToggle: (String) -> Void
    var onRemove: ((String) -> Void)? = nil

    var body: some View {
        FlowLayout(spacing: 7, lineSpacing: 7) {
            ForEach(repositories) { repo in
                RepoChip(
                    repo: repo,
                    selected: selected.contains(repo.id),
                    action: { onToggle(repo.id) },
                    onRemove: onRemove.map { remove in { remove(repo.id) } }
                )
            }
        }
    }
}

// MARK: - Stats

struct StatTile: View {
    @Environment(\.theme) private var theme
    var label: String
    var value: String
    var detail: String?
    var icon: String
    var accent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                MonoLabel(text: label)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(accent ? theme.accent : theme.secondary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(Typeface.display(27, weight: .semibold))
                    .tracking(-0.8)
                    .foregroundStyle(theme.ink)
                    .contentTransition(.numericText())
                if let detail {
                    Text(detail)
                        .font(Typeface.mono(9))
                        .foregroundStyle(theme.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(theme.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

// MARK: - Activity

struct RepoTag: View {
    @Environment(\.theme) private var theme
    var repo: Repository?

    var body: some View {
        if let repo {
            HStack(spacing: 3) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 7, weight: .medium))
                Text(repo.name)
                    .font(Typeface.mono(9))
            }
            .foregroundStyle(theme.secondary)
        }
    }
}

struct ActivityRow: View {
    @Environment(\.theme) private var theme
    var event: ActivityEvent
    var repo: Repository?
    var showTime = true

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.raised)
                    .frame(width: 28, height: 28)
                Image(systemName: event.kind.glyph)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(event.kind == .commit ? theme.ink.opacity(0.7) : theme.green)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(Typeface.body(12.5, weight: .medium))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    RepoTag(repo: repo)
                    Circle().fill(theme.line).frame(width: 2, height: 2)
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
            Spacer(minLength: 8)
            if showTime {
                Text(event.timestamp.relativeLabel)
                    .font(Typeface.mono(9))
                    .foregroundStyle(theme.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Session row

struct SessionRow: View {
    @Environment(\.theme) private var theme
    var session: Session
    var repositories: [Repository]
    var action: (() -> Void)?

    @State private var hovering = false

    private var sessionRepos: [Repository] {
        session.repoIDs.compactMap { id in repositories.first { $0.id == id } }
    }

    var body: some View {
        let row = HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.startedAt.formatted(.dateTime.hour().minute()))
                    .font(Typeface.mono(11, weight: .medium))
                    .foregroundStyle(theme.ink)
                Text(session.startedAt.formatted(.dateTime.month(.abbreviated).day()))
                    .font(Typeface.mono(9))
                    .foregroundStyle(theme.secondary)
            }
            .frame(width: 64, alignment: .leading)

            Rectangle()
                .fill(session.isCompleted ? theme.line : theme.accent)
                .frame(width: 1, height: 32)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    ForEach(sessionRepos.prefix(3)) { repo in
                        Text(repo.name)
                            .font(Typeface.body(12, weight: .medium))
                            .foregroundStyle(theme.ink)
                    }
                    if sessionRepos.count > 3 {
                        Text("+\(sessionRepos.count - 3)")
                            .font(Typeface.mono(9))
                            .foregroundStyle(theme.secondary)
                    }
                }
                HStack(spacing: 8) {
                    Text(session.isCompleted ? session.accumulatedSeconds.focusLabel : "in progress")
                        .font(Typeface.mono(9))
                        .foregroundStyle(session.isCompleted ? theme.secondary : theme.accent)
                    Text("\(session.commits) commits")
                        .font(Typeface.mono(9))
                        .foregroundStyle(theme.secondary)
                    if let note = session.note.isEmpty ? nil : session.note {
                        Text("· \(note)")
                            .font(Typeface.body(10))
                            .foregroundStyle(theme.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 8)
            if session.isCompleted {
                CoinAmount(amount: session.coinsEarned, size: 10, muted: true)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.secondary.opacity(0.7))
                    .opacity(action == nil ? 0 : 1)
            } else {
                StatusTag(text: session.isRunning ? "running" : "paused", color: session.isRunning ? theme.accent : theme.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(hovering && action != nil ? theme.raised.opacity(0.6) : .clear)
        .contentShape(Rectangle())

        if let action {
            Button(action: action) { row }
                .buttonStyle(.plain)
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
        } else {
            row
        }
    }
}

// MARK: - Empty state

struct EmptyState: View {
    @Environment(\.theme) private var theme
    var glyph: String
    var title: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().strokeBorder(theme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(width: 52, height: 52)
                Image(systemName: glyph)
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(theme.secondary)
            }
            Text(title)
                .font(Typeface.display(17, weight: .medium))
                .foregroundStyle(theme.ink)
            Text(message)
                .font(Typeface.body(12))
                .foregroundStyle(theme.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            if let actionTitle, let action {
                GFButton(actionTitle, kind: .outline, compact: true, action: action)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 20)
    }
}

// MARK: - Toast

struct NoticeToast: View {
    @Environment(\.theme) private var theme
    var notice: Notice
    var dismiss: () -> Void

    private var accentColor: Color {
        switch notice.kind {
        case .achievement: theme.accent
        case .error: theme.accent
        case .info: theme.green
        }
    }

    private var icon: String {
        switch notice.kind {
        case .achievement: "seal.fill"
        case .error: "exclamationmark.triangle.fill"
        case .info: "checkmark.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(accentColor)
                .frame(width: 28, height: 28)
                .background(accentColor.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 2))
            VStack(alignment: .leading, spacing: 2) {
                Text(notice.title)
                    .font(Typeface.body(12.5, weight: .semibold))
                    .foregroundStyle(theme.background)
                Text(notice.message)
                    .font(Typeface.body(11))
                    .foregroundStyle(theme.background.opacity(0.7))
                    .lineLimit(2)
            }
            Spacer(minLength: 12)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.background.opacity(0.5))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(theme.ink)
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(theme.background.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .floatingShadow(theme)
        .frame(maxWidth: 380)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Helpers

extension Date {
    var relativeLabel: String {
        let seconds = Date().timeIntervalSince(self)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h ago" }
        if seconds < 86400 * 2 { return "yesterday" }
        return formatted(.dateTime.month(.abbreviated).day())
    }

    var greetingPart: String {
        let hour = Calendar.current.component(.hour, from: self)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Still up"
        }
    }
}

struct KeyValue: View {
    @Environment(\.theme) private var theme
    var key: String
    var value: String

    var body: some View {
        HStack {
            Text(key)
                .font(Typeface.mono(9))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(theme.secondary)
            Spacer()
            Text(value)
                .font(Typeface.mono(10, weight: .medium))
                .foregroundStyle(theme.ink)
        }
    }
}
