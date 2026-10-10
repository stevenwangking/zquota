#!/bin/bash
# ZQuota BTT 版部署：清理同名旧条目 → 创建 Z图标 / 主widget / 刷新按钮 → 取回 widget uuid 落盘
# 幂等，可重复执行。依赖：~/.local/bin/zquota-btt、icons/{zcode,refresh}.png
# 条目必须带 BTTBelongsToApp:'Global' 才会落全局分组并在触控栏显示（缺了只在特定 app 域可见）
set -euo pipefail

export ZQUOTA_HOME="$(echo ~)"
export ZQUOTA_DIR="$(cd "$(dirname "$0")" && pwd)"

OUT="$(osascript -l JavaScript << 'JXA_EOF'
ObjC.import('Foundation');
ObjC.import('stdlib');
const HOME = $.getenv('ZQUOTA_HOME');
const DIR = $.getenv('ZQUOTA_DIR');
const b64 = (p) => {
  const d = $.NSData.dataWithContentsOfFile(p);
  return d ? d.base64EncodedStringWithOptions(0).js : null;
};
const BTT = Application('BetterTouchTool');
const MARKER = 'zquota-btt';

// 1. 清理旧条目：按 BTTNotes 标记 + 条目名双重匹配
const NAMES = new Set(['ZQuota', 'ZQuotaIcon', 'ZQuotaRefresh']);
const all = JSON.parse(BTT.get_triggers({trigger_type: 'BTTTriggerTypeTouchBar'}));
let removed = 0;
for (const t of all) {
  const name = t['BTTWidgetName'] || t['BTTTouchBarButtonName'] || '';
  if ((NAMES.has(name) || t['BTTNotes'] === MARKER) && t['BTTUUID']) {
    BTT.delete_trigger(t['BTTUUID']);
    removed++;
  }
}
console.log(`清理旧条目: ${removed}`);

// 2. 创建三个条目（全局分组；点击动作走 137 异步非阻塞，避免触控栏卡 2 秒）
const shellCfg = '/bin/sh:::-c:::-:::';
// 异步点击动作：终端命令形式（BTT 以非阻塞方式执行，不冻结触控栏）
const tapAction = (script) => ({
  BTTPredefinedActionType: 137,
  BTTPredefinedActionName: 'Execute Terminal Command (Asynchronous, non blocking)',
  BTTTerminalCommand: `${HOME}/.local/bin/zquota-btt --refresh`,
});
const base = {
  BTTTriggerClass: 'BTTTriggerTypeTouchBar',
  BTTBelongsToApp: 'Global',
  BTTNotes: MARKER,
  BTTMergeIntoTouchBarGroups: 0,
  BTTEnabled: 1,
};

const iconBtn = {
  ...base,
  BTTTouchBarButtonName: 'ZQuotaIcon',
  BTTTriggerType: 630,
  BTTOrder: 0,
  BTTPredefinedActionType: -1,
  BTTIconData: b64(`${DIR}/icons/zcode.png`),
  BTTTriggerConfig: {
    BTTTouchBarItemIconHeight: 22, BTTTouchBarItemIconWidth: 22,
    BTTTouchBarItemPadding: 0, BTTTouchBarFreeSpaceAfterButton: '0.000000',
    BTTTouchBarOnlyShowIcon: 1, BTTTouchBarItemPlacement: 0,
    BTTTouchBarAlwaysShowButton: 0,
  },
};

const widget = {
  ...base,
  BTTWidgetName: 'ZQuota',
  BTTTriggerType: 642,
  BTTTriggerTypeDescription: 'Shell Script / Task Widget',
  BTTOrder: 1,
  BTTShellScriptWidgetGestureConfig: shellCfg,
  ...tapAction(),
  BTTTriggerConfig: {
    BTTTouchBarShellScriptString: `${HOME}/.local/bin/zquota-btt`,
    BTTTouchBarAppleScriptStringRunOnInit: true,
    BTTTouchBarScriptUpdateInterval: 30,
    BTTTouchBarItemIconWidth: 176, BTTTouchBarItemIconHeight: 30,
    BTTTouchBarItemPadding: 0, BTTTouchBarFreeSpaceAfterButton: '0.000000',
    BTTTouchBarItemPlacement: 0,
    // 双行文本：11pt（与 ZQuota 一致），第二行同字号；MaxChars 放宽避免截断
    BTTTouchBarButtonFontSize: 11,
    BTTTouchBarButtonFontSizeLine2: 11,
    BTTTouchBarLine1MaxChars: 100,
    BTTTouchBarLine2MaxChars: 100,
  },
};

const refreshBtn = {
  ...base,
  BTTTouchBarButtonName: 'ZQuotaRefresh',
  BTTTriggerType: 630,
  BTTOrder: 2,
  ...tapAction(),
  BTTIconData: b64(`${DIR}/icons/refresh.png`),
  BTTTriggerConfig: {
    BTTTouchBarItemIconHeight: 20, BTTTouchBarItemIconWidth: 20,
    BTTTouchBarItemPadding: 0, BTTTouchBarFreeSpaceAfterButton: '5.000000',
    BTTTouchBarOnlyShowIcon: 1, BTTTouchBarItemPlacement: 0,
    BTTTouchBarAlwaysShowButton: 0,
  },
};

// 3. add_new_trigger 返回 BTT 掂定的 uuid（36 位）；失败即中止避免半残状态
for (const t of [iconBtn, widget, refreshBtn]) {
  const uuid = BTT.add_new_trigger(JSON.stringify(t));
  if (!uuid || String(uuid).length !== 36) {
    throw new Error(`创建失败: ${t.BTTWidgetName || t.BTTTouchBarButtonName} → "${uuid}"`);
  }
  console.log(`已创建: ${t.BTTWidgetName || t.BTTTouchBarButtonName} → ${uuid}`);
  if (t === widget) var WIDGET_UUID = String(uuid);
}
WIDGET_UUID;
JXA_EOF
)"

UUID="$OUT" ; UUID="${UUID##*$'\n'}" ; UUID="$(tail -1 <<< "$OUT")"
if [[ "$UUID" =~ ^[0-9A-F-]{36}$ ]]; then
  printf '%s\n' "$UUID" > "$ZQUOTA_DIR/widget-uuid.txt"
  echo "widget uuid 已存: $UUID" >&2
else
  echo "警告: 未取到 widget uuid（输出: $OUT）" >&2
  exit 1
fi
