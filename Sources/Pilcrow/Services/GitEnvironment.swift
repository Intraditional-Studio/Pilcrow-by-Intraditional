import Foundation

/// Describes whether Pilcrow can read local git history on this Mac.
///
/// Apple ships `/usr/bin/git` as a shim even when the Command Line Tools are
/// missing; running it pops a system installer dialog. Detection therefore
/// checks for a real toolchain before executing anything under `/usr/bin`.
struct GitEnvironmentInfo: Sendable, Equatable {
    enum Health: Sendable, Equatable {
        /// A working git binary was found and answered `--version`.
        case ready
        /// `/usr/bin/git` exists only as an installer shim.
        case commandLineToolsMissing
        /// No git binary was found at all.
        case missing
    }

    var health: Health
    var executable: String?
    var version: String?

    var isReady: Bool { health == .ready }

    /// Short status line for Settings and onboarding.
    var statusText: String {
        switch health {
        case .ready:
            if let version, let executable {
                return "\(version) · \(executable)"
            }
            return executable ?? "Git is available"
        case .commandLineToolsMissing:
            return "Git needs Apple's Command Line Tools."
        case .missing:
            return "Git wasn't found on this Mac."
        }
    }

    var guidance: String {
        switch health {
        case .ready:
            return "Commits are read from your local repositories."
        case .commandLineToolsMissing, .missing:
            return "Pilcrow needs git to capture commits. Install Apple's Command Line Tools, then reopen Pilcrow."
        }
    }
}

enum GitEnvironment {
    private static let lock = NSLock()
    private static var cached: GitEnvironmentInfo?

    /// Result of the most recent probe. The first call performs detection.
    static func current() -> GitEnvironmentInfo {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        let info = detect()
        cached = info
        return info
    }

    /// Re-probe after the user installs the tools or changes PATH.
    @discardableResult
    static func refresh() -> GitEnvironmentInfo {
        lock.lock()
        defer { lock.unlock() }
        let info = detect()
        cached = info
        return info
    }

    /// Opens Apple's Command Line Tools installer dialog.
    static func promptInstall() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        process.arguments = ["--install"]
        try? process.run()
    }

    // MARK: - Detection

    private static func detect() -> GitEnvironmentInfo {
        let homebrew = ["/opt/homebrew/bin/git", "/usr/local/bin/git"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }

        if let homebrew, let version = version(at: homebrew) {
            return GitEnvironmentInfo(health: .ready, executable: homebrew, version: version)
        }

        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/git") else {
            return GitEnvironmentInfo(health: .missing, executable: nil, version: nil)
        }

        guard commandLineToolsInstalled else {
            return GitEnvironmentInfo(
                health: .commandLineToolsMissing,
                executable: "/usr/bin/git",
                version: nil
            )
        }

        if let version = version(at: "/usr/bin/git") {
            return GitEnvironmentInfo(health: .ready, executable: "/usr/bin/git", version: version)
        }
        return GitEnvironmentInfo(
            health: .commandLineToolsMissing,
            executable: "/usr/bin/git",
            version: nil
        )
    }

    private static var commandLineToolsInstalled: Bool {
        let developerDirs = [
            "/Library/Developer/CommandLineTools/usr/bin/git",
            "/Applications/Xcode.app/Contents/Developer/usr/bin/git"
        ]
        if developerDirs.contains(where: FileManager.default.isExecutableFile(atPath:)) {
            return true
        }
        // `xcode-select -p` is a cheap check that never opens an installer.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        process.arguments = ["-p"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func version(at path: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let line = String(data: data, encoding: .utf8)?
                .split(separator: "\n").first else { return nil }
        // "git version 2.39.5 (Apple Git-154)" → "git 2.39.5"
        let parts = line.split(separator: " ")
        if parts.count >= 3, parts[0] == "git", parts[1] == "version" {
            return "git \(parts[2])"
        }
        return String(line)
    }
}
