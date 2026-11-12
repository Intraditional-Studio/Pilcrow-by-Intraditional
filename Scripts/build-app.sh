#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

source Scripts/version.env

CONFIG=${1:-release}
APP_NAME="Pilcrow"
DIST="dist/$APP_NAME.app"
UNIVERSAL=${UNIVERSAL:-1}

echo "Building $APP_NAME $APP_VERSION ($BUILD_NUMBER), $CONFIG…"

if [[ "$CONFIG" == "release" && "$UNIVERSAL" == "1" ]]; then
  swift build -c release --arch arm64 --arch x86_64
  PRODUCTS=".build/out/Products/Release"
  [[ -d "$PRODUCTS" ]] || PRODUCTS=".build/apple/Products/Release"
else
  swift build -c "$CONFIG"
  PRODUCTS=".build/$CONFIG"
fi

BIN="$PRODUCTS/Pilcrow"
BUNDLE="$PRODUCTS/Pilcrow_Pilcrow.bundle"
[[ -f "$BIN" ]] || { echo "error: built binary not found at $BIN" >&2; exit 1; }

# Retire the pre-rebrand artifact so only one app is left in dist/.
rm -rf "dist/GitFlow Swift.app"
rm -rf "$DIST"
mkdir -p "$DIST/Contents/MacOS" "$DIST/Contents/Resources"
cp "$BIN" "$DIST/Contents/MacOS/Pilcrow"
if [[ -d "$BUNDLE" ]]; then
  cp -R "$BUNDLE" "$DIST/Contents/Resources/"
else
  echo "error: resource bundle not found at $BUNDLE (fonts and licenses would be missing)" >&2
  exit 1
fi

# Icon
if [[ ! -f "Scripts/AppIcon.icns" ]]; then
  echo "Rendering icon…"
  mkdir -p .build/icon.iconset
  swift Scripts/make-icon.swift .build/icon-1024.png
  for s in 16 32 128 256 512; do
    sips -z $s $s .build/icon-1024.png --out ".build/icon.iconset/icon_${s}x${s}.png" >/dev/null
    d=$((s*2))
    sips -z $d $d .build/icon-1024.png --out ".build/icon.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns .build/icon.iconset -o Scripts/AppIcon.icns
fi
cp Scripts/AppIcon.icns "$DIST/Contents/Resources/AppIcon.icns"

# Legal paperwork travels with the binary.
cp LICENSE "$DIST/Contents/Resources/LICENSE.txt"
cp THIRD-PARTY-NOTICES.md "$DIST/Contents/Resources/THIRD-PARTY-NOTICES.md"
cp PRIVACY.md "$DIST/Contents/Resources/PRIVACY.md"
cp Scripts/PrivacyInfo.xcprivacy "$DIST/Contents/Resources/PrivacyInfo.xcprivacy"

cat > "$DIST/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>Pilcrow</string>
    <key>CFBundleIdentifier</key><string>studio.intraditional.pilcrow</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>Pilcrow</string>
    <key>CFBundleDisplayName</key><string>Pilcrow</string>
    <key>CFBundleGetInfoString</key><string>Pilcrow by Intraditional</string>
    <key>NSHumanReadableCopyright</key><string>Pilcrow by Intraditional. © 2026 Intraditional Studio. All rights reserved.</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${APP_VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSSupportsAutomaticTermination</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
</dict>
</plist>
PLIST

plutil -lint "$DIST/Contents/Info.plist" >/dev/null

# Sign. Use a Developer ID when one is provided; otherwise ad-hoc.
SIGN_IDENTITY="${PILCROW_SIGN_IDENTITY:--}"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "Signing ad-hoc (set PILCROW_SIGN_IDENTITY for a Developer ID build)."
  codesign --force --deep --sign - "$DIST"
else
  echo "Signing with $SIGN_IDENTITY (hardened runtime)."
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$DIST"
fi

codesign --verify --deep --strict --verbose=2 "$DIST"
ARCHS=$(lipo -archs "$DIST/Contents/MacOS/Pilcrow")
echo "Architectures: $ARCHS"
if [[ "$CONFIG" == "release" && "$UNIVERSAL" == "1" && "$ARCHS" != *"x86_64"* ]]; then
  echo "error: universal build is missing the x86_64 slice" >&2
  exit 1
fi

echo "Built $DIST"
