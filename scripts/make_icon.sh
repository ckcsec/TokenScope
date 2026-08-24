#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

MASTER_PNG="$TEMP_DIR/TokenScope-1024.png"
ICONSET_DIR="$TEMP_DIR/TokenScope.iconset"
mkdir -p "$ICONSET_DIR"

swift "$ROOT_DIR/scripts/make_icon.swift" "$MASTER_PNG"

for size in 16 32 128 256 512; do
    /usr/bin/sips -z "$size" "$size" "$MASTER_PNG" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
    double_size=$((size * 2))
    /usr/bin/sips -z "$double_size" "$double_size" "$MASTER_PNG" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done

/usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$ROOT_DIR/Resources/TokenScope.icns"
echo "$ROOT_DIR/Resources/TokenScope.icns"
