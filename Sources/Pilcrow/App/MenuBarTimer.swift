import SwiftUI
import AppKit

// MARK: - Menu bar label

/// The label is deliberately small: elapsed time while a session runs, today's
/// minutes when idle. No badges, no colour, no noise.
struct MenuBarLabel: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: store.activeSession?.isRunning == true ? "timer" : "paragraph")
                .font(.system(size: 11))
            if let session = store.activeSession {
                Text(session.duration(at: store.clockNow).shortClock)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .monospacedDigit()
            } else {
                Text("\(Int(store.todayFocus / 60))m")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Menu bar panel

struct MenuBarTimerView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.theme) private var theme
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if let session = store.activeSession {
                active(session)
            } else {
                idle
            }
            Hairline()
            stats
            Hairline()
            footer
        }
        .frame(width: 318)
        .background(theme.background)
    }

    private var header: some View {
        HStack(spacing: 8) {
            PilcrowMark(size: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text("PILCROW")
                    .font(Typeface.mono(8, weight: .medium))
                    .tracking(1.4)
                    .foregroundStyle(theme.ink)
                Text(store.hasCompletedOnboarding ? "FOCUS INSTRUMENT" : "SETUP NEEDED")
                    .font(Typeface.mono(6))
                    .tracking(1)
                    .foregroundStyle(theme.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                CoinMark(size: 11)
                Text("\(store.profile.coins)")
                    .font(Typeface.mono(9, weight: .medium))
                    .foregroundStyle(theme.ink)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: Idle

    private var idle: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.todayFocus > 0 ? store.todayFocus.focusLabel : "Ready when you are")
                        .font(Typeface.display(21, weight: .semibold))
                        .tracking(-0.4)
                        .foregroundStyle(theme.ink)
                    Text("\(store.profile.dailyGoalMinutes)m daily goal · \(store.profile.streak) day streak")
                        .font(Typeface.mono(8))
                        .foregroundStyle(theme.secondary)
                }
                Spacer()
            }

            if store.isOnBreak {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(spacing: 7) {
                        Image(systemName: "cup.and.saucer")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.accent)
                        Text("Break · \((store.breakRemaining(at: context.date) ?? 0).shortClock) left")
                            .font(Typeface.mono(8, weight: .medium))
                            .foregroundStyle(theme.secondary)
                        Spacer()
                        Button {
                            store.endBreak()
                        } label: {
                            Text("SKIP")
                                .font(Typeface.mono(7, weight: .medium))
                                .tracking(0.6)
                                .foregroundStyle(theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(theme.accentSoft.opacity(0.6))
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("START A SESSION")
                    .font(Typeface.mono(7, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(theme.secondary)
                HStack(spacing: 5) {
                    ForEach(FocusPreset.all) { preset in
                        Button {
                            store.startPresetSession(minutes: preset.minutes)
                        } label: {
                            Text(preset.isOpen ? "OPEN" : "\(preset.minutes)M")
                                .font(Typeface.mono(8, weight: .medium))
                                .tracking(0.5)
                                .foregroundStyle(theme.background)
                                .frame(maxWidth: .infinity)
                                .frame(height: 26)
                                .background(preset.minutes == store.settings.defaultPresetMinutes ? theme.accent : theme.ink)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .disabled(store.activeRepositories.isEmpty)
                .opacity(store.activeRepositories.isEmpty ? 0.4 : 1)

                if store.activeRepositories.isEmpty {
                    Text("Add a local repository in the main window to begin.")
                        .font(Typeface.mono(7.5))
                        .foregroundStyle(theme.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 13)
    }

    // MARK: Active

    private func active(_ session: Session) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            activeContent(session, now: context.date)
        }
    }

    private func activeContent(_ session: Session, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                HStack(spacing: 5) {
                    Circle()
                        .fill(session.isRunning ? theme.accent : theme.secondary)
                        .frame(width: 5, height: 5)
                    Text(session.isRunning ? "FOCUSING" : "PAUSED")
                        .font(Typeface.mono(7.5, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(theme.secondary)
                }
                Spacer()
                if let remaining = session.remaining(at: now) {
                    Text(remaining > 0 ? "\(remaining.shortClock) left" : "target reached")
                        .font(Typeface.mono(7.5, weight: .medium))
                        .foregroundStyle(remaining > 0 ? theme.accent : theme.green)
                }
            }

            SessionClock(session: session, size: 40)
                .foregroundStyle(theme.ink)

            if !session.intent.isEmpty {
                Text(session.intent)
                    .font(Typeface.body(11, weight: .medium))
                    .foregroundStyle(theme.ink)
                    .lineLimit(2)
            }

            if let target = session.targetSeconds {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.ink.opacity(0.08))
                        Capsule()
                            .fill(theme.accent)
                            .frame(width: max(3, geo.size.width * min(1, session.duration(at: now) / target)))
                    }
                }
                .frame(height: 3)
            }

            HStack(spacing: 6) {
                if session.isRunning {
                    GFButton("Pause", icon: "pause.fill", kind: .dark, compact: true) {
                        store.pauseSession()
                    }
                } else {
                    GFButton("Resume", icon: "play.fill", kind: .primary, compact: true) {
                        store.resumeSession()
                    }
                }
                GFButton("End", icon: "stop.fill", kind: .outline, compact: true) {
                    store.endSession()
                }
                Spacer()
                if !session.events.isEmpty {
                    Text("\(session.events.count) captured")
                        .font(Typeface.mono(7.5))
                        .foregroundStyle(theme.green)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 13)
    }

    // MARK: Stats

    private var stats: some View {
        HStack(spacing: 0) {
            miniStat("\(Int(store.todayFocus / 60))", "min today")
            divider
            miniStat("\(store.todayCommits)", "commits")
            divider
            miniStat("\(store.profile.streak)", "day streak")
            divider
            miniStat("\(store.profile.coins)", "coins")
        }
        .padding(.vertical, 9)
    }

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(Typeface.mono(10, weight: .medium))
                .foregroundStyle(theme.ink)
            Text(label)
                .font(Typeface.mono(6.5))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(theme.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(theme.line).frame(width: 1, height: 20)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 6) {
            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 8, weight: .semibold))
                    Text("Open Pilcrow")
                        .font(Typeface.mono(8, weight: .medium))
                }
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .overlay(Rectangle().strokeBorder(theme.line, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.secondary)
                    .frame(width: 28, height: 24)
                    .overlay(Rectangle().strokeBorder(theme.line, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.secondary)
                    .frame(width: 28, height: 24)
                    .overlay(Rectangle().strokeBorder(theme.line, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}
