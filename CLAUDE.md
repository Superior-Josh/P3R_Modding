# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此仓库中工作时提供指导。

## 项目概述

这是一个 **Persona 3 Reload (P3R) 逆向工程与 Mod 制作工作区**。无构建系统、包管理器或测试套件。Git 管理文档和工具源代码，`.gitignore` 排除二进制资产和预编译工具。

### 项目目标

构建 **自然语言驱动的 P3R Mod 制作 AI Agent**，对 P3R 进行 Mod 制作，涵盖：数值（技能/Persona/道具）、敌人 AI、文本/本地化、音乐/音频。

### Mod 交付机制

P3R 使用 **Reloaded II** 加载 Mod。**默认采用 UnrealEssentials 散文件挂载**——把修改后的 **Zen 单文件 `.uasset`** 放到 `Mods/<ModName>/UnrealEssentials/P3R/Content/...` 下，UnrealEssentials 自动注入 UE 4.27 资产加载链。Sprint 1.5 已确认：AgiMod、BufuMod（布芙 `hpn=999`）和 ExpMod（Normal `ExpRate=100.0`）均可在游戏内生效。

```
Extracted/IoStore Zen .uasset → Invoke-ZenPatch.ps1 byte-patch → UnrealEssentials loose file
                            │
                            ↓
Reloaded II + UnrealEssentials ← 散文件按虚拟路径镜像挂载
    │                                       ↑
    │            (可选 fallback) UnrealPak → .pak → FEmulator/PAK
    │
P3R.exe (Inaba EXE Patcher 解锁 mod 支持)
```

**两种挂载方式对比（必读，错选会出现 0 KB 空 PAK 或 mod 不生效）：**

| 维度 | UnrealEssentials 散文件 ★默认 | FEmulator/PAK |
|---|---|---|
| 依赖 | `UnrealEssentials`（或 `p3rpc.essentials`，后者间接引入 UE） | `reloaded.universal.fileemulationframework.pak` |
| 目录 | `<Mod>/UnrealEssentials/P3R/Content/.../<asset>.uasset(+.uexp)` | `<Mod>/FEmulator/PAK/<Mod>.pak` |
| 制作 | 直接拷贝 `.uasset+.uexp` | 还要走 UnrealPak 打包 |
| 失败模式 | 路径写错 → 覆盖不命中 | 0.4 KB 空 PAK（[P-002](docs/MODDING_PITFALLS.md#p-002-占位空-pak-不要部署到-reloaded-ii)）/ manifest mount path 错 |
| 项目内参考 | [`p3rpc.ui.barionskillnames`](tools/Reloaded II/Mods/p3rpc.ui.barionskillnames/)（deps=`p3rpc.essentials`） + [`p3r.qol.arkemultiplier`](tools/Reloaded II/Mods/p3r.qol.arkemultiplier/)（deps=`UnrealEssentials`） | 仅作 fallback；详见 [`docs/MODDING_PITFALLS.md` P-005](docs/MODDING_PITFALLS.md#p-005) |

新建 mod **优先用 UnrealEssentials 路径**。`modify-and-repack.ps1` 默认就走它；需要 PAK 备份再加 `-PackPak`。

> **关于 UnrealEssentials 的完整能力**（支持整包/散文件、Zen vs 传统资产、`utoc-extractor`、`.uassetmeta` 元数据、UE 版本范围、上游依赖链）：见 [`docs/UNREAL_ESSENTIALS_REFERENCE.md`](docs/UNREAL_ESSENTIALS_REFERENCE.md)。本仓库实际安装的 UnrealEssentials 版本可在 [`tools/Reloaded II/Mods/UnrealEssentials/ModConfig.json`](tools/Reloaded%20II/Mods/UnrealEssentials/ModConfig.json) 的 `ModVersion` 字段查看（当前 2.0.0）。
>
> ⚠️ **P3R 散文件替换的上游严格要求**：UnrealEssentials README 明确要求 *"any `.uasset` files you replace will have to come from a UTOC"*——即从 IoStore 容器直接拆出来的 **Zen 单文件**（首字节 `00 00 00 00`、无 `.uexp`）。项目当前唯一可工作的写回路径是 Sprint 1.5 的 Zen byte-patch；`P3RDataTools.create` 生成的传统 `.uasset+.uexp`（首字节 `C1 83 2A 9E`）已被 P-007 证伪，不要用于新 Mod。

## 快速开始

```powershell
# 首次使用: 初始化项目
.\setup.ps1

# 安装 Reloaded II (一次性)
# 1. 下载: https://github.com/Reloaded-Project/Reloaded-II/releases
# 2. 解压到任意目录，运行 Reloaded-II.exe
# 3. 添加 P3R.exe 为应用程序
# 4. 首次启动会自动安装 P3R Essentials + Inaba EXE Patcher

# 每日使用: 启动 Claude Code
claude
```

## 仓库结构

```
P3R_Modding/
├── setup.ps1                          ← 项目初始化脚本 (首次运行)
├── .env                               ← 本地环境变量 (从 .env.example 复制, Git 忽略)
├── .env.example                       ← 环境变量模板
├── .editorconfig                      ← 代码风格配置
├── .gitattributes                     ← Git 行尾规范
├── CLAUDE.md                          ← 本文件
│
├── docs/                              ← 项目文档
│   ├── PRD_P3R_AI_AGENT.md            ← 产品需求文档
│   ├── SYSTEM_ARCHITECTURE.md         ← 系统架构设计
│   ├── DEVELOPMENT_PLAN.md            ← Sprint 开发计划
│   ├── P3R_ASSET_ANALYSIS.md          ← 资产分析报告
│   ├── DEVELOPER_GUIDE.md             ← 开发环境指南
│   ├── amicitia/                      ← 英文参考 (Amicitia WIKI)
│   │   ├── README.md                  ← 37 个参考页面索引
│   │   ├── DATA_MAPPING.md            ← Wiki ↔ 游戏文件精确映射 ★
│   │   ├── md/                        ← 37 Wiki Markdown 参考
│   │   └── html/                      ← 原始 HTML 备份
│   └── zh-cn/                         ← 中文标准译名 (biligame WIKI) ★
│       ├── README.md                  ← 索引与使用约定
│       ├── skills.md                  ← 全技能中/日/英三语对照 (含 ID)
│       ├── personas.md                ← 全人格面具中/日/英 + Arcana
│       ├── enemies.md                 ← 全敌人/Shadow 中文名
│       ├── arcana.md                  ← 22 阿尔卡纳译名 + 大卡效果
│       ├── characters.md              ← SEES / Social Link NPC
│       ├── elements-status.md         ← 属性 / 异常状态译名
│       └── locations-systems.md       ← 地点 / 系统术语
│
├── tools/
│   ├── P3RDataTools/                  ← CLI 工具源码 (C#)
│   │   ├── Program.cs                 ← 主入口
│   │   ├── TemplateCreator.cs         ← 二进制模板序列化
│   │   └── P3RDataTools.csproj        ← .NET 8 项目文件
│   │
│   ├── scripts/
│   │   ├── Config.ps1                 ← 共享配置 (路径/密钥/别名/注册表)
│   │   ├── modify-and-repack.ps1      ← ★ 全流程编排 (Zen byte-patch 默认，T1.5.7)
│   │   ├── Invoke-ZenPatch.ps1        ← schema-driven Zen 字节写回引擎 (T1.5.5)
│   │   ├── Parse-BtTemplate.ps1       ← .bt 模板解析器 (T1.5.2)
│   │   ├── Calibrate-SchemaHeaders.ps1 ← Header 校准 (T1.5.3)
│   │   ├── Test-SchemaRegression.ps1  ← Schema 回归验证 (T1.5.4)
│   │   ├── dsl/
│   │   │   └── P3RModDSL.psm1         ← ★ Mod DSL 模块 (T1.5.6, 12 个 helper)
│   │   ├── verify-templates.ps1       ← 模板库验证
│   │   └── tools/                     ← Claude Code 工具脚本 (Sprint 2)
│   │       ├── search-datatable.ps1   ← 数据表定位
│   │       ├── search-wiki.ps1        ← Wiki 搜索
│   │       ├── diff-changes.ps1       ← 差分预览
│   │       ├── backup-mod.ps1         ← 备份
│   │       ├── rollback-mod.ps1       ← 回滚
│   │       ├── conflict-check.ps1     ← 冲突检测
│   │       └── guard-modify.ps1       ← 安全屏障
│   │
│   ├── templates/                     ← 传统格式 .uasset+.uexp 模板库
│   │   └── template_index.json        ← 模板索引
│   │
│   ├── Output/                        ← 生成产物 (mod/.backup/.data/Logs Git忽略; json 已跟踪)
│   │   ├── json/                      ← 489 DataTable JSON 快照
│   │   │   ├── Battle/   (35 files)   ← 技能/Persona/敌人/遇敌
│   │   │   ├── UI_Tables/(161 files)  ← 道具/武器/防具/商店
│   │   │   ├── Community/(276 files)  ← 社群事件
│   │   │   ├── Kernel/    (5 files)   ← 文件名映射
│   │   │   ├── Dictionary/(2 files)   ← 游戏字典
│   │   │   └── Tutorial/ (10 files)   ← 教程文本
│   │   ├── mod/                       ← Mod 产物 (每个 Mod 一个子目录)
│   │   ├── Logs/                      ← 运行时日志 (Git 忽略)
│   │   ├── .backup/                   ← 时间点备份
│   │   └── .data/                     ← 运行时缓存
│   │
│   ├── Reloaded II/                   ← Mod 加载器 (大型二进制, Git 忽略)
│   ├── FModel.exe                     ← GUI 资产浏览器
│   ├── UAssetGUI/                     ← GUI uasset 编辑工具
│   └── UnrealPakTool/                 ← PAK 打包/解包工具
│
├── Paks/                              ← 原始游戏容器 (20GB，未跟踪)
└── Extracted/                         ← 提取的资产 (48GB，未跟踪)
```

## 核心工作流

### 快速路径：Mod DSL（推荐，Sprint 1.5）

```powershell
# 导入 DSL 模块
Import-Module .\tools\scripts\dsl\P3RModDSL.psm1

# 把亚基伤害翻 5 倍（自动 N²）
Set-SkillHpn -SkillId 10 -DamageMultiplier 5.0 -OutputDir .\my-agimod\

# 改 Persona 等级
Set-PersonaLevel -PersonaId 1 -Level 99 -OutputDir .\my-persona\

# 改敌人技能槽
Set-EnemySkill -EnemyId 100 -Slot 3 -SkillId 47 -OutputDir .\my-enemy\

# 改难度参数
Set-DifficultyParam -Difficulty easy -Field ExpRate -Value 3.0 -OutputDir .\my-diff\
```

### 全流程管道（Zen byte-patch 默认）

```powershell
# 内联 changes（最简单）
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999}) -ModName "AgiMod"

# DryRun 预览（不写字节）
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999}) -DryRun

# 多表 joint mod
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -ModScript .\my-changes.ps1 -ModName "MyMod"

# 配合 -NoInstall 只产出 .uasset 不部署
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999}) -NoInstall
```

### Sprint 2/3 工具链与安全系统（定位 → 预览 → guard → 备份/冲突 → 注册表/审计）

`modify-and-repack.ps1` 已接入 Sprint 2/3 工具：自动写入 `changes.json` / `mod.json` / `history.json`，更新 `$ModRegistry`，并在写回前执行 diff、schema/field guard、冲突检测、Git pre-mod backup（脏工作区安全跳过）与文件备份；写回后再执行 Zen 输出大小/`.uexp` 安全检查。完整协议见 [`docs/SECURITY.md`](docs/SECURITY.md)，复验记录见 [`docs/SPRINT_3_TEST_REPORT.md`](docs/SPRINT_3_TEST_REPORT.md)。

```powershell
# 1) 中文译名 / ID / TableKey / SchemaKey 定位
.\tools\scripts\tools\search-datatable.ps1 -Query "亚基" -Field hpn
.\tools\scripts\tools\search-wiki.ps1 -Query "Agi"

# 2) 人类可读 diff（显示中文名、旧值→新值、offset）
.\tools\scripts\tools\diff-changes.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999})

# 3) schema/field guard：PASS + flat scalar 才自动放行；PARTIAL 风险字段会拦截
.\tools\scripts\tools\guard-modify.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999})

# 4) 备份 / 回滚 / 冲突检测
.\tools\scripts\tools\backup-mod.ps1 -ModName "AgiMod" -Description "before tweak"
.\tools\scripts\tools\backup-mod.ps1 -ModName "AgiMod" -List
.\tools\scripts\tools\backup-mod.ps1 -ModName "AgiMod" -Compare <backupId>
.\tools\scripts\tools\rollback-mod.ps1 -ModName "AgiMod" -Preview
.\tools\scripts\tools\rollback-mod.ps1 -ModName "AgiMod" -Timestamp <backupId> -Force
.\tools\scripts\tools\conflict-check.ps1 -All
```

**Sprint 3 安全约束（Agent 必须遵守）**：

- 默认先 `-DryRun` 或 `diff-changes.ps1` 预览；真实写回前必须通过 guard + conflict check。
- `rollback-mod.ps1` / `-RemoveInstalled` / 覆盖 Reloaded II 已安装目录等破坏性动作，必须先 `-Preview` 并获得明确授权后才加 `-Force`。
- Git pre-mod backup 只在工作区干净时自动提交；若工作区已有用户改动，会安全跳过，不得为了触发备份而擅自提交/丢弃用户改动。
- `history.json` 记录当前运行的 backup + modify/rollback 审计；长期历史以 `.backup/<ModName>/<backupId>/` 中保存的前序 `history.json` 为准。
- 冲突分级：`error` 阻断；`warning`/`info` 可继续但需在回复中说明。


**Guard 规则（自然语言 Agent 必须遵守）**：

- `regressionStatus=pass` 且字段为 flat scalar（1/2/4/8 字节）→ 可自动写回。
- `disposition=safeWithNormalization` → 仅按 schema 标注的归一化规则放行。
- `regressionStatus=partial` / `disposition=needsManualReview` → 只允许已复核字段；被 `fieldReviewStatus` 标记的字段必须拒绝自动写回并提示人工 offset 复核。
- `fail` / `skip` / `deprecatedDuplicate` / `unsupportedUntilSchemaFix`、union、nested struct array、string/TArray/变长字段 → 默认拒绝自动写回。
- 用户要求跳过 guard / 冲突时，只有明确授权才能使用 `-SkipGuard` / `-SkipConflictCheck` / `-Force`。

### 读取 DataTable (无需 GUI)

```powershell
# 加载配置
. .\tools\scripts\Config.ps1

# 导出单个 DataTable
& $DataTools read "P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset" skills.json

# 批量导出
& $DataTools batch "Xrd777/Battle/Tables" .\json\Battle\

# 优先使用缓存 JSON (tools/Output/json/)，速度 < 100ms
```

### P3RDataTools CLI 命令

| 命令 | 用途 | 示例 |
|------|------|------|
| `read <vpath> [out.json]` | 导出 DataTable 为 JSON | `read "P3R/Content/.../DatSkillNormalDataAsset.uasset" skills.json` |
| `batch <filter> <dir>` | 批量导出 | `batch "Xrd777/Battle/Tables" .\json\Battle\` |
| `create-template <vpath> <outDir>` | ~~生成传统格式模板~~ (Sprint 0 ⊘ 弃用) | `create-template "P3R/.../Skills.uasset" .\templates\` |
| `create <jsonFile> <outDir>` | ~~JSON → .uasset+.uexp + manifest~~ (Sprint 1 ⊘ 弃用，见 P-007) | `create skills_modified.json .\mod\` |
| `modify <vpath> <jsonFile> <dir>` | 读取 IoStore + 应用修改 → .uasset+.uexp | `modify "P3R/.../Skills.uasset" modified.json .\mod\` |
| `quick <vpath> <jsonPath> <value> <dir>` | 读取 IoStore + 单值修改 → .uasset+.uexp | `quick "P3R/.../Skills.uasset" "Properties.Data[0].hpn" 999 .\mod\` |

> ⚠️ **`create`/`create-template`/`modify`/`quick` 均输出传统 `.uasset+.uexp`**，P3R 实测崩游戏（[P-007](docs/MODDING_PITFALLS.md#p-007)）。**当前唯一可工作的写回路径是 Zen byte-patch**（`Invoke-ZenPatch.ps1` / `modify-and-repack.ps1` / `P3RModDSL.psm1`）。

虚拟路径格式：`P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset`

### 查找要修改的文件

1. 查 `docs/amicitia/DATA_MAPPING.md` — 按需求定位 DataTable 文件名
2. 查 `docs/amicitia/md/` — 获取 ID 表（技能 ID、道具 ID 等）
3. 用 P3RDataTools `read` 导出 JSON → 修改 → 打包

### 中文用户译名约定（必读）

中文用户提需求时常使用中文译名（如「亚基」「俄耳甫斯」「魔术之手」）。AI Agent 必须：

1. **识别中文输入** → 查 [`docs/zh-cn/`](docs/zh-cn/README.md) 找到对应英文/ID
   - 用户：「把**亚基**伤害改成 999」→ `docs/zh-cn/skills.md` → `Agi` → `ID=10` → 改 `Data[10].hpn`（伤害字段）
   - 用户：「让**俄耳甫斯**初始等级 50」→ `docs/zh-cn/personas.md` → `Orpheus` → 改 `DatPersonaDataAsset`

2. **回复中文用户时使用标准中文译名 + 校准 hpn 语义**
   - ✅「已将**亚基**（火焰，3 MP）`hpn` 提升到 999（约为原版 5 倍显示伤害，详见 [P-009](docs/MODDING_PITFALLS.md#p-009-skill-表的-hpn-字段是显示伤害的平方要改-n-倍伤害得乘-n²)）」
   - ⚠️ **当用户说"把亚基伤害改成 N 倍"时**，要写回 `hpn = 40 × N²`，不是 `hpn = 40 × N`——Skill 表的 `hpn` 是显示伤害的**平方**（见 [P-009](docs/MODDING_PITFALLS.md#p-009-skill-表的-hpn-字段是显示伤害的平方要改-n-倍伤害得乘-n²)）
   - ❌「已将 Agi 伤害提升到 999」（除非用户明显用英文）
   - ❌「已将『阿基』伤害提升到 999」（非标准译名）

3. **译名优先级**：标准中文（`docs/zh-cn/`）> 英文（`docs/amicitia/`）> 日文（仅用户用日文输入时）

4. **歧义/缺失译名**（biligame WIKI 未收录的条目，如饰品/失踪者/合成范式等）：
   - 先查游戏内 L10N：`Extracted/IoStore/L10N/zh-Hans/`
   - 再退回 `docs/amicitia/md/` 用英文名 + 中文音译注释

### 常用 DataTable 快速索引

| 类别 | 虚拟路径 |
|------|---------|
| 技能数值 | `Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset` |
| 技能元数据 | `Xrd777/Battle/Tables/DatSkillDataAsset.uasset` |
| Persona 基础 | `Xrd777/Battle/Tables/DatPersonaDataAsset.uasset` |
| Persona 成长 | `Xrd777/Battle/Tables/DatPersonaGrowthDataAsset.uasset` |
| Persona 耐性 | `Xrd777/Battle/Tables/DatPersonaAffinityDataAsset.uasset` |
| 敌人属性 | `Xrd777/Battle/Tables/DatEnemyDataAsset.uasset` |
| 敌人耐性 | `Xrd777/Battle/Tables/DatEnemyAffinityDataAsset.uasset` |
| 遇敌表 | `Xrd777/Battle/Tables/DatEncountTableDataAsset.uasset` |
| 消耗道具 | `Xrd777/UI/Tables/DatItemCommonDataAsset.uasset` |
| 武器 | `Xrd777/UI/Tables/DatItemWeaponDataAsset.uasset` |
| 防具 | `Xrd777/UI/Tables/DatItemArmorDataAsset.uasset` |
| 饰品 | `Xrd777/UI/Tables/DatItemAccsDataAsset.uasset` |
| 技能卡 | `Xrd777/UI/Tables/DatItemSkillcardDataAsset.uasset` |
| 玩家升级 | `Xrd777/Battle/Tables/DatPlayerLevelupDataAsset.uasset` |
| HP/SP上限 | `Xrd777/Battle/Tables/DatPlayerMaxHPSPDataAsset.uasset` |
| 素材/材料 | `Xrd777/UI/Tables/DatItemMaterialDataAsset.uasset` |
| 服装 | `Xrd777/UI/Tables/DatItemCostumeDataAsset.uasset` |
| 鞋子 | `Xrd777/UI/Tables/DatItemShoesDataAsset.uasset` |
| 社群事件 | `Xrd777/Community/Bf/` (目录, ~132 子表) |
| BGM / 音频 | `Xrd777/CriData/CueSheet/system.uasset` ⚠️ SoundAtomCueSheet (可读 cue 元数据; 当前写回不可靠, 音频流字节需 vgmstream + AWB 工具) |

## 资产格式

游戏使用 UE 4.27，资产以 IoStore 为主要容器，传统 PAK 为辅助：

| 格式 | 文件 | 提取工具 | 用途 |
|------|------|---------|------|
| IoStore | `.utoc` + `.ucas` | CUE4Parse / FModel / UnrealEssentials 自带 `utoc-extractor` | 游戏原生 DataTable 来源（读取） |
| 传统 PAK | `.pak` | UnrealPak (CLI) | Mod 输出格式（写入，通过 Reloaded II 加载） |

**UnrealEssentials 接受的产物形态**（见 [`docs/UNREAL_ESSENTIALS_REFERENCE.md`](docs/UNREAL_ESSENTIALS_REFERENCE.md)）：

| 产物 | 部署位置 | P3R 上的状态 |
|---|---|---|
| 整包 `.utoc + .ucas` | `<Mod>/UnrealEssentials/` 下任意位置 | ❌ 当前未用 |
| 整包 `.pak` | `<Mod>/UnrealEssentials/` 下任意位置（不需 `_P` 后缀） | ❌ 当前未用（旧路径走 FEmulator/PAK） |
| 散文件 Zen `.uasset`（单文件、首字节 `00 00 00 00`） | `<Mod>/UnrealEssentials/<虚拟路径>/...` | ✅ **2026-06-24 Sprint 1.5 工程化**：`Invoke-ZenPatch.ps1` 驱动字节写回，`modify-and-repack.ps1` 全流程编排，`P3RModDSL.psm1` DSL helper；AgiMod PoC 验证可运行 |
| 散文件传统 `.uasset+.uexp`（首字节 `C1 83 2A 9E`） | `<Mod>/UnrealEssentials/<虚拟路径>/...` | ❌ **2026-06-24 实测直接崩 P3R**（[P-007](docs/MODDING_PITFALLS.md#p-007-unrealessentials-iostore-资产替换偏好-zen-单文件)）；当前 `P3RDataTools.create` 仍输出这种，**别拿这条路径给用户用** |

- **Xrd777 > Astrea**：同名资产以 Xrd777 为准
- **IoStore 只读**：游戏从 IoStore 加载 DataTable，**写回不能改 IoStore**——只能让 mod 加载器（UnrealEssentials / FEmulator）在 UE 资产虚拟文件系统里覆盖同名 `.uasset`
- **✅ Zen byte-patch 写回链路已打通**：`Invoke-ZenPatch.ps1`（T1.5.5）+ `P3RModDSL.psm1`（T1.5.6）+ `modify-and-repack.ps1`（T1.5.7）组成完整管道。详见 [`docs/ZEN_BYTE_PATCH_WORKFLOW.md`](docs/ZEN_BYTE_PATCH_WORKFLOW.md) 与 [Sprint 1.5](docs/DEVELOPMENT_PLAN.md#sprint-15-zen-byte-patch-写回引擎-2026-06-24-起替代-sprint-1-传统格式写回)。
- **P3R 不能直接加载 `Paks/` 下的 .pak**：必须通过 Reloaded II + UnrealEssentials 或 FEmulator 注入

## 工具链详情

### P3RDataTools (.NET 8 CUE4Parse CLI)
- 源码：`tools/P3RDataTools/` (CUE4Parse 1.1.1 + UAssetAPI 1.1.0 + Newtonsoft.Json)
- **版本锁定**：CUE4Parse **1.1.1**（不可升级，1.2.2 的 Zlib-ng.NET 不兼容）
- 发布：`dotnet publish -c Release --self-contained -r win-x64 -o publish`
- 通过 IoStore 容器挂载 140K+ 文件，AES 解密内置

### UnrealPak (PAK 打包)
```powershell
# 在 tools/UnrealPakTool/ 目录下执行
.\UnrealPak.exe "MyMod_P.pak" -Create="manifest.txt" -compress
```

### FModel (GUI，最后手段)
- 浏览资产树、导出 DataTable JSON、提取纹理 PNG
- 一次性模板导出时使用

## Mod 制作流程

### Zen Byte-Patch 路径（★ 推荐，Sprint 1.5，P3R 唯一可工作写回）

```powershell
# 方案 A：DSL 函数（最方便）
Import-Module .\tools\scripts\dsl\P3RModDSL.psm1
Set-SkillHpn -SkillId 10 -DamageMultiplier 5.0 -OutputDir .\my-mod\

# 方案 B：内联 changes（一行搞定的常用修改）
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999}) -ModName "MyMod"

# 方案 C：changes.json 文件（批量修改很多字段）
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -ChangesJson .\my-changes.json -ModName "MyMod"

# 方案 D：DSL 脚本（复杂逻辑）
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -ModScript .\my-changes.ps1 -ModName "MyMod"
# (my-changes.ps1 里 Import-Module P3RModDSL.psm1 后调用 DSL 函数)

# 预览预览（DryRun——只看计划写什么字节，不改动文件）
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -Changes @(...) -DryRun

# 只产出 .uasset 不部署（用于手动检查）
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -Changes @(...) -NoInstall

# 部署后: Reloaded II 启用 mod → Reloaded-II.exe 启动游戏 → 数值生效
```

### 传统路径（⊘ 已弃用，产物在 P3R 上崩游戏，保留备查）

```powershell
# 以下命令均输出传统 .uasset+.uexp（首字节 C1 83 2A 9E），P3R 实测崩溃（P-007）
# 仅作文档参考——不要在实际 Mod 制作中使用
#
# & $DataTools create skills_modified.json .\mod\`
# & $DataTools modify "P3R/Content/.../Skills.uasset" modified.json .\mod\
# & $DataTools quick "P3R/Content/.../Skills.uasset" "Data[0].hpn" 999 .\mod\
```

# 直接指定虚拟路径
.\tools\scripts\modify-and-repack.ps1 -VirtualPath "P3R/Content/Xrd777/..." -ModName "MyMod"

# 同时生成 FEmulator/PAK 备用产物 (可选, 99% 情况不需要)
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -ModName "MyMod" -PackPak

# 只生成 Zen .uasset，不写入 Reloaded II Mods/
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -NoInstall
```

### Mod 安装（Reloaded II + UnrealEssentials，默认）

参考形态：[`tools/Reloaded II/Mods/p3rpc.ui.barionskillnames/`](tools/Reloaded II/Mods/p3rpc.ui.barionskillnames/)（已验证可运行的项目内参考 mod）。

```
Reloaded-II/
└── Mods/
    └── <ModName>/
        ├── ModConfig.json                          ← Mod 元数据 (SupportedAppId=["p3r.exe"], ModDependencies=["p3rpc.essentials"])
        └── UnrealEssentials/
            └── P3R/
                └── Content/
                    └── Xrd777/
                        └── Battle/Tables/          ← 与游戏内虚拟路径一一对应
                            └── DatSkillNormalDataAsset.uasset     ← Zen 单文件（无 .uexp）
```

**目录命名规则**：把虚拟路径 `P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset` 完整镜像到 `<Mod>/UnrealEssentials/P3R/Content/Xrd777/Battle/Tables/...uasset`。Zen byte-patch 产物只有 `.uasset`，文件名必须与原资产严格一致。

### ModConfig.json 模板（UnrealEssentials 默认）

```json
{
  "ModId": "<唯一ID>",
  "ModName": "<显示名称>",
  "ModAuthor": "claude",
  "ModVersion": "1.0.0",
  "ModDescription": "<描述>",
  "ModDll": "",
  "ModIcon": "",
  "ModR2RManagedDll32": "",
  "ModR2RManagedDll64": "",
  "ModNativeDll32": "",
  "ModNativeDll64": "",
  "Tags": [],
  "CanUnload": null,
  "HasExports": null,
  "IsLibrary": false,
  "ReleaseMetadataFileName": "<ModId>.ReleaseMetadata.json",
  "PluginData": null,
  "IsUniversalMod": false,
  "ModDependencies": ["p3rpc.essentials"],
  "OptionalDependencies": [],
  "SupportedAppId": ["p3r.exe"],
  "ProjectUrl": ""
}
```

- **`SupportedAppId`**: 必须包含 `"p3r.exe"`，否则 Reloaded II 不会为 P3R 加载此 Mod
- **`ModDependencies`**: **项目级默认 `["p3rpc.essentials"]`**（2026-06-24 起；间接拉齐 UnrealEssentials + UTOC.Stream.Emulator + FileEmulationFramework；与 [`p3rpc.ui.barionskillnames`](tools/Reloaded II/Mods/p3rpc.ui.barionskillnames/) 一致）。极小化需求可改写 `["UnrealEssentials"]`（只拉资产替换链，不暴露 P3R 体验补丁面板）。两种都能跑，详见 [`docs/P3RPC_ESSENTIALS_REFERENCE.md`](docs/P3RPC_ESSENTIALS_REFERENCE.md) 与 [`docs/MODDING_PITFALLS.md` P-008](docs/MODDING_PITFALLS.md#p-008-modconfigjson-默认依赖统一为-p3rpcessentials)。如果同时也想要 FEmulator/PAK fallback，再加 `reloaded.universal.fileemulationframework.pak`
- **`ModId`**: 唯一标识符，不可与其他 Mod 重复
- **`ModAuthor`**: 统一填写 `"claude"`（AI Agent 生成标识）

### Mod 安装（FEmulator/PAK，仅作 fallback）

仅当 UnrealEssentials 路径出问题需要排查时使用：

```
Reloaded-II/
└── Mods/
    └── <ModName>/
        ├── ModConfig.json          ← ModDependencies 改为 ["reloaded.universal.fileemulationframework.pak"]
        └── FEmulator/PAK/<ModName>.pak
```

注意：必须用 `modify-and-repack.ps1 -PackPak`，且**校验 PAK 大小 > 1 KB**（< 1 KB 是空 PAK，见 [`docs/MODDING_PITFALLS.md` P-002](docs/MODDING_PITFALLS.md#p-002-占位空-pak-不要部署到-reloaded-ii)）。

Mod 通过 Reloaded II 启动游戏后生效。无论哪种挂载方式，都必须由 Reloaded-II.exe 启动 P3R，不能 Steam/桌面快捷方式直接启动。

## 关键约束

- **UE 版本**：4.27（pak version 11），UnrealPak 和 CUE4Parse 均需匹配
- **Xrd777 > Astrea**：同名资产以 Xrd777 为准
- **CUE4Parse = 1.1.1**：不要升级到 1.2.2（Zlib 初始化失败）
- **P3R 不直接加载 Paks/ 下的 .pak**：必须通过 Reloaded II + File Emulation Framework 加载
- **Mod PAK 不加密**（UnrealPak 不需要 `-encrypt`）
- **IoStore 只读**：DataTable 从 IoStore 读取（CUE4Parse），修改后通过 Reloaded II 以传统 PAK 形式注入
- **Crypto.json 必须简化**（不含 `$types` 字典）
- **`Dat*DataAsset` 数组下标 == 资产 ID**：写 Mod 脚本前必查 [`docs/MODDING_PITFALLS.md`](docs/MODDING_PITFALLS.md) 与 Wiki ID 表。`Data[0]` 通常是引擎占位行，**不是**任何游戏内技能/Persona/道具。已踩：Agi 实际是 `Data[10]`，不是 `Data[0]`。

## 常见问题排查

### Mod 不生效

```
检查清单 (UnrealEssentials 默认路径):
□ 是否通过 Reloaded II 启动游戏（不是 Steam/快捷方式）
□ .uasset(+.uexp) 是否在 <Mods>/<ModName>/UnrealEssentials/P3R/Content/<虚拟路径>/ 下
□ 文件名（除后缀）是否与原资产严格一致
□ ModConfig.json 是否包含 "UnrealEssentials" 依赖 + SupportedAppId=["p3r.exe"]
□ Reloaded II UI 里这个 Mod 是否已勾选启用
□ （若用了 P3RDataTools.create 产物）.uasset 与 .uexp 是否成对存在

检查清单 (FEmulator/PAK fallback 路径):
□ PAK 是否放在 <Mods>/<ModName>/FEmulator/PAK/ 下
□ PAK 大小 > 1 KB（< 1 KB 是空 PAK, 见 P-002）
□ ModConfig.json 是否包含 reloaded.universal.fileemulationframework.pak 依赖
□ Manifest mount point 路径是否正确: "../../../P3R/Content/..."

调试方法:
  Reloaded II → 右键 Mod → 查看日志
  用 FModel 加载你的 Mod PAK → 检查内部路径是否正确
  确认 Inaba EXE Patcher 已安装并启用
```

### 游戏崩溃（通过 Reloaded II 启动时）

```
症状: Reloaded II 启动游戏后崩溃
原因:
  1. UnrealPak 版本不匹配 (必须 UE 4.27)
  2. .uasset 版本号不兼容（TemplateCreator 二进制格式问题）
  3. 缺少 .uexp (只打包了 .uasset)
  4. 资产引用路径错误 (manifest mount point)

解决:
  - 运行 setup.ps1 验证 UnrealPak 版本
  - 确保 .uasset + .uexp 成对发布
  - 检查 manifest.txt: "../../../P3R/Content/..."
  - 暂时禁用 Mod → 确认游戏本身正常 → 逐个启用排查
```

### 游戏崩溃

```
症状: 打包 Mod PAK 后游戏崩溃在启动时
原因:
  1. UnrealPak 版本不匹配 (必须 UE 4.27)
  2. .uasset 版本号不兼容
  3. 缺少 .uexp (只打包了 .uasset)
  4. 资产引用路径错误 (manifest mount point)

解决:
  - 运行 setup.ps1 验证 UnrealPak 版本
  - 确保 .uasset + .uexp 成对发布
  - 检查 manifest.txt 中路径格式: "../../../P3R/Content/..."
  - 用 -log -verbose 启动游戏定位崩溃资产
```

### 加密 Key 提取 (如需)

```
当前项目已内置 AES Key，通常无需修改。
如果游戏更新后 Key 变更:
  1. 用 Ghidra 分析游戏 EXE → 搜索 "0x" 256-bit hex 字符串
  2. 或用 Process Hacker dump 游戏运行时内存 → 搜索 AES S-Box
  3. 更新 tools/scripts/Config.ps1 中的 $AesKey 变量
```

## 相关文档

| 文档 | 内容 |
|------|------|
| `docs/PRD_P3R_AI_AGENT.md` | 产品需求、用户画像、功能列表、验收标准、术语表 |
| `docs/SYSTEM_ARCHITECTURE.md` | 分层架构、模块设计、数据流、接口定义、安全架构、技术选型 |
| `docs/DEVELOPMENT_PLAN.md` | Sprint 分解、任务依赖、工时估算、风险缓冲、里程碑日历 |
| `docs/P3R_ASSET_ANALYSIS.md` | 资产结构分析、DataTable 索引、IoStore/PAK 分片详情、Mod 制作速查 |
| `docs/DEVELOPER_GUIDE.md` | 开发环境搭建、模板导出指南、调试排查、日常开发工作流 |
| `docs/MODDING_PITFALLS.md` | **Mod 制作避坑指南（写脚本前必读）**：DataTable 索引陷阱、空 PAK、加载链等已踩坑及修复 |
| `docs/UNREAL_ESSENTIALS_REFERENCE.md` | **UnrealEssentials 能力速查**：上游 README 提炼，含整包/散文件路径、Zen 资产、`utoc-extractor`、元数据格式、依赖链 |
| `docs/P3RPC_ESSENTIALS_REFERENCE.md` | **Persona 3 Reload Essentials (p3rpc.essentials) 能力速查**：依赖关系、5 个运行时配置项（去焦点暂停 / 跳开场 / 快速菜单）、与 UnrealEssentials 的关系、何时该依赖它 |
| `docs/SECURITY.md` | **Sprint 3 安全协议**：四层安全架构、`mod.json` / `history.json` / registry、备份/回滚/冲突命令、紧急恢复指南 |
| `docs/SPRINT_3_TEST_REPORT.md` | **Sprint 3 验收复验报告**：非破坏性 CLI smoke、冲突阻断、重复运行备份/审计修复、剩余人工项 |
| `docs/ZEN_BYTE_PATCH_WORKFLOW.md` | **★ Zen Byte-Patch 写回工作流（P3R 当前唯一可工作路径，Sprint 1.5 已工程化）**：`Invoke-ZenPatch.ps1` 引擎 + `P3RModDSL.psm1` DSL + `modify-and-repack.ps1` 全流程管道 |
| `docs/zh-cn/README.md` | **中文用户译名（biligame WIKI）**：技能/Persona/敌人/Arcana/角色/系统术语三语对照 |
| `docs/amicitia/DATA_MAPPING.md` | Amicitia WIKI ↔ 提取资产文件精确映射（英文 ID 权威源） |
