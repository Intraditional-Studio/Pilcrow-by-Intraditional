# Release process

## Versioning

`Scripts/version.env` is the single source of truth:

```sh
APP_VERSION="1.0.0"   # marketing version, CFBundleShortVersionString
BUILD_NUMBER="100"    # monotonic build number, CFBundleVersion
```

Bump both for every public build. `CFBundleVersion` must always increase,
even for a re-release of the same marketing version. `build-app.sh` and
`package.sh` read this file, so no other place needs editing.

## 1. Build and test

```sh
./Scripts/build-app.sh debug
GITFLOW_STATE_DIR="$TMPDIR/pilcrow-selftest" \
  ./dist/Pilcrow.app/Contents/MacOS/Pilcrow --selftest
```

The self-test suite must pass before a release. Then produce the release
bundle:

```sh
./Scripts/build-app.sh release     # universal (arm64 + x86_64)
```

`build-app.sh` verifies the signature and checks that the x86_64 slice is
present. It fails loudly instead of shipping a broken bundle.

## 2. Package

```sh
./Scripts/package.sh
```

Outputs, in `dist/release/`:

- `Pilcrow-<version>-universal.zip`
- `Pilcrow-<version>-universal.dmg`
- `SHA256SUMS.txt`

Publish the checksum next to the downloads. Users verify with:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

## 3. Signing paths

### Ad-hoc (no Apple Developer account)

This is the default. The app is signed with `-` and runs on the build Mac,
but downloads on other Macs are quarantined. Users must allow the app once:

1. Try to open Pilcrow.
2. Open **System Settings → Privacy & Security**.
3. Click **Open Anyway** next to the Pilcrow notice.
4. Confirm with Touch ID or password.

On macOS 14 and later the old Control-click → Open shortcut is not
guaranteed to work. Put these instructions in the release notes and on the
download page. Do not tell users to disable Gatekeeper globally.

Ad-hoc builds also mean **Launch at Login** may fail to register. Pilcrow
disables the toggle unless the app lives in `/Applications` and surfaces
the system error if registration is refused.

### Developer ID (recommended for public distribution)

Requires an Apple Developer Program membership.

1. Install a **Developer ID Application** certificate in the login
   keychain.
2. Store notary credentials once:

   ```sh
   xcrun notarytool store-credentials pilcrow-notary \
     --apple-id you@example.com \
     --team-id TEAMID \
     --password "app-specific-password"
   ```

3. Build and package with signing and notarization enabled:

   ```sh
   PILCROW_SIGN_IDENTITY="Developer ID Application: Intraditional Studio (TEAMID)" \
   PILCROW_NOTARY_PROFILE=pilcrow-notary \
   ./Scripts/package.sh
   ```

4. Verify:

   ```sh
   codesign --verify --deep --strict --verbose=2 dist/Pilcrow.app
   spctl --assess --type execute --verbose=4 dist/Pilcrow.app
   xcrun stapler validate dist/release/Pilcrow-1.0.0-universal.dmg
   ```

Only this path gives a download that opens with a double-click and no
Gatekeeper prompt.

## 4. Test matrix before publishing

At minimum:

- Current macOS, Apple Silicon, fresh download (quarantined), fresh state.
- macOS 14.x, Intel Mac or VM, fresh download and fresh state.
- Mac **without Xcode Command Line Tools**, to confirm the git warning is
  visible and actionable.
- Move the app to `/Applications`, enable Launch at Login, sign out and
  back in.
- Connect GitHub through Device Flow, then disconnect and confirm the
  Keychain item is removed.
- Run a session with a local repo, make a commit, end the session and
  confirm the commit appears.
- Export the weekly receipt as PNG and Markdown.
- Start over from Settings and confirm progress resets while GitHub and
  settings survive.

## 5. What ships inside the bundle

- `AppIcon.icns`
- `Pilcrow_Pilcrow.bundle` (fonts + OFL license texts)
- `LICENSE.txt`, `PRIVACY.md`, `THIRD-PARTY-NOTICES.md`
- `PrivacyInfo.xcprivacy`

These are copied automatically by `build-app.sh`. Do not ship a bundle
without them.

## 6. Known constraints for 1.0

- **No automatic updates.** Users download new versions manually.
- **No crash reporting or telemetry.** Reports arrive by email only.
- **Git commit capture requires git.** Apple's Command Line Tools provide
  it; Homebrew git is also picked up. Pilcrow detects a missing install
  and offers to open the installer.
- **No Mac App Store build** (no sandbox, no Apple account).
