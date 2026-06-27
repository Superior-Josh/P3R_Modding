# 人工测试暂缓清单

> **状态日期**: 2026-06-25
> **决策**: 暂缓真实游戏与破坏性测试，先推进 Sprint 4 非测试任务；每个功能完成后再补对应人工验证。
> **适用范围**: Sprint 3 剩余人工项 + Sprint 4 验收项。

## A. 暂缓项

| ID     | 项目                        | 触发条件                                    | 建议步骤                                                       | 通过标准                                                                        |
| ------ | --------------------------- | ------------------------------------------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| MT-001 | 新生成 Mod 游戏内表现       | `modify-and-repack.ps1` 生成安装型 Mod 后 | [§MT-001 详细步骤](#mt-001-详细测试步骤)                         | 不崩溃，数值/效果与`changes.json` 一致                                        |
| MT-002 | 破坏性回滚真实覆盖          | 备份可用且选低风险 Mod 后                   | 先`rollback-mod.ps1 -Preview`；确认恢复项；再授权 `-Force` | workdir / installed dir 恢复到指定 backup；history 记录 rollback                |
| MT-003 | Git pre-mod backup 干净分支 | 工作区清洁时                                | 改一处已 tracked mod 元数据；观察自动 checkpoint               | 自动提交`auto: pre-mod backup for <ModName>`，不含无关文件                    |
| MT-101 | 多表 Mod 安装验证           | T4.1 多表管道实现后                         | 准备含 2 张 PASS schema 的`tables[]` 变更；运行安装          | 同一 Mod 下多张 Zen`.uasset`，路径均镜像 `UnrealEssentials/P3R/Content/...` |
| MT-102 | 多表 Mod 游戏内验证         | MT-101 通过后                               | Reloaded II 启动 P3R；分别观察两表效果                         | 两表修改均生效，无启动崩溃                                                      |
| MT-103 | 多表冲突验证                | T4.1 后                                     | 一表与既有 Mod 冲突、另一表无冲突                              | 冲突表阻断或需`-Force`，无冲突表不被部分安装                                  |
| MT-104 | Sprint 4 边界测试           | T4.3/T4.4 后                                | 见 §B 边界矩阵                                                | guard / patch 在进入游戏前拒绝不安全输入                                        |
| MT-105 | 最终用户场景验收            | README 用户工作流初稿完成后                 | 按用户文档从自然语言需求生成 Mod                               | 步骤可复现，产物可启用、可回滚、可审计                                          |

## B. 边界 / negative 测试矩阵

> 原则：先记录可自动化的非破坏性检查；涉及安装、启动 P3R、`rollback -Force` 的项只列为人工待测，由 MT-104 汇总。

| ID     | 场景                | 推荐命令 / 输入                                                     | 预期结果                              | 状态                    |
| ------ | ------------------- | ------------------------------------------------------------------- | ------------------------------------- | ----------------------- |
| BT-001 | PowerShell 语法解析 | `PSParser::Tokenize` 覆盖 `modify-and-repack.ps1` 及 tools 脚本 | 无 parse error                        | ✅ 已纳入               |
| BT-002 | 空 changes          | `changes=[]` 调 `Invoke-ZenPatch.ps1` 或 pipeline               | 拒绝，提示 changes 不能为空           | 待跑                    |
| BT-003 | 无效 ID / 越界 row  | `Data[999999].hpn`                                                | offset 越界，patch 前失败             | 待跑                    |
| BT-004 | 无效字段            | `Data[10].NoSuchField`                                            | resolver/guard 拒绝                   | 待跑                    |
| BT-005 | unsupported schema  | `SkillCards` / FAIL schema                                        | guard 拒绝自动写回                    | 待跑                    |
| BT-006 | PARTIAL 风险字段    | `Enemies.skill*` 或 `EnemyAffinity.attr`                        | guard 拒绝或提示人工复核              | 待跑                    |
| BT-007 | file size mismatch  | 构造非同长输出资产后跑`guard-modify -CheckOutput`                 | post-patch guard 拒绝                 | 待设计                  |
| BT-008 | 路径含空格          | 默认项目路径含`Reloaded II`                                       | quoted path 正常处理                  | ✅ 间接覆盖             |
| BT-009 | 批量空匹配          | `batch-modify.ps1` 不命中 filter                                  | 拒绝，提示 No rows matched            | 待跑                    |
| BT-010 | 批量 PreviewOnly    | `batch-modify.ps1 -PreviewOnly`                                   | 只生成/展示 changes，不 patch/install | ✅ 已跑：2 rows preview |
| BT-011 | 多表 DryRun         | `modify-and-repack.ps1 -MultiChangesJson ... -DryRun -NoInstall`  | 逐表 dry-run，无写字节/安装           | 暂缓到 MT-101 前        |

**补跑顺序**：BT-002~BT-006 纯 guard/patch negative（确认失败在写字节前）→ BT-011 多表 `-DryRun -NoInstall` → 等人工窗口跑 MT-101/102/103。

### 已执行的非破坏性验证记录

| 时间       | 项目                                                                            | 结果                                                                                                            |
| ---------- | ------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| 2026-06-25 | `schema-coverage-report.ps1` parse + run                                      | ✅ PASS；38 schema，213 auto-safe / 392 blocked-manual target patterns                                          |
| 2026-06-26 | `schema-coverage-report.ps1` 重生成（清理被污染的 `regressionReason` 后）   | ✅ PASS；34 schema（19 pass / 9 partial / 2 fail / 4 skip），163 auto-safe / 404 blocked-manual target patterns |
| 2026-06-25 | `batch-modify.ps1` parse + `-PreviewOnly`                                   | ✅ PASS；生成`Sprint4BatchPreview/batch-changes.json`，2 个 `Data[118/119].hpn` 变更                        |
| 2026-06-25 | `modify-and-repack.ps1` / `guard-modify.ps1` / `conflict-check.ps1` parse | ✅ PASS                                                                                                         |

## C. 验收口径

Sprint 4 代码与文档交付物（T4.1 多表编排、T4.2 schema 覆盖报告、T4.3 批量 changes、T4.4 边界矩阵、T4.5 用户指南）已基本完成；端到端验收（T4.6）暂缓，因真实游戏启动、Reloaded II UI 操作与破坏性回滚需人工窗口和明确授权。

- ✅ 可声明：**Sprint 4 非破坏性代码与文档交付物已完成，进入人工验收待测阶段。**
- ❌ 不建议声明：Sprint 4 已完成最终产品验收。

最终验收需补齐 §A 中真实游戏与破坏性动作确认。

---

## MT-001 详细测试步骤

> **版本**: 2026-06-28
> **测试人**: \_\_\_\_\_\_\_\_\_\_（填写）
> **测试日期**: \_\_\_\_\_\_\_\_\_\_
> **推荐测试用例**: 亚基（Agi, Skill ID 10）hpn=400, cost=1。两个字段均为 `p3re_datskillnormaldataasset` PASS schema 的 flat scalar，前序 Sprint 1.5 实测已验证写回链路。

### 阶段 A：环境确认

| #  | 操作                                                                           | 预期结果                                 | ✅/❌ |
| -- | ------------------------------------------------------------------------------ | ---------------------------------------- | ----- |
| A1 | 启动 Reloaded II，确认 P3R 在游戏列表中且`p3rpc.essentials` 已安装           | Reloaded II 主界面可见 P3R 条目          | pass  |
| A2 | 在 Reloaded II 中确保无正在测试的 Mod（禁用所有无关 Mod）                      | 除`p3rpc.essentials` 外无其他 Mod 启用 | pass  |
| A3 | 确认工作区 git 状态干净：`git status --porcelain`                            | 无未提交修改，或有明确已知的脏文件       |       |
| A4 | 确认 Zen 原件可从 IoStore 提取或缓存可用：`tools/Output/.data/Skills.uasset` | 文件非空，首字节`00 00 00 00`          |       |

### 阶段 B：DryRun 预览（不写文件）

```powershell
# B1 — 预览 diff
.\tools\scripts\tools\diff-changes.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=400}, @{target='Data[10].cost'; value=1})

# B2 — 安全检查
.\tools\scripts\tools\guard-modify.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=400}, @{target='Data[10].cost'; value=1})

# B3 — 冲突检查（无其他 Mod 时也应通过）
.\tools\scripts\tools\conflict-check.ps1 -All

# B4 — 主流程 DryRun（模拟全过程，不实际写字节）
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=400}, @{target='Data[10].cost'; value=1}) `
  -ModName 'MT001_AgiMod' -DryRun
```

| #  | 操作                           | 预期结果                                                                        | ✅/❌ |
| -- | ------------------------------ | ------------------------------------------------------------------------------- | ----- |
| B1 | 执行 diff-changes              | 输出亚基（Agi/Skill ID 10）的 hpn: 原值→400, cost: 原值→1，含 offset 和中文名 | pass  |
| B2 | 执行 guard-modify              | 输出`All checks passed` 或绿色 PASS，0 issues/errors                          | pass  |
| B3 | 执行 conflict-check            | 输出`No conflicts detected` 或空列表                                          |       |
| B4 | 执行 modify-and-repack -DryRun | 输出`[DRY-RUN]` 字样，列举每个步骤但不写字节、不安装                          |       |

> **B1 附加检查**：记录原版 `hpn` 值（如 40），用于 D6 步的伤害推算。

### 阶段 C：真实生成与安装

```powershell
# C1 — 真实写回（生成 + 自动安装到 Reloaded II）
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=400}, @{target='Data[10].cost'; value=1}) `
  -ModName 'MT001_AgiMod' -ModAuthor 'tester' `
  -ModDisplayName 'MT-001 AgiMod' -ModDescription 'MT-001: Agi hpn=400 cost=1'
```

| #  | 操作                   | 预期结果                                                                                                                  | ✅/❌ |
| -- | ---------------------- | ------------------------------------------------------------------------------------------------------------------------- | ----- |
| C1 | 执行 modify-and-repack | 依次输出：backup → guard → diff → patch → install 各阶段，最终绿色`Mod installed successfully` 或类似确认           |       |
| C2 | 验证安装路径           | `<Reloaded-II>/Mods/MT001_AgiMod/UnrealEssentials/P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset` 存在 |       |
| C3 | 验证 ModConfig.json    | `<Reloaded-II>/Mods/MT001_AgiMod/ModConfig.json` 包含 `SupportedAppId: ["p3r.exe"]`、依赖 `p3rpc.essentials`        |       |
| C4 | 验证产物文件大小       | `.uasset` 大小与原 Zen 原件完全一致（539,474 字节）                                                                     |       |
| C5 | 验证 changes.json 产物 | Mod 输出目录有`changes.json`，记录两条变更的旧值→新值                                                                  |       |

> **如果 C1 exit code ≠ 0**：记录错误信息并中止测试。
>
> **如果 C2~C5 任何一项不符**：记录差异，不要启动游戏，先排查。

### 阶段 D：游戏内验证

| #  | 操作                                                                        | 预期结果                                                  | ✅/❌ |
| -- | --------------------------------------------------------------------------- | --------------------------------------------------------- | ----- |
| D1 | 通过 Reloaded II 启动 P3R（点击 Reloaded II 的启动按钮，非 Steam 快捷方式） | 游戏正常启动，无崩溃、无黑屏、无加载卡死                  |       |
| D2 | 在 Reloaded II UI 确认 MT001_AgiMod 已勾选启用                              | Mod 状态为启用（左侧方框已勾选）                          |       |
| D3 | 加载一个能进入战斗的存档（任意周目，推荐 4 月或更早以快速遇敌）             | 存档正常加载，角色/场景正常渲染                           |       |
| D4 | 进入一场战斗（遇敌触发）                                                    | 战斗界面正常载入，无贴图/UI 异常                          |       |
| D5 | 使用主角（或持有亚基的角色）对任意敌方施放亚基                              | 技能正常释放，动画无异常                                  |       |
| D6 | **记录亚基对同一敌人造成的显示伤害**，与 `changes.json` 对比        | 显示伤害与`原版伤害 × (400 / 原版 hpn)²` 的取整值一致 |       |
| D7 | 查看 SP 消耗是否为 1                                                        | SP 消耗显示为 1                                           |       |
| D8 | 结束战斗 → 再进行 1-2 场额外战斗并重复 D5-D7                               | 每场结果一致（伤害和 SP 消耗无波动）                      |       |
| D9 | 正常退出游戏（通过游戏内菜单退出，非 Alt+F4/任务管理器）                    | 游戏正常退出，无崩溃弹窗                                  |       |

**伤害推算示例**（以原版 hpn=40 为例）：

- 原版显示伤害 ≈ 原版显示值（假设对无耐性敌人 = 40 左右）
- hpn=400 时，显示伤害 ≈ 原版 × (400/40)² = 原版 × 100
- 若原版显示 40 → 改后显示约 4000（具体受敌人防御、等级差等因素轻微波动）

> **如果 hpn=400 导致伤害过高一击秒杀**：降低 hpn 值重新测试（如 hpn=200 → 约 25 倍）。记录实际 hpn 与伤害比，与 N² 换算对比验证。
>
> **如果 D1 启动失败/游戏崩溃**：立即进入恢复方案。

### 阶段 E：回滚与清理

```powershell
# E1 — 预览回滚
.\tools\scripts\tools\rollback-mod.ps1 -ModName MT001_AgiMod -Preview

# E3 — 执行回滚（确认 E1 预览无误后）
.\tools\scripts\tools\rollback-mod.ps1 -ModName MT001_AgiMod -Force
```

| #  | 操作                                                    | 预期结果                               | ✅/❌ |
| -- | ------------------------------------------------------- | -------------------------------------- | ----- |
| E1 | 预览回滚                                                | 输出将恢复的文件列表和备份位置         |       |
| E2 | 确认 E1 的恢复列表匹配 C5 的 changes.json               | 恢复项与安装变更一一对应               |       |
| E3 | 执行回滚 -Force                                         | 安装目录文件被移除或恢复，workdir 恢复 |       |
| E4 | 回滚后二次确认：`conflict-check.ps1 -All`             | 不再有 MT001_AgiMod 的冲突记录         |       |
| E5 | 检查`<Reloaded-II>/Mods/MT001_AgiMod/` 已被移除或禁用 | Mod 目录不存在或已被清理               |       |

### 阶段 F：回归确认（可选）

再次通过 Reloaded II 启动 P3R，加载同一存档进入战斗，确认亚基伤害和 SP 已恢复原版值。

### 通过 / 失败标准

| 判定                    | 条件                                                                           |
| ----------------------- | ------------------------------------------------------------------------------ |
| **✅ 通过**       | A~E 阶段全部步骤达到预期结果，游戏无崩溃，伤害/SP 数值与`changes.json` 一致  |
| **⚠️ 部分通过** | D 阶段数值准确但 D9 退出时轻微异常（非崩溃），记录后可标记为部分通过           |
| **❌ 失败**       | 任何步骤未达到预期结果，尤其是：P3R 崩溃、无法启动、写回文件不正确、回滚不正确 |

### 恢复方案

若测试过程中出现意外：

| 场景         | 恢复操作                                                                          |
| ------------ | --------------------------------------------------------------------------------- |
| 游戏崩溃     | 关闭 P3R → Reloaded II 禁用 MT001_AgiMod → 重启 P3R 确认恢复 → 执行 E 阶段回滚 |
| Mod 安装失败 | 删除`<Reloaded-II>/Mods/MT001_AgiMod/` → 检查工作区备份 → 重新执行阶段 C      |
| 存档损坏疑虑 | 使用不同存档槽位测试，不覆盖原存档                                                |

### 测试记录

| 阶段           | 总计步骤     | 通过 | 失败 | 备注 |
| -------------- | ------------ | ---- | ---- | ---- |
| A              | 4            |      |      |      |
| B              | 4            |      |      |      |
| C              | 5            |      |      |      |
| D              | 9            |      |      |      |
| E              | 5            |      |      |      |
| **合计** | **27** |      |      |      |

---
