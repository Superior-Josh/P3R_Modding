# 人工测试暂缓清单

> **状态日期**: 2026-06-28
> **决策**: 暂缓真实游戏与破坏性测试，先推进 Sprint 4 非测试任务；每个功能完成后再补对应人工验证。
> **适用范围**: Sprint 3 剩余人工项 + Sprint 4 验收项。

## A. 验收口径

Sprint 4 代码与文档交付物（T4.1 多表编排、T4.2 schema 覆盖报告、T4.3 批量 changes、T4.4 边界矩阵、T4.5 用户指南）已基本完成；端到端验收（T4.6）暂缓，因真实游戏启动、Reloaded II UI 操作与破坏性回滚需人工窗口和明确授权。

- ✅ 可声明：**Sprint 4 非破坏性代码与文档交付物已完成，进入人工验收待测阶段。**
- ❌ 不建议声明：Sprint 4 已完成最终产品验收。

最终验收需补齐 §B 中真实游戏与破坏性动作确认。

## B. 暂缓项

| ID     | 项目                        | 触发条件                                    | 建议步骤                                         | 通过标准                                                                        |
| ------ | --------------------------- | ------------------------------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------- |
| MT-001 | 新生成 Mod 游戏内表现 | `modify-and-repack.ps1` 生成安装型 Mod 后 | [§D.4](#d4-mt-001单表生成--安装--游戏内验证--回滚) | 不崩溃，数值/效果与 `changes.json` 一致 |
| MT-002 | 破坏性回滚真实覆盖          | 备份可用且选低风险 Mod 后                   | [§D.5](#d5-mt-002破坏性回滚真实覆盖)               | workdir / installed dir 恢复到指定 backup；history 记录 rollback                |
| MT-003 | Git pre-mod backup 干净分支 | 工作区清洁时                                | [§D.3](#d3-mt-003git-pre-mod-backup-干净分支)      | 自动提交`auto: pre-mod backup for <ModName>`，不含无关文件                    |
| MT-101 | 多表 Mod 安装验证           | T4.1 多表管道实现后                         | [§D.6](#d6-mt-101多表-mod-安装验证)                | 同一 Mod 下多张 Zen`.uasset`，路径均镜像 `UnrealEssentials/P3R/Content/...` |
| MT-102 | 多表 Mod 游戏内验证         | MT-101 通过后                               | [§D.7](#d7-mt-102多表-mod-游戏内验证)              | 两表修改均生效，无启动崩溃                                                      |
| MT-103 | 多表冲突验证                | T4.1 后                                     | [§D.8](#d8-mt-103多表冲突验证)                     | 冲突表阻断或需`-Force`，无冲突表不被部分安装                                  |
| MT-104 | Sprint 4 边界测试           | T4.3/T4.4 后                                | [§D.2](#d2-mt-104sprint-4-边界测试汇总)            | guard / patch 在进入游戏前拒绝不安全输入                                        |
| MT-105 | 最终用户场景验收            | README 用户工作流初稿完成后                 | [§D.9](#d9-mt-105最终用户-e2e-验收)                | 步骤可复现，产物可启用、可回滚、可审计                                          |

## C. 边界 / negative 测试矩阵

> 原则：先记录可自动化的非破坏性检查；涉及安装、启动 P3R、`rollback -Force` 的项只列为人工待测，由 MT-104 汇总。

| ID     | 场景                | 推荐命令 / 输入                                                     | 预期结果                              | 状态                    |
| ------ | ------------------- | ------------------------------------------------------------------- | ------------------------------------- | ----------------------- |
| BT-001 | PowerShell 语法解析 | `PSParser::Tokenize` 覆盖 `modify-and-repack.ps1` 及 tools 脚本 | 无 parse error                        | ✅ 已纳入               |
| BT-002 | 空 changes          | `changes=[]` 调 `Invoke-ZenPatch.ps1` 或 pipeline               | 拒绝，提示 changes 不能为空           | ✅ PASS                 |
| BT-003 | 无效 ID / 越界 row  | `Data[999999].hpn`                                                | offset 越界，patch 前失败             | ✅ PASS                 |
| BT-004 | 无效字段            | `Data[10].NoSuchField`                                            | resolver/guard 拒绝                   | ✅ PASS                 |
| BT-005 | unsupported schema  | `SkillCards` / FAIL schema                                        | guard 拒绝自动写回                    | ✅ PASS                 |
| BT-006 | PARTIAL 风险字段    | `Enemies.skill*` 或 `EnemyAffinity.attr`                        | guard 拒绝或提示人工复核              | ✅ PASS                 |
| BT-007 | file size mismatch  | 构造非同长输出资产后跑`guard-modify -CheckOutput`                 | post-patch guard 拒绝                 | ✅ PASS                 |
| BT-008 | 路径含空格          | 默认项目路径含`Reloaded II`                                       | quoted path 正常处理                  | ✅ 间接覆盖             |
| BT-009 | 批量空匹配          | `batch-modify.ps1` 不命中 filter                                  | 拒绝，提示 No rows matched            | ✅ PASS                 |
| BT-010 | 批量 PreviewOnly    | `batch-modify.ps1 -PreviewOnly`                                   | 只生成/展示 changes，不 patch/install | ✅ 已跑：2 rows preview |
| BT-011 | 多表 DryRun         | `modify-and-repack.ps1 -MultiChangesJson ... -DryRun -NoInstall`  | 逐表 dry-run，无写字节/安装           | ✅ PASS                 |

## D. 详细测试步骤

> **建议执行顺序**：BT（独立负测试）→ MT-003（git）→ MT-001（单表）→ MT-002（回滚）→ MT-101→MT-102→MT-103（多表）→ MT-105（E2E）。MT-104 是 BT 的汇总运行。

### D.1 BT 边界负测试

> 边界测试可在不启动游戏、不修改文件的前提下运行，用于验证 guard 和 pipeline 在非法输入下的拒绝行为。每个 BT 可独立执行。

#### BT-002：空 changes

```powershell
$emptyJson = Join-Path $env:TEMP 'empty_changes.json'
'{"schemaKey":"p3re_skillNormal","changes":[]}' | Out-File $emptyJson -Encoding UTF8
.\tools\scripts\Invoke-ZenPatch.ps1 -ChangesJson $emptyJson -OutputDir $env:TEMP -DryRun
```

| # | 操作 | 预期结果 | ✅/❌ |
|---|---|---|---|
| 1 | 构造空 changes.json 后调用 Invoke-ZenPatch | 拒绝，报错如 `changes list is empty` 或 exit code ≠ 0 | ✅ |

#### BT-003：无效 ID / 越界 row

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[999999].hpn'; value=999}) `
  -ModName 'BT003_OOB' -DryRun
```

| # | 操作 | 预期结果 | ✅/❌ |
|---|---|---|---|
| 1 | 指定远超行数的下标（Data[999999]）跑 -DryRun | resolver 或 guard 在 patch 前报 offset 越界或行数超限 | ✅ |

#### BT-004：无效字段

```powershell
.\tools\scripts\tools\guard-modify.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].NoSuchField'; value=1})
```

| # | 操作 | 预期结果 | ✅/❌ |
|---|---|---|---|
| 1 | 指定不存在的字段名 | guard 报错 `Field 'NoSuchField' not found in schema` 或类似信息 | ✅ |

#### BT-005：unsupported schema（FAIL）

```powershell
.\tools\scripts\tools\guard-modify.ps1 -TableKey SkillCards `
  -Changes @(@{target='Data[0].skillID'; value=1})
```

| # | 操作 | 预期结果 | ✅/❌ |
|---|---|---|---|
| 1 | 使用 FAIL schema 的表（SkillCards）发起修改 | guard 报 `regressionStatus=fail` 阻断自动写回 | ✅ |

#### BT-006：PARTIAL 风险字段

```powershell
.\tools\scripts\tools\guard-modify.ps1 -TableKey Enemies `
  -Changes @(@{target='Data[0].skill'; value=1})
```

| # | 操作 | 预期结果 | ✅/❌ |
|---|---|---|---|
| 1 | 使用 PARTIAL schema 的表 + 标记为 skill 槽的字段 | guard 报错或提示人工复核（如 `manualOnlyForSkillSlots`） | ✅ |

#### BT-007：file size mismatch

```powershell
# 1. 正常生成一个已 patch 的 uasset
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=400}) `
  -ModName 'BT007_SizeTest' -NoInstall

# 2. 篡改输出文件大小（追加一字节）
$outDir = "tools\Output\mod\BT007_SizeTest"
$asset = Get-ChildItem $outDir -Filter *.uasset | Select-Object -First 1
$bytes = [System.IO.File]::ReadAllBytes($asset.FullName)
[System.IO.File]::WriteAllBytes($asset.FullName, ($bytes + @(0x00)))

# 3. 用 guard 的 -CheckOutput 检测
.\tools\scripts\tools\guard-modify.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=400}) `
  -ModName 'BT007_SizeTest' -CheckOutput -OutputAsset $asset.FullName
```

| # | 操作 | 预期结果 | ✅/❌ |
|---|---|---|---|
| 1 | 正常生成 patch | pipeline 完成，产物 .uasset 存在 | ✅ |
| 2 | 篡改输出（追加 1 字节） | 文件大小比原件大 1 字节 | ✅ |
| 3 | guard -CheckOutput | 报 `zenSizeChanged` 错误，拒绝 | ✅ |

> **注意**：执行后清理：`Remove-Item tools\Output\mod\BT007_SizeTest -Recurse -Force`

#### BT-009：批量空匹配

```powershell
.\tools\scripts\tools\batch-modify.ps1 -TableKey Skills `
  -Field cost -Value 1 -Ids 99999 -PreviewOnly
```

| # | 操作 | 预期结果 | ✅/❌ |
|---|---|---|---|
| 1 | 使用不存在的 ID 过滤 | 报错 `No rows matched the batch filter.` | ✅ |

#### BT-011：多表 DryRun

```powershell
$multiPath = Join-Path $env:TEMP 'bt011_multi.json'
@'
{
  "tables": [
    {
      "tableKey": "Skills",
      "changes": [{"target": "Data[10].hpn", "value": 400}]
    },
    {
      "tableKey": "PlayerLevelup",
      "changes": [{"target": "Data[1].exp", "value": 999}]
    }
  ]
}
'@ | Out-File $multiPath -Encoding UTF8

.\tools\scripts\modify-and-repack.ps1 -MultiChangesJson $multiPath `
  -ModName 'BT011_MultiDryRun' -DryRun -NoInstall
```

| # | 操作 | 预期结果 | ✅/❌ |
|---|---|---|---|
| 1 | 准备含 Skills + PlayerLevelup 的多表 JSON | 文件保存成功 | ✅ |
| 2 | 执行 -MultiChangesJson -DryRun -NoInstall | 逐表输出 DryRun 计划，无写字节、无安装 | ✅ |

#### 通过 / 失败标准

| 判定 | 条件 |
|---|---|
| **✅ 通过** | 全部 8 个 BT（BT-002~BT-011）均输出明确错误信息且 exit code ≠ 0，或 DryRun 输出正确计划（BT-011 exit code = 0） |
| **❌ 失败** | 任一 BT 未拒绝非法输入/未输出错误信息/exit code = 0（预期非零时）/或实际写入了文件 |

#### 测试记录

| 测试 | 结果 | 错误信息 | Exit Code |
|---|---|---|---|
| BT-002 空 changes | ✅ PASS | `changes.json must have a non-empty 'changes' array` | 1 |
| BT-003 越界 Data[999999] | ✅ PASS | `out of bounds for file (539474 bytes)` | 1 |
| BT-004 无效字段 NoSuchField | ✅ PASS | `Field 'NoSuchField' not found in schema` | 2 |
| BT-005 FAIL schema SkillCards | ✅ PASS | `regressionStatus=fail; automatic write is blocked` | 2 |
| BT-006 PARTIAL skill 字段 | ✅ PASS | `enemy skill feature requires separate reverse engineering` | 2 |
| BT-007 输出大小篡改 +1B | ✅ PASS | `Output size changed: source=539474 output=539475` | 2 |
| BT-009 批量空匹配 ID 99999 | ✅ PASS | `No rows matched the batch filter.` | 1 |
| BT-011 多表 DryRun | ✅ PASS | 逐表输出 plan，`Dry run complete - no files deployed.` | 0 |

---

### D.2 MT-104：Sprint 4 边界测试（汇总）

MT-104 是对 §C 边界矩阵全部待跑项的汇总运行。执行 [§D.1](#d1-bt-边界负测试) 的所有 BT 步骤，验证每个负测试在被拒绝时输出明确的错误信息且 **exit code ≠ 0**，或成功输出 DryRun 计划（BT-011），且**没有意外修改任何文件**。

**执行顺序**：BT-002→BT-003→BT-004→BT-005→BT-006→BT-007→BT-009→BT-011

---

### D.3 MT-003：Git pre-mod backup 干净分支

> **前提**: 工作区 git 状态干净，无未提交修改。

#### 阶段 A：确认状态

| #  | 操作                                    | 预期结果               | ✅/❌ |
| -- | --------------------------------------- | ---------------------- | ----- |
| A1 | `git status --porcelain`              | 输出为空（工作区干净） |       |
| A2 | `git rev-parse --is-inside-work-tree` | 输出`true`           |       |
| A3 | 记录当前 commit 用于清理时回退          | —                     |       |

#### 阶段 B：触发自动 checkpoint

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=400}) `
  -ModName 'MT003_GitTest' -NoInstall
```

| #  | 操作                                   | 预期结果                                                                            | ✅/❌ |
| -- | -------------------------------------- | ----------------------------------------------------------------------------------- | ----- |
| B1 | 执行 modify-and-repack（工作区干净时） | 输出`Git pre-mod backup committed: <hash>` 或 `Git pre-mod backup skipped: ...` |       |

#### 阶段 C：验证 checkpoint

| #  | 操作                                 | 预期结果                                                     | ✅/❌ |
| -- | ------------------------------------ | ------------------------------------------------------------ | ----- |
| C1 | `git log --oneline -3`             | 最近一条提交信息为`auto: pre-mod backup for MT003_GitTest` |       |
| C2 | `git diff --name-only HEAD~1 HEAD` | 输出文件都在`tools/Output/mod/MT003_GitTest/` 下           |       |
| C3 | `git status --porcelain`           | 依然干净（auto-commit 已提交更改）                           |       |

#### 阶段 D：清理

```powershell
git reset --hard HEAD~1
Remove-Item tools\Output\mod\MT003_GitTest -Recurse -Force
```

| #  | 操作                        | 预期结果                        | ✅/❌ |
| -- | --------------------------- | ------------------------------- | ----- |
| D1 | `git reset --hard HEAD~1` | 回到测试前的 commit，工作区干净 |       |

#### 通过 / 失败标准

| 判定              | 条件                                                                             |
| ----------------- | -------------------------------------------------------------------------------- |
| **✅ 通过** | A~D 全部达到预期，auto-commit 信息正确，workdir 干净                             |
| **❌ 失败** | 任何步骤未达预期，尤其是 auto-commit 未产生/commit 含无关文件/git reset 后不干净 |

#### 恢复方案

| 场景                   | 恢复操作                                                   |
| ---------------------- | ---------------------------------------------------------- |
| auto-commit 含无关文件 | `git reset --soft HEAD~1` → 恢复 stash → 选择性 commit |
| git reset 后仍有脏文件 | `git checkout -- .` 清理工作区                           |
| 测试前工作区已脏       | 不接受 auto-commit 跳过，手动 stash 或 commit 后再测       |

#### 测试记录

| 阶段           | 步骤        | 通过 | 失败 | 备注 |
| -------------- | ----------- | ---- | ---- | ---- |
| A              | 3           |      |      |      |
| B              | 1           |      |      |      |
| C              | 3           |      |      |      |
| D              | 1           |      |      |      |
| **合计** | **8** |      |      |      |

---

### D.4 MT-001：单表生成 → 安装 → 游戏内验证 → 回滚

> **测试人**: \_\_\_\_\_\_\_\_\_\_ **测试日期**: \_\_\_\_\_\_\_\_\_\_
> **推荐测试用例**: 亚基（Agi, Skill ID 10）hpn=400, cost=1。两个字段均为 `p3re_datskillnormaldataasset` PASS schema 的 flat scalar，前序 Sprint 1.5 实测已验证写回链路。

#### 阶段 A：环境确认

| #  | 操作                                                                                                     | 预期结果                                 | ✅/❌ |
| -- | -------------------------------------------------------------------------------------------------------- | ---------------------------------------- | ----- |
| A1 | 启动 Reloaded II，确认 P3R 在列表中且`p3rpc.essentials` 已安装                                         | Reloaded II 主界面可见 P3R 条目          | pass  |
| A2 | 禁用所有无关 Mod                                                                                         | 除`p3rpc.essentials` 外无其他 Mod 启用 | pass  |
| A3 | `git status --porcelain`                                                                               | 无未提交修改，或有明确已知的脏文件       | pass  |
| A4 | 确认 Zen 原件存在：`Extracted\IoStore\P3R\Content\Xrd777\Battle\Tables\DatSkillNormalDataAsset.uasset` | 文件非空，首字节`00 00 00 00`          | pass  |

#### 阶段 B：DryRun 预览（不写文件）

```powershell
.\tools\scripts\tools\diff-changes.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=400}, @{target='Data[10].cost'; value=1})

.\tools\scripts\tools\guard-modify.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=400}, @{target='Data[10].cost'; value=1})

.\tools\scripts\tools\conflict-check.ps1 -All

.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=400}, @{target='Data[10].cost'; value=1}) `
  -ModName 'MT001_AgiMod' -DryRun
```

| #  | 操作                      | 预期结果                                             | ✅/❌ |
| -- | ------------------------- | ---------------------------------------------------- | ----- |
| B1 | diff-changes              | 输出 hpn 原值→400, cost 原值→1，含 offset 和中文名 | pass  |
| B2 | guard-modify              | 绿色 PASS，0 issues/errors                           | pass  |
| B3 | conflict-check -All       | `No conflicts detected` 或空列表                   | pass  |
| B4 | modify-and-repack -DryRun | 输出`Dry run complete`，各步骤模拟                 | pass  |

> 记录原版 `hpn` 值（如 40），用于 D6 步的伤害推算。

#### 阶段 C：真实生成与安装

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=400}, @{target='Data[10].cost'; value=1}) `
  -ModName 'MT001_AgiMod' -ModAuthor 'tester' `
  -ModDisplayName 'MT-001 AgiMod' -ModDescription 'MT-001: Agi hpn=400 cost=1'
```

| #  | 操作                | 预期结果                                                                                                                  | ✅/❌ |
| -- | ------------------- | ------------------------------------------------------------------------------------------------------------------------- | ----- |
| C1 | modify-and-repack   | 管道全部 7 步完成，绿色确认                                                                                               | pass  |
| C2 | 验证安装路径        | `<Reloaded-II>/Mods/MT001_AgiMod/UnrealEssentials/P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset` 存在 | pass  |
| C3 | 验证 ModConfig.json | 含`SupportedAppId: ["p3r.exe"]`、`ModDependencies: ["p3rpc.essentials"]`                                              | pass  |
| C4 | 验证文件大小        | 产物 539,474 字节，与原版一致                                                                                             | pass  |
| C5 | 验证 changes.json   | 输出目录有`changes.json`，2 条变更记录                                                                                  | pass  |

> **C1 exit code ≠ 0** → 记录错误并中止。**C2~C5 不符** → 记录差异，不要启动游戏。

#### 阶段 D：游戏内验证

> 需要启动 P3R。

| #  | 操作                                    | 预期结果                                   | ✅/❌ |
| -- | --------------------------------------- | ------------------------------------------ | ----- |
| D1 | 通过 Reloaded II 启动 P3R               | 正常启动，无崩溃/黑屏                      |       |
| D2 | 确认 MT001_AgiMod 已勾选                | Mod 状态启用                               |       |
| D3 | 加载能进入战斗的存档（推荐 4 月或更早） | 存档正常加载                               |       |
| D4 | 进入战斗                                | 战斗界面正常                               |       |
| D5 | 主角施放亚基                            | 技能正常释放                               |       |
| D6 | 记录显示伤害，验证倍率                  | 显示伤害 ≈ 原版伤害 × √(400 / 原版 hpn) |       |
| D7 | 查看 SP 消耗                            | 消耗为 1                                   |       |
| D8 | 再打 1-2 场并重复 D5-D7                 | 数值稳定                                   |       |
| D9 | 游戏内菜单正常退出                      | 无崩溃弹窗                                 |       |

**伤害推算**（以原版 hpn=40 为例）：`hpn` 是显示伤害的平方 → 显示伤害 = √hpn。原版 ≈ √40 ≈ 6，改后 = √400 = 20，倍率 ≈ √(400/40) = √10 ≈ 3.16 倍。

> 伤害偏低 → 找无耐性敌人重测。D1 崩溃 → 进恢复方案。

#### 阶段 E：回滚与清理

```powershell
.\tools\scripts\tools\rollback-mod.ps1 -ModName MT001_AgiMod -Preview
.\tools\scripts\tools\rollback-mod.ps1 -ModName MT001_AgiMod -Force
```

| #  | 操作                                          | 预期结果                 | ✅/❌ |
| -- | --------------------------------------------- | ------------------------ | ----- |
| E1 | rollback -Preview                             | 输出恢复文件列表         |       |
| E2 | 核对 E1 列表匹配 C5 的 changes.json           | 恢复项一一对应           |       |
| E3 | rollback -Force                               | workdir / installed 恢复 |       |
| E4 | `conflict-check.ps1 -All`                   | 无 MT001_AgiMod 冲突     |       |
| E5 | 检查`<Reloaded-II>/Mods/MT001_AgiMod/` 状态 | 目录移除或清理           |       |

#### 阶段 F：回归确认（可选）

再次通过 Reloaded II 启动 P3R，确认伤害和 SP 已恢复原版值。

#### 通过 / 失败标准

| 判定                    | 条件                                                        |
| ----------------------- | ----------------------------------------------------------- |
| **✅ 通过**       | A~E 全部达到预期，游戏无崩溃，数值与 changes.json 一致      |
| **⚠️ 部分通过** | D 数值准确但 D9 退出轻微异常（非崩溃）                      |
| **❌ 失败**       | 任何步骤未达预期，尤其是崩溃/无法启动/写回不正确/回滚不正确 |

#### 恢复方案

| 场景         | 恢复操作                                                   |
| ------------ | ---------------------------------------------------------- |
| 游戏崩溃     | 关闭 P3R → Reloaded II 禁用 Mod → 重启 P3R → E 阶段回滚 |
| Mod 安装失败 | 删除 installed 目录 → 检查备份 → 重跑 C 阶段             |
| 存档损坏疑虑 | 用不同存档槽位，不覆盖原存档                               |

#### 测试记录

| 阶段           | 步骤         | 通过 | 失败 | 备注 |
| -------------- | ------------ | ---- | ---- | ---- |
| A              | 4            |      |      |      |
| B              | 4            |      |      |      |
| C              | 5            |      |      |      |
| D              | 9            |      |      |      |
| E              | 5            |      |      |      |
| **合计** | **27** |      |      |      |

---

### D.5 MT-002：破坏性回滚真实覆盖

> **前提**: 依赖 MT-001 已完成（安装了 MT001_AgiMod 并有备份），或任意已安装 Mod 有可用备份。
> **风险**: 破坏性操作，会移除 Reloaded II 已安装的 Mod 目录。

#### 阶段 A：确认备份与状态

| #  | 操作                                                                 | 预期结果                                    | ✅/❌ |
| -- | -------------------------------------------------------------------- | ------------------------------------------- | ----- |
| A1 | 列出备份：`rollback-mod.ps1 -ModName MT001_AgiMod -List`           | 输出至少一个备份条目                        |       |
| A2 | 确认 Mod 已安装：`Test-Path "tools\Reloaded II\Mods\MT001_AgiMod"` | `True`                                    |       |
| A3 | 确认 registry 有条目                                                 | registry 含 MT001_AgiMod，installedDir 非空 |       |
| A4 | 记录 workDir / installedDir 快照                                     | 供回滚后对比                                |       |

#### 阶段 B：预览回滚

```powershell
.\tools\scripts\tools\rollback-mod.ps1 -ModName MT001_AgiMod -Preview
```

| #  | 操作                                | 预期结果                                                  | ✅/❌ |
| -- | ----------------------------------- | --------------------------------------------------------- | ----- |
| B1 | rollback -Preview                   | `Preview: would restore N item(s)` 列出备份文件         |       |
| B2 | 核对 B1 列表对应 C5 的 changes.json | 含 DatSkillNormalDataAsset.uasset、changes.json、mod.json |       |

#### 阶段 C：执行回滚

```powershell
.\tools\scripts\tools\rollback-mod.ps1 -ModName MT001_AgiMod -Force
```

| #  | 操作                        | 预期结果                                                                              | ✅/❌ |
| -- | --------------------------- | ------------------------------------------------------------------------------------- | ----- |
| C1 | rollback -Force             | 输出`Rollback complete`，exit code 0                                                |       |
| C2 | workDir 恢复                | `tools\Output\mod\MT001_AgiMod\DatSkillNormalDataAsset.uasset` 存在，大小与原件一致 |       |
| C3 | installedDir 恢复           | 目录存在，有 ModConfig.json + UnrealEssentials                                        |       |
| C4 | `conflict-check.ps1 -All` | `No conflicts detected`                                                             |       |
| C5 | history 最后一条            | action =`rollback`，含 beforeHash / afterHash                                       |       |

#### 阶段 D：二次回滚验证（幂等性）

```powershell
.\tools\scripts\tools\rollback-mod.ps1 -ModName MT001_AgiMod -List
```

| #  | 操作         | 预期结果                       | ✅/❌ |
| -- | ------------ | ------------------------------ | ----- |
| D1 | 再次列出备份 | 备份列表仍在（回滚不删除备份） |       |
| D2 | 再次回滚     | 应成功执行（幂等）             |       |

> 若回滚后需重测：重新执行 MT-001 C 阶段。

#### 通过 / 失败标准

| 判定              | 条件                                                                         |
| ----------------- | ---------------------------------------------------------------------------- |
| **✅ 通过** | A~D 全部达到预期，幂等回滚成功                                               |
| **❌ 失败** | 任何步骤未达预期，尤其是回滚后文件不恢复/installedDir 未清理/registry 未更新 |

#### 恢复方案

| 场景            | 恢复操作                                                                     |
| --------------- | ---------------------------------------------------------------------------- |
| 回滚失败        | 检查 backup 目录 → 手动复制备份文件到 workDir / installedDir → 重跑 C 阶段 |
| 文件丢失        | 从 backup 时间戳目录手动恢复                                                 |
| registry 不一致 | `Remove-Item tools\Output\registry\MT002_* -Recurse -Force` 清理后重跑     |

#### 测试记录

| 阶段           | 步骤         | 通过 | 失败 | 备注 |
| -------------- | ------------ | ---- | ---- | ---- |
| A              | 4            |      |      |      |
| B              | 2            |      |      |      |
| C              | 5            |      |      |      |
| D              | 2            |      |      |      |
| **合计** | **13** |      |      |      |

---

### D.6 MT-101：多表 Mod 安装验证

> **推荐测试用例**: Skills（Data[10].hpn=400）+ PlayerLevelup（Data[1].exp=0）。两个表均为 PASS schema。

#### 阶段 A：准备多表 JSON

```powershell
$multiPath = "tools\Output\mod\MT101_MultiTable\mt101_changes.json"
New-Item -ItemType Directory -Force (Split-Path $multiPath -Parent) | Out-Null
@'
{
  "tables": [
    {
      "tableKey": "Skills",
      "changes": [{"target": "Data[10].hpn", "value": 400}]
    },
    {
      "tableKey": "PlayerLevelup",
      "changes": [{"target": "Data[1].exp", "value": 0}]
    }
  ]
}
'@ | Out-File $multiPath -Encoding UTF8
```

| #  | 操作               | 预期结果               | ✅/❌ |
| -- | ------------------ | ---------------------- | ----- |
| A1 | 构造含 2 表的 JSON | 文件保存成功，语法正确 |       |

#### 阶段 B：DryRun

```powershell
.\tools\scripts\modify-and-repack.ps1 -MultiChangesJson $multiPath `
  -ModName 'MT101_MultiTable' -DryRun -NoInstall
```

| #  | 操作        | 预期结果                                      | ✅/❌ |
| -- | ----------- | --------------------------------------------- | ----- |
| B1 | 多表 DryRun | 逐表输出 patch plan，最终`Dry run complete` |       |

#### 阶段 C：真实生成并安装

```powershell
.\tools\scripts\modify-and-repack.ps1 -MultiChangesJson $multiPath `
  -ModName 'MT101_MultiTable' -ModAuthor 'tester' `
  -ModDisplayName 'MT-101 MultiTable'
```

| #  | 操作                     | 预期结果                                                                               | ✅/❌ |
| -- | ------------------------ | -------------------------------------------------------------------------------------- | ----- |
| C1 | 多表安装                 | 两表均`PATCHED`，`Multi-table pipeline complete: 2 table(s).`                      |       |
| C2 | Skills asset 路径        | `<Reloaded-II>/Mods/MT101_MultiTable/.../DatSkillNormalDataAsset.uasset` 存在        |       |
| C3 | PlayerLevelup asset 路径 | 同 Mod 下`.../DatPlayerLevelupDataAsset.uasset` 存在                                 |       |
| C4 | 产物数量                 | `Get-ChildItem "tools\Output\mod\MT101_MultiTable" -Recurse -Filter *.uasset` 返回 2 |       |
| C5 | ModConfig.json           | `SupportedAppId` + `ModDependencies` 正确                                          |       |
| C6 | mod.json 多表标记        | `isMultiTable` = `true`                                                            |       |

#### 阶段 D：清理

```powershell
.\tools\scripts\tools\rollback-mod.ps1 -ModName MT101_MultiTable -Force
Remove-Item "tools\Reloaded II\Mods\MT101_MultiTable" -Recurse -Force
```

#### 通过 / 失败标准

| 判定              | 条件                                                                        |
| ----------------- | --------------------------------------------------------------------------- |
| **✅ 通过** | A~D 全部达到预期，两表均生成且安装路径正确，mod.json 标记 isMultiTable=true |
| **❌ 失败** | 任何步骤未达预期，尤其是 asset 缺失/路径错误/ModConfig.json 不完整          |

#### 恢复方案

| 场景                | 恢复操作                                                               |
| ------------------- | ---------------------------------------------------------------------- |
| 安装失败            | 检查 workDir 产物是否存在 → 删除 installedDir → 检查备份后重跑 C     |
| 部分表未生成        | 检查对应 schema 是否 PASS → 确认源文件存在 → 单表重试定位问题表      |
| ModConfig.json 损坏 | 手动编辑`ModConfig.json` 补 `SupportedAppId` / `ModDependencies` |

#### 测试记录

| 阶段           | 步骤         | 通过 | 失败 | 备注 |
| -------------- | ------------ | ---- | ---- | ---- |
| A              | 1            |      |      |      |
| B              | 1            |      |      |      |
| C              | 6            |      |      |      |
| D              | 2            |      |      |      |
| **合计** | **10** |      |      |      |

---

### D.7 MT-102：多表 Mod 游戏内验证

> **前提**: MT-101 已通过，MT101_MultiTable 仍安装。需要启动 P3R。

#### 阶段 A：Skills 验证

| #  | 操作                                            | 预期结果     | ✅/❌ |
| -- | ----------------------------------------------- | ------------ | ----- |
| A1 | Reloaded II 启动 P3R（MT101_MultiTable 已勾选） | 正常启动     |       |
| A2 | 加载能战斗的存档                                | 存档正常     |       |
| A3 | 战斗中使用亚基                                  | 技能正常释放 |       |
| A4 | 记录伤害，验证 √(400/原版 hpn) 倍率            | 伤害数值合理 |       |
| A5 | 确认 SP 消耗（未改 cost）                       | 原版值       |       |

#### 阶段 B：PlayerLevelup 验证

| #  | 操作                         | 预期结果          | ✅/❌ |
| -- | ---------------------------- | ----------------- | ----- |
| B1 | 查看主角经验 / 战斗获得经验  | 经验累积正常      |       |
| B2 | Data[1].exp=0，Lv 2 所需经验 | 应为 0 或极大减少 |       |
| B3 | 如可能升级到 Lv 2            | 属性正常，无崩溃  |       |
| B4 | 正常退出游戏                 | 无崩溃            |       |

> PlayerLevelup Data[N] 的 N 对应 N-1→N 级所需经验。Data[1]=0 意味着 Lv 1→Lv 2 无需经验。

#### 通过 / 失败标准

| 判定                    | 条件                                                                 |
| ----------------------- | -------------------------------------------------------------------- |
| **✅ 通过**       | A~B 全部达到预期，Skills 伤害倍率和 PlayerLevelup 经验均生效，无崩溃 |
| **⚠️ 部分通过** | 一张表生效但另一张不生效（需排查表路径或 schema 问题）               |
| **❌ 失败**       | 任何步骤未达预期，尤其是启动崩溃/技能不释放/经验异常/退出崩溃        |

#### 恢复方案

| 场景       | 恢复操作                                                           |
| ---------- | ------------------------------------------------------------------ |
| 游戏崩溃   | 关闭 P3R → Reloaded II 禁用 MT101_MultiTable → 重启 P3R → 回滚  |
| 单表不生效 | 检查对应 asset 路径是否正确 → 确认 schema 为 PASS → 单独测试该表 |
| 经验异常   | 检查 PlayerLevelup Data[N] 的 N 是否对应正确等级                   |

#### 测试记录

| 阶段           | 步骤        | 通过 | 失败 | 备注 |
| -------------- | ----------- | ---- | ---- | ---- |
| A              | 5           |      |      |      |
| B              | 4           |      |      |      |
| **合计** | **9** |      |      |      |

---

### D.8 MT-103：多表冲突验证

> **前提**: registry 中已有 Mod 占用 Skills.Data[10].hpn（如 MT001_AgiMod）。

#### 阶段 A：准备冲突源

```powershell
# 安装一个占位 Mod
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=500}) `
  -ModName 'MT103_ConflictingMod' -NoInstall

# 检查冲突
.\tools\scripts\tools\conflict-check.ps1 -All
```

| #  | 操作         | 预期结果                             | ✅/❌ |
| -- | ------------ | ------------------------------------ | ----- |
| A1 | 安装占位 Mod | pipeline 完成                        |       |
| A2 | 全局冲突检查 | Data[10].hpn 被多 Mod 共用，显示冲突 |       |

#### 阶段 B：多表冲突检测

```powershell
$multiPath = "tools\Output\mod\MT103_ConflictTest\mt103_changes.json"
New-Item -ItemType Directory -Force (Split-Path $multiPath -Parent) | Out-Null
@'
{
  "tables": [
    {
      "tableKey": "Skills",
      "changes": [{"target": "Data[10].hpn", "value": 400}]
    },
    {
      "tableKey": "PlayerLevelup",
      "changes": [{"target": "Data[1].exp", "value": 0}]
    }
  ]
}
'@ | Out-File $multiPath -Encoding UTF8

# 不加 -Force，应被冲突阻断
.\tools\scripts\modify-and-repack.ps1 -MultiChangesJson $multiPath `
  -ModName 'MT103_ConflictTest' -NoInstall
```

| #  | 操作                                                                                                   | 预期结果                                                  | ✅/❌ |
| -- | ------------------------------------------------------------------------------------------------------ | --------------------------------------------------------- | ----- |
| B1 | 构造多表 JSON（Skills 冲突 + PlayerLevelup 不冲突）                                                    | 文件保存成功                                              |       |
| B2 | 多表安装（无 -Force）                                                                                  | Skills 冲突检查失败，**PlayerLevelup 不被部分安装** |       |
| B3 | 验证未被部分安装：`Test-Path "tools\Output\mod\MT103_ConflictTest\DatPlayerLevelupDataAsset.uasset"` | 文件不存在                                                |       |

#### 阶段 C：-Force 可绕过

```powershell
.\tools\scripts\modify-and-repack.ps1 -MultiChangesJson $multiPath `
  -ModName 'MT103_ConflictTest' -Force -NoInstall
```

| #  | 操作      | 预期结果                    | ✅/❌ |
| -- | --------- | --------------------------- | ----- |
| C1 | 加 -Force | pipeline 继续，两表均 patch |       |

#### 阶段 D：清理

```powershell
Remove-Item "tools\Output\mod\MT103_ConflictingMod" -Recurse -Force
Remove-Item "tools\Output\mod\MT103_ConflictTest" -Recurse -Force
# 清理 registry 条目（通过修改 registry 或保留供后续参考）
```

#### 通过 / 失败标准

| 判定              | 条件                                                                              |
| ----------------- | --------------------------------------------------------------------------------- |
| **✅ 通过** | A~D 全部达到预期：冲突正确阻断、`-Force` 可绕过、无冲突表不被部分安装           |
| **❌ 失败** | 任何步骤未达预期，尤其是冲突未被检测/无`-Force` 仍继续/PlayerLevelup 被部分安装 |

#### 恢复方案

| 场景              | 恢复操作                                                                    |
| ----------------- | --------------------------------------------------------------------------- |
| 冲突检测遗漏      | 检查 registry 中是否存在旧 Mod 记录 → 手动`conflict-check.ps1 -All` 验证 |
| 部分安装发生      | 检查 output 目录是否有多余 asset → 手动清理未授权的 asset                  |
| registry 条目残留 | `Remove-Item tools\Output\registry\MT103_* -Recurse -Force`               |

#### 测试记录

| 阶段           | 步骤        | 通过 | 失败 | 备注 |
| -------------- | ----------- | ---- | ---- | ---- |
| A              | 2           |      |      |      |
| B              | 3           |      |      |      |
| C              | 1           |      |      |      |
| D              | 1           |      |      |      |
| **合计** | **7** |      |      |      |

---

### D.9 MT-105：最终用户 E2E 验收

> **依赖**: 上述所有 MT 测试已通过。

#### 阶段 A：自然语言 → 定位

| #  | 操作                                                     | 预期结果       | ✅/❌ |
| -- | -------------------------------------------------------- | -------------- | ----- |
| A1 | 假设用户需求："把亚基的 SP 改成 1，伤害改成 2 倍"        | —             |       |
| A2 | 查中文译名 → 定位 Skill ID 10                           | 确认亚基 ID=10 |       |
| A3 | 查 JSON 确认字段：`cost`（原值 3）、`hpn`（原值 40） | 字段确认       |       |
| A4 | 2 倍伤害：`hpn = 40 × 2² = 160`                      | hpn=160        |       |

#### 阶段 B：预览 → guard → 安装

```powershell
.\tools\scripts\tools\diff-changes.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].cost'; value=1}, @{target='Data[10].hpn'; value=160})

.\tools\scripts\tools\guard-modify.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].cost'; value=1}, @{target='Data[10].hpn'; value=160})

.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].cost'; value=1}, @{target='Data[10].hpn'; value=160}) `
  -ModName 'MT105_E2E' -ModAuthor 'user' `
  -ModDisplayName 'E2E Test Mod'
```

| #  | 操作              | 预期结果                          | ✅/❌ |
| -- | ----------------- | --------------------------------- | ----- |
| B1 | diff-changes      | 显示亚基 cost: 3→1, hpn: 40→160 |       |
| B2 | guard-modify      | 绿色 PASS                         |       |
| B3 | modify-and-repack | pipeline 7 步完成                 |       |

#### 阶段 C：验证与审计

| #  | 操作           | 预期结果                               | ✅/❌ |
| -- | -------------- | -------------------------------------- | ----- |
| C1 | 安装路径       | `<Reloaded-II>/Mods/MT105_E2E/` 存在 |       |
| C2 | changes.json   | 2 条变更，值与需求一致                 |       |
| C3 | history.json   | action=install 含时间戳                |       |
| C4 | registry       | 含 MT105_E2E 条目                      |       |
| C5 | ModConfig.json | SupportedAppId + 依赖                  |       |
| C6 | 文件大小       | 与原版一致                             |       |

#### 阶段 D：回滚与清理

```powershell
.\tools\scripts\tools\rollback-mod.ps1 -ModName MT105_E2E -Preview
.\tools\scripts\tools\rollback-mod.ps1 -ModName MT105_E2E -Force
```

| #  | 操作                        | 预期结果          | ✅/❌ |
| -- | --------------------------- | ----------------- | ----- |
| D1 | rollback -Preview           | 预览恢复列表      |       |
| D2 | rollback -Force             | 回滚完成          |       |
| D3 | `conflict-check.ps1 -All` | 无 MT105_E2E 冲突 |       |

#### 通过 / 失败标准

| 判定                    | 条件                                                                             |
| ----------------------- | -------------------------------------------------------------------------------- |
| **✅ 通过**       | A~D 全部达到预期，自然语言需求正确翻译为写回，产物可审计、可回滚                 |
| **⚠️ 部分通过** | B 阶段通过但 C/D 验证有轻微异常（非崩溃/非数据错误）                             |
| **❌ 失败**       | 任何步骤未达预期，尤其是中文→ID 定位错误/字段名错误/hpn 平方换算错误/回滚不完整 |

#### 恢复方案

| 场景                  | 恢复操作                                                                       |
| --------------------- | ------------------------------------------------------------------------------ |
| 伤害数值不符          | 确认 hpn 平方换算：`hpn_new = hpn_old × N²`；diff-changes 核对原值         |
| 自然语言→ID 定位错误 | 查`docs/zh-cn/` 确认中文译名 → 查 `docs/amicitia/DATA_MAPPING.md` 确认 ID |
| 回滚失败              | 检查 backup 目录 → 手动复制备份文件 → 重跑 rollback                          |
| registry 记录缺失     | history.json 和 mod.json 在`tools/Output/mod/MT105_E2E/` 中手动核验          |

#### 测试记录

| 阶段           | 步骤         | 通过 | 失败 | 备注 |
| -------------- | ------------ | ---- | ---- | ---- |
| A              | 4            |      |      |      |
| B              | 3            |      |      |      |
| C              | 6            |      |      |      |
| D              | 3            |      |      |      |
| **合计** | **16** |      |      |      |

---

## E. 测试依赖关系与执行顺序

```
BT-002~BT-011（独立负测试，可最先跑）
  │
  ├──→ MT-003（git checkpoint，需干净工作区）
  │
  ├──→ MT-001（单表基础安装 + 回滚，核心路径）
  │      │
  │      └──→ MT-002（回滚真实性，依赖 MT-001 的备份）
  │
  ├──→ MT-101（多表安装，依赖单表路径畅通）
  │      │
  │      ├──→ MT-102（多表游戏内验证，需 MT-101 产物）
  │      │
  │      └──→ MT-103（多表冲突，需 registry 中有占位 Mod）
  │
  ├──→ MT-104（边界汇总，即 §D.1 的 BT 集合）
  │
  └──→ MT-105（E2E 验收，依赖前述经验）

```

**建议执行顺序**：BT 负测试 → MT-003 → MT-001 → MT-002 → MT-101 → MT-102 → MT-103 → MT-105。MT-104 是 BT 的总成，可在 BT 跑完后标记完成。

---

## F. 执行记录

### 已执行的非破坏性验证记录

| 时间 | 项目 | 结果 |
|---|---|---|
| 2026-06-25 | `schema-coverage-report.ps1` parse + run | ✅ PASS；38 schema，213 auto-safe / 392 blocked-manual target patterns |
| 2026-06-26 | `schema-coverage-report.ps1` 重生成（清理被污染的 `regressionReason` 后） | ✅ PASS；34 schema（19 pass / 9 partial / 2 fail / 4 skip），163 auto-safe / 404 blocked-manual target patterns |
| 2026-06-25 | `batch-modify.ps1` parse + `-PreviewOnly` | ✅ PASS；生成 `Sprint4BatchPreview/batch-changes.json`，2 个 `Data[118/119].hpn` 变更 |
| 2026-06-25 | `modify-and-repack.ps1` / `guard-modify.ps1` / `conflict-check.ps1` parse | ✅ PASS |
| 2026-06-28 | BT-002~BT-011 全部 8 个边界负测试重新运行 | ✅ 全部 PASS；无需修复，guard/pipeline 在非法输入下正确阻断 |

### MT-001 执行记录（2026-06-28）

| 阶段 | 步骤 | 通过 | 失败 | 备注 |
|---|---|---|---|---|
| A | 4 | 4 | 0 | 环境确认全部通过 |
| B | 4 | 4 | 0 | 修复 exit code 泄露 bug（guard/diff 加 exit 0）；清理 20 个 Sprint 残留目录 |
| C | 5 | 5 | 0 | 安装验证全部通过 |
| D | 9 | | | **待执行**（需启动 P3R）|
| E | 5 | | | **待执行**（回滚）|
```
