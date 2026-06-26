# P3R Modding AI Agent — 开发指南

> **面向**: 希望参与 P3R Modding AI Agent 开发或扩展的开发者
> **前提**: 已安装 P3R 游戏（Steam / Game Pass）、Windows 10+、PowerShell 5.1+

---

## 一、环境要求

### 必需

| 组件 | 版本 | 用途 | 下载 |
|------|------|------|------|
| **.NET 8 SDK** | 8.0.x | 编译 P3RDataTools | [dotnet.microsoft.com](https://dotnet.microsoft.com/download/dotnet/8.0) |
| **PowerShell** | 5.1+ | 编排脚本 | Windows 内置 |
| **P3R 游戏** | 任意 | 游戏资产来源 | Steam / Game Pass |
| **Claude Code** | 最新 | AI Agent | [claude.ai/code](https://claude.ai/code) |

### 可选

| 组件 | 版本 | 用途 | 下载 |
|------|------|------|------|
| **FModel** | 最新 | GUI 资产浏览器 / 调试提取；传统模板导出仅作历史 fallback | 项目内 `tools/FModel.exe` |
| **Git** | 2.x | 版本管理 | `winget install Git.Git` |
| **VS Code** | 最新 | 代码编辑 | `winget install Microsoft.VisualStudioCode` |

---

## 二、项目初始化

### 首次安装

```powershell
# 1. 克隆仓库
git clone <repo-url> P3R_Modding
cd P3R_Modding

# 2. 运行初始化脚本
.\setup.ps1
```

`setup.ps1` 执行 5 个步骤：

```
[0/5] 加载配置          ← 从 .env 或环境变量读取路径
[1/5] 检查运行时        ← .NET / PowerShell / OS 版本
[2/5] 创建项目目录      ← tools/Output/ 子目录
[3/5] 编译 P3RDataTools  ← dotnet publish (首次 1-2 分钟)
[4/5] 验证游戏资产      ← Paks/ 目录 .utoc/.ucas 数量/大小
[5/5] 最终检查          ← P3RDataTools / UnrealPak / JSON 缓存 / 模板库
```

### 跳过部分步骤

```powershell
.\setup.ps1 -SkipBuild      # 跳过编译 (已有发布版本)
.\setup.ps1 -SkipVerify     # 跳过游戏资产验证
.\setup.ps1 -WhatIf         # 仅预览，不执行
```

### 配置游戏路径

编辑 `.env` 文件：

```ini
P3R_PAKS_DIR=C:\Program Files (x86)\Steam\steamapps\common\P3R\P3R\Content\Paks
P3R_MOD_OUTPUT_DIR=C:\Users\<你>\Code\P3R_Modding\tools\Output\mod
```

或设置环境变量：

```powershell
$env:P3R_PAKS_DIR = "你的游戏 Paks 目录"
```

---

## 三、项目结构速览

```
P3R_Modding/
├── CLAUDE.md                    ← AI Agent 工作指令 (⭐ 核心)
├── setup.ps1                    ← 项目初始化
│
├── docs/                        ← 文档
│   ├── SYSTEM_ARCHITECTURE.md   ← 架构设计
│   ├── P3R_ASSET_ANALYSIS.md    ← 资产分析
│   ├── DEVELOPER_GUIDE.md       ← 本文件
│   └── amicitia/                ← Wiki 参考数据
│       ├── DATA_MAPPING.md      ← 需求→DataTable 映射 ★
│       └── md/                  ← 37 Wiki Markdown
│
├── tools/
│   ├── P3RDataTools/            ← CLI 读写引擎 (C#)
│   │   ├── Program.cs           ← 主入口
│   │   └── P3RDataTools.csproj  ← .NET 8 + CUE4Parse 1.1.1 + UAssetAPI 1.1.0
│   ├── scripts/
│   │   ├── Config.ps1           ← 共享配置
│   │   ├── modify-and-repack.ps1 ← ★ Zen byte-patch 全流程编排
│   │   ├── Invoke-ZenPatch.ps1  ← schema-driven Zen 字节写回引擎
│   │   ├── Parse-BtTemplate.ps1 ← 010 .bt 模板解析器
│   │   ├── Test-SchemaRegression.ps1 ← schema 回归验证
│   │   ├── dsl/P3RModDSL.psm1  ← Mod DSL helper
│   │   ├── verify-templates.ps1 ← 传统模板验证（弃用路径）
│   │   └── tools/               ← Claude Code 工具脚本 (Sprint 2)
│   ├── templates-010/           ← ★ 010 .bt schema 与校准/回归报告
│   │   └── schemas/             ← 解析后的 schema JSON
│   ├── templates/               ← 传统格式 .uasset+.uexp 模板库（弃用/fallback）
│   │   └── template_index.json  ← 模板索引
│   ├── Output/                  ← 生成文件 (Git 忽略)
│   │   ├── json/                ← DataTable JSON 快照 (489 个)
│   │   ├── mod/                 ← Mod 产物
│   │   └── .backup/             ← 备份
│   ├── FModel.exe               ← GUI 资产浏览器
│   └── UnrealPakTool/           ← PAK 打包工具
│
├── Paks/                        ← 游戏容器 (Git 忽略, ~20GB)
└── Extracted/                   ← 提取资产 (Git 忽略, ~48GB)
```

---

## 四、核心技术栈

### 数据流

```
主路径（Sprint 1.5，P3R 当前唯一验证可工作）

游戏 Paks/  (.utoc+.ucas / .pak)
    │
    ├──→ [CUE4Parse 1.1.1]       读取 IoStore → JSON 缓存
    │    │  P3RDataTools read / batch
    │    │
Extracted/IoStore/.../*.uasset   Zen 原件（只读，不直接修改）
    │
    ├──→ [010 schema]             rowSize/headerSize/field offset
    │    │  tools/templates-010/schemas/*.json
    │    │
    └──→ [Invoke-ZenPatch.ps1]    复制 Zen 原件 → 定长标量 byte-patch
         │  output size == original size，无 .uexp
         │
         └──→ [UnrealEssentials]  <Mod>/UnrealEssentials/P3R/Content/...

弃用/fallback 路径（保留备查，不用于新 DataTable Mod）

FModel / P3RDataTools create-template → 传统 .uasset+.uexp → UAssetAPI/TemplateCreator → UnrealPak/PAK
```

### 关键版本锁定

| 库 | 版本 | 不可升级原因 |
|------|------|------|
| CUE4Parse | **1.1.1** | 1.2.2 的 Zlib-ng.NET 在 Windows 上初始化失败 |
| UAssetAPI | 1.1.0 | 仅传统 UE Package fallback 使用；P3R 主写回不依赖它 |
| UnrealPak | **UE 4.27** | 必须匹配 P3R 游戏引擎版本 |
| .NET | **8.0** | LTS，CUE4Parse/UAssetAPI 兼容 |

### 为什么 CUE4Parse 不能升级？

```
CUE4Parse 1.2.2 → 依赖 Zlib-ng.NET → System.TypeInitializationException on Windows
已验证: 1.1.1 稳定可用，不可升级
```

---

## 五、日常开发工作流

### 读取 DataTable

```powershell
# 加载配置
. .\tools\scripts\Config.ps1

# 按别名导出
& $DataTools read $DataTables["Skills"] skills.json

# 按虚拟路径导出
& $DataTools read "P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset" out.json

# 批量导出
& $DataTools batch "Xrd777/Battle/Tables" .\json\Battle\
```

### 修改并打包 Mod (Sprint 1.5 Zen Byte-Patch)

> ✅ **Sprint 1.5 已全部完成并人工实测通过**：AgiMod、BufuMod（布芙 `hpn=999`）和 ExpMod（Normal `ExpRate=100.0`）均已确认可在游戏内生效。新 Mod 默认走 Zen byte-patch + UnrealEssentials 散文件部署。

> ⚠ **写 ModScript 前先读 [MODDING_PITFALLS.md](MODDING_PITFALLS.md)**：DataTable 数组下标 == 资产 ID，`Data[0]` 通常是引擎占位行，不是任何真实技能/Persona/道具。改错下标会导致 PAK 看似成功但游戏内无效果。

```powershell
# 方案 A：DSL 函数（最方便）
Import-Module .\tools\scripts\dsl\P3RModDSL.psm1
Set-SkillHpn -SkillId 10 -DamageMultiplier 5.0 -OutputDir .\my-mod\

# 方案 B：内联 changes（一行搞定）
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999}) -ModName "AgiMod"

# 方案 C：changes.json 文件（批量修改）
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -ChangesJson .\changes.json

# 方案 D：DSL 脚本（复杂逻辑）
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -ModScript .\my-changes.ps1 -ModName "MyMod"

# DryRun 预览（不写字节，确认 offset 和值正确后再正式执行）
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -Changes @(...) -DryRun

# 只产出 .uasset 不部署到 Reloaded II（用于手动检查）
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -Changes @(...) -NoInstall
```

### DSL 可用函数速查

| 函数 | 目标 | 示例 |
|------|------|------|
| `Set-SkillHpn` | 技能伤害 | `Set-SkillHpn -SkillId 10 -DamageMultiplier 5.0 -OutputDir .\mod\` |
| `Set-SkillCost` | 技能消耗 | `Set-SkillCost -SkillId 10 -Cost 1 -OutputDir .\mod\` |
| `Set-SkillData` | 技能多字段 | `Set-SkillData -SkillId 10 -Hpn 999 -Cost 1 -OutputDir .\mod\` |
| `Set-PersonaLevel` | Persona 等级 | `Set-PersonaLevel -PersonaId 1 -Level 99 -OutputDir .\mod\` |
| `Set-PersonaStat` | Persona 属性 | `Set-PersonaStat -PersonaId 1 -Level 99 -Race 1 -OutputDir .\mod\` |
| `Set-EnemyHP` | 敌人 HP | `Set-EnemyHP -EnemyId 100 -MaxHP 5000 -OutputDir .\mod\` |
| `Set-EnemySP` | 敌人 SP | `Set-EnemySP -EnemyId 100 -MaxSP 999 -OutputDir .\mod\` |
| `Set-EnemySkill` | 敌人技能槽 | `Set-EnemySkill -EnemyId 100 -Slot 3 -SkillId 47 -OutputDir .\mod\` |
| `Set-EnemyStat` | 敌人多字段 | `Set-EnemyStat -EnemyId 100 -MaxHP 5000 -Level 50 -OutputDir .\mod\` |
| `Set-DifficultyParam` | 难度参数 | `Set-DifficultyParam -Difficulty easy -Field ExpRate -Value 3.0 -OutputDir .\mod\` |
| `Set-PlayerLevelup` | 升级经验 | `Set-PlayerLevelup -Level 10 -Exp 2000 -OutputDir .\mod\` |
| `New-ModChanges` | 通用 (任意 schema) | `New-ModChanges -SchemaKey p3re_skillNormal -Changes @(@{target='Data[10].hpn'; value=999}) -OutputDir .\mod\` |

### 查看修改差异

```powershell
# 对比两个 JSON
code --diff skills_original.json skills_modified.json
```

---

## 六、传统模板生成指南（已弃用，仅作 fallback / 历史说明）

> ⚠️ **不要把本节产物用于新 P3R DataTable Mod。**
> `P3RDataTools create-template` / `create` 生成的是传统 `.uasset+.uexp`（Magic `C1 83 2A 9E`），已在 P3R 上实测 boot-crash（见 [MODDING_PITFALLS.md P-007](MODDING_PITFALLS.md#p-007-unrealessentials-iostore-资产替换偏好-zen-单文件)）。当前主写回路径是第五节的 Zen byte-patch。本节只保留给未来完整序列化研究或非 P3R fallback。

### 生成单个模板

```powershell
# 加载配置
. .\tools\scripts\Config.ps1

# 从 IoStore 生成传统格式模板
& $DataTools create-template "P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset" .\tools\templates\
```

### 批量生成全部 18 种

```powershell
. .\tools\scripts\Config.ps1
foreach ($vpath in $DataTables.Values) {
    & $DataTools create-template $vpath "$TemplatesDir"
}
# 加上扩展模板
& $DataTools create-template "P3R/Content/Xrd777/UI/Tables/DatItemMaterialDataAsset.uasset" "$TemplatesDir"
& $DataTools create-template "P3R/Content/Xrd777/UI/Tables/DatItemCostumeDataAsset.uasset" "$TemplatesDir"
& $DataTools create-template "P3R/Content/Xrd777/UI/Tables/DatItemShoesDataAsset.uasset" "$TemplatesDir"
```

### 验证模板

```powershell
.\tools\scripts\verify-templates.ps1
# 预期输出: Total: 18 | Pass: 18 | Warn: 0 | Fail: 0
```

### 工作原理

`create-template` 命令：
1. CUE4Parse 从 IoStore (.utoc/.ucas) 读取 DataTable → JSON
2. TemplateCreator 将 JSON 转为 UE4 传统 Package 二进制格式
3. 直接写入 .uasset (Package Header + NameMap + ImportMap + ExportMap) 和 .uexp (行数据)

输出文件 Magic bytes = `C1 83 2A 9E` (UE4 Package Magic)，可由 UAssetAPI 加载修改。

### 模板列表（18 种）

| # | 资产名 | FModel 路径 |
|---|--------|-------------|
| 1 | `DatSkillNormalDataAsset` | `Xrd777/Battle/Tables/` |
| 2 | `DatSkillDataAsset` | `Xrd777/Battle/Tables/` |
| 3 | `DatPersonaDataAsset` | `Xrd777/Battle/Tables/` |
| 4 | `DatPersonaGrowthDataAsset` | `Xrd777/Battle/Tables/` |
| 5 | `DatPersonaAffinityDataAsset` | `Xrd777/Battle/Tables/` |
| 6 | `DatEnemyDataAsset` | `Xrd777/Battle/Tables/` |
| 7 | `DatEnemyAffinityDataAsset` | `Xrd777/Battle/Tables/` |
| 8 | `DatEncountTableDataAsset` | `Xrd777/Battle/Tables/` |
| 9 | `DatItemCommonDataAsset` | `Xrd777/UI/Tables/` |
| 10 | `DatItemWeaponDataAsset` | `Xrd777/UI/Tables/` |
| 11 | `DatItemArmorDataAsset` | `Xrd777/UI/Tables/` |
| 12 | `DatItemAccsDataAsset` | `Xrd777/UI/Tables/` |
| 13 | `DatItemSkillcardDataAsset` | `Xrd777/UI/Tables/` |
| 14 | `DatItemMaterialDataAsset` | `Xrd777/UI/Tables/` |
| 15 | `DatItemCostumeDataAsset` | `Xrd777/UI/Tables/` |
| 16 | `DatItemShoesDataAsset` | `Xrd777/UI/Tables/` |
| 17 | `DatPlayerLevelupDataAsset` | `Xrd777/Battle/Tables/` |
| 18 | `DatPlayerMaxHPSPDataAsset` | `Xrd777/Battle/Tables/` |

---

## 七、编译与构建

### 编译 P3RDataTools

```powershell
cd tools\P3RDataTools
dotnet restore
dotnet build -c Release
```

### 发布自包含版本

```powershell
dotnet publish -c Release --self-contained -r win-x64 -o publish
```

产出：`publish/P3RDataTools.exe` (~65 MB 自包含)

### 依赖项

| NuGet 包 | 版本 | 用途 |
|------|------|------|
| CUE4Parse | 1.1.1 | 读取 IoStore 容器 |
| UAssetAPI | 1.1.0 | 传统 UE4 Package fallback / 历史路径 |
| Newtonsoft.Json | 13.0.4 | JSON 序列化 |
| OffiUtils | 2.0.1 | CUE4Parse 工具依赖 |

---

## 八、调试指南

## 九、Mod 安装指南 (Reloaded II)

P3R **不支持**直接把 .pak 丢进 `Content/Paks/` 加载。所有 Mod 必须通过 **Reloaded II** 模组管理器加载。

> **完整 Mod 生成规范**: 见 [CLAUDE.md](../CLAUDE.md) 的 ModConfig.json 模板、[UNREAL_ESSENTIALS_REFERENCE.md](UNREAL_ESSENTIALS_REFERENCE.md) 的散文件规则，以及 [P3RPC_ESSENTIALS_REFERENCE.md](P3RPC_ESSENTIALS_REFERENCE.md) 的默认依赖说明。
>
> **UnrealEssentials 完整能力**: 见 [UNREAL_ESSENTIALS_REFERENCE.md](UNREAL_ESSENTIALS_REFERENCE.md) — 支持的产物形态、Zen 资产 vs 传统 `.uasset+.uexp`、`utoc-extractor`、元数据格式。

### 一次性安装 Reloaded II

1. 下载 Reloaded II: https://github.com/Reloaded-Project/Reloaded-II/releases
2. 解压到任意目录（如 `C:\Reloaded-II\`）
3. 运行 `Reloaded-II.exe`，点击 "Add Application" → 选择 `P3R.exe`
4. 首次启动会自动安装 **P3R Essentials** + **Inaba EXE Patcher**
5. 确认 **UnrealEssentials**（默认 Mod 加载链）与 File Emulation Framework（fallback 用）均已下载

### 安装 Mod 散文件（默认，UnrealEssentials 路径）

把 Zen byte-patch 产出的**单个 `.uasset`** 按虚拟路径镜像到：

```
<Reloaded-II>/
└── Mods/
    └── <ModName>/
        ├── ModConfig.json
        └── UnrealEssentials/
            └── P3R/
                └── Content/
                    └── Xrd777/Battle/Tables/
                        └── <资产名>.uasset      ← Zen 单文件，首字节 00 00 00 00，无 .uexp
```

`ModConfig.json` 完整示例：

```json
{
  "ModId": "p3r.agi.damage.999",
  "ModName": "P3R - 亚基伤害 999",
  "ModAuthor": "claude",
  "ModVersion": "1.0.0",
  "ModDescription": "将亚基 (Agi) 的伤害从 40 改为 999",
  "ModDependencies": [
    "p3rpc.essentials"
  ],
  "SupportedAppId": ["p3r.exe"]
}
```

> 完整字段说明、ModId 命名规范、依赖链等见 [CLAUDE.md](../CLAUDE.md) 与 [P3RPC_ESSENTIALS_REFERENCE.md](P3RPC_ESSENTIALS_REFERENCE.md)。
>
> **关键约束**: `SupportedAppId` 必须包含 `"p3r.exe"`；`ModDependencies` 默认 `["p3rpc.essentials"]`（项目级统一约定，间接拉齐 UnrealEssentials；与参考 mod [`p3rpc.ui.barionskillnames`](../tools/Reloaded%20II/Mods/p3rpc.ui.barionskillnames/) 一致）。极小化需求可改写 `["UnrealEssentials"]`，详见 [P3RPC_ESSENTIALS_REFERENCE.md](P3RPC_ESSENTIALS_REFERENCE.md) 与 [MODDING_PITFALLS.md P-008](MODDING_PITFALLS.md#p-008-modconfigjson-默认依赖统一为-p3rpcessentials)。

### 安装 Mod PAK（fallback，FEmulator/PAK 路径）

仅当 UnrealEssentials 散文件路径出问题排查时使用：

```
<Reloaded-II>/
└── Mods/
    └── <ModName>/
        ├── ModConfig.json              ← ModDependencies: ["reloaded.universal.fileemulationframework.pak"]
        └── FEmulator/
            └── PAK/
                └── <ModName>.pak       ← 注意 PAK 大小 > 1 KB，否则是空头（见 P-002）
```

### 启动

通过 Reloaded II 启动游戏 → Mod 自动生效。**不能用 Steam 快捷方式启动**。

### Mod 不生效

```
检查清单 (UnrealEssentials 默认):
□ 是否通过 Reloaded II 启动游戏（不是 Steam/快捷方式）
□ Zen .uasset 是否放在 <Mod>/UnrealEssentials/P3R/Content/<虚拟路径>/ 下
□ 同目录是否没有 .uexp（传统格式才需要 .uexp，当前主路径不需要）
□ .uasset 首字节是否为 00 00 00 00，大小是否与 Extracted/IoStore 原件一致
□ ModConfig.json 是否包含 "UnrealEssentials" 依赖（或 "p3rpc.essentials"）
□ SupportedAppId 是否包含 "p3r.exe"
□ Inaba EXE Patcher 是否已安装并启用
□ schema/field guard 是否通过（PASS + flat scalar；PARTIAL/FAIL/SKIP/union/nested/变长默认拦截）

检查清单 (FEmulator/PAK fallback):
□ PAK 是否放在 <Mod>/FEmulator/PAK/ 下
□ PAK > 1 KB（见 P-002）
□ ModConfig.json 是否包含 File Emulation Framework 依赖

如果以上全过仍不生效，参考 docs/MODDING_PITFALLS.md P-007（IoStore Zen 资产偏好）。
```
  - 用 -log -verbose 启动游戏定位崩溃资产
```

### P3RDataTools 读取失败

```
"CUE4Parse: Package has no data"
  → 解密失败: 检查 AES Key 是否匹配游戏版本
  → IoStore 容器损坏: 重新验证游戏文件完整性

"Zlib initialization failed"
  → CUE4Parse 版本错误: 必须使用 1.1.1
  → 清理 obj/bin: 重新 dotnet restore
```

### 传统 UAssetAPI 写回问题（弃用路径）

```
"Package is IoStore format (zero header)"
  → 不能直接写入 IoStore .uasset
  → 过去尝试用传统格式模板绕过，但 P3R 实测 boot-crash（P-007）
  → 当前应改用 Invoke-ZenPatch.ps1 / modify-and-repack.ps1 Zen byte-patch

"Write() produced corrupt data"
  → 属于传统模板路径问题；不要作为新 Mod 主路径排查
  → 仅在未来研究完整 UE Zen asset writer / serializer 时参考
```

---

## 十、Mod 文件格式规范

### UnrealEssentials Zen 散文件结构（默认）

```
tools/Output/mod/<ModName>/
├── mod.json                 ← 元数据 (名称、版本、描述、修改表列表)
├── history.json             ← 操作审计日志
├── changes.json             ← schemaKey + target/value 修改计划
└── UnrealEssentials/
    └── P3R/
        └── Content/
            └── Xrd777/...
                └── <AssetName>.uasset   ← Zen 单文件，大小与 Extracted/IoStore 原件一致，无 .uexp
```

安装到 Reloaded II 后结构相同，只是根目录变为 `<Reloaded-II>/Mods/<ModName>/`。

### FEmulator/PAK fallback（仅排查时使用）

```text
<ModName>/FEmulator/PAK/<ModName>.pak
```

只有显式使用 `modify-and-repack.ps1 -PackPak` 时才生成 PAK。PAK 必须 > 1 KB，否则是空包（见 P-002）。

### 传统 manifest 格式（弃用路径）

```
"DatSkillNormalDataAsset.uasset" "../../../P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset"
"DatSkillNormalDataAsset.uexp"   "../../../P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uexp"
```

传统 `.uasset+.uexp` / manifest / `_P.pak` 不是 P3R DataTable 当前主路径，仅保留给历史研究或 fallback。
---

## 十一、Sprint 开发节奏

### 当前状态（2026-06-25）

- [x] Sprint 1.5 Zen byte-patch 主线完成：`Invoke-ZenPatch.ps1` / DSL / `modify-and-repack.ps1`
- [x] AgiMod、BufuMod、ExpMod 已人工实测生效
- [x] 传统 `.uasset+.uexp` / `P3RDataTools create` 路线已弃用（P-007）
- [x] Sprint 2 工具链完成：search/diff/guard/conflict 与 Zen 管道集成
- [x] Sprint 3 安全系统完成并复验通过：registry v2、`mod.json` / `history.json`、Git pre-mod backup、命名备份、回滚预览、冲突分级、post-patch guard；详见 [SECURITY.md](SECURITY.md)（§7 含 Sprint 3 复验结论）

### Sprint 3 安全系统速查

| 能力 | 命令 / 文件 | 说明 |
|---|---|---|
| 安全协议 | [SECURITY.md](SECURITY.md) | 四层安全架构、紧急恢复流程、人工验证边界 |
| 验收记录 | [SECURITY.md §7](SECURITY.md#7-sprint-3-复验结论2026-06-25) | 非破坏性 CLI smoke、冲突阻断、重复运行修复 |
| 命名备份 | `backup-mod.ps1 -ModName <name> -Name <label>` | 写入 `.backup/<ModName>/<backupId>/backup.json` 与 snapshot hash |
| 备份比较 | `backup-mod.ps1 -ModName <name> -Compare <backupId>` | 比较备份与当前 workdir 或 `-With <otherBackupId>` |
| 回滚预览 | `rollback-mod.ps1 -ModName <name> -Preview` | 不修改文件；实际覆盖必须显式 `-Force` |
| 冲突分级 | `conflict-check.ps1 -All` | `error` 阻断，`warning/info` 仅提示 |
| 审计链 | `mod.json` / `history.json` / `.data/mod_registry.json` | 记录 before/after hash、userInput、变更 target、产物 hash |

### Sprint 2 开发重点

1. `search-datatable.ps1` — 中文译名 / ID / TableKey / SchemaKey 定位（返回 virtualPath、schemaKey、target、当前值）
2. `search-wiki.ps1` — DATA_MAPPING / docs/zh-cn / Amicitia Wiki 统一检索
3. `diff-changes.ps1` — 人类可读差分 + 当前 JSON 值 + byte offset 预览
4. `guard-modify.ps1` — PASS/PARTIAL/FAIL/SKIP、fieldReviewStatus、union/nested/变长字段拦截
5. `backup-mod.ps1` / `rollback-mod.ps1` / `conflict-check.ps1` — Zen loose file Mod 安全管理
6. `modify-and-repack.ps1` — 已接入 diff/guard/conflict/backup/registry，并输出 `changes.json` / `mod.json` / `history.json`

常用验证命令：

```powershell
.\tools\scripts\tools\search-datatable.ps1 -Query "亚基" -Field hpn
.\tools\scripts\tools\diff-changes.ps1 -TableKey Skills -Changes @(@{target='Data[10].hpn'; value=999})
.\tools\scripts\tools\guard-modify.ps1 -TableKey Skills -Changes @(@{target='Data[10].hpn'; value=999})
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -Changes @(@{target='Data[10].hpn'; value=999}) -DryRun
```

### 代码风格

- C#: 遵循 .NET 8 conventions，使用顶级语句（Program.cs）
- PowerShell: 动词-名词命名，使用 `$Script:` 作用域变量
- JSON: UTF-8，2 空格缩进，Newtonsoft.Json 序列化
- 注释: 中文（面向中文开发者）

---

## 十二、相关资源

| 资源 | 链接/路径 |
|------|------|
| CUE4Parse 源码 | https://github.com/FabianFG/CUE4Parse |
| UAssetAPI 源码 | https://github.com/atenfyr/UAssetAPI |
| Zen byte-patch 工作流 | `docs/ZEN_BYTE_PATCH_WORKFLOW.md` |
| Zen 已知限制 / 未解析模板 / PARTIAL schema | `docs/ZEN_BYTE_PATCH_WORKFLOW.md` §6 |
| UnrealEssentials 参考 | `docs/UNREAL_ESSENTIALS_REFERENCE.md` |
| 安全协议 / Sprint 3 复验 | `docs/SECURITY.md` |
| 人工验收 / 边界测试待测项 | `docs/MANUAL_TEST_TODO.md` |
| Amicitia Wiki | https://amicitia.miraheze.org/wiki/Persona_3_Reload |
| P3R 内部文档 | `docs/amicitia/md/` (37 个参考页面) |
| DataTable 映射 | `docs/amicitia/DATA_MAPPING.md` |
| 架构设计 | `docs/SYSTEM_ARCHITECTURE.md` |


