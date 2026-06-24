# P3R Modding AI Agent — 项目开发计划

> **开发方式**: Claude Code 辅助开发（AI 生成代码 → 人工审查/测试 → 迭代）
> **总预估工时**: 108h（原始） + 28h（Sprint 1.5 补丁路线）= 136h
> **Sprint 周期**: 2 周 / Sprint（约 20-30h 有效编码时间）
>
> ## ⚠️ 2026-06-24 重大方向调整
>
> **Sprint 0 / Sprint 1 的"传统 `.uasset+.uexp` 模板法写回"路线在 P3R 上不可工作**——实测启用 AgiMod 会让游戏在初始化阶段静默崩溃（详见 [`docs/MODDING_PITFALLS.md` P-007](MODDING_PITFALLS.md#p-007-unrealessentials-iostore-资产替换偏好-zen-单文件)）。
>
> **新路线**：插入 [**Sprint 1.5: Zen Byte-Patch 写回引擎**](#sprint-15-zen-byte-patch-写回引擎-2026-06-24-起替代-sprint-1-传统格式写回)，复用 [`Extracted/IoStore/`](../Extracted/) 里的 Zen 原件 + [godofknife 010-Editor 模板](https://github.com/godofknife/010-Editor-Templates) 的字段 schema + 字节级 patch。AgiMod PoC 已端到端验证可行（亚基 hpn=999 实测约布芙 5x）。
>
> **影响**：
> - Sprint 0 的 18 个传统格式模板 / `template_index.json` / `TemplateCreator.cs` **降级为"已弃用、保留以备 fallback"**，不再是主写回路径
> - Sprint 1 的 `P3RDataTools.create` / `TemplateCreator.cs` 同上
> - Sprint 2 / 3 / 4 大部分任务仍然成立，只需把"`P3RDataTools.create` → .pak"换成"Zen patch → 散文件部署"
>
> **新工作流参考**：[`docs/ZEN_BYTE_PATCH_WORKFLOW.md`](ZEN_BYTE_PATCH_WORKFLOW.md)

---

## Sprint 总览

```
Sprint 0  ██ 基础设施补全 (12h)          ← 前置准备
Sprint 1  ████ 写回引擎 (30h)            ← ⚠️ 路线被推翻（产物在 P3R 上崩游戏，详见 P-007）
Sprint 1.5 ███ Zen Byte-Patch 写回 (28h) ← ★ 2026-06-24 新路线，AgiMod PoC 已验证
Sprint 2  ████ 工具链集成 (26h)          ← 端到端闭环
Sprint 3  ████ 安全系统 (24h)            ← 防护层
Sprint 4  ██ 扩展与验证 (16h)            ← 覆盖 + 确认
         ──
         合计: 136h (~7 周 全职，或 14 周 半职)
```

---

## Sprint 0: 基础设施补全

> **状态**：⚠️ **部分弃用 (2026-06-24)**——`tools/templates/` 下的 18 个传统格式 `.uasset+.uexp` 模板与 `template_index.json` 不再是主写回路径（仍保留作 fallback）。其它交付物（`setup.ps1` / DEVELOPER_GUIDE.md / Git 配置）保持有效。新写回路径见 [Sprint 1.5](#sprint-15-zen-byte-patch-写回引擎-2026-06-24-起替代-sprint-1-传统格式写回)。
>
> **目标**: 补齐开发环境依赖，完成所有一次性手动准备工作  
> **工期**: 12h | **依赖**: 无 | **可交付物**: 模板库 + 项目初始化脚本

### 任务清单

| ID | 任务 | 描述 | 工时 | 依赖 | Claude Code 做什么 | 人工做什么 |
|----|------|------|------|------|-------------------|-----------|
| **T0.1** | 模板导出 | 用 FModel GUI 为 18 种 DataTable 类型导出传统格式 .uasset+.uexp | 4h | — | 生成导出清单文档 | **操作 FModel GUI**（手工操作，不可 AI 化） |
| **T0.2** | 模板验证 | UAssetAPI 加载每个模板 → 不改动 .Write() → 二进制对比原始 | 2h | T0.1 | 编写模板验证测试脚本 | 审查验证结果，确认 18/18 通过 |
| **T0.3** | 模板目录建立 | 将验证通过的模板存入 `tools/templates/`，建立命名规范 | 0.5h | T0.2 | 生成模板索引 JSON | 确认目录结构 |
| **T0.4** | 项目初始化脚本 | 编写 `setup.ps1`：检查运行时 → 编译 P3RDataTools → 验证容器 → 生成配置文件 | 2h | — | 编写完整 setup.ps1 | 从头测试安装流程 |
| **T0.5** | 开发环境文档 | 编写 `docs/DEVELOPER_GUIDE.md`：环境要求、编译步骤、调试方法 | 1.5h | T0.4 | 生成开发者文档初稿 | 审查并补充游戏特有细节 |
| **T0.6** | Git 工作流配置 | 配置 `.gitignore` 更新、Git LFS（如需）、分支策略 | 0.5h | — | 生成配置建议 | 执行并验证 |
| **T0.7** | Sprint 0 评审 | 确认模板库完整、setup.ps1 可从头安装、文档清晰 | 1.5h | T0.1-T0.6 | — | 逐项检查验收 |

### 交付物

- [x] `tools/templates/` 目录，含 18 种 .uasset+.uexp 模板 ← **已通过 P3RDataTools create-template 自动生成**
- [x] `tools/templates/template_index.json` 模板索引
- [x] `setup.ps1` 项目初始化脚本
- [x] `docs/DEVELOPER_GUIDE.md` 开发指南
- [x] `tools/scripts/verify-templates.ps1` 模板验证脚本
- [x] 模板往返验证报告（18/18 通过）← **已验证: 全部 Magic=C1832A9E**

### 任务依赖图

```
T0.1 (FModel导出)
  │
  └──→ T0.2 (模板验证)
         │
         └──→ T0.3 (存入templates/)
                │
                └──→ T0.7 (Sprint 评审)
                      
T0.4 (setup.ps1) ──→ T0.5 (开发文档) ──→ T0.7
T0.6 (Git配置) ──────────────────────→ T0.7
```

---

## Sprint 1: 写回引擎

> **状态**：⚠️ **路线已弃用 (2026-06-24)**——TemplateCreator.cs 输出的传统 `.uasset+.uexp` 散文件在 P3R 上 boot-crash 游戏（详见 [`docs/MODDING_PITFALLS.md` P-007](MODDING_PITFALLS.md#p-007-unrealessentials-iostore-资产替换偏好-zen-单文件)）。`TemplateCreator.cs` / `P3RDataTools.create` 命令保留在仓库内**仅供未来 IoStore-aware 重新封装时复用**，不再是主写回入口。**新写回引擎**见 [Sprint 1.5](#sprint-15-zen-byte-patch-写回引擎-2026-06-24-起替代-sprint-1-传统格式写回)。
>
> **目标**: 实现模板法写回，打通「修改 JSON → .uasset+.uexp → .pak」全链路
> **工期**: 30h | **依赖**: Sprint 0 完成 | **可交付物**: 可用的 P3RDataTools create 命令

### 任务清单

| ID | 任务 | 描述 | 工时 | 依赖 | Claude Code 做什么 | 人工做什么 |
|----|------|------|------|------|-------------------|-----------|
| **T1.1** | UAssetAPI 模板加载模块 | 实现 `TemplateLoader.cs`：根据 JSON Type 字段匹配模板、加载 .uasset+.uexp、定位 DataTableExport | 4h | T0.3 | 编写 TemplateLoader 类（~150 行 C#） | 审查代码、验证加载逻辑 |
| **T1.2** | 行数据替换引擎 | 实现 `DataTablePatcher.cs`：遍历 Export → 定位 StructPropertyData → 替换行值 → 调整行数 | 6h | T1.1 | 编写 DataTablePatcher 类（~300 行 C#），处理嵌套结构 | 审查代码、验证替换逻辑 |
| **T1.3** | 输出写回模块 | 实现 `AssetWriter.cs`：调用 UAssetAPI `.Write()` 输出 .uasset+.uexp，处理 manifest 生成 | 3h | T1.2 | 编写 AssetWriter 类（~100 行 C#） | 审查代码 |
| **T1.4** | CLI 集成 | 在 Program.cs 中重写 `CreateUassetFromJson`，接入三个新模块，新增 `create` 命令 | 3h | T1.3 | 重写 Program.cs 相关方法（~150 行） | 审查代码、CLI 测试 |
| **T1.5** | 往返测试脚本 | 编写自动化测试：IoStore read → 修改 JSON → create → UAssetAPI 重新加载 → 断言值一致 | 3h | T1.4 | 编写测试 PowerShell 脚本 + 测试用例数据 | 执行测试、分析失败 |
| **T1.6** | 游戏加载测试（关键） | 对 DatSkillNormalDataAsset 做最小修改 → 打包 _P.pak → 放入 Paks/ → 启动游戏 | 3h | T1.5 | 生成测试用最小修改 JSON | **手动启动游戏、观察运行** |
| **T1.7** | 问题修复与调优 | 根据 T1.5/T1.6 的发现修复 bug：文件头、偏移、行数匹配、StructProperty 嵌套 | 6h | T1.6 | 分析问题根因、生成修复代码 | 验证修复、重新测试 |
| **T1.8** | Sprint 1 评审 | 确认写回引擎对 18 种模板全部可用、游戏加载成功、往返测试通过 | 2h | T1.7 | 生成测试报告 | 逐项验收 |

### 交付物

> **方案变更**: 原计划使用 UAssetAPI load→modify→write 流程，但 UAssetAPI 无法加载我们生成的模板（header 解析失败）。
> 改用 **直接二进制序列化方案**：TemplateCreator.cs（已在 Sprint 0 验证 Magic=C1832A9E）直接从修改后的 JSON 生成 .uasset+.uexp。
> 不需要 TemplateLoader/DataTablePatcher/AssetWriter —— TemplateCreator.cs 替代了全部三个模块。

- [x] `tools/P3RDataTools/TemplateCreator.cs` 统一写回引擎（替代 TemplateLoader+Patcher+Writer）
- [x] `tools/P3RDataTools/Program.cs` 更新（`create` 命令 + `CreateUassetFromJson` 重写）
- [x] `tools/scripts/modify-and-repack.ps1` 全自动编排（read→modify→create→pack）
- [x] 往返测试：read → modify → create → verify (Magic=C1832A9E)
- [x] 游戏加载测试：**P3R 不能直接加载 Paks/ 下的 .pak**（IoStore 优先）
- [x] 解决方案：**Reloaded II + File Emulation Framework**（P3R mod 社区标准方案）
- [ ] T1.6 最终验证：通过 Reloaded II 加载 TestLoad_P.pak 并确认数据生效 ← **待人工**

### 任务依赖图

```
T1.1 (模板加载)
  │
  └──→ T1.2 (数据替换) 
         │
         └──→ T1.3 (输出写回)
                │
                └──→ T1.4 (CLI集成)
                       │
                       └──→ T1.5 (往返测试)
                              │
                              └──→ T1.6 (游戏测试) ← ⚠️ 最高风险点
                                     │
                                     └──→ T1.7 (修复调优)
                                            │
                                            └──→ T1.8 (评审)
```

> ⚠️ **风险提示**: T1.6 如果失败，T1.7 可能延长 2-3 倍工时。最坏情况需探索 hex-editing 或 C++ 替代方案。

---

## Sprint 1.5: Zen Byte-Patch 写回引擎 (2026-06-24 起替代 Sprint 1 传统格式写回)

> **目标**: 把 AgiMod PoC 验证过的 Zen 字节级 patch 工作流工程化进 P3RDataTools；从 `Extracted/IoStore/` 取原件 → 010 模板算字段偏移 → JSON-driven byte patch → 部署到 `<Mod>/UnrealEssentials/<虚拟路径>/`。
>
> **工期**: 28h | **依赖**: AgiMod PoC（已完成）| **可交付物**: `P3RDataTools.exe patch` 命令 + 完整 010 模板库 + 改造后的 modify-and-repack.ps1
>
> **背景与论据**：
> - Sprint 1 的传统 `.uasset+.uexp` 路径会导致 P3R 启动崩溃（[P-007](MODDING_PITFALLS.md#p-007-unrealessentials-iostore-资产替换偏好-zen-单文件)）
> - 项目内已有可工作的参考 mod（[`p3rpc.AllInherit`](../tools/Reloaded%20II/Mods/p3rpc.AllInherit/) / [`p3r.qol.arkemultiplier`](../tools/Reloaded%20II/Mods/p3r.qol.arkemultiplier/)）都是 Zen 单文件（首字节 `00 00 00 00`、无 `.uexp`、大小与 IoStore 原件**完全相同**——byte-patch in-place）
> - [godofknife/010-Editor-Templates](https://github.com/godofknife/010-Editor-Templates) 已提供 41 个 p3re 表的字段 schema，免去逆向工程负担
> - 2026-06-24 AgiMod PoC：把 Agi 的 `hpn` 从 40 改成 999（offset 0x0246A 写 2 字节 `E7 03`），游戏内实测亚基约为布芙 5x 显示伤害（√(999/40) = 5.00 精确吻合）

### 任务清单

| ID | 任务 | 描述 | 工时 | 依赖 | Claude Code 做什么 | 人工做什么 |
|----|------|------|------|------|-------------------|-----------|
| **T1.5.1** ✅ | 010 模板库导入 | 下载 [godofknife 仓库](https://github.com/godofknife/010-Editor-Templates) 的 41 个 p3re 模板到 `tools/templates-010/`，固化在仓库内 | 1h | — | 已完成（2026-06-24）：44/45 文件 + README，仅 `p3re_BP_BtlCalcuasset.bt` 因网络超时未抓取（非 DataTable，不影响主路径）| 审查 LICENSE 与上游协议 |
| **T1.5.2** ✅ | `.bt` 模板解析器 | 写 [`Parse-BtTemplate.ps1`](../tools/scripts/Parse-BtTemplate.ps1) 把 `.bt` 解析成 `{tableName, rowStructName, rowSize, headerSizeHint, fields:[{name, offsetInRow, byteSize, type}]}` JSON | 6h | T1.5.1 | 已完成（2026-06-24）：解析 **29/41** 模板成功（含 `skillNormal` 21/21 字段对 AgiMod 实测值精确匹配，文件 offset 0x0246A 完全复现）；schema 持久化到 `tools/templates-010/schemas/` | 已交叉验证 AgiMod ground truth |
| **T1.5.2b** ✅ | 解析器扩展（边缘表型）| 加 3 种 root struct 类型：单命名行（`Some s;`）/ 多命名行（`DT_*` 风格 `safety/easy/normal/hard/risky`）/ intrinsic-array typedef（`}theurgyBoostData[18];`）| 3h | T1.5.2 | **已完成（2026-06-24）**：覆盖率 29 → **38/41**（92%），新增 4 种 `tableShape`：`indexed_rows`(29) / `named_rows`(1, DT_BtlDIfficultyParam) / `single_record`(5) / `single_record_array`(3, 含 Theurgy boost) | 验证 8 个新表型 |
| **T1.5.3** ✅ | Header 自动校准 | 用 `fileSize - rowSize × rowCount = headerSize` 反推真实 header（模板里的 `unk[N]` 是估算），失败时回退到模板值并 warn | 2h | T1.5.2b | **已完成（2026-06-24）**：[`Calibrate-SchemaHeaders.ps1`](../tools/scripts/Calibrate-SchemaHeaders.ps1) 把 34/38 schema 校准到精确 `headerSize`，黄金锚点 `p3re_skillNormal=1174` 与 AgiMod PoC 完全吻合；3 个 dat-* 重复模板标记 deprecated（rowSize 与 canonical 不一致），1 个 `supportInfoNavi` 资产未提取标 not_found；`DatItemShopLineupDataAsset` 加 rowCount=1024→24 覆盖；详细数据见 [`tools/templates-010/schemas/calibration-report.md`](../tools/templates-010/schemas/calibration-report.md) | 跨核对 arkemultiplier 字节差分：`Easy.ExpRate @ 0x73A` 与 schema 计算的 file offset 完全一致 |
| **T1.5.4** ✅ | Schema 验证回归测试 | 对每张有 010 模板的表，按 schema 从 Zen 字节解码每一行，与 CUE4Parse JSON 对比，全字段 match 才算 schema 通过 | 4h | T1.5.3 | **已完成（2026-06-24）**：[`Test-SchemaRegression.ps1`](../tools/scripts/Test-SchemaRegression.ps1) 回归全部 38 schema：18 PASS（含 skillNormal 120/120 ✓ + DT_BtlDIfficultyParam 50/50 ✓）、12 PARTIAL（5 个 CUE4Parse JSON 缺口 + 4 个待人工核对 + 1 个轻微差异）、2 FAIL（`itemSkillCard`/`skillPack`，JSON 结构不兼容），6 SKIP（3 deprecated + 2 无 JSON + 1 未校准）。黄金锚点 `Agi.hpn=40` 完全通过 | 审查 C 类 PARTIAL 的 4 个可疑表 |
| **T1.5.5** ✅ | `patch` CLI 命令 | `Invoke-ZenPatch.ps1`（PowerShell prototype for `P3RDataTools.exe patch`），输入 changes.json，按 4 种 tableShape 定位 file offset + 大小保持标量写入 | 4h | T1.5.4 | **已完成（2026-06-24）**：[`Invoke-ZenPatch.ps1`](../tools/scripts/Invoke-ZenPatch.ps1) 消费 changes.json→schema→Zen 原件副本→字节写入→输出 .uasset；4 种 tableShape 均通过目标语法 `Data[N]` / `Rows.key` / `Record[N]` / bare field 测试；Agi hpn=999 0x246A 字节写入按预期完成 | CLI 单元测试（已完成：4/4 形状通过） |
| **T1.5.6** ✅ | Mod-script DSL | PowerShell helper：`Set-SkillHpn -Id 10 -DamageMultiplier 5.0`（自动 N²）、`Set-PersonaLevel -PersonaId 250 -Level 99`、`Set-EnemySkill -EnemyId 100 -Slot 3 -SkillId 47` 等 | 3h | T1.5.5 | **已完成（2026-06-24）**：`tools/scripts/dsl/P3RModDSL.psm1`（~300 行），12 个导出函数覆盖 5 种 schema（skillNormal/persona/enemy/playerLevelup/DT_BtlDIfficultyParam），全部 7 项测试通过（含 AgiMod 黄金锚点 0x246A 精确命中） | 人工测试每条 helper |
| **T1.5.7** ✅ | `modify-and-repack.ps1` 改造 | 默认走 patch 路径而不是 `P3RDataTools.create`：从 `Extracted/IoStore/` 取原件、应用 patch、部署到 `<Mod>/UnrealEssentials/`、写 ModConfig.json | 3h | T1.5.5 | **已完成（2026-06-24）**：完全重写——支持 `-SchemaKey`/`-TableKey`/`-VirtualPath` 解析 schema；`-Changes` 内联变更 / `-ChangesJson` 文件 / `-ModScript` DSL 脚本三种模式；DryRun 预览无写入；废弃重复 dat-* schema 自动跳过 | 端到端测试 |
| **T1.5.8** ✅ | AgiMod 回归 | 用新管道重新生成 AgiMod，对比手工 PoC 的字节，应**完全一致**（hpn=999 在 0x0246A） | 1h | T1.5.7 | **已完成（2026-06-24）**：PoC AgiMod 与 DSL 产物逐字节 100% 一致（539,474 bytes, 0 diffs）；6 个 gold anchor 全部验证通过；**人工启游戏实测确认**：亚基伤害约为布芙 5 倍 ✅ | 启游戏复测亚基伤害 |
| **T1.5.9** ✅ | 工作流文档 | 完善 [`docs/ZEN_BYTE_PATCH_WORKFLOW.md`](ZEN_BYTE_PATCH_WORKFLOW.md)：把"中期工程化"段落改为"已完成"，补充新 CLI 用法 | 1h | T1.5.7 | **已完成（2026-06-24）**：完全重写 ZEN_BYTE_PATCH_WORKFLOW.md（§2 快速开始 → §3 前置条件已交付 → §4 手工 fallback → §5 语义陷阱；DEVELOPMENT_PLAN.md/DEVELOPER_GUIDE.md/CLAUDE.md/regression-report.md 同步更新） | 审查 |
| **T1.5.10** ✅ | Sprint 1.5 评审 | 验收所有交付物 + 端到端测试 | 3h | T1.5.1-T1.5.9 | **已完成（2026-06-24）**：17/17 交付物审计通过；E2E 全部功能正确——BufuMod（N²）、MultiMod（双表）、DSL Smoke（12/12）；**人工实测**: AgiMod 亚基≈布芙 5x ✅。**边缘发现**: personaGrowth 的 `SkillEventStruct`（含 `{SkillList\|ItemList}` union）直接 byte-patch 崩溃（P-010），`Set-PersonaGrowthSkill` 降级为 DEV-ONLY 骨架保留待逆向 | 真人启游戏验证已完成 |

### 交付物

- [ ] `tools/templates-010/` — 41 个 p3re `.bt` 模板（含 `p3re_structs.bt` / `p3re_enums.bt`），LICENSE 通告原作者
- [ ] `tools/P3RDataTools/BtParser.cs` — `.bt` 模板解析器
- [ ] `tools/P3RDataTools/ZenPatcher.cs` — 字节级 patch 引擎（含 header 校准、字段定位、写入断言）
- [ ] `tools/P3RDataTools/Program.cs` — 新增 `patch` 命令
- [x] `tools/scripts/dsl/P3RModDSL.psm1` — Mod-script DSL 模块（T1.5.6 ✅ 2026-06-24；**12 个导出函数**，覆盖 5 种平坦标量表；`Set-PersonaGrowthSkill` 因 union crash 转为 DEV-ONLY 保留骨架，见 P-010）
- [x] `tools/scripts/modify-and-repack.ps1` — 改造默认走 Zen patch 路径（T1.5.7 ✅ 2026-06-24；支持 3 种变更输入模式 + DryRun + 废弃 schema 过滤）
- [x] 41 张表的 schema 校验报告（CUE4Parse JSON 对照）[→ regression-report.md](../tools/templates-010/schemas/regression-report.md)（T1.5.4 完成 18/30 PASS + T1.5.8 补充 AgiMod 黄金锚点验证）
- [x] AgiMod 回归测试（字节级完全一致 + **人工实测通过**）：PoC 与 DSL 产物 0 diff，6 个 gold anchor 全过，亚基≈布芙 5x [→ full report](../tools/templates-010/schemas/agi_regression_report.md)
- [x] [`docs/ZEN_BYTE_PATCH_WORKFLOW.md`](ZEN_BYTE_PATCH_WORKFLOW.md) 完善（T1.5.9 ✅ 2026-06-24：完全重写，§2 快速开始 → §3 前置条件已完成 → §4 手工 fallback）

### 任务依赖图

```
T1.5.1 (010 模板库) ──→ T1.5.2 (.bt 解析器)
                              │
                              └──→ T1.5.3 (header 校准)
                                     │
                                     └──→ T1.5.4 (schema 回归) ──→ T1.5.10
                                            │
                                            └──→ T1.5.5 (patch CLI)
                                                   │
                                                   ├──→ T1.5.6 (DSL helper)
                                                   │       │
                                                   └──→ T1.5.7 (modify-and-repack) → T1.5.8 (AgiMod 回归)
                                                          │                               │
                                                          └──→ T1.5.9 (文档) ────────────┴──→ T1.5.10 (评审)
```

### 风险与缓冲

| 风险 | 概率 | 额外工时 | 触发条件 |
|------|------|---------|---------|
| 010 模板语法子集不够 / 某些表用了高级语法（if / Switch / local）| 30% | +6h | T1.5.2 解析某张表失败 |
| Header 校准算法失效（某表 fileSize 不能被整除）| 20% | +4h | T1.5.3 几张表回归失败 |
| Schema 与 CUE4Parse JSON 字段对不上 | 25% | +6h | T1.5.4 多个字段 MISMATCH |
| Zen 字节 patch 在某些表上让游戏崩 | 15% | +10h | T1.5.10 实测某新 mod 崩 |

**建议**: Sprint 1.5 预留 25% 缓冲（28h + 7h = 35h）

### 与 Sprint 1 的关系

| 内容 | Sprint 1（已弃用主路径） | Sprint 1.5（新主路径） |
|---|---|---|
| 模板来源 | FModel 导出的传统格式 `.uasset+.uexp`（`tools/templates/`） | godofknife 010-Editor `.bt` schema（`tools/templates-010/`）+ `Extracted/IoStore/` 真实 Zen 字节 |
| 写回方式 | UAssetAPI 重新序列化整个包 | 复制 Zen 原件 + 就地字节 patch |
| 输出形态 | `.uasset+.uexp` 传统格式 | Zen 单文件 `.uasset`（无 `.uexp`）|
| 文件大小 | 与原件不同（重新序列化）| 与原件**完全相同** |
| 游戏接受 | ❌ boot-crash | ✅ AgiMod / AllInherit / arkemultiplier 三个实证 |
| 字段覆盖 | 取决于 CUE4Parse JSON | 取决于 010 模板覆盖（41 张表） + CUE4Parse 验证 |
| 变长字段支持 | 理论可以（重写整个包）| ❌ 不支持（patch 不能改大小）|

Sprint 1.5 在功能矩阵上**不完全替代** Sprint 1——变长字段 / 字符串改写在未来仍可能需要回到"完整序列化"路径。但 99% 的数值类 mod 用 Sprint 1.5 就够，且唯一被验证可工作。

---

## Sprint 2: 工具链集成

> **目标**: 编写 Claude Code 工具脚本，更新 CLAUDE.md，实现端到端自然语言闭环  
> **工期**: 26h | **依赖**: Sprint 1 完成 | **可交付物**: 全部 8 个工具可用 + 完整 CLAUDE.md

### 任务清单

| ID | 任务 | 描述 | 工时 | 依赖 | Claude Code 做什么 | 人工做什么 |
|----|------|------|------|------|-------------------|-----------|
| **T2.1** | Config.ps1 扩展 | 添加 `$Templates`、`$ModRegistry`、`$BackupDir`、`$ToolsDir` 变量 | 1h | T0.3 | 生成 Config.ps1 新增部分 | 审查并加载测试 |
| **T2.2** | search-datatable.ps1 | 实现：查 DATA_MAPPING.md + Wiki MD → 返回虚拟路径、行索引、字段、当前值 | 4h | — | 编写搜索脚本（~200 行 PS），含中文模糊匹配逻辑 | 测试各种查询（中/日/英名称、拼音、描述） |
| **T2.3** | search-wiki.ps1 | 实现：grep 37 个 Wiki MD → 返回相关条目 + 对应游戏文件路径 | 2h | — | 编写 Wiki 搜索脚本（~100 行 PS），含索引缓存优化 | 测试查询质量 |
| **T2.4** | diff-changes.ps1 | 实现：对比修改前后 JSON → 人类可读输出（含 Wiki 名称标注） | 5h | T2.2 | 编写 diff 脚本（~200 行 PS），含 ID→名称翻译 | 测试各种类型修改的预览效果 |
| **T2.5** | backup-mod.ps1 | 实现：创建时间点备份 → 复制原始 JSON → 写入 backup.json | 2h | T2.1 | 编写备份脚本（~80 行 PS） | 测试备份/恢复 |
| **T2.6** | rollback-mod.ps1 | 实现：查找 mod 注册表 → 展示信息 → 确认 → 移除 PAK → 清理产物 → 验证 | 3h | T2.5 | 编写回滚脚本（~150 行 PS） | 端到端测试回滚 |
| **T2.7** | conflict-check.ps1 | 实现：遍历已安装 mod → 对比 DataTable 行 → 报告重叠 | 3h | T2.1 | 编写冲突检测脚本（~150 行 PS） | 创建冲突场景测试 |
| **T2.8** | modify-and-repack.ps1 重写 | 集成 `create` 命令 → 移除手动步骤 → 添加进度提示 → 错误友好输出 | 3h | T1.7, T2.1 | 重写编排脚本（~200 行 PS） | 全流程测试 |
| **T2.9** | CLAUDE.md 更新 | 添加全部工具定义、工作流规则、安全协议、使用示例 | 2h | T2.2-T2.8 | 生成 CLAUDE.md 新增章节 | 审查并确认 Claude Code 正确加载 |
| **T2.10** | Sprint 2 评审 | 端到端 AI 测试：自然语言输入 → Agent 自动完成 → .pak 生成 | 1h | T2.9 | — | 用 5+ 种不同需求的自然语言做完整测试 |

### 交付物

- [ ] `tools/scripts/Config.ps1` 更新（新增变量）
- [ ] `tools/scripts/tools/search-datatable.ps1`
- [ ] `tools/scripts/tools/search-wiki.ps1`
- [ ] `tools/scripts/tools/diff-changes.ps1`
- [ ] `tools/scripts/tools/backup-mod.ps1`
- [ ] `tools/scripts/tools/rollback-mod.ps1`
- [ ] `tools/scripts/tools/conflict-check.ps1`
- [ ] `tools/scripts/modify-and-repack.ps1` 重写
- [ ] `CLAUDE.md` 更新（含 8 个工具定义 + 安全规则）
- [ ] 端到端测试报告（5+ 自然语言场景）

### 任务依赖图

```
T2.1 (Config扩展)
  │
  ├──→ T2.5 (backup) ──→ T2.6 (rollback)
  │                       │
  ├──→ T2.7 (conflict)    │
  │                       │
  └──→ T2.8 (modify-and-repack重写)
         │                 │
         └──→ ... ────────┴──→ T2.9 (CLAUDE.md) ──→ T2.10 (评审)

T2.2 (search-datatable) ──→ T2.4 (diff-changes)
         │                      │
         └──→ T2.9 ─────────────┘

T2.3 (search-wiki) ──→ T2.9
```

---

## Sprint 3: 安全系统

> **目标**: 实现四层安全架构，保证操作可逆、冲突可检测、历史可审计  
> **工期**: 24h | **依赖**: Sprint 2 完成 | **可交付物**: 完整安全系统

### 任务清单

| ID | 任务 | 描述 | 工时 | 依赖 | Claude Code 做什么 | 人工做什么 |
|----|------|------|------|------|-------------------|-----------|
| **T3.1** | Mod 注册表系统 | 实现 `mod.json` 元数据格式 + 创建/读取/更新/删除 API | 3h | T2.1 | 编写 ModRegistry 模型 + PS 脚本（~200 行） | 审查格式设计、测试 CRUD |
| **T3.2** | history.json 操作审计 | 每次修改自动记录：action、timestamp、beforeHash、afterHash、userInput | 2h | T3.1 | 编写审计记录模块（~100 行 PS） | 验证审计完整性 |
| **T3.3** | Git 集成层 | 修改前自动 commit 原始 JSON → 标记 "auto: pre-mod backup for <modName>" | 3h | T3.1 | 编写 Git 操作脚本（~100 行 PS），处理边缘情况 | 测试各种 Git 状态下的行为 |
| **T3.4** | 备份系统增强 | 增强 T2.5：支持命名备份、列出备份、从备份恢复、版本比较 | 3h | T2.5, T3.1 | 增强 backup-mod.ps1（+150 行 PS） | 测试多版本备份场景 |
| **T3.5** | 回滚系统增强 | 增强 T2.6：支持选择性回滚、回滚预览、回滚后验证 | 3h | T2.6, T3.4 | 增强 rollback-mod.ps1（+100 行 PS） | 测试部分回滚场景 |
| **T3.6** | 冲突检测增强 | 增强 T2.7：冲突严重性分级（错误/警告/信息）、合并建议 | 3h | T2.7, T3.1 | 增强 conflict-check.ps1（+150 行 PS） | 测试复杂冲突场景 |
| **T3.7** | 安全屏障脚本 | 实现 `guard-modify.ps1`：修改前自动检查清单（备份存在、无冲突、值合法） | 2h | T3.2-T3.6 | 编写安全屏障脚本（~100 行 PS） | 集成到 modify-and-repack 流程 |
| **T3.8** | 安全协议文档 | 编写 `docs/SECURITY.md`：安全架构、操作流程、紧急恢复指南 | 2h | T3.7 | 生成安全文档初稿 | 审查并补充细节 |
| **T3.9** | Sprint 3 评审 | 全量安全测试：批量修改、模拟冲突、破坏性回滚、审计链验证 | 3h | T3.8 | 生成测试场景脚本 | 逐项验收 |

### 交付物

- [ ] `tools/Output/mod/<name>/mod.json` 注册表格式
- [ ] `tools/Output/mod/<name>/history.json` 审计日志
- [ ] `tools/scripts/tools/backup-mod.ps1` 增强版
- [ ] `tools/scripts/tools/rollback-mod.ps1` 增强版
- [ ] `tools/scripts/tools/conflict-check.ps1` 增强版
- [ ] `tools/scripts/tools/guard-modify.ps1` 安全屏障
- [ ] `docs/SECURITY.md` 安全协议文档
- [ ] 安全系统测试报告

### 任务依赖图

```
T3.1 (Mod注册表)
  │
  ├──→ T3.2 (审计日志)
  │       │
  ├──→ T3.3 (Git集成)
  │       │
  ├──→ T3.4 (备份增强) ──→ T3.5 (回滚增强)
  │       │                   │
  └──→ T3.6 (冲突增强) ───────┤
          │                   │
          └──→ T3.7 (安全屏障) ←┘
                 │
                 └──→ T3.8 (安全文档) ──→ T3.9 (评审)
```

---

## Sprint 4: 扩展与验证

> **目标**: 扩展覆盖率、端到端验证、用户文档编写  
> **工期**: 16h | **依赖**: Sprint 3 完成 | **可交付物**: 完整产品 + 文档

### 任务清单

| ID | 任务 | 描述 | 工时 | 依赖 | Claude Code 做什么 | 人工做什么 |
|----|------|------|------|------|-------------------|-----------|
| **T4.1** | 多表 Mod 支持 | 修改 modify-and-repack.ps1 支持一次修改多个 DataTable | 3h | T2.8 | 扩展编排脚本（+100 行 PS） | 测试 2-3 表联合修改 |
| **T4.2** | 模板库扩展验证 | 验证全部 18 种模板的读写正确性 | 2h | T1.7 | 生成批量验证脚本 | 审查结果并修复遗漏 |
| **T4.3** | 批量修改支持 | 实现 "将所有 X 的 Y 改为 Z" 模式（筛选 + 批量 modify + 单次打包） | 3h | T4.1 | 编写批量修改脚本（~150 行 PS） | 测试批量操作正确性 |
| **T4.4** | 边界情况测试 | 测试：空行、最大值溢出、负值、无效 ID、文件名冲突、路径空格 | 3h | T4.3 | 生成边界测试用例脚本 | 逐项执行并记录 |
| **T4.5** | 用户文档 | 编写 `docs/USER_GUIDE.md`：安装、首次使用、常见场景、FAQ | 3h | T4.4 | 生成用户文档初稿 | 审查、补充截图和示例 |
| **T4.6** | Sprint 4 评审 | 全量端到端测试 + 文档完整性检查 | 2h | T4.5 | 生成最终测试报告 | 逐项验收 |

### 交付物

- [ ] `tools/scripts/modify-and-repack.ps1` 多表支持版
- [ ] `tools/scripts/tools/batch-modify.ps1` 批量修改脚本
- [ ] 全模板验证报告（18/18 表类型）
- [ ] 边界测试报告
- [ ] `docs/USER_GUIDE.md` 用户指南
- [ ] 端到端最终测试报告

### 任务依赖图

```
T4.1 (多表支持) ──→ T4.3 (批量修改) ──→ T4.4 (边界测试)
                                          │
T4.2 (模板验证) ──────────────────────────┤
                                          │
                                          └──→ T4.5 (用户文档) ──→ T4.6 (评审)
```

---

## 依赖关系总图

```
Sprint 0 ──→ Sprint 1 ⊘ ──→ Sprint 1.5 ★ ──→ Sprint 2 ──→ Sprint 3 ──→ Sprint 4
  │              │                │              │            │            │
  │              │                │              │            │            └── 多表/批量/文档
  │              │                │              │            └── 备份/回滚/冲突/审计
  │              │                │              └── 8个工具脚本 + CLAUDE.md
  │              │                └── ★ Zen byte-patch 写回（AgiMod PoC 已验证）
  │              └── ⊘ UAssetAPI写回 + 游戏验证（弃用，P3R 崩游戏，P-007）
  └── 模板库 + setup + 开发环境（templates/ 部分弃用，setup/ 仍有效）
```

**关键路径**: Sprint 0 T0.4-T0.6（保留有效部分）→ Sprint 1.5 T1.5.5（patch CLI）→ Sprint 2 改造继续推进

> ⚠️ **Sprint 1 不再是关键路径**: 2026-06-24 后 Sprint 1 的传统格式产物被证伪，关键路径迁到 Sprint 1.5 byte-patch 引擎。

---

## 工时汇总

| Sprint | 名称 | 预估工时 | Claude Code 产出 | 人工 |
|--------|------|---------|-------------------|------|
| Sprint 0 | 基础设施补全 | 12h | 脚本/文档生成 (6h) | FModel 操作 + 审查 (6h) |
| Sprint 1 | 写回引擎（⊘ 弃用） | 30h | C# 代码生成 (16h) | 审查 + 游戏测试 (14h) |
| Sprint 1.5 | ★ Zen Byte-Patch 写回 | 28h | C# 解析器 + DSL (18h) | 启游戏回归 + schema 审查 (10h) |
| Sprint 2 | 工具链集成 | 26h | PS 脚本生成 (18h) | 集成测试 + 审查 (8h) |
| Sprint 3 | 安全系统 | 24h | PS 脚本生成 (16h) | 安全场景测试 (8h) |
| Sprint 4 | 扩展与验证 | 16h | 脚本/文档生成 (9h) | 端到端测试 + 审查 (7h) |
| **合计** | | **136h** | **83h (61%)** | **53h (39%)** |

### Claude Code 的角色

| 阶段 | Claude Code 负责 | 不能替代人工 |
|------|-----------------|-------------|
| **编写代码** | 生成 C# 模块、PowerShell 脚本、配置文件 | 架构决策、API 选型 |
| **测试** | 生成测试脚本、测试数据、边界用例 | 游戏加载验证（必须真人启动游戏） |
| **文档** | 生成初稿、格式排版、交叉引用 | 游戏机制描述、截图、FAQ 真实性 |
| **调试** | 分析错误日志、提出修复方案 | 确认修复在真实游戏环境生效 |
| **审查** | 代码质量检查、安全检查清单 | 最终判断是否合格 |

---

## 风险时间缓冲

| 风险 | 概率 | 额外工时 | 触发条件 |
|------|------|---------|---------|
| 游戏不加载传统格式 PAK | 25% | +20h | T1.6 失败 |
| FModel 无法导出某类型 | 20% | +8h | T0.1 部分失败 |
| UAssetAPI 写回数据错位 | 15% | +10h | T1.5 大量失败 |
| 模板 NameMap 不匹配 | 10% | +6h | T1.2 遇到特定类型 |

**建议**: Sprint 1 预留 30% 缓冲（30h + 9h = 39h）

---

## 里程碑日历

```
Week 1 ─ Sprint 0: 基础设施
  Day 1-2  ██ 模板导出 + 验证
  Day 3-4  ██ setup.ps1 + 文档
  Day 5    ██ Sprint 0 评审
  ───────────────────────────
      里程碑 A: 模板库就绪，可开始写回引擎开发

Week 2-3 ─ Sprint 1: 写回引擎
  Day 1-3  ██ 三个 C# 模块（TemplateLoader / Patcher / Writer）
  Day 4-5  ██ CLI 集成 + 往返测试
  Day 6     ██ 游戏加载测试 ← 关键决策点
  Day 7-9  ██ 修复调优
  Day 10   ██ Sprint 1 评审
  ───────────────────────────
      里程碑 B: 写回链路打通，可生成可用 .pak

Week 4-5 ─ Sprint 2: 工具链集成
  Day 1-3  ██ search + diff + wiki 脚本
  Day 4-6  ██ backup + rollback + conflict 脚本
  Day 7-8  ██ modify-and-repack 重写 + CLAUDE.md
  Day 9-10 ██ 端到端 AI 测试 + Sprint 2 评审
  ───────────────────────────
      里程碑 C: 自然语言 → .pak 全流程可用

Week 6-7 ─ Sprint 3: 安全系统
  Day 1-3  ██ 注册表 + 审计 + Git 集成
  Day 4-5  ██ 备份/回滚/冲突增强
  Day 6-7  ██ 安全屏障 + 文档
  Day 8-9  ██ 安全测试 + Sprint 3 评审
  ───────────────────────────
      里程碑 D: 安全系统就绪，操作完全可逆

Week 8 ─ Sprint 4: 验证发布
  Day 1-2  ██ 多表/批量支持
  Day 3-4  ██ 边界测试 + 模板全验证
  Day 5-6  ██ 用户文档 + 最终评审
  ───────────────────────────
      里程碑 E: v1.0 发布就绪
```

---

## 关键文件产出清单

| 文件 | Sprint | 类型 |
|------|--------|------|
| `tools/P3RDataTools/TemplateLoader.cs` | S1 ⊘ | 弃用（保留备查）|
| `tools/P3RDataTools/DataTablePatcher.cs` | S1 ⊘ | 弃用 |
| `tools/P3RDataTools/AssetWriter.cs` | S1 ⊘ | 弃用 |
| `tools/P3RDataTools/TemplateCreator.cs` | S1 ⊘ | 弃用（产物在 P3R 上崩游戏）|
| `tools/P3RDataTools/BtParser.cs` | **S1.5 ★** | **新建**（C# port 暂未做，PowerShell 原型 `tools/scripts/Parse-BtTemplate.ps1` 已交付且 29/41 表通过）|
| `tools/scripts/Parse-BtTemplate.ps1` | **S1.5 ★** | **已交付（T1.5.2 + T1.5.2b 完成 2026-06-24）**：PowerShell prototype，覆盖 010 语法子集 + 4 种 tableShape（indexed_rows / named_rows / single_record / single_record_array）；38/41 表 schema 已持久化到 `tools/templates-010/schemas/` |
| `tools/templates-010/schemas/` (38 个 `_schema.json`)| **S1.5 ★** | **新建（T1.5.2 + T1.5.2b 输出）**|
| `tools/scripts/Calibrate-SchemaHeaders.ps1` | **S1.5 ★** | **已交付（T1.5.3 完成 2026-06-24）**：把 38 schema 的 headerSizeHint 替换为校准过的真实 headerSize；产出 `tools/templates-010/schemas/calibration-report.md` |
| `tools/templates-010/schemas/calibration-report.md` | **S1.5 ★** | **新建（T1.5.3 输出）**：34 OK / 3 DEP / 1 NOT_FOUND 校准结果 + 黄金锚点验证 |
| `tools/scripts/Test-SchemaRegression.ps1` | **S1.5 ★** | **已交付（T1.5.4 完成 2026-06-24）**：回归测试脚本，从 Zen 字节解析字段并与 CUE4Parse JSON 对比；产出 `tools/templates-010/schemas/regression-report.md` |
| `tools/templates-010/schemas/regression-report.md` | **S1.5 ★** | **新建（T1.5.4 输出）**：38 schema × 详细回归结果 + 黄金锚点 |
| `tools/scripts/Invoke-ZenPatch.ps1` | **S1.5 ★** | **已交付（T1.5.5 完成 2026-06-24）**：schema-driven Zen byte-patch CLI——输入 changes.json（schemaKey + target/values）+ 输出 patched .uasset；支持 4 种 tableShape（Data[N].field / Rows.key.field / Record[N].field / bare field）；所有标量类型 + enum；通过 AgiMod/Difficulty/combineMisc/Theurgy 全形验证 |
| `tools/P3RDataTools/ZenPatcher.cs` | **S1.5 ★** | **新建** |
| `tools/P3RDataTools/Program.cs` | S1/S1.5 | 修改（新增 `patch` 命令，`create` 命令降级为弃用警告）|
| `tools/templates-010/` (41 个 `.bt`)| **S1.5 ★** | **新建** |
| `tools/scripts/dsl/Set-SkillHpn.ps1` 等 | **S1.5 ★** | **新建** |
| `tools/scripts/Config.ps1` | S2 | 修改 |
| `tools/scripts/tools/search-datatable.ps1` | S2 | 新建 |
| `tools/scripts/tools/search-wiki.ps1` | S2 | 新建 |
| `tools/scripts/tools/diff-changes.ps1` | S2 | 新建 |
| `tools/scripts/tools/backup-mod.ps1` | S2/S3 | 新建 |
| `tools/scripts/tools/rollback-mod.ps1` | S2/S3 | 新建 |
| `tools/scripts/tools/conflict-check.ps1` | S2/S3 | 新建 |
| `tools/scripts/tools/guard-modify.ps1` | S3 | 新建 |
| `tools/scripts/tools/batch-modify.ps1` | S4 | 新建 |
| `tools/scripts/modify-and-repack.ps1` | S2/S4/**S1.5** | 改造（S1.5 把默认从 `.create` 切到 Zen patch）|
| `CLAUDE.md` | S2 | 修改 |
| `tools/templates/` (18 对文件) | S0 ⊘ | 弃用（保留 fallback）|
| `tools/templates/template_index.json` | S0 ⊘ | 弃用 |
| `setup.ps1` | S0 | 保留有效 |
| `docs/DEVELOPER_GUIDE.md` | S0 | 保留有效 |
| `docs/ZEN_BYTE_PATCH_WORKFLOW.md` | **S1.5 ★** | **新建（已存在初稿，S1.5 完善）**|
| `docs/SECURITY.md` | S3 | 新建 |
| `docs/USER_GUIDE.md` | S4 | 新建 |
