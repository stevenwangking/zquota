#!/usr/bin/env bash
set -euo pipefail

# 构建 ZQuota.app 并打包为 DMG 安装盘（UDZO 压缩，盘面含 Applications 快捷方式）。
# 用法：./scripts/build-dmg.sh [版本号] [输出目录]
# 示例：./scripts/build-dmg.sh 0.1.0 dist

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-0.1.0}"
OUT_DIR="${2:-$ROOT_DIR/dist}"
DMG_NAME="ZQuota-${VERSION}-macOS.dmg"

# 版本号随 build-app.sh 写入 app 内 Info.plist，保证 DMG 文件名与应用版本一致
APP_PATH="$(bash "$ROOT_DIR/scripts/build-app.sh" "$VERSION" | tail -n 1)"

STAGE_PARENT="$(mktemp -d)"
trap 'rm -rf "$STAGE_PARENT"' EXIT
STAGE="$STAGE_PARENT/root"
mkdir -p "$STAGE"
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR/$DMG_NAME"
hdiutil create \
    -volname "ZQuota ${VERSION}" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -size 40m \
    -format UDZO \
    -ov \
    "$OUT_DIR/$DMG_NAME" >/dev/null

hdiutil verify "$OUT_DIR/$DMG_NAME" >/dev/null
echo "$OUT_DIR/$DMG_NAME"
