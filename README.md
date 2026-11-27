# Pilcrow

### by Intraditional

A small macOS focus tracker for people who make things. Start a session, watch your GitHub activity roll in, earn coins, and spend them on a desk that feels like yours.

Built with SwiftUI for macOS 14+. A first-run setup takes you through a proper GitHub sign-in, your daily rhythm, and into an empty, local-first workspace.

> Renamed from GitFlow Swift. Existing state and Keychain credentials are migrated automatically on first launch.

## Requirements

- macOS 14.0 or later
- Apple Silicon or Intel (universal build)
- Optional: git, for local commit capture. Apple's Command Line Tools provide it; Pilcrow detects a missing install and offers the installer. Homebrew git is also picked up.

## Install

Download the latest `Pilcrow-1.0.0-universal.dmg` from the releases page, open it, and drag Pilcrow to Applications. Verify the download first:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

The 1.0 build is **ad-hoc signed** (no Apple Developer ID yet), so macOS quarantines it on first launch. Allow it once:

1. Try to open Pilcrow.
2. Open **System Settings → Privacy & Security**.
3. Click **Open Anyway** next to the Pilcrow notice.
4. Confirm with Touch ID or password.

This is a one-time step. If you build from source yourself, Gatekeeper doesn't apply.

## Build it

```sh
./Scripts/run.sh
```

Or build the app bundle without launching:

```sh
./Scripts/build-app.sh release     # universal arm64 + x86_64
open "dist/Pilcrow.app"
```

Build a distributable ZIP, DMG, and checksum:

```sh
./Scripts/package.sh
```

You can also open `Package.swift` in Xcode and run the `Pilcrow` scheme. Versions live in `Scripts/version.env`; see `docs/RELEASE.md` for the full release and notarization process.

## What's inside

- **Home** — live session clock, daily and weekly quests, a copyable daily strip, weekly focus chart, recent activity.
- **Sessions** — preset targets, intent and tags, pause/resume/end, repository selection, searchable history.
- **Reports** — weekly focus, commit breakdown, best-hours heatmap, session-length distribution, focus-vs-commits scatter, week-over-week deltas, tag summary, and a designed weekly receipt (PNG or Markdown).
- **Shop** — premade themes, maker avatars, and shelf objects bought with focus coins. Badges are earned through milestones, never sold.
- **Profile** — level, XP, streaks, bankable streak freezes, achievements, 14-week heatmap, daily rhythm, customization.
- **Menu bar** — a live session clock with quick-start presets, pause/resume/end, daily stats, and a jump back into the app.
- **Settings** (`⌘,`) — appearance and premade themes, sound effects and per-cue toggles, sound volume, reduce motion, session report behaviour, Dock badge, menu bar timer, live commit watching, idle auto-pause and its threshold, default preset, auto-end, launch at login, daily goal, GitHub connection, and data tools.

Keyboard: `⌘1`–`⌘5` navigate, `⌘,` opens Settings, `⇧⌘S` starts a session, `⇧⌘E` ends it, `⇧⌘P` pauses/resumes, `⇧⌘R` syncs GitHub.

## Design — Editorial Engineering

The interface is built as a technical document: warm archival paper (`#F5EFEA`), deep charcoal ink (`#1F1F1F`), recycled-paper surfaces (`#ECE5DE`), and a single safety-orange accent (`#FF521B`). Hairline dividers, a discreet drafting grid, numbered section markers, and revision labels carry the editorial layer. Black specimen cards appear once per screen for the information that deserves emphasis.

Primary content uses the macOS system face; metadata, timestamps, and annotations use IBM Plex Mono in uppercase with generous tracking. Corner radii are restrained. Motion is short, mechanical, and eased with a soft deceleration curve rather than spring bounce.

## Notes

State lives at `~/Library/Application Support/Pilcrow/state.json`. On first launch after the rebrand, Pilcrow copies the old `GitFlowSwift` state forward once; the original file is left untouched. Delete `state.json` to start over. The GitHub token is never written there.

Build target, module, and bundle identifier: `Pilcrow`, `studio.intraditional.pilcrow`.

## GitHub connection

First launch opens a four-step setup: welcome, GitHub sign-in, your first local repository, and daily rhythm. Finishing setup starts a clean ledger — 0 coins, 0 sessions, level 1, no purchased cosmetics — while keeping the GitHub account you connected.

**Sign in with GitHub** uses OAuth Device Flow. Pilcrow shows a short code, opens `github.com/login/device`, and waits for approval. The public OAuth Client ID is configured in `Sources/Pilcrow/Services/GitHubOAuth.swift`; **no client secret is used or shipped**.

Pilcrow is **local-repository first**. Connecting GitHub does not import all your remote repositories. Instead, add project folders yourself from the session screen or the GitHub sheet. Only folders containing a `.git` directory (or a valid `.git` worktree file) are accepted.

If the folder has a `github.com` origin, Pilcrow links it to GitHub. Either way, commits are read directly from the local `.git` history — so unpushed commits, feature branches, and repositories without a GitHub origin are all captured.

GitHub is an enrichment, not a requirement. When connected, Pilcrow also reads pushed commits from the GitHub API and merges them with the local result (deduplicated by SHA).

Tokens are stored in the macOS Keychain, never in `state.json`. The pre-rebrand Keychain item is migrated to `studio.intraditional.pilcrow.github` on first read. You can disconnect from the sidebar or GitHub sheet at any time.

## Focus toolkit

- **Presets** — open-ended, 25, 50, or 90 minutes, with an optional automatic end at the target.
- **Intent and tags** — one line before you start, plus a closed vocabulary (`#deep`, `#refactor`, `#fix`, `#ship`, `#learn`, `#review`) for looking back.
- **Breaks** — a five-minute countdown follows an auto-ended target. It logs nothing and can be skipped.
- **Idle and lock handling** — sessions pause when the Mac sleeps, locks, or sits idle past the threshold; time away stays out of the ledger and a welcome-back notice says how much was excluded.
- **Live commits** — local git is polled while a session runs, so commits appear in the live card instead of waiting for the final sweep.
- **Quests** — daily and weekly briefs that pay coins and XP once, with progress visible on Home.
- **Streak freezes** — buy up to three at 200 coins each; a freeze automatically covers one missed day.
- **Unclaimed work** — commits made in other local repositories during the session window are offered on the report instead of being silently counted.
- **Time editing** — correct a session that ran too long; coins and XP are recalculated from the corrected window.
- **Daily strip** — today's sessions, commits, coins, streak, intent, and tags as plain text for a standup or note.
- **Weekly receipt** — a designed summary shareable as a 2× PNG or Markdown, including the day-by-day bars and tag breakdown.

## Themes

**Light** (Paper) and **Dark** (Midnight) are free and always owned. The shop sells the rest of the palette as **premade themes** — Blueprint, Oxide, Sage, Graphite, and Plum — for coins. Every theme keeps the same charcoal ink and safety-orange accent so the identity never breaks.

**Badges are not purchasable.** Each badge unlocks with a milestone: finishing a first session, completing 10 sessions, landing 5 commits in one session, holding a 7 day streak, or tracking 100 commits. The shop shows the requirement and your progress instead of a price.

## Coins

Sessions earn **2 coins per focused minute**, plus:

- a length multiplier: 1.10× from 25 minutes, 1.20× from 50, 1.35× from 90
- 6 coins per commit, capped at 72
- 2 coins per changed file, capped at 24
- 3 coins per streak day, capped at 30

A single session is capped at 500 coins. The session report shows the full ledger so the math is never a mystery.

The advanced panel in the GitHub sheet still accepts a classic personal access token (`repo`, `read:user`) as a fallback.

`GitHubProviding` in `Sources/Pilcrow/Services/GitHubService.swift` is the seam: `MockGitHubService` powers demo mode and `GitHubAPIService` handles the real REST calls.

Typefaces: Space Grotesk, Inter, and IBM Plex Mono, bundled under the SIL Open Font License.

## Privacy

Pilcrow has no analytics, telemetry, advertising, or third-party servers. Focus data stays in `~/Library/Application Support/Pilcrow/state.json`; the GitHub token lives only in the macOS Keychain. GitHub is contacted only when you connect or refresh it. Full details: [PRIVACY.md](PRIVACY.md).

## License

Pilcrow is open source under the [Apache License 2.0](LICENSE) © 2026 Intraditional Studio. The bundled typefaces remain under the SIL Open Font License 1.1; see [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

Security reports: [SECURITY.md](SECURITY.md). Release process: [docs/RELEASE.md](docs/RELEASE.md).
