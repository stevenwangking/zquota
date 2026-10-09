#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/ZQuota.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
EXECUTABLE_PATH="$ROOT_DIR/.build/release/ZQuota"
MODULE_CACHE="${TMPDIR:-/tmp}/zquota-module-cache"

cd "$ROOT_DIR"

if ! swift build -c release; then
    SDK_PATH="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"
    mkdir -p "$(dirname "$EXECUTABLE_PATH")" "$MODULE_CACHE"
    swiftc -sdk "$SDK_PATH" \
        -Xcc "-fmodules-cache-path=$MODULE_CACHE" \
        Sources/*.swift \
        -o "$EXECUTABLE_PATH"
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/ZQuota"
cp "Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "Resources/zquota-launcher.sh" "$RESOURCES_DIR/zquota-launcher.sh"
chmod +x "$RESOURCES_DIR/zquota-launcher.sh"
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "$APP_DIR"
