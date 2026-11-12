import SwiftUI
import AppKit
import Combine

/// Native Settings window (⌘,). Everything here is a real preference that is
/// persisted with the rest of the app state.
struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingReset = false
    @State private var gitInfo = GitEnvironment.current()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                appearanceCard
                soundCard
                behaviourCard
                sessionToolkitCard
                focusCard
                connectionCard
                dataCard
                footer
            }
            .padding(26)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .frame(width: 700, height: 780)
        .onAppear { if !gitInfo.isReady { gitInfo = GitEnvironment.refresh() } }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if !gitInfo.isReady { gitInfo = GitEnvironment.refresh() }
        }
        .confirmationDialog("Start over with a clean ledger?", isPresented: $confirmingReset) {
            Button("Reset everything", role: .destructive) {
                store.startOver()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Coins, sessions, achievements, and purchased cosmetics are cleared. Your GitHub connection and settings stay.")
        }
    }

    // MARK: Appearance

    private var appearanceCard: some View {
        SettingsCard(title: "appearance", icon: "paintpalette") {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text("Theme")
                        .font(Typeface.body(12, weight: .medium))
                        .foregroundStyle(theme.ink)
                    Spacer()
                    Text(store.themeDisplayName.uppercased())
                        .font(Typeface.mono(8, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(theme.accent)
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(store.ownedThemeItems) { item in
                            themeChip(item)
                        }
                    }
                    .padding(.vertical, 1)
                }
                .scrollIndicators(.hidden)

                HStack(spacing: 8) {
                    Text("Light and dark are free. More themes live in the shop catalog.")
                        .font(Typeface.body(10.5))
                        .foregroundStyle(theme.secondary)
                    Spacer()
                    if lockedThemeCount > 0 {
                        TagLabel(text: "\(lockedThemeCount) in shop", icon: "bag")
                    }
                }
            }
            .padding(.vertical, 13)
        }
    }

    private var lockedThemeCount: Int {
        ShopItem.items(in: .themes).filter { !store.ownedItemIDs.contains($0.id) }.count
    }

    private func themeChip(_ item: ShopItem) -> some View {
        let swatch = AppTheme.resolve(ThemeID(rawValue: item.payload) ?? .paper)
        let equipped = store.profile.equippedThemeID == item.payload
        return Button {
            store.equipTheme(item.payload)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ThemeSwatch(theme: swatch)
                    .frame(height: 46)
                HStack(spacing: 4) {
                    Text(item.name.uppercased())
                        .font(Typeface.mono(7.5, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(theme.ink)
                    Spacer()
                    if equipped {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(theme.accent)
                    }
                }
            }
            .padding(7)
            .frame(width: 132)
            .background(equipped ? theme.accentSoft : .clear)
            .overlay(
                Rectangle()
                    .strokeBorder(equipped ? theme.accent.opacity(0.5) : theme.line, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .help("Use \(item.name)")
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Text("PILCROW / FIELD NOTES")
                    .font(Typeface.mono(7, weight: .medium))
                    .tracking(1.9)
                    .foregroundStyle(theme.secondary.opacity(0.85))
                Rectangle().fill(theme.line).frame(height: 1)
                Text("PREFERENCES / 00")
                    .font(Typeface.mono(7, weight: .medium))
                    .tracking(1.9)
                    .foregroundStyle(theme.secondary.opacity(0.85))
                Rectangle().fill(theme.line).frame(width: 14, height: 1)
                Text("REV 2026.11")
                    .font(Typeface.mono(7, weight: .medium))
                    .tracking(1.9)
                    .foregroundStyle(theme.secondary.opacity(0.55))
            }

            HStack(alignment: .top, spacing: 14) {
                Rectangle()
                    .fill(theme.accent)
                    .frame(width: 3, height: 30)
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Settings")
                        .font(Typeface.display(32, weight: .semibold))
                        .tracking(-1.2)
                        .foregroundStyle(theme.ink)
                    Text("Sound, motion, focus, and your data. Everything stays on this Mac.")
                        .font(Typeface.body(12))
                        .foregroundStyle(theme.secondary)
                }
            }
        }
    }

    // MARK: Sound

    private var soundCard: some View {
        SettingsCard(title: "sound", icon: "speaker.wave.2") {
            SettingsToggleRow(
                icon: "speaker.wave.2.fill",
                title: "Sound effects",
                detail: "Short cues for sessions, coins, and purchases.",
                isOn: binding(\.soundEnabled),
                onPreview: { store.previewSound(.reward) }
            )
            Hairline().padding(.leading, 33)

            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.secondary)
                Slider(value: binding(\.soundVolume), in: 0...1)
                    .tint(theme.accent)
                    .disabled(!store.settings.soundEnabled)
                Text("\(Int((store.settings.clampedVolume * 100).rounded()))%")
                    .font(Typeface.mono(9, weight: .medium))
                    .foregroundStyle(theme.ink)
                    .frame(width: 34, alignment: .trailing)
            }
            .padding(.vertical, 10)
            .opacity(store.settings.soundEnabled ? 1 : 0.5)

            Hairline().padding(.leading, 33)
            SettingsToggleRow(
                icon: "play.circle",
                title: "Session starts",
                isOn: binding(\.soundOnSessionStart),
                isEnabled: store.settings.soundEnabled,
                onPreview: { store.previewSound(.sessionStart) }
            )
            SettingsToggleRow(
                icon: "stop.circle",
                title: "Session ends",
                isOn: binding(\.soundOnSessionEnd),
                isEnabled: store.settings.soundEnabled,
                onPreview: { store.previewSound(.sessionEnd) }
            )
            SettingsToggleRow(
                icon: "circle.hexagongrid.fill",
                title: "Coins are earned",
                isOn: binding(\.soundOnReward),
                isEnabled: store.settings.soundEnabled,
                onPreview: { store.previewSound(.reward) }
            )
            SettingsToggleRow(
                icon: "bag",
                title: "Something is bought",
                isOn: binding(\.soundOnPurchase),
                isEnabled: store.settings.soundEnabled,
                onPreview: { store.previewSound(.purchase) }
            )
            SettingsToggleRow(
                icon: "rosette",
                title: "Achievement unlocked",
                isOn: binding(\.soundOnAchievement),
                isEnabled: store.settings.soundEnabled,
                onPreview: { store.previewSound(.achievement) }
            )
        }
    }

    // MARK: Behaviour

    private var behaviourCard: some View {
        SettingsCard(title: "behaviour", icon: "slider.horizontal.3") {
            SettingsToggleRow(
                icon: "doc.text",
                title: "Show the report when a session ends",
                detail: "Open the coin ledger automatically. Sessions stay in the log either way.",
                isOn: binding(\.showSessionReport)
            )
            Hairline().padding(.leading, 33)
            SettingsToggleRow(
                icon: "wind",
                title: "Reduce motion",
                detail: "Trim transitions and screen animations.",
                isOn: binding(\.reduceMotion)
            )
            Hairline().padding(.leading, 33)
            SettingsToggleRow(
                icon: "dock.rectangle",
                title: "Show today's focus on the Dock icon",
                detail: "A small badge with today's minutes.",
                isOn: binding(\.dockBadge)
            )
            Hairline().padding(.leading, 33)
            SettingsToggleRow(
                icon: "power",
                title: "Launch at login",
                detail: store.launchAtLoginSupported
                    ? "Open Pilcrow when you sign in to this Mac."
                    : "Move Pilcrow to Applications to use this.",
                isOn: launchAtLogin,
                isEnabled: store.launchAtLoginSupported
            )
        }
    }

    // MARK: Session toolkit

    private var sessionToolkitCard: some View {
        SettingsCard(title: "session toolkit", icon: "timer") {
            SettingsToggleRow(
                icon: "menubar.rectangle",
                title: "Menu bar timer",
                detail: "Keep the live clock in the menu bar, with quick-start and controls.",
                isOn: binding(\.menuBarTimer)
            )
            Hairline().padding(.leading, 33)
            SettingsToggleRow(
                icon: "arrow.triangle.2.circlepath",
                title: "Watch for commits while focusing",
                detail: "Check local git every few seconds so commits appear in the live card.",
                isOn: binding(\.liveCommitWatch)
            )
            Hairline().padding(.leading, 33)
            SettingsToggleRow(
                icon: "moon.zzz",
                title: "Pause when the Mac is idle",
                detail: "Time away is left out of the ledger instead of inflating a session.",
                isOn: binding(\.idleAutoPause)
            )
            if store.settings.idleAutoPause {
                thresholdRow
            }
            Hairline().padding(.leading, 33)
            SettingsToggleRow(
                icon: "stop.circle",
                title: "End the session at its target",
                detail: "When a 25, 50, or 90 minute target is reached, wrap up automatically.",
                isOn: binding(\.autoEndAtPreset)
            )
            Hairline().padding(.leading, 33)
            defaultPresetRow
        }
    }

    private var thresholdRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "hourglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.secondary)
                .frame(width: 22, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text("Idle after")
                    .font(Typeface.body(12, weight: .medium))
                    .foregroundStyle(theme.ink)
                Text("Pause once there has been no keyboard or pointer input for this long.")
                    .font(Typeface.body(10.5))
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 10)
            HStack(spacing: 4) {
                ForEach([2, 5, 10, 15], id: \.self) { minutes in
                    Button {
                        store.updateSettings { $0.idleThresholdMinutes = minutes }
                    } label: {
                        Text("\(minutes)m")
                            .font(Typeface.mono(8.5, weight: .medium))
                            .foregroundStyle(store.settings.clampedIdleThreshold == minutes ? theme.background : theme.secondary)
                            .padding(.horizontal, 7)
                            .frame(height: 23)
                            .background(store.settings.clampedIdleThreshold == minutes ? theme.ink : theme.raised.opacity(0.4))
                            .overlay(Rectangle().strokeBorder(theme.line, lineWidth: 1))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
        .padding(.vertical, 9)
        .padding(.leading, 0)
    }

    private var defaultPresetRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "target")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.secondary)
                .frame(width: 22, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text("Default target")
                    .font(Typeface.body(12, weight: .medium))
                    .foregroundStyle(theme.ink)
                Text("Pre-selected when the session card opens.")
                    .font(Typeface.body(10.5))
                    .foregroundStyle(theme.secondary)
            }
            Spacer(minLength: 10)
            HStack(spacing: 4) {
                ForEach(FocusPreset.all) { preset in
                    Button {
                        store.updateSettings { $0.defaultPresetMinutes = preset.minutes }
                        store.draftPresetMinutes = preset.minutes
                    } label: {
                        Text(preset.isOpen ? "OPEN" : "\(preset.minutes)m")
                            .font(Typeface.mono(8.5, weight: .medium))
                            .foregroundStyle(store.settings.defaultPresetMinutes == preset.minutes ? theme.background : theme.secondary)
                            .padding(.horizontal, 7)
                            .frame(height: 23)
                            .background(store.settings.defaultPresetMinutes == preset.minutes ? theme.ink : theme.raised.opacity(0.4))
                            .overlay(Rectangle().strokeBorder(theme.line, lineWidth: 1))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
        .padding(.vertical, 9)
    }

    // MARK: Focus

    private var focusCard: some View {
        SettingsCard(title: "focus", icon: "target") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Daily goal")
                        .font(Typeface.body(12, weight: .medium))
                        .foregroundStyle(theme.ink)
                    Spacer()
                    Text("\(store.profile.dailyGoalMinutes) min")
                        .font(Typeface.mono(9, weight: .medium))
                        .foregroundStyle(theme.accent)
                }
                HStack(spacing: 6) {
                    ForEach([30, 45, 60, 90, 120, 180], id: \.self) { minutes in
                        Button {
                            withAnimation(.easeOut(duration: 0.15)) { store.updateGoal(minutes) }
                        } label: {
                            Text("\(minutes)")
                                .font(Typeface.mono(9, weight: .medium))
                                .foregroundStyle(store.profile.dailyGoalMinutes == minutes ? theme.background : theme.secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 28)
                                .background(store.profile.dailyGoalMinutes == minutes ? theme.ink : theme.raised.opacity(0.4))
                                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                Text("The ring in the sidebar fills against this number. Change it whenever your week changes.")
                    .font(Typeface.body(10.5))
                    .foregroundStyle(theme.secondary)
            }
            .padding(.vertical, 13)
        }
    }

    // MARK: Connection

    private var connectionCard: some View {
        SettingsCard(title: "connection", icon: "arrow.triangle.branch") {
            HStack(spacing: 11) {
                Circle()
                    .fill(store.isGitHubConnected ? theme.green : theme.accent)
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.githubStatusLabel)
                        .font(Typeface.body(12, weight: .medium))
                        .foregroundStyle(theme.ink)
                    Text(connectionDetail)
                        .font(Typeface.body(10.5))
                        .foregroundStyle(theme.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if store.isGitHubConnected {
                    GFButton("Sync now", icon: "arrow.triangle.2.circlepath", kind: .outline, compact: true, isEnabled: !store.isSyncing) {
                        store.syncGitHub()
                    }
                }
                GFButton(store.isGitHubConnected ? "Manage" : "Connect", icon: "link", kind: .dark, compact: true) {
                    store.openGitHubConnection()
                }
            }
            .padding(.vertical, 13)
        }
    }

    private var connectionDetail: String {
        let local = store.activeRepositories.filter { $0.localPath != nil }.count
        if store.isGitHubConnected {
            return "@\(store.githubAccountLogin) · \(local) local \(local == 1 ? "repository" : "repositories")"
        }
        if store.hasDemoWorkspace {
            return "Demo workspace. Add a local repository to track real commits."
        }
        return "No account connected. Local focus still works."
    }

    // MARK: Data

    private var dataCard: some View {
        SettingsCard(title: "your data", icon: "externaldrive") {
            HStack(spacing: 11) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Everything lives on this Mac")
                        .font(Typeface.body(12, weight: .medium))
                        .foregroundStyle(theme.ink)
                    Text(store.stateFileURL.path)
                        .font(Typeface.mono(8.5))
                        .foregroundStyle(theme.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 8)
                GFButton("Reveal", icon: "folder", kind: .outline, compact: true) {
                    NSWorkspace.shared.activateFileViewerSelecting([store.stateFileURL])
                }
            }
            .padding(.vertical, 13)

            Hairline()

            HStack(spacing: 11) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local commit capture")
                        .font(Typeface.body(12, weight: .medium))
                        .foregroundStyle(theme.ink)
                    Text(gitInfo.statusText)
                        .font(Typeface.mono(8.5))
                        .foregroundStyle(theme.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    if !gitInfo.isReady {
                        Text(gitInfo.guidance)
                            .font(Typeface.body(10.5))
                            .foregroundStyle(theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                if !gitInfo.isReady {
                    GFButton("Install git", icon: "arrow.down.circle", kind: .outline, compact: true) {
                        GitEnvironment.promptInstall()
                    }
                }
            }
            .padding(.vertical, 13)

            Hairline()

            HStack(spacing: 11) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Privacy & licenses")
                        .font(Typeface.body(12, weight: .medium))
                        .foregroundStyle(theme.ink)
                    Text("How your data is handled, the app license, and font attributions.")
                        .font(Typeface.body(10.5))
                        .foregroundStyle(theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                GFButton("Privacy", kind: .outline, compact: true) {
                    openBundledDocument("PRIVACY.md")
                }
                GFButton("Licenses", kind: .outline, compact: true) {
                    openBundledDocument("THIRD-PARTY-NOTICES.md")
                }
            }
            .padding(.vertical, 13)

            Hairline()

            HStack(spacing: 11) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start over")
                        .font(Typeface.body(12, weight: .medium))
                        .foregroundStyle(theme.ink)
                    Text("Clear progress and reopen setup. GitHub and settings stay.")
                        .font(Typeface.body(10.5))
                        .foregroundStyle(theme.secondary)
                }
                Spacer(minLength: 8)
                GFButton("Start over", icon: "arrow.counterclockwise", kind: .outline, compact: true) {
                    confirmingReset = true
                }
            }
            .padding(.vertical, 13)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Text("PILCROW · BY INTRADITIONAL · \(appVersion)")
                .font(Typeface.mono(8))
                .tracking(0.8)
                .foregroundStyle(theme.secondary.opacity(0.7))
            Spacer()
            Text("Made for quiet work.")
                .font(Typeface.mono(8))
                .foregroundStyle(theme.secondary.opacity(0.7))
        }
        .padding(.top, 2)
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version.map { "v\($0)" } ?? "v1.0"
    }

    private func openBundledDocument(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: nil) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: Bindings

    private func binding<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { store.settings[keyPath: keyPath] },
            set: { value in
                store.updateSettings { $0[keyPath: keyPath] = value }
            }
        )
    }

    private var launchAtLogin: Binding<Bool> {
        Binding(
            get: { store.launchAtLoginEnabled },
            set: { store.setLaunchAtLogin($0) }
        )
    }
}

// MARK: - Components

private struct SettingsCard<Content: View>: View {
    @Environment(\.theme) private var theme
    var title: String
    var icon: String
    var content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        Panel(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.accent)
                    Text(title.uppercased())
                        .font(Typeface.mono(8, weight: .medium))
                        .tracking(1.4)
                        .foregroundStyle(theme.secondary)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 13)
                .padding(.bottom, 10)

                Hairline()

                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 3)
            }
        }
    }
}

private struct SettingsToggleRow: View {
    @Environment(\.theme) private var theme
    var icon: String
    var title: String
    var detail: String? = nil
    @Binding var isOn: Bool
    var isEnabled: Bool = true
    var onPreview: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.secondary)
                .frame(width: 22, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typeface.body(12, weight: .medium))
                    .foregroundStyle(theme.ink)
                if let detail {
                    Text(detail)
                        .font(Typeface.body(10.5))
                        .foregroundStyle(theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 10)

            if let onPreview, isOn, isEnabled {
                Button(action: onPreview) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(theme.accent)
                        .frame(width: 22, height: 22)
                        .background(theme.accentSoft)
                        .clipShape(Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(PressableButtonStyle())
                .help("Play this sound")
                .accessibilityLabel("Preview sound")
            }

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(GFToggleStyle())
                .disabled(!isEnabled)
        }
        .padding(.vertical, 9)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

struct GFToggleStyle: ToggleStyle {
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(configuration.isOn ? theme.accent : theme.ink.opacity(0.16))
                    .frame(width: 36, height: 21)
                Circle()
                    .fill(configuration.isOn ? theme.accentInk : theme.surface)
                    .frame(width: 17, height: 17)
                    .shadow(color: .black.opacity(configuration.isOn ? 0 : 0.12), radius: 1, y: 1)
                    .offset(x: configuration.isOn ? 17 : 2)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .animation(.timingCurve(0.2, 0.9, 0.2, 1, duration: 0.22), value: configuration.isOn)
        .accessibilityLabel(configuration.isOn ? "On" : "Off")
    }
}
