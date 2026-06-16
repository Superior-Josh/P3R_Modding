# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此仓库中工作时提供指导。

## 项目概述

这是一个 **Persona 3 Reload (P3R) 逆向工程与 Mod 制作工作区**。无构建系统、包管理器或测试套件。Git 管理文档和工具源代码，`.gitignore` 排除二进制资产和预编译工具。

### 项目目标

对 P3R（女神异闻录 3 Reload）进行 Mod 制作，涵盖：数值（技能/Persona/道具）、敌人 AI、文本/本地化、音乐/音频、角色模型、粒子特效、事件/剧情脚本。

## 仓库结构

```
P3R_Modding/
├── docs/
│   ├── UE_MODDING_GUIDE.md           ← 完整 UE Mod 制作中文指南
│   ├── P3R_ASSET_ANALYSIS.md         ← 资产分析报告（IoStore + PAK）
│   └── amicitia/
│       ├── README.md                 ← 37 个参考页面索引
│       ├── DATA_MAPPING.md           ← Wiki ↔ 游戏文件精确映射 ★
│       ├── md/                       ← Markdown 参考文档
│       └── html/                     ← 原始 HTML 备份
├── tools/
│   ├── P3RDataTools/                 ← CLI 读取工具源码 (C#)
│   │   ├── Program.cs
│   │   └── P3RDataTools.csproj
│   ├── scripts/
│   │   ├── Config.ps1                ← 共享配置（路径/密钥/DataTable 索引）
│   │   └── modify-and-repack.ps1     ← Mod 制作全流程编排脚本
│   ├── Output/json/                  ← 489 个 DataTable JSON 导出
│   │   ├── Battle/  (35 files)      技能/Persona/敌人/遇敌
│   │   ├── UI_Tables/ (161 files)   道具/武器/防具/商店/UI
│   │   ├── Community/ (276 files)   社群事件/系数/礼物
│   │   ├── Kernel/ (5 files)        文件名映射/数据继承
│   │   ├── Dictionary/ (2 files)    游戏字典
│   │   └── Tutorial/ (10 files)     教程文本
│   ├── FModel.exe                    ← GUI 资产浏览器
│   ├── UAssetGUI/UAssetGUI.exe       ← CLI uasset JSON 互转
│   └── UnrealPakTool/                ← PAK 打包/解包工具
├── Paks/                             ← 原始游戏容器（20GB，未跟踪）
├── Extracted/                        ← 提取的资产（48GB，未跟踪）
└── CLAUDE.md
```

## 核心工作流：读取 DataTable 无需 GUI

### P3RDataTools CLI（自包含 .exe，无需安装运行时）

```powershell
.\tools\P3RDataTools\publish\P3RDataTools.exe <command> <args>
```

| 命令 | 用途 | 示例 |
|------|------|------|
| `read <vpath> [out.json]` | 导出 DataTable 为 JSON | `read "P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset" skills.json` |
| `batch <filter> <dir>` | 批量导出 | `batch "Xrd777/Battle/Tables" .\json\Battle\` |
| `quick <vpath> <jsonPath> <value> <dir>` | 修改单个属性，生成 manifest | `quick "P3R/.../DatSkillNormalDataAsset.uasset" "Properties.Data[0].Power" 999 .\mod\` |
| `modify <vpath> <jsonFile> <dir>` | 应用 JSON 修改，生成 manifest | `modify "P3R/.../Skills.uasset" modified.json .\mod\` |

虚拟路径格式：`P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset`

### 查找要修改的文件

1. 查 `docs/amicitia/DATA_MAPPING.md` — 按需求定位 DataTable 文件名
2. 查 `docs/amicitia/md/` — 获取 ID 表（技能 ID、道具 ID 等）
3. 用 P3RDataTools `read` 导出 JSON → 修改 → 打包

### 常用 DataTable 快速索引

```
技能数值/伤害                   → Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset
技能元数据                      → Xrd777/Battle/Tables/DatSkillDataAsset.uasset
Persona 基础/成长/耐性          → Xrd777/Battle/Tables/DatPersonaDataAsset / DatPersonaGrowthDataAsset / DatPersonaAffinityDataAsset
敌人属性/耐性                   → Xrd777/Battle/Tables/DatEnemyDataAsset / DatEnemyAffinityDataAsset
遇敌表                          → Xrd777/Battle/Tables/DatEncountTableDataAsset
道具/武器/防具/饰品/技能卡       → Xrd777/UI/Tables/DatItemCommonDataAsset / DatItemWeaponDataAsset / DatItemArmorDataAsset / DatItemAccsDataAsset / DatItemSkillcardDataAsset
玩家升级/HP上限                 → Xrd777/Battle/Tables/DatPlayerLevelupDataAsset / DatPlayerMaxHPSPDataAsset
社群事件                        → Xrd777/Community/Bf/ (132 .uasset)
BGM                             → Xrd777/CriData/CueSheet/system.uasset
```

JSON 副本已导出到 `tools/Output/json/`（489 文件），可直接查阅无需重新读取。

## 资产格式与提取

游戏使用 UE 4.27，资产以两种容器并存：

| 格式 | 文件 | 提取工具 | 状态 |
|------|------|---------|------|
| IoStore | `.utoc` + `.ucas` | FModel (GUI) | 已导出至 `Extracted/IoStore/`（138,936 文件，41.2 GB） |
| 传统 PAK | `.pak` | UnrealPak (CLI) | 已提取至 `Extracted/pakchunk*/`（6,257 文件，7.3 GB） |

- **Xrd777 > Astrea**：同名资产以 Xrd777 为准
- **IoStore .uasset 文件头全为零**：无法直接用 UAssetGUI/UAssetAPI 编辑，需通过 CUE4Parse（即 P3RDataTools）读取

## AES 密钥

```
Hex:  0x92BADFE2921B376069D3DE8541696D230BA06B5E4320084DD34A26D117D2FFEE
Base64: krrf4pIbN2Bp096FQWltIwuga15DIAhN00om0RfS/+4=
```

`tools/UnrealPakTool/Crypto.json` 必须是简化格式：
```json
{ "EncryptionKey": { "Name": "null", "Guid": "null", "Key": "krrf4pIbN2Bp096FQWltIwuga15DIAhN00om0RfS/+4=" } }
```

## 工具链详情

### P3RDataTools（.NET 8 CUE4Parse CLI）
- 源码：`tools/P3RDataTools/Program.cs`（CUE4Parse 1.1.1 + UAssetAPI + Newtonsoft.Json）
- **版本关键**：必须用 CUE4Parse **1.1.1**（1.2.2 的 Zlib-ng.NET 与本机不兼容）
- 发布：`dotnet publish -c Release --self-contained -r win-x64 -o publish`
- 通过 IoStore 容器挂载 140,007 个文件，AES 解密内置

### UnrealPak（PAK 打包）
```powershell
# 在 tools/UnrealPakTool/ 下执行
.\UnrealPak.exe "MyMod_P.pak" -Create="manifest.txt" -compress
```

### FModel（GUI，最后手段）
- 浏览资产树、导出 DataTable JSON、提取纹理 PNG
- 仅在 P3RDataTools 无法满足需求时使用

## Mod 制作流程

### 自动化路径（推荐）
```powershell
# 1. 导出
.\P3RDataTools.exe read "P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset" skills.json

# 2. 编辑 skills.json（任意编辑器/脚本）

# 3. 生成修改版 JSON + manifest
.\P3RDataTools.exe modify "P3R/Content/.../DatSkillNormalDataAsset.uasset" skills_modified.json .\mod\

# 4. 打包（需先手动创建 .uasset+.uexp 文件，见下方限制）
.\UnrealPak.exe "MyMod_P.pak" -Create=".\mod\manifest.txt" -compress
```

### ⚠️ 已知限制：.uasset+.uexp 写回

P3R 的 DataTable 全部使用 **IoStore 格式**（文件头为零），UAssetGUI/UAssetAPI 无法直接编辑或创建对应文件。当前工具自动生成 `modified.json` + `manifest.txt`，但最终的 .uasset+.uexp 对需要通过 FModel GUI 或其他方式手动创建。

### 编排脚本
```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills  # 全流程（读→改→生成 manifest）
```
`Config.ps1` 包含所有常用 DataTable 的虚拟路径别名。

## 关键约束

- **UE 版本**：4.27（pak version 11），UnrealPak 和 CUE4Parse 均需匹配
- **Xrd777 > Astrea**：同名资产以 Xrd777 为准
- **CUE4Parse = 1.1.1**：不要升级到 1.2.2（Zlib 初始化失败）
- **Mod PAK 命名**：`_P` 后缀 = 最高优先级
- **Crypto.json 必须简化**（不含 `$types` 字典）
- **IoStore 写回受限**：读取全自动，写入需手动步骤
