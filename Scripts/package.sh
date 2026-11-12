#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

source Scripts/version.env

APP="dist/Pilcrow.app"
OUT="dist/release"
NAME="Pilcrow-$APP_VERSION"
ZIP="$OUT/$NAME-universal.zip"
DMG="$OUT/$NAME-universal.dmg"
SUMS="$OUT/SHA256SUMS.txt"

echo "Packaging Pilcrow $APP_VERSION ($BUILD_NUMBER)…"
./Scripts/build-app.sh release

mkdir -p "$OUT"
rm -f "$ZIP" "$DMG" "$SUMS"

# Archive without resource forks or extended attributes so the signature
# survives the download.
ditto -c -k --norsrc --noextattr --keepParent "$APP" "$ZIP"

# Notarize before building the DMG when a notary profile is configured.
# Create one with:
#   xcrun notarytool store-credentials pilcrow-notary \
#     --apple-id you@example.com --team-id TEAMID --password app-specific-password
if [[ -n "${PILCROW_NOTARY_PROFILE:-}" ]]; then
  echo "Submitting ZIP to Apple notary service…"
  xcrun notarytool submit "$ZIP" --keychain-profile "$PILCROW_NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  rm -f "$ZIP"
  ditto -c -k --norsrc --noextattr --keepParent "$APP" "$ZIP"
fi

# Disk image with the usual drag-to-Applications affordance.
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/Pilcrow.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Pilcrow $APP_VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

if [[ -n "${PILCROW_NOTARY_PROFILE:-}" ]]; then
  echo "Submitting DMG to Apple notary service…"
  xcrun notarytool submit "$DMG" --keychain-profile "$PILCROW_NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
fi

(
  cd "$OUT"
  shasum -a 256 "$(basename "$ZIP")" "$(basename "$DMG")" > "$(basename "$SUMS")"
)

if [[ -f "docs/RELEASE-NOTES-$APP_VERSION.md" ]]; then
  cp "docs/RELEASE-NOTES-$APP_VERSION.md" "$OUT/RELEASE-NOTES-$APP_VERSION.md"
fi

echo
echo "Packaged:"
echo "  $(pwd)/$ZIP"
echo "  $(pwd)/$DMG"
echo "  $(pwd)/$SUMS"
echo
echo "Verify with: cd $OUT && shasum -a 256 -c SHA256SUMS.txt"

if [[ -z "${PILCROW_SIGN_IDENTITY:-}" ]]; then
  cat <<'NOTE'

Note: this is an ad-hoc signed build. It runs on this Mac, but downloads on
other Macs are quarantined by Gatekeeper and need a manual allow:

  System Settings → Privacy & Security → "Open Anyway"

For Gatekeeper-clean distribution, sign with a Developer ID Application
certificate and notarize:

  PILCROW_SIGN_IDENTITY="Developer ID Application: …" \
  PILCROW_NOTARY_PROFILE=pilcrow-notary \
  ./Scripts/package.sh

See docs/RELEASE.md.
NOTE
fi
