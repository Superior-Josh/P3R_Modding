# 人工测试暂缓清单

> **状态日期**: 2026-06-25  
> **决策**: 暂缓真实游戏与破坏性测试；先继续逐步实现 Sprint 4 非测试任务。  
> **适用范围**: Sprint 3 剩余人工项 + Sprint 4 新增功能验收项。

## A. Sprint 3 暂缓项

| ID | 项目 | 触发条件 | 建议步骤 | 通过标准 |
|---|---|---|---|---|
| MT-001 | 新生成 Mod 游戏内表现验证 | 使用 `modify-and-repack.ps1` 生成新的安装型 Mod 后 | 通过 Reloaded II 启动 P3R；启用目标 Mod；进入能观察目标数值的场景 | 游戏不崩溃，目标数值/效果与 `changes.json` 一致 |
| MT-002 | 破坏性回滚真实覆盖 | 确认备份可用且选择低风险测试 Mod 后 | 先执行 `rollback-mod.ps1 -Preview`；确认恢复项；再人工授权 `-Force` | workdir / installed dir 恢复到指定 backup；history 记录 rollback |
| MT-003 | Git pre-mod backup 干净工作区分支 | 仓库工作区清洁时 | 对已有 tracked mod 元数据做一次修改；观察自动 Git checkpoint | 自动提交 `auto: pre-mod backup for <ModName>`，不包含无关文件 |

## B. Sprint 4 暂缓项

| ID | 项目 | 触发条件 | 建议步骤 | 通过标准 |
|---|---|---|---|---|
| MT-101 | 多表 Mod 安装验证 | T4.1 多表管道实现后 | 准备含 2 张 PASS schema 的 `tables[]` 变更；运行安装；检查 Reloaded II 目录 | 同一 Mod 下存在多张 Zen `.uasset`，路径均镜像到 `UnrealEssentials/P3R/Content/...` |
| MT-102 | 多表 Mod 游戏内验证 | MT-101 通过后 | 通过 Reloaded II 启动 P3R；分别观察两个表的效果 | 两个表的修改都生效，且无启动崩溃 |
| MT-103 | 多表冲突验证 | T4.1 多表管道实现后 | 用一个表设置与既有 Mod 不同值，另一个表无冲突 | 冲突表阻断或需 `-Force`，无冲突表不应被部分安装 |
| MT-104 | Sprint 4 边界测试 | T4.3/T4.4 后 | 覆盖空 changes、无效 ID、溢出值、unsupported target、schema mismatch、file size mismatch | guard / patch 在进入游戏前拒绝不安全输入 |
| MT-105 | 最终用户场景验收 | USER_GUIDE 初稿完成后 | 按用户文档从自然语言需求生成 Mod | 文档步骤可复现，产物可启用、可回滚、可审计 |

## 暂缓原因

- 真实游戏启动与 Reloaded II UI 操作必须真人执行，当前先不占用人工测试窗口。
- `rollback -Force` / `-RemoveInstalled` 属于破坏性动作，必须先明确授权。
- Sprint 4 先实现非破坏性代码路径；每个功能完成后再补对应人工验证记录。

## C. Sprint 4 边界 / negative 测试矩阵

> 原则：先记录可自动化的非破坏性检查；涉及安装、启动 P3R、`rollback -Force` 的项只列为人工待测。MT-104 汇总这些边界测试。

| ID | 场景 | 推荐命令 / 输入 | 预期结果 | 当前状态 |
|---|---|---|---|---|
| BT-001 | PowerShell 语法解析 | `PSParser::Tokenize` 覆盖 `modify-and-repack.ps1`、tools 脚本 | 无 parse error | ✅ 已纳入非破坏性验证 |
| BT-002 | 空 changes | `changes=[]` 调用 `Invoke-ZenPatch.ps1` 或 pipeline | 拒绝，提示 changes 不能为空 | 待跑 |
| BT-003 | 无效 ID / 越界 row | `Data[999999].hpn` | offset 越界，patch 前失败 | 待跑 |
| BT-004 | 无效字段 | `Data[10].NoSuchField` | resolver/guard 拒绝 | 待跑 |
| BT-005 | unsupported schema | `SkillCards` / FAIL schema | guard 拒绝自动写回 | 待跑 |
| BT-006 | PARTIAL 风险字段 | `Enemies` 的 `skill*` 或 `EnemyAffinity.attr` | guard 拒绝或提示人工复核 | 待跑 |
| BT-007 | file size mismatch | 人工构造非同长输出资产后跑 `guard-modify -CheckOutput` | post-patch guard 拒绝 | 待设计，避免覆盖真实资产 |
| BT-008 | 路径含空格 | 默认项目路径含 `Reloaded II` 空格 | 命令可正常处理 quoted path | ✅ 间接覆盖于既有脚本结构；真实安装暂缓 |
| BT-009 | 批量空匹配 | `batch-modify.ps1` 使用不命中 filter | 拒绝，提示 No rows matched | 待跑 |
| BT-010 | 批量 PreviewOnly | `batch-modify.ps1 -PreviewOnly` | 只生成/展示 changes，不调用 patch/install | ✅ 已跑：2 rows preview |
| BT-011 | 多表 DryRun | `modify-and-repack.ps1 -MultiChangesJson ... -DryRun -NoInstall` | 逐表 dry-run，无写字节/安装 | 暂缓到 MT-101 前 |
| BT-012 | 真实游戏启动 | 通过 Reloaded II 启动 P3R | 游戏不崩溃，效果生效 | ⏸ 暂缓，见 MT-001/MT-102 |
| BT-013 | 破坏性回滚 | `rollback-mod.ps1 -Force` | 恢复到指定备份 | ⏸ 暂缓，见 MT-002 |

**补跑顺序建议**：先跑 BT-002~BT-006 的纯 guard/patch negative tests（确认失败发生在写字节前）→ 再跑 BT-011 多表 `-DryRun -NoInstall` → 最后等人工窗口执行 MT-101/MT-102/MT-103。

### 已执行的非破坏性验证记录

| 时间 | 项目 | 结果 |
|---|---|---|
| 2026-06-25 | `schema-coverage-report.ps1` parse + run | ✅ PASS；38 schema，213 auto-safe target patterns，392 blocked/manual target patterns |
| 2026-06-25 | `batch-modify.ps1` parse + `-PreviewOnly` | ✅ PASS；生成 `Sprint4BatchPreview/batch-changes.json`，2 个 `Data[118/119].hpn` 变更 |
| 2026-06-25 | `modify-and-repack.ps1` / `guard-modify.ps1` / `conflict-check.ps1` parse | ✅ PASS |

## D. Sprint 4 验收口径

Sprint 4 代码与文档交付物（T4.1 多表编排、T4.2 schema 覆盖报告、T4.3 批量 changes、T4.4 边界测试矩阵、T4.5 用户指南）已基本完成；最终端到端验收（T4.6）暂缓，因真实游戏启动、Reloaded II UI 操作与破坏性回滚需要人工窗口和明确授权。

- ✅ 可声明：**Sprint 4 非破坏性代码与文档交付物已完成，进入人工验收待测阶段。**
- ❌ 不建议声明：Sprint 4 已完成最终产品验收。

最终验收需补齐本清单 A/B/C 节中的真实游戏与破坏性动作确认。
