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
| **FModel** | 最新 | GUI 资产浏览器（一次性模板导出） | 项目内 `tools/FModel.exe` |
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
│   ├── PRD_P3R_AI_AGENT.md      ← 产品需求
│   ├── SYSTEM_ARCHITECTURE.md   ← 架构设计
│   ├── DEVELOPMENT_PLAN.md      ← Sprint 计划
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
│   │   ├── modify-and-repack.ps1 ← 全流程编排
│   │   ├── verify-templates.ps1 ← 模板验证
│   │   └── tools/               ← Claude Code 工具脚本 (Sprint 2)
│   ├── templates/               ← 传统格式 .uasset+.uexp 模板库
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
游戏 Paks/  (.utoc+.ucas / .pak)
    │
    ├──→ [CUE4Parse 1.1.1]    读取 IoStore → JSON
    │    │  P3RDataTools read / batch
    │    │
    ├──→ [FModel GUI]          一次性导出传统格式模板
    │    │  手动操作 Sprint 0
    │    │
    └──→ [UAssetAPI 1.1.0]    修改模板 → .uasset+.uexp
         │  P3RDataTools create (Sprint 1)
         │
         └──→ [UnrealPak 4.27]  打包 → _P.pak
               manifest.txt → PAK
```

### 关键版本锁定

| 库 | 版本 | 不可升级原因 |
|------|------|------|
| CUE4Parse | **1.1.1** | 1.2.2 的 Zlib-ng.NET 在 Windows 上初始化失败 |
| UAssetAPI | **1.1.0** | 唯一支持 .NET 的 UE4 Package 读写库 |
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

### 修改并打包 Mod (Sprint 1+)

> ⚠ **写 ModScript 前先读 [MODDING_PITFALLS.md](MODDING_PITFALLS.md)**：DataTable 数组下标 == 资产 ID，`Data[0]` 通常是引擎占位行，不是任何真实技能/Persona/道具。改错下标会导致 PAK 看似成功但游戏内无效果。

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -ModScript .\my-changes.ps1 -ModName "MyMod"
```

### 查看修改差异

```powershell
# 对比两个 JSON
code --diff skills_original.json skills_modified.json
```

---

## 六、模板生成指南 (Sprint 0 T0.1)

> P3RDataTools `create-template` 命令自动从 IoStore 读取 DataTable 并生成传统格式 .uasset+.uexp 模板。
> 无需 FModel GUI 手动操作。

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
| UAssetAPI | 1.1.0 | 读取/写入传统 UE4 Package |
| Newtonsoft.Json | 13.0.4 | JSON 序列化 |
| OffiUtils | 2.0.1 | CUE4Parse 工具依赖 |

---

## 八、调试指南

## 九、Mod 安装指南 (Reloaded II)

P3R **不支持**直接把 .pak 丢进 `Content/Paks/` 加载。所有 Mod 必须通过 **Reloaded II** 模组管理器加载。

> **完整 Mod 生成规范**: 见 [MOD_SPECIFICATION.md](MOD_SPECIFICATION.md) — 包含 ModConfig.json 完整字段参考、ModId 命名规范、依赖链、PAK/manifest 格式、验证清单、自动化生成模板等。

### 一次性安装 Reloaded II

1. 下载 Reloaded II: https://github.com/Reloaded-Project/Reloaded-II/releases
2. 解压到任意目录（如 `C:\Reloaded-II\`）
3. 运行 `Reloaded-II.exe`，点击 "Add Application" → 选择 `P3R.exe`
4. 首次启动会自动安装 **P3R Essentials** + **Inaba EXE Patcher**
5. 确认 File Emulation Framework (`reloaded.universal.fileemulationframework.pak`) 已安装

### 安装 Mod PAK

将我们生成的 .pak 放入 Reloaded II 目录结构：

```
<Reloaded-II>/
└── Mods/
    └── <ModName>/
        ├── ModConfig.json              ← 需手动创建
        └── FEmulator/
            └── PAK/
                └── <ModName>.pak       ← 我们的产物
```

  `ModConfig.json` 完整示例：
  
  ```json
  {
    "ModId": "p3r.agi.damage.999",
    "ModName": "P3R - 阿耆尼伤害 999",
    "ModAuthor": "P3R Modding Agent",
    "ModVersion": "1.0.0",
    "ModDescription": "将阿耆尼 (Agi) 的伤害从 15 改为 999",
    "ModDependencies": [
      "reloaded.universal.fileemulationframework.pak"
    ],
    "SupportedAppId": ["p3r.exe"]
  }
  ```
  
  > 完整字段说明、ModId 命名规范、依赖链等见 [MOD_SPECIFICATION.md](MOD_SPECIFICATION.md)。
  >
  > **关键约束**: `SupportedAppId` 必须包含 `"p3r.exe"`，`ModDependencies` 必须包含 `"reloaded.universal.fileemulationframework.pak"`。

### 启动

通过 Reloaded II 启动游戏 → Mod 自动生效。**不能用 Steam 快捷方式启动**。

### Mod 不生效

```
检查清单:
□ 是否通过 Reloaded II 启动游戏（不是 Steam/快捷方式）
□ PAK 是否放在 FEmulator/PAK/ 下
□ ModConfig.json 是否包含 File Emulation Framework 依赖
□ Inaba EXE Patcher 是否已安装并启用
□ .uasset+.uexp 成对打包
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

### UAssetAPI 写回问题

```
"Package is IoStore format (zero header)"
  → 不能直接写入 IoStore .uasset
  → 需要使用传统格式模板 (见第六节)
  → 确认 FModel 导出的是 "Packages Raw" 格式

"Write() produced corrupt data"
  → 模板可能有问题: 用 verify-templates.ps1 检查
  → NameMap/ImportMap 不匹配: 检查是否修改了字段名
```

---

## 十、Mod 文件格式规范

### Manifest 格式

```
"DatSkillNormalDataAsset.uasset" "../../../P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset"
"DatSkillNormalDataAsset.uexp" "../../../P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uexp"
```

### PAK 命名规则

| 后缀 | 优先级 | 说明 |
|------|------|------|
| `_P.pak` | 最高 | Patch 包，覆盖所有低优先级 |
| `_0.pak` ~ `_9.pak` | 中 | 数字越小优先级越高 |
| 无后缀 | 低 | 基础包 |

### Mod 目录结构 (Sprint 2+)

```
tools/Output/mod/<ModName>/
├── mod.json              ← 元数据 (名称、版本、描述、修改表列表)
├── history.json          ← 操作审计日志
├── manifest.txt          ← PAK 文件清单
├── <AssetName>.uasset    ← 修改后的资产
└── <AssetName>.uexp      ← 修改后的导出数据
```

---

## 十一、Sprint 开发节奏

### 当前 Sprint 0 → 进入 Sprint 1 的前提

- [ ] 18 对模板文件已导出到 `tools/templates/`
- [ ] `verify-templates.ps1` 全部通过 (18/18)
- [ ] `setup.ps1` 可从头初始化项目
- [ ] `.gitignore` 正确排除中间产物

### Sprint 1 开发任务

1. `TemplateLoader.cs` — 模板加载模块
2. `DataTablePatcher.cs` — 行数据替换引擎
3. `AssetWriter.cs` — 输出写回模块
4. `Program.cs` 更新 — `create` 命令

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
| UnrealPak 文档 | https://docs.unrealengine.com/4.27/en-US/SharingAndReleasing/Patching/GeneralPatching/ |
| Amicitia Wiki | https://amicitia.miraheze.org/wiki/Persona_3_Reload |
| P3R 内部文档 | `docs/amicitia/md/` (37 个参考页面) |
| DataTable 映射 | `docs/amicitia/DATA_MAPPING.md` |
| 架构设计 | `docs/SYSTEM_ARCHITECTURE.md` |
| 产品需求 | `docs/PRD_P3R_AI_AGENT.md` |


