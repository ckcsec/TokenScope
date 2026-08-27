#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ARM_BUILD_DIR="$ROOT_DIR/.build-release-arm64"
X86_BUILD_DIR="$ROOT_DIR/.build-release-x86_64"
APP_DIR="$ROOT_DIR/build/TokenScope.app"
UNIVERSAL_BINARY="$APP_DIR/Contents/MacOS/TokenScope"

swift build --configuration release --triple arm64-apple-macosx13.0 --scratch-path "$ARM_BUILD_DIR"
swift build --configuration release --triple x86_64-apple-macosx13.0 --scratch-path "$X86_BUILD_DIR"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
/usr/bin/lipo -create \
    "$ARM_BUILD_DIR/arm64-apple-macosx/release/TokenScope" \
    "$X86_BUILD_DIR/x86_64-apple-macosx/release/TokenScope" \
    -output "$UNIVERSAL_BINARY"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/TokenScope.icns" "$APP_DIR/Contents/Resources/TokenScope.icns"
cp "$ROOT_DIR/Resources/PrivacyInfo.xcprivacy" "$APP_DIR/Contents/Resources/PrivacyInfo.xcprivacy"

SIGNING_IDENTITY="${CODESIGN_IDENTITY:--}"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    /usr/bin/codesign --force --deep --sign - "$APP_DIR"
else
    /usr/bin/codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_DIR"
fi

/usr/bin/codesign --verify --deep --strict "$APP_DIR"

echo "$APP_DIR"
