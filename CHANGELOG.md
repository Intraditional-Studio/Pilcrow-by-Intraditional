# Changelog

All notable changes to Pilcrow are documented here. Versions follow
[Semantic Versioning](https://semver.org/).

## 1.0.0 — 2026-11-12

First public release. Formerly GitFlow Swift.

### Focus

- Session clock with open-ended, 25, 50, and 90 minute presets, optional
  automatic end, pause/resume, and intent.
- Five-minute break countdown after an auto-ended target.
- Idle, sleep, and lock auto-pause with excluded-time accounting and a
  welcome-back notice.
- Closed tag vocabulary for looking back at the kind of work.
- Daily and weekly quests, streaks, and bankable streak freezes.
- Session time editing with coin and XP recalculation.
- Unclaimed work detection for commits made in other repositories during
  a session.

### Reports

- Weekly focus, commit breakdown, best-hours heatmap, session-length
  distribution, focus-versus-commits scatter, week-over-week deltas, and a
  tag summary.
- Designed weekly receipt exported as a 2× PNG or Markdown.
- Daily strip copied as plain text.

### Local-first work

- Add repositories by folder; only valid `.git` directories and worktrees
  are accepted.
- Commits are read from local history, including unpushed commits and all
  branches, with live watching during a session.
- GitHub OAuth Device Flow and PAT fallback. Tokens are stored only in the
  macOS Keychain.
- GitHub metadata is merged with local commits by SHA. GitHub remains
  optional.

### Product

- Four-step onboarding that starts a clean ledger while preserving the
  connected account and settings.
- Premade themes with free light and dark options; no theme creator.
- Earn-only badges.
- Menu bar timer with quick starts and controls.
- Native Settings window with sound, behaviour, toolkit, focus, GitHub, and
  data preferences.
- Editorial Engineering visual identity with bundled Space Grotesk, Inter,
  and IBM Plex Mono.

### Distribution

- Universal binary for Apple Silicon and Intel.
- macOS 14.0 or later.
- Ad-hoc signed; notarization requires a Developer ID certificate.
- ZIP and DMG packaging with SHA-256 checksums.
