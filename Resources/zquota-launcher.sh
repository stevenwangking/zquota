#!/bin/zsh
set -euo pipefail

APP_BUNDLE="${1:-}"
APP_NAME="ZQuota"
LOCK_FILE="$HOME/Library/Application Support/ZQuota/manual-quit.lock"

if [[ -z "$APP_BUNDLE" || ! -d "$APP_BUNDLE" ]]; then
    exit 0
fi

# ZCode 桌面端（ZCode 主进程）或 CLI 会话（zcode-cli，路径在 ZCode.app 包内）任一在跑即视为宿主存活
zcode_host_is_running() {
    /usr/bin/pgrep -f "/Applications/ZCode.app" >/dev/null 2>&1
}

if ! zcode_host_is_running; then
    /bin/rm -f "$LOCK_FILE" >/dev/null 2>&1 || true
    exit 0
fi

if [[ -f "$LOCK_FILE" ]]; then
    exit 0
fi

if /usr/bin/pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    exit 0
fi

/usr/bin/open "$APP_BUNDLE" >/dev/null 2>&1 || true
