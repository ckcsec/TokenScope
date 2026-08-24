#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Resources/Info.plist")"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$ROOT_DIR/build/TokenScope.app"
ZIP_PATH="$DIST_DIR/TokenScope-v${VERSION}-macOS-universal.zip"
DMG_PATH="$DIST_DIR/TokenScope-v${VERSION}-macOS-universal.dmg"
CHECKSUM_PATH="$DIST_DIR/SHA256SUMS.txt"
STAGE_DIR="$(mktemp -d)"
NOTARY_ZIP="$(mktemp -t TokenScope-notary).zip"
trap 'rm -rf "$STAGE_DIR" "$NOTARY_ZIP"' EXIT

if [[ ! -f "$ROOT_DIR/Resources/TokenScope.icns" ]]; then
    "$ROOT_DIR/scripts/make_icon.sh"
fi

"$ROOT_DIR/scripts/package_app.sh"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$NOTARY_ZIP"
    /usr/bin/xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    /usr/bin/xcrun stapler staple "$APP_PATH"
fi

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

cp -R "$APP_PATH" "$STAGE_DIR/TokenScope.app"
ln -s /Applications "$STAGE_DIR/Applications"
/usr/bin/hdiutil create -quiet -volname "TokenScope" -srcfolder "$STAGE_DIR" -ov -format UDZO "$DMG_PATH"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    /usr/bin/xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    /usr/bin/xcrun stapler staple "$DMG_PATH"
fi

(
    cd "$DIST_DIR"
    /usr/bin/shasum -a 256 "$(basename "$ZIP_PATH")" "$(basename "$DMG_PATH")" > "$(basename "$CHECKSUM_PATH")"
)

echo "$DMG_PATH"
echo "$ZIP_PATH"
echo "$CHECKSUM_PATH"
