# P3R Modding AI Agent

> 仓库总入口。面向 **Persona 3 Reload (P3R)** 的 Mod 制作与逆向工程工作区——把中文/自然语言需求落到 P3R DataTable 的安全、可回滚字节修改上。
>
> 本文件为仓库总入口，合并了原用户指南与开发指南。深度参考见文末「深入文档」。

## 当前能力

✅ 已工程化（Zen byte-patch 主路径）：

- 从 `Extracted/IoStore` Zen `.uasset` 获取原始 DataTable 资产。
- 用 010-Editor 模板生成/校准 schema（`Parse-BtTemplate` / `Calibrate-SchemaHeaders` / `Test-SchemaRegression`）。
- 用 `Invoke-ZenPatch.ps1` 对定长标量字段做 little-endian byte patch。
- 用 `modify-and-repack.ps1` 编排 diff → guard → conflict → backup → patch → install。
- 默认部署到 `<Mod>/UnrealEssentials/P3R/Content/...`，由 Reloaded II 加载。

⚠️ 边界（不在自动写回范围）：

- 文本/本地化、模型、纹理、动画、音频重打包（见 [FUTURE_RESOURCE_SUPPORT.md](docs/FUTURE_RESOURCE_SUPPORT.md)）。
- `TArray`/string/union/nested struct array/变长字段。
- `regressionStatus=fail/skip/partial` 且未人工复核字段。
- 传统 `.uasset+.uexp` 产物（[P-007](docs/MODDING_PITFALLS.md#p-007-unrealessentials-iostore-资产替换偏好-zen-单文件)）。
- 真实游戏内验证仍需用户通过 Reloaded II 手动启动 P3R。

## 仓库快照

| 项 | 当前值 |
|---|---:|
| `tools/Output/json/**/*.json` | 约 490 个 DataTable JSON 快照 |
| `tools/templates-010/**/*.bt` | 44 个 010 Editor 模板 |
| `tools/templates-010/schemas/*_schema.json` | 34 个 schema（19 PASS / 9 PARTIAL / 2 FAIL / 4 SKIP）|
| `tools/scripts` PowerShell 模块/脚本 | 17 |
| Amicitia Markdown 参考页 | 37 |
| 中文译名 Markdown 文件 | 8 |

## 必须遵守的项目事实

- 当前唯一推荐写回路径是 **Zen 单文件 `.uasset` byte-patch** + Reloaded II / UnrealEssentials 散文件挂载。
- `P3RDataTools create/modify/quick/create-template` 仍存在，但属传统 `.uasset+.uexp` 路径；新 Mod 不应使用（[P-007](docs/MODDING_PITFALLS.md#p-007-unrealessentials-iostore-资产替换偏好-zen-单文件)）。
- `Data[N]` 的 N 通常就是游戏资产 ID；**不要默认改 `Data[0]`**（引擎占位行）。
- Skill 表 `hpn` 是显示伤害的平方语义；「N 倍伤害」应写 `原 hpn × N²`（[P-009](docs/MODDING_PITFALLS.md)）。
- 自动写回仅面向 guard 放行的定长标量字段（1/2/4/8 字节 flat scalar）；其余默认拒绝。
- `Paks/`、`Extracted/`、`tools/Reloaded II/`、`tools/UnrealPakTool/`、`tools/Output/.data/` 为本地/生成/忽略目录，不提交。

完整硬规则见 [CLAUDE.md](CLAUDE.md) §3。

---

## 一、环境与初始化（开发者）

### 必需组件

| 组件 | 版本 | 用途 |
|------|------|------|
| **.NET 8 SDK** | 8.0.x | 编译 P3RDataTools | [下载](https://dotnet.microsoft.com/download/dotnet/8.0) |
| **PowerShell** | 5.1+ | 编排脚本 | Windows 内置 |
| **P3R 游戏** | 任意 | 游戏资产来源 | Steam / Game Pass |
| **Claude Code** | 最新 | AI Agent | [claude.ai/code](https://claude.ai/code) |

可选：FModel（`tools/FModel.exe`，GUI 资产浏览器）、Git、VS Code。

### 首次安装

```powershell
git clone <repo-url> P3R_Modding
cd P3R_Modding
copy .env.example .env
notepad .env       # 配置 P3R_PAKS_DIR / P3R_MOD_OUTPUT_DIR
.\setup.ps1
```

`setup.ps1` 执行：加载配置 → 检查运行时 → 创建目录 → 编译 P3RDataTools（首次 1-2 分钟）→ 验证游戏资产 → 最终检查。可 `-SkipBuild` / `-SkipVerify` / `-WhatIf`。

`.env` 关键项：

```ini
P3R_PAKS_DIR=C:\Program Files (x86)\Steam\steamapps\common\P3R\P3R\Content\Paks
P3R_MOD_OUTPUT_DIR=C:\Users\<你>\Code\P3R_Modding\tools\Output\mod
```

---

## 二、项目结构

```
P3R_Modding/
├── CLAUDE.md                    ← AI Agent 工作指令（硬规则 / 工作流 / 入口表）⭐
├── README.md                    ← 本文件
├── setup.ps1                    ← 项目初始化
├── docs/                        ← 文档（见文末「深入文档」）
├── tools/
│   ├── P3RDataTools/            ← CLI 读写引擎 (C# / .NET 8 + CUE4Parse 1.1.1)
│   ├── scripts/
│   │   ├── Config.ps1           ← 共享配置
│   │   ├── modify-and-repack.ps1 ← ★ Zen byte-patch 全流程编排
│   │   ├── Invoke-ZenPatch.ps1  ← schema-driven Zen 字节写回引擎
│   │   ├── Parse-BtTemplate.ps1 / Calibrate-SchemaHeaders.ps1 / Test-SchemaRegression.ps1
│   │   ├── dsl/P3RModDSL.psm1   ← Mod DSL helper
│   │   └── tools/               ← search / diff / guard / conflict / backup / rollback / batch
│   ├── templates-010/           ← ★ 010 .bt schema 与校准/回归报告
│   ├── templates/               ← 传统 .uasset+.uexp 模板库（弃用/fallback）
│   ├── Output/                  ← 生成文件 (Git 忽略)：json / mod / .backup / .data
│   ├── FModel.exe               ← GUI 资产浏览器
│   └── UnrealPakTool/           ← PAK 打包工具
├── Paks/                        ← 游戏容器 (Git 忽略)
└── Extracted/                   ← 提取资产 (Git 忽略)
```

---

## 三、核心技术栈与版本锁定

| 库 | 版本 | 不可升级原因 |
|------|------|------|
| CUE4Parse | **1.1.1** | 1.2.2 依赖 Zlib-ng.NET，Windows 上 `System.TypeInitializationException` |
| UAssetAPI | 1.1.0 | 仅传统 UE Package fallback；P3R 主写回不依赖 |
| UnrealPak | **UE 4.27** | 必须匹配 P3R 引擎版本 |
| .NET | **8.0** | LTS，CUE4Parse/UAssetAPI 兼容 |

数据流（主路径）：

```
游戏 Paks/ (.utoc+.ucas / .pak)
    │  CUE4Parse 1.1.1 → P3RDataTools read/batch → JSON 缓存
Extracted/IoStore/.../*.uasset   Zen 原件（只读）
    │  010 schema (rowSize/headerSize/field offset)
    └──→ Invoke-ZenPatch.ps1   复制原件 → 定长标量 byte-patch（output size == original，无 .uexp）
         └──→ UnrealEssentials  <Mod>/UnrealEssentials/P3R/Content/...
```

---

## 四、用户工作流：制作一个 Mod

### 4.1 定位目标

中文需求先查标准译名与 ID：

```powershell
.\tools\scripts\tools\search-datatable.ps1 -Query "亚基" -Field hpn
```

### 4.2 预览（DryRun，不写字节不安装）

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999}) -ModName AgiMod -DryRun
```

`Data[10]` = 亚基 / Agi（Skill ID 10）。`hpn` 是显示伤害平方：5 倍伤害应写 `40 × 25 = 1000`（`999` 约等于 5 倍）。

### 4.3 只生成产物，不安装

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999}) -ModName AgiMod -NoInstall
```

产物在 `tools/Output/mod/AgiMod/`。

### 4.4 生成并安装到 Reloaded II

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999}) -ModName AgiMod
```

安装后：打开 Reloaded II → 启用 Mod → 用 `Reloaded-II.exe` 启动 P3R（**不能用 Steam 快捷方式**）→ 游戏内观察。

### 4.5 DSL 函数速查

```powershell
Import-Module .\tools\scripts\dsl\P3RModDSL.psm1
Set-SkillHpn -SkillId 10 -DamageMultiplier 5.0 -OutputDir .\my-mod\
```

| 函数 | 目标 |
|------|------|
| `Set-SkillHpn` / `Set-SkillCost` / `Set-SkillData` | 技能伤害 / 消耗 / 多字段 |
| `Set-PersonaLevel` / `Set-PersonaStat` | Persona 等级 / 属性 |
| `Set-EnemyHP` / `Set-EnemySP` / `Set-EnemySkill` / `Set-EnemyStat` | 敌人 HP / SP / 技能槽 / 多字段 |
| `Set-DifficultyParam` | 难度参数（`Rows.normal.ExpRate` 等） |
| `Set-PlayerLevelup` | 升级经验 |
| `New-ModChanges` | 通用（任意 schema） |

> DSL 底层偏向直接调用 `Invoke-ZenPatch.ps1`；完整审计/安装优先用 `modify-and-repack.ps1`。

### 4.6 多表 Mod（Sprint 4）

`-MultiChangesJson` 接受含 `tables[]` 的 JSON，逐表 dry-run / patch / install。建议先 `-DryRun -NoInstall` 人工确认。

### 4.7 批量修改

```powershell
.\tools\scripts\tools\batch-modify.ps1 -TableKey Skills -Field cost -Value 1 `
  -Ids 118,119 -ModName BatchSkillMod -PreviewOnly

# 按 where 条件筛选
.\tools\scripts\tools\batch-modify.ps1 -TableKey Skills -Field cost -Value 1 `
  -WhereField costtype -WhereOperator eq -WhereValue 2 -ModName LowCostSkills -DryRun -NoInstall
```

`WhereOperator`：`eq`/`ne`/`gt`/`ge`/`lt`/`le`/`match`。

---

## 五、备份、冲突与回滚

```powershell
# 冲突检测（error 阻断，warning/info 仅提示）
.\tools\scripts\tools\conflict-check.ps1 -All

# 命名备份 / 列出 / 比较
.\tools\scripts\tools\backup-mod.ps1 -ModName AgiMod -Name before-tweak -Description 'before hpn tweak'
.\tools\scripts\tools\backup-mod.ps1 -ModName AgiMod -List
.\tools\scripts\tools\backup-mod.ps1 -ModName AgiMod -Compare <backupId>

# 回滚预览 → 执行（必须显式 -Force）
.\tools\scripts\tools\rollback-mod.ps1 -ModName AgiMod -Preview
.\tools\scripts\tools\rollback-mod.ps1 -ModName AgiMod -Force
```

四层安全架构、元数据格式（`mod.json` / `history.json` / `mod_registry.json`）、紧急恢复流程见 [docs/SECURITY.md](docs/SECURITY.md)。

---

## 六、Mod 安装格式（Reloaded II）

P3R **不支持**直接把 `.pak` 丢进 `Content/Paks/`；所有 Mod 必须通过 Reloaded II 加载。完整能力（整包/散文件、Zen vs 传统、`utoc-extractor`、元数据、依赖链）见 [docs/ESSENTIALS_REFERENCE.md](docs/ESSENTIALS_REFERENCE.md)。

### UnrealEssentials Zen 散文件（默认）

```
<Reloaded-II>/Mods/<ModName>/
├── ModConfig.json
└── UnrealEssentials/P3R/Content/Xrd777/Battle/Tables/<资产名>.uasset
```

`ModConfig.json`：

```json
{
  "ModId": "p3r.agi.damage.999",
  "ModName": "P3R - 亚基伤害 999",
  "ModAuthor": "claude",
  "ModVersion": "1.0.0",
  "ModDescription": "将亚基 (Agi) 的伤害从 40 改为 999",
  "ModDependencies": ["p3rpc.essentials"],
  "SupportedAppId": ["p3r.exe"]
}
```

- `SupportedAppId` 必须含 `"p3r.exe"`；`ModDependencies` 默认 `["p3rpc.essentials"]`（[P-008](docs/MODDING_PITFALLS.md#p-008-modconfigjson-默认依赖统一为-p3rpcessentials)），极小化可改 `["UnrealEssentials"]`。
- `.uasset` 首字节 `00 00 00 00`，大小与 `Extracted/IoStore` 原件一致，**无 `.uexp`**。

### FEmulator/PAK（仅 fallback 排查）

`modify-and-repack.ps1 -PackPak` 生成 PAK，放 `<Mod>/FEmulator/PAK/<ModName>.pak`，依赖改 `["reloaded.universal.fileemulationframework.pak"]`。PAK < 1 KB 通常是空包（[P-002](docs/MODDING_PITFALLS.md)）。

### 一次性安装 Reloaded II

1. 下载 [Reloaded II](https://github.com/Reloaded-Project/Reloaded-II/releases) 解压。
2. 运行 `Reloaded-II.exe` → "Add Application" → 选 `P3R.exe`。
3. 首次启动自动安装 **P3R Essentials** + **Inaba EXE Patcher**。
4. 确认 **UnrealEssentials** 已下载。

---

## 七、常见失败与处理

| 症状 | 可能原因 | 处理 |
|---|---|---|
| guard 拒绝 | schema fail/skip/partial 或字段需人工复核 | 查看 [SCHEMA_COVERAGE_REPORT.md](docs/SCHEMA_COVERAGE_REPORT.md) |
| conflict 阻断 | 其它 Mod 修改同字段且值不同 | 选一个 Mod 负责，或明确 `-Force` |
| Mod 不生效 | 未用 Reloaded II 启动 / 路径错误 / Mod 未启用 | 检查 `UnrealEssentials/P3R/Content/...` 镜像路径、`ModConfig.json`、`SupportedAppId` |
| 游戏崩溃 | 改到不安全字段或用传统 `.uasset+.uexp` | 禁用 Mod，回滚，检查 guard 与 P-007/P-010 |
| `CUE4Parse: Package has no data` | AES Key 不匹配 / IoStore 容器损坏 | 核对 `$AesKey`，验证游戏文件完整性 |
| `Zlib initialization failed` | CUE4Parse 版本错误 | 必须用 1.1.1；清理 obj/bin 重新 restore |

---

## 八、构建与扩展

### 编译 P3RDataTools

```powershell
cd tools\P3RDataTools
dotnet restore
dotnet build -c Release
# 自包含发布：
dotnet publish -c Release --self-contained -r win-x64 -o publish
```

NuGet：CUE4Parse 1.1.1、UAssetAPI 1.1.0、Newtonsoft.Json 13.0.4、OffiUtils 2.0.1。

### 新增 DataTable 类型

1. 导入/修复 010 `.bt` → `tools/templates-010/`
2. `Parse-BtTemplate.ps1` → schema JSON
3. `Calibrate-SchemaHeaders.ps1` 校准 headerSize
4. `Test-SchemaRegression.ps1` 对照 Zen bytes 与 CUE4Parse JSON
5. PASS + flat scalar 进自动 allowlist；其余写 guard metadata
6. 更新 `Config.ps1` `$DataTables`/`$SchemaMap` 与 `DATA_MAPPING.md`

无需改 C# 写回模块。新增 Claude Code 工具只需写 `.ps1` + 在 [CLAUDE.md](CLAUDE.md) §6 入口表登记。

---

## 九、传统模板生成（已弃用，仅 fallback / 历史研究）

> ⚠️ **不要用于新 P3R DataTable Mod。** `P3RDataTools create-template`/`create` 产出传统 `.uasset+.uexp`（Magic `C1 83 2A 9E`），P3R 实测 boot-crash（[P-007](docs/MODDING_PITFALLS.md#p-007-unrealessentials-iostore-资产替换偏好-zen-单文件)）。本节仅供未来完整序列化研究或非 P3R fallback。

```powershell
. .\tools\scripts\Config.ps1
# 单个
& $DataTools create-template "P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset" .\tools\templates\
# 批量（18 种 + 扩展）
foreach ($vpath in $DataTables.Values) { & $DataTools create-template $vpath "$TemplatesDir" }
& $DataTools create-template "P3R/Content/Xrd777/UI/Tables/DatItemMaterialDataAsset.uasset" "$TemplatesDir"
& $DataTools create-template "P3R/Content/Xrd777/UI/Tables/DatItemCostumeDataAsset.uasset" "$TemplatesDir"
& $DataTools create-template "P3R/Content/Xrd777/UI/Tables/DatItemShoesDataAsset.uasset" "$TemplatesDir"
# 验证
.\tools\scripts\verify-templates.ps1   # 预期 Total: 18 | Pass: 18
```

`create-template` 流程：CUE4Parse 读 IoStore → JSON → `TemplateCreator` 转 UE4 传统 Package 二进制 → 写 `.uasset`（Header+NameMap+ImportMap+ExportMap）+ `.uexp`（行数据）。输出 Magic `C1 83 2A 9E`，可由 UAssetAPI 加载。

18 种模板清单见 [docs/ZEN_BYTE_PATCH_WORKFLOW.md](docs/ZEN_BYTE_PATCH_WORKFLOW.md) 或 `tools/templates/template_index.json`。

---

## 深入文档

| 文档 | 用途 |
|---|---|
| [CLAUDE.md](CLAUDE.md) | AI Agent 工作指令：硬规则、标准工作流、TableKey 索引、schema/guard 策略、入口表 ⭐ |
| [docs/ZEN_BYTE_PATCH_WORKFLOW.md](docs/ZEN_BYTE_PATCH_WORKFLOW.md) | 当前唯一推荐写回链路详解 |
| [docs/SECURITY.md](docs/SECURITY.md) | 四层安全架构、元数据格式、紧急恢复、Sprint 3 复验 |
| [docs/ESSENTIALS_REFERENCE.md](docs/ESSENTIALS_REFERENCE.md) | UnrealEssentials + p3rpc.essentials 能力、依赖与路径规则 |
| [docs/SYSTEM_ARCHITECTURE.md](docs/SYSTEM_ARCHITECTURE.md) | 架构全景图、工具调用关系、错误处理、技术选型理由 |
| [docs/SCHEMA_COVERAGE_REPORT.md](docs/SCHEMA_COVERAGE_REPORT.md) | schema 安全覆盖与 allow/deny 边界 |
| [docs/MODDING_PITFALLS.md](docs/MODDING_PITFALLS.md) | 已确认坑点（P-001~P-010）；写脚本前必读 |
| [docs/MANUAL_TEST_TODO.md](docs/MANUAL_TEST_TODO.md) | 人工验收 / 边界测试矩阵 |
| [docs/P3R_ASSET_ANALYSIS.md](docs/P3R_ASSET_ANALYSIS.md) | 资产拓扑与按 Mod 目标分类索引 |
| [docs/zh-cn/README.md](docs/zh-cn/README.md) | 中文译名入口 |
| [docs/amicitia/DATA_MAPPING.md](docs/amicitia/DATA_MAPPING.md) | Amicitia Wiki ↔ 游戏文件映射 |
| [docs/FUTURE_RESOURCE_SUPPORT.md](docs/FUTURE_RESOURCE_SUPPORT.md) | 音乐/文本/模型等非 DataTable 未来路线 |

### 相关资源

| 资源 | 链接 |
|------|------|
| CUE4Parse | https://github.com/FabianFG/CUE4Parse |
| UAssetAPI | https://github.com/atenfyr/UAssetAPI |
| 010-Editor-Templates | https://github.com/godofknife/010-Editor-Templates |
| Amicitia Wiki | https://amicitia.miraheze.org/wiki/Persona_3_Reload |
| Reloaded II | https://github.com/Reloaded-Project/Reloaded-II/releases |
