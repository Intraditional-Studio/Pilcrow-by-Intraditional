import SwiftUI
import AppKit

/// Development-only offscreen renderer. Launch with `--snapshot <folder>` to
/// capture every screen without needing screen-recording permission.
@MainActor
enum SnapshotRunner {
    static func run(store: AppStore, folder: String) async {
        let base = URL(fileURLWithPath: folder)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        if ProcessInfo.processInfo.arguments.contains("--badges-only") {
            let badges = ShopView(selection: .constant(.shop), initialFilter: .badges)
                .environmentObject(store)
                .environment(\.theme, store.theme)
                .environment(\.isSnapshotting, true)
                .preferredColorScheme(store.theme.isDark ? .dark : .light)
            await render(badges, size: CGSize(width: 1280, height: 840),
                         to: base.appendingPathComponent("shop-badges.png"))
            print("Badges snapshot written")
            exit(0)
        }

        if ProcessInfo.processInfo.arguments.contains("--device-check") {
            do {
                let service = GitHubDeviceFlowService()
                let code = try await service.requestDeviceCode()
                let poll = try await service.pollAccessToken(deviceCode: code.deviceCode)
                if case .pending = poll {
                    print("DEVICE CHECK PASS code=\(code.userCode) interval=\(code.interval) expires=\(code.expiresIn) poll=pending")
                } else {
                    print("DEVICE CHECK UNEXPECTED poll result")
                }
            } catch {
                print("DEVICE CHECK FAIL: \(error.localizedDescription)")
            }
            exit(0)
        }

        if ProcessInfo.processInfo.arguments.contains("--onboarding") {
            for index in 0..<4 {
                let view = OnboardingView(initialStep: index)
                    .environmentObject(store)
                    .environment(\.theme, AppTheme.resolve(.paper))
                    .environment(\.isSnapshotting, true)
                    .preferredColorScheme(.light)
                await render(view, size: CGSize(width: 1280, height: 840),
                             to: base.appendingPathComponent("onboarding-\(index).png"))
            }
            let root = RootView(selection: .constant(.home))
                .environmentObject(store)
                .environment(\.theme, store.theme)
                .environment(\.isSnapshotting, true)
                .preferredColorScheme(store.theme.isDark ? .dark : .light)
            await render(root, size: CGSize(width: 1280, height: 840),
                         to: base.appendingPathComponent("onboarding-root.png"))
            print("Onboarding snapshots done")
            exit(0)
        }

        let sections: [(String, AppSection)] = [
            ("home", .home), ("sessions", .sessions), ("reports", .reports),
            ("shop", .shop), ("profile", .profile)
        ]

        for (name, section) in sections {
            let view = RootView(selection: .constant(section))
                .environmentObject(store)
                .environment(\.theme, store.theme)
                .environment(\.isSnapshotting, true)
                .preferredColorScheme(store.theme.isDark ? .dark : .light)
            await render(view, size: CGSize(width: 1280, height: 840),
                         to: base.appendingPathComponent("\(name).png"))
        }

        if let session = store.sessions.first(where: \.isCompleted) {
            let report = SessionReportView(session: session)
                .environmentObject(store)
                .environment(\.theme, store.theme)
                .environment(\.isSnapshotting, true)
                .preferredColorScheme(store.theme.isDark ? .dark : .light)
            await render(report, size: CGSize(width: 780, height: 650),
                         to: base.appendingPathComponent("report.png"))
        }

        let settings = SettingsView()
            .environmentObject(store)
            .environment(\.theme, store.theme)
            .environment(\.isSnapshotting, true)
            .preferredColorScheme(store.theme.isDark ? .dark : .light)
        await render(settings, size: CGSize(width: 700, height: 780),
                     to: base.appendingPathComponent("settings.png"))

        let receipt = WeeklyReceiptView(weekOffset: 0)
            .environmentObject(store)
            .environment(\.theme, store.theme)
            .environment(\.isSnapshotting, true)
            .preferredColorScheme(store.theme.isDark ? .dark : .light)
        await render(receipt, size: CGSize(width: 660, height: 780),
                     to: base.appendingPathComponent("weekly-receipt.png"))

        let menuBar = MenuBarTimerView()
            .environmentObject(store)
            .environment(\.theme, store.theme)
            .environment(\.isSnapshotting, true)
            .preferredColorScheme(store.theme.isDark ? .dark : .light)
        await render(menuBar, size: CGSize(width: 318, height: 420),
                     to: base.appendingPathComponent("menu-bar.png"))

        if !store.isGitHubConnected {
            let github = GitHubConnectionSheet()
                .environmentObject(store)
                .environment(\.theme, store.theme)
                .environment(\.isSnapshotting, true)
                .preferredColorScheme(store.theme.isDark ? .dark : .light)
            await render(github, size: CGSize(width: 560, height: 610),
                         to: base.appendingPathComponent("github-connect.png"))
        }

        let darkShop = RootView(selection: .constant(.shop))
            .environmentObject(store)
            .environment(\.theme, AppTheme.resolve(.midnight))
            .environment(\.isSnapshotting, true)
            .preferredColorScheme(.dark)
        await render(darkShop, size: CGSize(width: 1280, height: 840),
                     to: base.appendingPathComponent("shop-midnight.png"))




        print("Snapshots written to \(base.path)")
        exit(0)
    }

    private static func render<V: View>(_ view: V, size: CGSize, to url: URL) async {
        let hosting = NSHostingView(rootView: AnyView(view))
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: NSRect(x: 80, y: 80, width: size.width, height: size.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.isOpaque = false
        window.backgroundColor = .clear
        window.orderFront(nil)
        try? await Task.sleep(nanoseconds: 450_000_000)
        window.displayIfNeeded()
        hosting.layoutSubtreeIfNeeded()
        try? await Task.sleep(nanoseconds: 150_000_000)

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            print("Snapshot failed: \(url.lastPathComponent)")
            window.orderOut(nil)
            return
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: url)
        }
        window.orderOut(nil)
        window.contentView = nil
    }
}
