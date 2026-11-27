# AGENTS.md

## Overview

Pilcrow is a local-first focus tracker for macOS, by Intraditional Studio. A
session is timed, then matched against commits read directly from the local git
history — all branches, unpushed work included. GitHub is optional enrichment.
Sessions pay coins for premade themes, avatars and desk objects; badges are
earned, never sold. No telemetry, no third-party packages.

The repository folder is `GitFlow_Swift`; the product, package and bundle are
`Pilcrow`. That mismatch is historical — do not rename anything to "fix" it
without asking.

## Stack

- Swift 5.9 tools, SwiftUI + AppKit, macOS 14.0+.
- One executable target, no external dependencies.
- Resources: bundled fonts (Inter, IBM Plex Mono, Space Grotesk) and their OFL
  licences.
- State: one JSON document in Application Support, written atomically.
- Token: macOS Keychain only.

## Commands

```sh
./Scripts/build-app.sh debug      # build and assemble dist/Pilcrow.app
./Scripts/build-app.sh release    # universal arm64 + x86_64, signed, verified
./Scripts/run.sh                  # build if needed, then open
./dist/Pilcrow.app/Contents/MacOS/Pilcrow --selftest          # 87 assertions
./dist/Pilcrow.app/Contents/MacOS/Pilcrow --snapshot "$TMPDIR/snap"
./Scripts/package.sh              # ZIP, DMG, checksums, release notes
```

There is no linter. The gates are the self-test, `codesign --verify --deep
--strict`, and `lipo -archs` on release builds.

## Architecture

`Sources/Pilcrow/` is split into `App` (scenes, commands, menu bar, test and
snapshot entry points), `Features` (screens), `Design` (theme tokens,
components, charts), `Data` (`AppStore` — the single `@MainActor` source of
truth), `Models` (Codable types and pure logic) and `Services` (git, GitHub,
Keychain, sound, repository import).

Rules that matter:

- All mutable state and business rules go through `AppStore`; views are
  declarative.
- Coin, level, quest, streak and report maths live in `Models/` so they are
  testable without SwiftUI.
- Colour comes only from `AppTheme`. The accent `#FF521B` is never themed away.
- Git is read-only: `git log`, `git --version`, config reads. No fetch or push.
- Automation runs (`--selftest`, `--snapshot`, `--git-probe`, `--device-check`)
  force a temporary state directory and skip the Keychain and sound. Never run
  them against the real ledger.

## Conventions

- Copy is plain, specific and calm: no exclamation marks, no productivity
  moralising, no marketing buzzwords.
- Comments explain why, not what.
- No new dependency without a decision entry; the zero-dependency position is
  deliberate.
- Snapshot every major screen before shipping a visual change.
- British-leaning spelling in prose (`licence` as a noun), American identifiers.

<!-- obsidian:begin -->
## Obsidian project memory

- Vault: `/Users/seb/Documents/Everything`
- Project memory: `Projects/GitFlow Swift/`
- Read `README.md`, `Progress.md`, and `Decisions.md` before substantial work.
- Use the `knowledge-sync` skill after decisions, verified discoveries, and milestones.
- Never store secrets in the vault.
<!-- obsidian:end -->

The full product vault is `Pilcrow Vault/` in the same Obsidian collection —
start at `Pilcrow Master Index`. The project folder carries the short version;
do not duplicate the long-form notes there.

## Verification

Before claiming a change is done:

1. `./Scripts/build-app.sh debug` succeeds.
2. `./dist/Pilcrow.app/Contents/MacOS/Pilcrow --selftest` reports all checks
   passing.
3. Release work: `./Scripts/build-app.sh release`, then `lipo -archs` shows
   `x86_64 arm64` and `codesign --verify --deep --strict` passes.
4. Visual work: `--snapshot` and actually look at the output.
5. Packaging: `./Scripts/package.sh`, then `shasum -a 256 -c
   dist/release/SHA256SUMS.txt`.

Never report a build, a signature or a test as passing without reading the
command's output.
