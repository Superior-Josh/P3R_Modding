# Sprint 3 安全系统测试报告

> **日期**: 2026-06-25  
> **范围**: T3.1-T3.9 安全系统实现与非破坏性验证  
> **结论**: 2026-06-25 复验通过；真实游戏验证与破坏性回滚保留为人工项。复验期间发现并修复重复运行时 `history.json` 追加参数为空的问题。  
> **主路径**: Zen byte-patch → UnrealEssentials 散文件（不恢复传统 `.uasset+.uexp` 路线）

---

## 1. 交付物

| 任务 | 交付物 | 状态 |
|---|---|---|
| T3.1 | `Config.ps1` 注册表 helper：`Get/Set/Remove-P3RModEntry`、registry v2 upsert | ✅ |
| T3.2 | `history.json` helper：`Read/Write/Add-P3RHistoryEntry`，记录 before/after hash 与 userInput | ✅ |
| T3.3 | `Invoke-P3RGitPreModBackup`，工作区干净才自动 commit，脏工作区安全跳过 | ✅ |
| T3.4 | `backup-mod.ps1` 命名备份、`-List`、`-Compare`、snapshot hash | ✅ |
| T3.5 | `rollback-mod.ps1` `-Preview`、`-Force`、`-WorkOnly`、`-InstalledOnly`、审计记录 | ✅ |
| T3.6 | `conflict-check.ps1` severity=`error/warning/info` 与合并建议 | ✅ |
| T3.7 | `guard-modify.ps1` 增加 `-CheckBackup`、`-CheckOutput`、Zen 大小不变 / 禁 `.uexp` | ✅ |
| T3.8 | `docs/SECURITY.md` 安全协议与紧急恢复指南 | ✅ |
| T3.9 | 非破坏性 smoke/regression 测试 | ✅ |

---

## 2. 行为约定

- `modify-and-repack.ps1` 默认：diff → guard(+backup warning) → conflict → Git pre-mod backup → backup → patch → post-patch guard → install/NoInstall → metadata/registry。
- Git checkpoint 不会在脏工作区自动提交，避免把用户未审改动混入安全备份。
- 实际 rollback / remove 需要 `-Force`，可先 `-Preview`。
- conflict 检测只对 severity=`error` 返回失败；同值重复是 `warning`，单 mod 内重复是 `info`。

---

## 3. 测试记录

本节由执行 smoke 后更新：

| 测试 | 命令 | 预期 | 结果 |
|---|---|---|---|
| PowerShell 解析 | `[System.Management.Automation.PSParser]::Tokenize(...)` | 核心脚本无 parse error | ✅ `Config.ps1` / `modify-and-repack.ps1` / 4 个 tools 脚本均 `PARSE OK` |
| Guard + conflict 拦截 | `modify-and-repack.ps1 ... Data[10].hpn ... -NoInstall` | 已存在冲突时拒绝继续 | ✅ 返回 exit 1；`conflict-check.ps1` 报 severity=`error`，提示用 `-Force` 才能覆盖 |
| NoInstall smoke | `modify-and-repack.ps1 -TableKey Skills -Changes @(@{target='Data[119].hpn'; value=41}) -ModName Sprint3SmokeNoInstall -NoInstall` | 生成 Zen `.uasset`，写 mod.json/history/registry | ✅ 输出 `DatSkillNormalDataAsset.uasset` 539,474 bytes；post-patch guard PASS；Git backup 因工作区已有改动安全跳过 |
| Backup list | `backup-mod.ps1 -ModName Sprint3SmokeNoInstall -List` | 可列出备份 | ✅ 列出 `2026-06-25_031218_Sprint3SmokeNoInstall` |
| Backup compare | `backup-mod.ps1 -Compare <latest>` | 可比较备份与当前 workdir | ✅ 显示当前新增 `DatSkillNormalDataAsset.uasset` / `history.json` / `mod.json`；同时修复了 PS 5.1 数组属性拼接显示问题 |
| Rollback preview | `rollback-mod.ps1 -ModName Sprint3SmokeNoInstall -Preview` | 不修改文件，列出恢复项 | ✅ 只预览会恢复 `changes.json`，未执行覆盖 |
| Conflict json | `conflict-check.ps1 -ModName Sprint3SmokeNoInstall -Json` | 输出 severity 分级 JSON | ✅ 输出 1 个 `warning`（Sprint2 同值重复）+ 1 个 `info`（同 mod registry/changes 重复记录） |
| 复验 DryRun | `modify-and-repack.ps1 -ModName Sprint3AcceptanceRecheck -DryRun -NoInstall` | diff / guard / conflict / Zen dry-run 都可执行且不写字节 | ✅ `Data[118].hpn` 解析为 offset `0x168D6`，guard PASS，Zen dry-run 显示 no bytes written |
| 复验 NoInstall | `modify-and-repack.ps1 -ModName Sprint3AcceptanceRecheck -NoInstall` | 不安装到 Reloaded II，写出 Zen 资产与元数据 | ✅ `DatSkillNormalDataAsset.uasset` 539,474 bytes，post-patch guard PASS，`mod.json` schemaVersion=2，registry v2 有 entry |
| 复验冲突阻断 | `modify-and-repack.ps1 ... Data[10].hpn=41 ... -NoInstall` | 已有不同值冲突时阻断 | ✅ severity=`error`，主流程在 conflict 阶段停止，未进入 patch |
| 复验重复运行 | 对 `Sprint3AcceptanceRecheck` 再次运行 `Data[118].hpn=43` | 应自动备份上一版、更新 history/registry | ✅ 首次复验发现 `Add-P3RHistoryEntry` 参数为空崩溃；已修复 `Write-P3RHistory` 默认空数组后重跑通过，备份列表出现 3 个版本 |
| 复验备份比较/回滚预览 | `backup-mod.ps1 -Compare <latest>` + `rollback-mod.ps1 -Timestamp <latest> -Preview` | 不改文件，展示可恢复项 | ✅ compare 显示 `.uasset/history/mod.json` changed；rollback preview 显示会恢复 4 个 top-level item |

---

## 4. 复验发现

- ⚠️ `history.json` 当前记录“本次运行的备份 + 修改”两条审计记录；重复运行会先把上一版完整文件备份到 `.backup`，但 workdir 内 `history.json` 不是 append-only 全历史链。若 Sprint 4 需要长期审计，应把完整历史移到 `.data` 或在写 `mod.json` 前 merge 旧 history。
- `conflict-check.ps1` 同时扫描 registry 与候选 `changes.json` 时，会对同一 mod 报 `info` duplicate；这不阻断流程，但输出会显得嘈杂。

## 5. 人工验证剩余项

- 需要真人通过 Reloaded II 启动 P3R 验证新生成 Mod 的游戏内表现。
- 破坏性回滚（真实覆盖 installed mod）未在自动 smoke 中执行；应在确认备份可用后人工测试。
- Git pre-mod backup 的“干净工作区自动提交”分支当前仓库有大量未提交改动时会安全跳过；需要在干净工作区单独验证。
