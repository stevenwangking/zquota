---
name: release
description: 发布 ZQuota 新版本——确定版本号、更新 Info.plist 与 CHANGELOG.md、提交并打 tag，DMG 打包与 GitHub Release 由 CI 自动完成。用法 /release [版本号]（如 /release 0.3.0），缺省自动推断；「发布 x.y.z / 出个新版本」等自然语言同样路由到本 skill。
---

# Skill: release

ZQuota 一句话发版入口。分工：本地只负责「版本号 + CHANGELOG + tag」；推送 `v*` tag 后由 `.github/workflows/release.yml` 在云端构建 DMG、提取 CHANGELOG 段落为发布说明并创建 GitHub Release。**全程不做本地打包。**

## 前置检查（任一不满足即停下，向用户说明后中止）

1. 工作区干净：`git status --short` 为空；
2. `main` 与 `origin/main` 同步：`git status -sb` 无 ahead/behind；
3. 目标 tag 不存在且大于当前最新 tag（`git tag -l`、`git describe --tags --abbrev=0`）。

## 步骤

1. **确定版本号**：用户显式给出 X.Y.Z 则采用（校验格式）；否则以最新 tag 为基线，分析 `git log --oneline <基线>..HEAD`：含 feat → minor +1，仅 fix / docs / chore → patch +1，无提交 → 停止并说明。推断的版本号需先向用户展示并确认。
2. **更新版本号**：将 `Resources/Info.plist` 的 `CFBundleShortVersionString` 改为目标版本。
3. **更新 CHANGELOG.md**：以 `## [<版本号>] - <今天日期>` 在 `# 更新日志` 标题后插入新段落，按「新增 / 变更 / 修复」归纳 `git log`（仅用户可见变更，中文，条目说清行为而非文件清单）。
4. **提交并推送**：`git add` 相关文件，message 为 `chore: 发布 v<版本号>——<一句话>`，推送 main。
5. **打 tag 并推送**：`git tag -a v<版本号> -m "ZQuota <版本号>：<一句话>" && git push origin v<版本号>`，触发 CI 发版。
6. **等待并验证**：`gh run list --workflow=Release --limit 1` 找到本次 run，`gh run watch <run-id>` 等待完成；成功后 `gh release view v<版本号> --json assets -q '.assets[].name'` 确认 DMG 附件存在。
7. **回报**：Release URL、版本号与 CHANGELOG 摘要；CI 失败时给出 run 链接与失败步骤日志，修复需先征得用户同意。

## 默认禁止

删除或移动已推送的 tag、force push、跳过 CHANGELOG 或前置检查直接发版；CI 失败后自动修改 workflow 重试需用户同意。
