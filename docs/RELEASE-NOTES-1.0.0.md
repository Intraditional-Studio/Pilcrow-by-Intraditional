# Pilcrow 1.0.0

First public release.

Pilcrow is a local-first focus tracker for macOS. Start a session, read
commits straight from your repositories, and spend the coins you earn on a
desk that feels like yours. GitHub is optional.

## Requirements

- macOS 14.0 or later
- Apple Silicon or Intel Mac
- Optional: git (Apple Command Line Tools) for local commit capture

## Install

1. Download `Pilcrow-1.0.0-universal.dmg` and `SHA256SUMS.txt`.
2. Verify: `shasum -a 256 -c SHA256SUMS.txt`
3. Open the disk image and drag Pilcrow to **Applications**.
4. First launch only: macOS quarantines ad-hoc signed apps. Open
   **System Settings → Privacy & Security**, click **Open Anyway** next to
   the Pilcrow notice, then confirm.
5. Follow the four-step setup: welcome, GitHub (optional), your first local
   repository, daily rhythm.

The same build is available as a ZIP:

- `Pilcrow-1.0.0-universal.zip`

## Highlights

- Focus sessions with presets, intent, tags, breaks, and idle auto-pause.
- Local git capture, including unpushed commits and every branch.
- Reports with a best-hours heatmap, session-length distribution, and a
  designed weekly receipt you can export as PNG or Markdown.
- Quests, streaks, streak freezes, earn-only badges, and premade themes.
- A live menu bar timer.
- GitHub Device Flow; the token stays in your Keychain.

## Privacy

No analytics, no telemetry, no third-party servers. Focus data stays at
`~/Library/Application Support/Pilcrow/state.json`. See `PRIVACY.md` inside
the app bundle or in the repository.

## Notes

- This build is ad-hoc signed, not notarized. Gatekeeper requires the
  one-time **Open Anyway** step above.
- Launch at Login requires Pilcrow to live in an Applications folder.
- Automatic updates are not included in 1.0; new versions are manual
  downloads with published checksums.

Pilcrow is proprietary software © 2026 Intraditional Studio. Bundled
typefaces are licensed under the SIL Open Font License 1.1.
