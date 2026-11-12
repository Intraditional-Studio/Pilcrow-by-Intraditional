import SwiftUI
import AppKit

enum AppSection: String, CaseIterable, Identifiable {
    case home, sessions, reports, shop, profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .sessions: "Sessions"
        case .reports: "Reports"
        case .shop: "Shop"
        case .profile: "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .sessions: "timer"
        case .reports: "chart.bar.xaxis"
        case .shop: "bag"
        case .profile: "person"
        }
    }

    var shortcut: String {
        switch self {
        case .home: "1"
        case .sessions: "2"
        case .reports: "3"
        case .shop: "4"
        case .profile: "5"
        }
    }

    var number: String {
        switch self {
        case .home: "01"
        case .sessions: "02"
        case .reports: "03"
        case .shop: "04"
        case .profile: "05"
        }
    }

    var annotation: String {
        switch self {
        case .home: "FIELD NOTES"
        case .sessions: "TIMELOG"
        case .reports: "WEEKLY REVIEW"
        case .shop: "CATALOG"
        case .profile: "OPERATOR"
        }
    }
}

@main
struct PilcrowApp: App {
    @StateObject private var store = AppStore()
    @State private var selection: AppSection = .home
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        FontLoader.register()
    }

    var body: some Scene {
        Window("Pilcrow", id: "main") {
            RootView(selection: $selection)
                .environmentObject(store)
                .environment(\.theme, store.theme)
                .preferredColorScheme(store.theme.isDark ? .dark : .light)
                .background(WindowConfigurator())
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1280, height: 840)
        .commands {
            PilcrowCommands(store: store, selection: $selection)
        }

        Settings {
            SettingsView()
                .environmentObject(store)
                .environment(\.theme, store.theme)
                .preferredColorScheme(store.theme.isDark ? .dark : .light)
        }

        MenuBarExtra(isInserted: menuBarInserted) {
            MenuBarTimerView()
                .environmentObject(store)
                .environment(\.theme, store.theme)
                .preferredColorScheme(store.theme.isDark ? .dark : .light)
        } label: {
            MenuBarLabel()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarInserted: Binding<Bool> {
        Binding(
            get: { store.settings.menuBarTimer },
            set: { value in
                guard store.settings.menuBarTimer != value else { return }
                store.updateSettings { $0.menuBarTimer = value }
            }
        )
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

struct PilcrowCommands: Commands {
    @ObservedObject var store: AppStore
    @Binding var selection: AppSection

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Start a Session") { store.startSession() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(store.activeSession != nil || store.isFinalizingSession)
            Button("End Session") { store.endSession() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(store.activeSession == nil)
        }

        CommandMenu("Go") {
            ForEach(AppSection.allCases) { section in
                Button(section.title) { selection = section }
                    .keyboardShortcut(KeyEquivalent(Character(section.shortcut)), modifiers: .command)
            }
        }

        CommandMenu("GitHub") {
            Button("GitHub Connection…") { store.openGitHubConnection() }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(!store.hasCompletedOnboarding)
            Button("Sync Now") { store.syncGitHub() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(store.isSyncing || !store.hasCompletedOnboarding)
        }

        CommandGroup(after: .toolbar) {
            Button(store.activeSession?.isRunning == true ? "Pause Session" : "Resume Session") {
                if store.activeSession?.isRunning == true {
                    store.pauseSession()
                } else if store.activeSession != nil {
                    store.resumeSession()
                }
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(store.activeSession == nil)
        }
    }
}

// MARK: - Native window plumbing

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = ConfiguringView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class ConfiguringView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.title = "Pilcrow"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.minSize = NSSize(width: 980, height: 680)
            window.backgroundColor = NSColor(red: 0.961, green: 0.937, blue: 0.918, alpha: 1)
            window.styleMask.insert(.fullSizeContentView)
        }
    }
}
