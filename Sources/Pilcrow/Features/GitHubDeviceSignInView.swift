import SwiftUI
import AppKit

struct GitHubDeviceSignInView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.theme) private var theme
    @StateObject private var model = GitHubDeviceFlowModel()
    @State private var copied = false
    @State private var copyResetTask: Task<Void, Never>?

    var compact = false
    var showsPrivacyNote = true
    var onConnected: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            if store.isGitHubConnected {
                connectedRow
            } else {
                switch model.phase {
                case .idle, .failed:
                    signInPrompt
                case .requesting:
                    busyRow("Requesting a sign-in code from GitHub…")
                case .waiting:
                    waitingContent
                case .connecting:
                    busyRow("Approved. Importing your repositories…")
                case .connected:
                    connectedRow
                }
            }
        }
        .onChange(of: model.phase) { _, phase in
            if phase == .connected { onConnected?() }
        }
        .onDisappear {
            copyResetTask?.cancel()
            model.cancel()
        }
    }

    // MARK: Idle / error

    private var signInPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                model.start(store: store)
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.background)
                            .frame(width: 25, height: 25)
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(theme.ink)
                    }
                    Text("Continue with GitHub")
                        .font(Typeface.body(13, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(theme.background)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Continue with GitHub")

            if case .failed(let message) = model.phase {
                inlineError(message)
            }

            if showsPrivacyNote {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.green)
                    Text("GitHub handles the sign-in. Your password never touches Pilcrow. The access token is kept in Keychain.")
                        .font(Typeface.body(10))
                        .foregroundStyle(theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Waiting

    private var waitingContent: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                MonoLabel(text: "one step on GitHub", dot: true)
                Spacer()
                Text("expires in \(Int((model.code?.expiresIn ?? 900) / 60)) min")
                    .font(Typeface.mono(8))
                    .foregroundStyle(theme.secondary)
            }

            HStack(spacing: 10) {
                Text(model.code?.userCode ?? "————")
                    .font(Typeface.mono(28, weight: .medium))
                    .tracking(2.5)
                    .foregroundStyle(theme.ink)
                    .textSelection(.enabled)
                Spacer()
                Button {
                    model.copyCode()
                    copied = true
                    copyResetTask?.cancel()
                    copyResetTask = Task {
                        try? await Task.sleep(nanoseconds: 1_400_000_000)
                        await MainActor.run { copied = false }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9, weight: .medium))
                        Text(copied ? "Copied" : "Copy")
                            .font(Typeface.body(10, weight: .medium))
                    }
                    .foregroundStyle(copied ? theme.green : theme.secondary)
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(theme.raised.opacity(0.45))
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 2))

            HStack(spacing: 9) {
                GFButton("Open GitHub", icon: "arrow.up.right", kind: .dark, compact: true) {
                    model.openBrowser()
                }
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini).tint(theme.accent)
                    Text("Waiting for approval…")
                        .font(Typeface.mono(8))
                        .foregroundStyle(theme.secondary)
                }
                Spacer()
                Button("Cancel") { model.cancel() }
                    .buttonStyle(.plain)
                    .font(Typeface.body(10, weight: .medium))
                    .foregroundStyle(theme.secondary)
            }

            Text("A browser tab should have opened at github.com/login/device. Enter the code there and approve access.")
                .font(Typeface.body(10.5))
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Connected

    private var connectedRow: some View {
        HStack(spacing: 11) {
            if let account = store.githubConnection?.account {
                GitHubAvatar(urlString: account.avatarURL, login: account.login, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connected as @\(account.login)")
                        .font(Typeface.body(12, weight: .semibold))
                        .foregroundStyle(theme.ink)
                    Text(account.name?.isEmpty == false ? account.name! : "GitHub account ready")
                        .font(Typeface.body(10))
                        .foregroundStyle(theme.secondary)
                }
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(theme.green)
                Text("GitHub connected")
                    .font(Typeface.body(12, weight: .medium))
                    .foregroundStyle(theme.ink)
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14))
                .foregroundStyle(theme.green)
        }
        .padding(12)
        .background(theme.green.opacity(0.07))
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.green.opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .accessibilityElement(children: .combine)
    }

    // MARK: Bits

    private func busyRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small).tint(theme.accent)
            Text(text)
                .font(Typeface.body(11.5, weight: .medium))
                .foregroundStyle(theme.ink)
            Spacer()
        }
        .padding(14)
        .background(theme.raised.opacity(0.35))
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    private func inlineError(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(theme.accent)
            Text(message)
                .font(Typeface.body(10.5))
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if model.isFailed {
                Button("Retry") { model.reset(); model.start(store: store) }
                    .buttonStyle(.plain)
                    .font(Typeface.body(10, weight: .medium))
                    .foregroundStyle(theme.accent)
            }
        }
        .padding(10)
        .background(theme.accentSoft)
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(theme.accent.opacity(0.25), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}
