#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/build/TokenScope.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Resources/Info.plist")"
DMG_PATH="$ROOT_DIR/dist/TokenScope-v${VERSION}-macOS-universal.dmg"
ZIP_PATH="$ROOT_DIR/dist/TokenScope-v${VERSION}-macOS-universal.zip"
BINARY="$APP_PATH/Contents/MacOS/TokenScope"

/usr/bin/file "$BINARY" | /usr/bin/grep -q "arm64"
/usr/bin/file "$BINARY" | /usr/bin/grep -q "x86_64"
/usr/bin/plutil -lint "$APP_PATH/Contents/Info.plist"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"
/usr/bin/hdiutil verify "$DMG_PATH" >/dev/null
/usr/bin/unzip -t "$ZIP_PATH" >/dev/null

echo "Universal binary: $(/usr/bin/file "$BINARY")"
echo "Code signature: valid"
echo "DMG and ZIP: valid"

if /usr/sbin/spctl --assess --type execute "$APP_PATH" >/dev/null 2>&1; then
    echo "Gatekeeper: accepted"
else
    echo "Gatekeeper: not notarized (Developer ID is required for zero-warning downloads)"
fi
