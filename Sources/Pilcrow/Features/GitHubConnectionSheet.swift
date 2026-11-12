import SwiftUI
import AppKit

struct GitHubConnectionSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var token = ""
    @State private var revealToken = false
    @State private var confirmingDisconnect = false
    @State private var showPAT = false

    private let tokenURL = URL(string: "https://github.com/settings/tokens/new?scopes=repo,read:user&description=Pilcrow%20Swift")!

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    Hairline()
                    if store.isGitHubConnected {
                        connectedContent
                    } else {
                        connectContent
                    }
                    Hairline()
                    privacyNote
                }
                .padding(24)
            }

            Hairline()
            footer
        }
        .frame(width: 560, height: store.isGitHubConnected ? 610 : 520)
        .background(theme.background)
        .onExitCommand { dismiss() }
        .onAppear {
            token = ""
        }
        .onChange(of: store.isGitHubConnected) { _, connected in
            if connected { token = "" }
        }
        .confirmationDialog("Disconnect GitHub?", isPresented: $confirmingDisconnect) {
            Button("Disconnect", role: .destructive) { store.disconnectGitHub() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The token is removed from Keychain. Your sessions and history stay on this Mac.")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                MonoLabel(text: "GitHub / connection", dot: true)
                Text(store.isGitHubConnected ? "Connected." : "Bring your real work in.")
                    .font(Typeface.display(28, weight: .semibold))
                    .tracking(-0.8)
                    .foregroundStyle(theme.ink)
                Text(store.isGitHubConnected
                     ? "Commits are read from the local repositories you add."
                     : "One approval in your browser. Pilcrow reads commits from the local repositories you add; nothing else.")
                    .font(Typeface.body(12.5))
                    .foregroundStyle(theme.secondary)
            }
            Spacer()
            GFIconButton(icon: "xmark", label: "Close") { dismiss() }
        }
    }

    // MARK: Connected

    private var connectedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let connection = store.githubConnection {
                HStack(spacing: 14) {
                    GitHubAvatar(urlString: connection.account.avatarURL, login: connection.account.login, size: 54)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(connection.account.name?.isEmpty == false ? connection.account.name! : connection.account.login)
                            .font(Typeface.display(19, weight: .medium))
                            .foregroundStyle(theme.ink)
                        Text("@\(connection.account.login)")
                            .font(Typeface.mono(10))
                            .foregroundStyle(theme.secondary)
                        HStack(spacing: 6) {
                            StatusTag(text: "live connection", color: theme.green)
                            Text("since \(connection.connectedAt.formatted(.dateTime.month(.abbreviated).day()))")
                                .font(Typeface.mono(8))
                                .foregroundStyle(theme.secondary)
                        }
                    }
                    Spacer()
                    Circle()
                        .fill(theme.green)
                        .frame(width: 7, height: 7)
                }
                .padding(16)
                .background(theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }

            HStack(spacing: 0) {
                connectionStat("\(store.activeRepositories.filter { $0.localPath != nil }.count)", "local repos")
                Rectangle().fill(theme.line).frame(width: 1, height: 28)
                connectionStat("\(store.recentActivity.filter { $0.authorLogin != nil }.count)", "commits cached")
                Rectangle().fill(theme.line).frame(width: 1, height: 28)
                connectionStat(store.lastSyncedAt?.relativeLabel ?? "not yet", "last sync")
            }
            .padding(.vertical, 10)
            .background(theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 2))

            if let error = store.githubConnectionError {
                inlineError(error)
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    MonoLabel(text: "local repositories")
                    Spacer()
                    Button {
                        addLocalRepositories()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 8, weight: .bold))
                            Text("Add repository")
                                .font(Typeface.body(10, weight: .medium))
                        }
                        .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                }
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(store.activeRepositories.filter { $0.localPath != nil }.prefix(10)) { repo in
                        HStack(spacing: 4) {
                            Image(systemName: repo.isGitHubLinked ? "chevron.left.forwardslash.chevron.right" : "folder")
                                .font(.system(size: 8))
                            Text(repo.name)
                                .font(Typeface.body(10.5, weight: .medium))
                        }
                        .foregroundStyle(theme.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                    if store.activeRepositories.filter({ $0.localPath != nil }).isEmpty {
                        Text("No local repositories yet. Add a folder containing a .git directory.")
                            .font(Typeface.body(11))
                            .foregroundStyle(theme.secondary)
                    }
                }
                Text("Only local folders with .git can be added. Commits are read from the folder's GitHub origin.")
                    .font(Typeface.body(10.5))
                    .foregroundStyle(theme.secondary)
            }

            HStack(spacing: 9) {
                GFButton("Sync now", icon: "arrow.triangle.2.circlepath", kind: .dark, compact: true) {
                    store.syncGitHub()
                }
                .disabled(store.isSyncing)
                Spacer()
                GFButton("Disconnect", icon: "rectangle.portrait.and.arrow.right", kind: .outline, compact: true) {
                    confirmingDisconnect = true
                }
            }
        }
    }

    private func addLocalRepositories() {
        _ = store.addLocalRepositories(at: LocalRepositoryPicker.chooseFolders())
    }

    private func connectionStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Typeface.mono(11, weight: .medium))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
            Text(label)
                .font(Typeface.mono(7))
                .textCase(.uppercase)
                .tracking(0.7)
                .foregroundStyle(theme.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Connect

    private var connectContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            GitHubDeviceSignInView(showsPrivacyNote: false)

            if let error = store.githubConnectionError {
                inlineError(error)
            }

            DisclosureGroup(isExpanded: $showPAT) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Group {
                            if revealToken {
                                TextField("ghp_…", text: $token)
                            } else {
                                SecureField("ghp_…", text: $token)
                            }
                        }
                        .textFieldStyle(.plain)
                        .font(Typeface.mono(11))
                        .foregroundStyle(theme.ink)
                        .disabled(store.isConnectingGitHub)
                        .onSubmit { store.connectGitHub(token: token) }

                        Button {
                            revealToken.toggle()
                        } label: {
                            Image(systemName: revealToken ? "eye.slash" : "eye")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(theme.secondary)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(revealToken ? "Hide token" : "Show token")
                    }
                    .padding(.leading, 11)
                    .padding(.trailing, 6)
                    .frame(height: 36)
                    .background(theme.raised.opacity(0.45))
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 2))

                    HStack(spacing: 9) {
                        GFButton(store.isConnectingGitHub ? "Connecting…" : "Connect with token",
                                 icon: store.isConnectingGitHub ? "arrow.triangle.2.circlepath" : "link",
                                 kind: .outline, compact: true,
                                 isEnabled: !store.isConnectingGitHub) {
                            store.connectGitHub(token: token)
                        }
                        if store.isConnectingGitHub {
                            ProgressView().controlSize(.small)
                        }
                        Spacer()
                        Button {
                            NSWorkspace.shared.open(tokenURL)
                        } label: {
                            HStack(spacing: 4) {
                                Text("Create a token")
                                    .font(Typeface.body(10, weight: .medium))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 7, weight: .semibold))
                            }
                            .foregroundStyle(theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("Classic token with repo and read:user scopes. Stored in Keychain.")
                        .font(Typeface.mono(8))
                        .foregroundStyle(theme.secondary)
                }
                .padding(.top, 10)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "key")
                        .font(.system(size: 9, weight: .medium))
                    Text("Use a personal access token instead")
                        .font(Typeface.body(10.5, weight: .medium))
                }
                .foregroundStyle(theme.secondary)
            }

            Hairline()

            HStack(spacing: 10) {
                StatusTag(
                    text: store.hasDemoWorkspace ? "sample workspace" : "not connected",
                    color: store.hasDemoWorkspace ? theme.accent : theme.secondary
                )
                Text(store.hasDemoWorkspace
                     ? "Sample repositories are active until you add local folders."
                     : "Local repositories work without GitHub. Connecting adds commit activity.")
                    .font(Typeface.body(10.5))
                    .foregroundStyle(theme.secondary)
                Spacer(minLength: 0)
            }
        }
    }

    private func inlineError(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(theme.accent)
            Text(message)
                .font(Typeface.body(10.5))
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(theme.accentSoft)
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.accent.opacity(0.28), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 11))
                .foregroundStyle(theme.green)
            Text("The token stays in your Mac's Keychain and is sent only to api.github.com. Pilcrow never uploads your sessions. Disconnecting removes the token immediately.")
                .font(Typeface.body(10))
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(store.isGitHubConnected ? theme.green : theme.accent)
                    .frame(width: 5, height: 5)
                Text(store.isGitHubConnected
                     ? "Live GitHub connection"
                     : store.hasDemoWorkspace ? "Sample workspace · no account needed" : "Local-only until you connect")
                    .font(Typeface.mono(8))
                    .foregroundStyle(theme.secondary)
            }
            Spacer()
            GFButton("Done", kind: .primary, compact: true) { dismiss() }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(theme.background)
    }
}

struct GitHubAvatar: View {
    @Environment(\.theme) private var theme
    var urlString: String?
    var login: String
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .strokeBorder(theme.line, lineWidth: 1)
        )
        .accessibilityLabel("GitHub avatar for \(login)")
    }

    private var fallback: some View {
        ZStack {
            theme.raised
            Text(String(login.prefix(1)).uppercased())
                .font(Typeface.display(size * 0.4, weight: .semibold))
                .foregroundStyle(theme.ink)
        }
    }
}
