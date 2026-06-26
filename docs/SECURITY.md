# P3R Modding 安全系统

> **状态**: Sprint 3（2026-06-25）  
> **目标**: 让 Zen byte-patch Mod 操作可预览、可备份、可回滚、可审计，并在风险字段/冲突/错误产物进入游戏前拦截。

---

## 1. 四层安全架构

| 层级 | 脚本 / 文件 | 作用 |
|---|---|---|
| 预检层 | `tools/scripts/tools/guard-modify.ps1` | schema 回归状态、field-level review、flat scalar、值大小、Zen 输出大小、禁止 `.uexp` |
| 冲突层 | `tools/scripts/tools/conflict-check.ps1` | 扫描 registry、`changes.json`、`mod.json`，按 `virtualPath + row + field` 分级报告冲突 |
| 恢复层 | `tools/scripts/tools/backup-mod.ps1` / `rollback-mod.ps1` | 命名备份、列表、比较、预览回滚、选择 work/installed 回滚 |
| 审计层 | `mod.json` / `history.json` / `mod_registry.json` / Git pre-mod backup | 记录 before/after hash、用户输入、变更目标、产物 hash、Git checkpoint 结果 |

`modify-and-repack.ps1` 默认串联这些层：diff → guard → conflict → Git pre-mod backup（脏工作区安全跳过）→ 文件备份 → Zen patch → post-patch guard → 安装 → 写元数据。

---

## 2. 元数据格式

### `tools/Output/mod/<ModName>/mod.json`

关键字段：

- `schemaVersion`: 当前为 `2`。
- `modName` / `displayName` / `author` / `description`: Mod 元数据。
- `tableKey` / `schemaKey` / `virtualPath`: 本次写回资产定位。
- `changes`: 解析后的 target、row、field、offset、byteSize、value。
- `assets`: 生成的 Zen `.uasset` 路径、长度、SHA256。
- `safety.beforeHash` / `safety.afterHash`: 修改前后 workdir + installed dir 快照聚合 hash。
- `safety.gitBackup`: 自动 Git checkpoint 的结果；工作区已有改动时会安全跳过，不会把无关改动提交。
- `safety.workSnapshot` / `safety.installedSnapshot`: 文件级 length + SHA256。

### `history.json`

数组格式，每个条目包含：

- `action`: `modify-and-repack` / `backup` / `rollback` / `remove-installed`。
- `timestamp`: 操作时间。
- `beforeHash` / `afterHash`: 操作前后快照 hash。
- `virtualPath` / `schemaKey`: 涉及资产。
- `userInput`: 自然语言或 changes/mod script 来源。
- `details`: 变更列表、备份 ID、Git checkpoint、产物信息等。

### `tools/Output/.data/mod_registry.json`

全局注册表按 `(modName, virtualPath)` upsert，供冲突检测和自然语言 Agent 查询当前已生成/已安装 Mod。

---

## 3. 常用安全命令

```powershell
# DryRun：只预览 diff/guard/conflict/offset，不部署
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999}) -ModName AgiMod -DryRun

# 创建命名备份
.\tools\scripts\tools\backup-mod.ps1 -ModName AgiMod -Name before-tweak -Description 'before hpn tweak'

# 列出备份
.\tools\scripts\tools\backup-mod.ps1 -ModName AgiMod -List

# 比较某个备份与当前 workdir
.\tools\scripts\tools\backup-mod.ps1 -ModName AgiMod -Compare 2026-06-25_120000_before-tweak

# 回滚预览（不改文件）
.\tools\scripts\tools\rollback-mod.ps1 -ModName AgiMod -Preview

# 执行回滚（必须显式 -Force）
.\tools\scripts\tools\rollback-mod.ps1 -ModName AgiMod -Force

# 只刷新 workdir，不动 Reloaded II 已安装目录
.\tools\scripts\tools\rollback-mod.ps1 -ModName AgiMod -WorkOnly -Force

# 冲突检测（错误会返回 exit code 3；同值重复为 warning）
.\tools\scripts\tools\conflict-check.ps1 -All
```

---

## 4. Guard 放行规则

自动写回必须满足：

1. schema `regressionStatus=pass`，或字段有明确 `safeWithNormalization` 元数据。
2. 字段为 flat scalar，byte size 为 1/2/4/8。
3. 不属于 `fieldReviewStatus.needsManualReview`。
4. 不涉及 union、nested struct array、string、TArray 或变长字段。
5. post-patch 输出仍为 Zen 单文件 `.uasset`，大小与 `Extracted/IoStore` 原件一致，且无 `.uexp`。

以下情况默认拒绝或要求人工复核：

- schema `fail` / `skip` / `deprecatedDuplicate` / `unsupportedUntilSchemaFix`。
- PARTIAL schema 上未复核字段（`-Strict` 时直接拒绝）。
- PersonaGrowth 的 union 技能槽、敌人技能折叠字段、敌人耐性 19 槽等 Sprint 1.5 TODO 标记项。

---

## 5. 紧急恢复流程

1. **禁用 Mod**：在 Reloaded II UI 取消勾选对应 Mod。
2. **移除已安装目录**：
   ```powershell
   .\tools\scripts\tools\rollback-mod.ps1 -ModName <ModName> -RemoveInstalled -Force
   ```
3. **回滚工作产物**：
   ```powershell
   .\tools\scripts\tools\rollback-mod.ps1 -ModName <ModName> -List
   .\tools\scripts\tools\rollback-mod.ps1 -ModName <ModName> -Timestamp <backupId> -Preview
   .\tools\scripts\tools\rollback-mod.ps1 -ModName <ModName> -Timestamp <backupId> -Force
   ```
4. **核查审计链**：查看 `tools/Output/mod/<ModName>/history.json`，确认最后一条 `afterHash` 与回滚后状态一致。
5. **必要时使用 Git**：如果自动 Git checkpoint 成功，可用常规 `git log` / `git show` 查看 pre-mod 备份提交。不要在未确认的情况下执行 `git reset --hard`。

---

## 6. 约束

- Git pre-mod backup 只在工作区干净时自动提交；如果仓库已有用户改动，会记录 skipped，避免提交无关文件。
- `history.json` 当前记录本次运行的 `backup` + `modify-and-repack` / `rollback` 审计；重复运行前的完整历史会随整个 workdir 保存到 `.backup/<ModName>/<backupId>/history.json`。如果未来需要全局 append-only 审计链，应在 Sprint 4 迁移到 `.data` 或单独审计日志。
- `rollback-mod.ps1` 的实际删除/覆盖操作要求 `-Force`；默认建议先 `-Preview`。
- 真实游戏生效仍需人工验证：安全系统只能保证文件级可逆和已知风险拦截，不能替代 Reloaded II + P3R 启动测试。

---

## 7. Sprint 3 复验结论（2026-06-25）

> 范围：T3.1–T3.9 安全系统实现与**非破坏性**验证。结论：复验通过；真实游戏验证与破坏性回滚保留为人工项（见 [MANUAL_TEST_TODO.md](MANUAL_TEST_TODO.md)）。主路径维持 Zen byte-patch → UnrealEssentials 散文件，不恢复传统 `.uasset+.uexp`。

**交付物**：registry v2 helper（`Get/Set/Remove-P3RModEntry`）、`history.json` helper（记录 before/after hash 与 userInput）、`Invoke-P3RGitPreModBackup`（干净工作区才自动 commit）、`backup-mod.ps1` 命名备份/`-List`/`-Compare`、`rollback-mod.ps1` `-Preview`/`-Force`/`-WorkOnly`/`-InstalledOnly`、`conflict-check.ps1` severity 分级、`guard-modify.ps1` `-CheckBackup`/`-CheckOutput`（Zen 大小不变 / 禁 `.uexp`）、本安全文档。

**非破坏性验证要点**（均 PASS）：

- PowerShell parse：`Config.ps1` / `modify-and-repack.ps1` / 4 个 tools 脚本无 parse error。
- Guard + conflict 拦截：已有不同值冲突时 severity=`error`，主流程在 conflict 阶段返回 exit 1，未进入 patch。
- NoInstall smoke：生成 `DatSkillNormalDataAsset.uasset` 539,474 bytes，post-patch guard PASS，脏工作区下 Git backup 安全跳过。
- backup `-List` / `-Compare`、rollback `-Preview`、conflict `-Json` 分级均按预期工作。
- 重复运行：首次复验发现 `Add-P3RHistoryEntry` 参数为空崩溃，已修复 `Write-P3RHistory` 默认空数组后重跑通过，备份列表正确累积多版本。

**复验发现 / 限制**：

- ⚠️ `history.json` 当前只记录“本次运行的 backup + modify/rollback”两条审计；workdir 内不是 append-only 全历史链。重复运行前的完整历史会随整个 workdir 备份到 `.backup/<ModName>/<backupId>/history.json`。需要长期审计时应迁到 `.data` 或单独审计日志（见 §6）。
- `conflict-check.ps1` 同时扫描 registry 与候选 `changes.json` 时会对同一 mod 报 `info` duplicate，不阻断流程但输出偏嘈杂。
