# 更新日志

记录 ZQuota 每个版本的用户可见变更，格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

## [0.2.0] - 2026-10-10

### 新增

- BetterTouchTool 版集成：`btt/render-bars.swift` 以与 APP 版一致的绘制参数渲染电量条 PNG，`btt/install.sh` 通过 BTT 的 AppleScript 接口幂等部署 ZCode 图标、主 widget（30 秒自刷新）与刷新按钮三个条目，点击 widget 或刷新按钮可即时重拉数据上屏；与 APP 版可共存、互不干扰。要求系统设置「触控栏显示」为 App 控制模式。
- DMG 打包脚本 `scripts/build-dmg.sh` 与 README 安装说明。

### 变更

- Touch Bar 仅在 ZCode 位于前台时呈现：监听前台应用切换，其他应用激活时自动隐藏，切回 ZCode 自动恢复；菜单栏开关更名为「在 ZCode 前台时显示」。
- Touch Bar 呈现不再激活 APP，避免抢走 ZCode 的键盘焦点（改为启动时激活一次）。

## [0.1.0] - 2026-10-09

### 新增

- Touch Bar 双行分段电量条常驻展示（5 小时额度 + 周额度 + 重置倒计时）。
- 菜单栏紧凑指示与桌面 HUD 浮窗，不依赖 Touch Bar 硬件。
- 每 30 秒自动刷新；自动读取 ZCode 本地凭据，无需配置 API Key。
- 支持 macOS 11+。
