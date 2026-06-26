# 人工测试暂缓清单

> **状态日期**: 2026-06-25
> **决策**: 暂缓真实游戏与破坏性测试，先推进 Sprint 4 非测试任务；每个功能完成后再补对应人工验证。
> **适用范围**: Sprint 3 剩余人工项 + Sprint 4 验收项。

## A. 暂缓项

| ID | 项目 | 触发条件 | 建议步骤 | 通过标准 |
|---|---|---|---|---|
| MT-001 | 新生成 Mod 游戏内表现 | `modify-and-repack.ps1` 生成安装型 Mod 后 | Reloaded II 启动 P3R；启用 Mod；进入能观察目标数值的场景 | 不崩溃，数值/效果与 `changes.json` 一致 |
| MT-002 | 破坏性回滚真实覆盖 | 备份可用且选低风险 Mod 后 | 先 `rollback-mod.ps1 -Preview`；确认恢复项；再授权 `-Force` | workdir / installed dir 恢复到指定 backup；history 记录 rollback |
| MT-003 | Git pre-mod backup 干净分支 | 工作区清洁时 | 改一处已 tracked mod 元数据；观察自动 checkpoint | 自动提交 `auto: pre-mod backup for <ModName>`，不含无关文件 |
| MT-101 | 多表 Mod 安装验证 | T4.1 多表管道实现后 | 准备含 2 张 PASS schema 的 `tables[]` 变更；运行安装 | 同一 Mod 下多张 Zen `.uasset`，路径均镜像 `UnrealEssentials/P3R/Content/...` |
| MT-102 | 多表 Mod 游戏内验证 | MT-101 通过后 | Reloaded II 启动 P3R；分别观察两表效果 | 两表修改均生效，无启动崩溃 |
| MT-103 | 多表冲突验证 | T4.1 后 | 一表与既有 Mod 冲突、另一表无冲突 | 冲突表阻断或需 `-Force`，无冲突表不被部分安装 |
| MT-104 | Sprint 4 边界测试 | T4.3/T4.4 后 | 见 §B 边界矩阵 | guard / patch 在进入游戏前拒绝不安全输入 |
| MT-105 | 最终用户场景验收 | README 用户工作流初稿完成后 | 按用户文档从自然语言需求生成 Mod | 步骤可复现，产物可启用、可回滚、可审计 |

## B. 边界 / negative 测试矩阵

> 原则：先记录可自动化的非破坏性检查；涉及安装、启动 P3R、`rollback -Force` 的项只列为人工待测，由 MT-104 汇总。

| ID | 场景 | 推荐命令 / 输入 | 预期结果 | 状态 |
|---|---|---|---|---|
| BT-001 | PowerShell 语法解析 | `PSParser::Tokenize` 覆盖 `modify-and-repack.ps1` 及 tools 脚本 | 无 parse error | ✅ 已纳入 |
| BT-002 | 空 changes | `changes=[]` 调 `Invoke-ZenPatch.ps1` 或 pipeline | 拒绝，提示 changes 不能为空 | 待跑 |
| BT-003 | 无效 ID / 越界 row | `Data[999999].hpn` | offset 越界，patch 前失败 | 待跑 |
| BT-004 | 无效字段 | `Data[10].NoSuchField` | resolver/guard 拒绝 | 待跑 |
| BT-005 | unsupported schema | `SkillCards` / FAIL schema | guard 拒绝自动写回 | 待跑 |
| BT-006 | PARTIAL 风险字段 | `Enemies.skill*` 或 `EnemyAffinity.attr` | guard 拒绝或提示人工复核 | 待跑 |
| BT-007 | file size mismatch | 构造非同长输出资产后跑 `guard-modify -CheckOutput` | post-patch guard 拒绝 | 待设计 |
| BT-008 | 路径含空格 | 默认项目路径含 `Reloaded II` | quoted path 正常处理 | ✅ 间接覆盖 |
| BT-009 | 批量空匹配 | `batch-modify.ps1` 不命中 filter | 拒绝，提示 No rows matched | 待跑 |
| BT-010 | 批量 PreviewOnly | `batch-modify.ps1 -PreviewOnly` | 只生成/展示 changes，不 patch/install | ✅ 已跑：2 rows preview |
| BT-011 | 多表 DryRun | `modify-and-repack.ps1 -MultiChangesJson ... -DryRun -NoInstall` | 逐表 dry-run，无写字节/安装 | 暂缓到 MT-101 前 |

**补跑顺序**：BT-002~BT-006 纯 guard/patch negative（确认失败在写字节前）→ BT-011 多表 `-DryRun -NoInstall` → 等人工窗口跑 MT-101/102/103。

### 已执行的非破坏性验证记录

| 时间 | 项目 | 结果 |
|---|---|---|
| 2026-06-25 | `schema-coverage-report.ps1` parse + run | ✅ PASS；38 schema，213 auto-safe / 392 blocked-manual target patterns |
| 2026-06-26 | `schema-coverage-report.ps1` 重生成（清理被污染的 `regressionReason` 后） | ✅ PASS；34 schema（19 pass / 9 partial / 2 fail / 4 skip），163 auto-safe / 404 blocked-manual target patterns |
| 2026-06-25 | `batch-modify.ps1` parse + `-PreviewOnly` | ✅ PASS；生成 `Sprint4BatchPreview/batch-changes.json`，2 个 `Data[118/119].hpn` 变更 |
| 2026-06-25 | `modify-and-repack.ps1` / `guard-modify.ps1` / `conflict-check.ps1` parse | ✅ PASS |

## C. 验收口径

Sprint 4 代码与文档交付物（T4.1 多表编排、T4.2 schema 覆盖报告、T4.3 批量 changes、T4.4 边界矩阵、T4.5 用户指南）已基本完成；端到端验收（T4.6）暂缓，因真实游戏启动、Reloaded II UI 操作与破坏性回滚需人工窗口和明确授权。

- ✅ 可声明：**Sprint 4 非破坏性代码与文档交付物已完成，进入人工验收待测阶段。**
- ❌ 不建议声明：Sprint 4 已完成最终产品验收。

最终验收需补齐 §A 中真实游戏与破坏性动作确认。
