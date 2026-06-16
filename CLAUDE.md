# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此仓库中工作时提供指导。

## 项目概述

这是一个 **Persona 3 Reload (P3R) 逆向工程与 Mod 制作工作区**。无构建系统、包管理器或测试套件。Git 管理文档和工具源代码，`.gitignore` 排除二进制资产和预编译工具。

### 项目目标

构建 **自然语言驱动的 P3R Mod 制作 AI Agent**，对 P3R 进行 Mod 制作，涵盖：数值（技能/Persona/道具）、敌人 AI、文本/本地化、音乐/音频。

## 快速开始

```powershell
# 首次使用: 初始化项目
.\setup.ps1

# 每日使用: 启动 Claude Code
claude
```

## 仓库结构

```
P3R_Modding/
├── setup.ps1                          ← 项目初始化脚本 (首次运\\u884c)
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
│   └── amicitia/
│       ├── README.md                  ← 37 个参考页面索引
│       ├── DATA_MAPPING.md            ← Wiki ↔ 游戏文件精确映射 ★
│       ├── md/                        ← 37 Wiki Markdown 参考
│       └── html/                      ← 原始 HTML 备份
│
├── tools/
│   ├── P3RDataTools/                  ← CLI 工具源码 (C#)
│   │   ├── Program.cs                 ← 主入口
│   │   └── P3RDataTools.csproj        ← .NET 8 项目文件
│   │
│   ├── scripts/
│   │   ├── Config.ps1                 ← 共享配置 (路径/密钥/别名/注册表)
│   │   ├── modify-and-repack.ps1      ← 全流程编排脚本
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
│   ├── Output/                        ← 生成文件 (Git 忽略)
│   │   ├── json/                      ← 489 DataTable JSON 快照
│   │   │   ├── Battle/   (35 files)   ← 技能/Persona/敌人/遇敌
│   │   │   ├── UI_Tables/(161 files)  ← 道具/武器/防具/商店
│   │   │   ├── Community/(276 files)  ← 社群事件
│   │   │   ├── Kernel/    (5 files)   ← 文件名映射
│   │   │   ├── Dictionary/(2 files)   ← 游戏字典
│   │   │   └── Tutorial/ (10 files)   ← 教程文本
│   │   ├── mod/                       ← Mod 产物 (每个 Mod 一个子目录)
│   │   ├── .backup/                   ← 时间点备份
│   │   └── .data/                     ← 运行时缓存
│   │
│   ├── FModel.exe                     ← GUI 资产浏览器
│   ├── UAssetGUI/                     ← GUI uasset 编辑工具
│   └── UnrealPakTool/                 ← PAK 打包/解包工具
│
├── Paks/                              ← 原始游戏容器 (20GB，未跟踪)
└── Extracted/                         ← 提取的资产 (48GB，未跟踪)
```

## 核心工作流

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
| `create-template <vpath> <outDir>` | **生成传统格式模板** (Sprint 0) | `create-template "P3R/.../Skills.uasset" .\templates\` |
| `quick <vpath> <jsonPath> <value> <dir>` | 修改单属性 + manifest | `quick "P3R/.../Skills.uasset" "Properties.Data[0].Power" 999 .\mod\` |
| `modify <vpath> <jsonFile> <dir>` | 应用 JSON 修改 + manifest | `modify "P3R/.../Skills.uasset" modified.json .\mod\` |
| `create <vpath> <jsonFile> <dir>` | **模板法写回 → .uasset+.uexp** (Sprint 1) | `create "P3R/.../Skills.uasset" modified.json .\mod\` |

虚拟路径格式：`P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset`

### 查找要修改的文件

1. 查 `docs/amicitia/DATA_MAPPING.md` — 按需求定位 DataTable 文件名
2. 查 `docs/amicitia/md/` — 获取 ID 表（技能 ID、道具 ID 等）
3. 用 P3RDataTools `read` 导出 JSON → 修改 → 打包

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
| 社群事件 | `Xrd777/Community/Bf/` (132 .uasset) |
| BGM | `Xrd777/CriData/CueSheet/system.uasset` |

## 资产格式

游戏使用 UE 4.27，资产以两种容器并存：

| 格式 | 文件 | 提取工具 | 状态 |
|------|------|---------|------|
| IoStore | `.utoc` + `.ucas` | FModel (GUI) | 已导出至 `Extracted/IoStore/` |
| 传统 PAK | `.pak` | UnrealPak (CLI) | 已提取至 `Extracted/pakchunk*/` |

- **Xrd777 > Astrea**：同名资产以 Xrd777 为准
- **IoStore .uasset 文件头全为零**：无法直接用 UAssetAPI 编辑，需通过 CUE4Parse 读取
- **写回方案**：模板法 — P3RDataTools `create-template` 自动生成传统格式模板 + UAssetAPI 修改 (见 `docs/SYSTEM_ARCHITECTURE.md`)

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

### 自动化路径 (推荐)
```powershell
# 1. 加载配置
. .\tools\scripts\Config.ps1

# 2. 读取原始表
& $DataTools read "P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset" skills.json

# 3. 编辑 skills.json

# 4. 模板法写回 + 打包 (Sprint 1 实现)
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -ModScript .\my-changes.ps1 -ModName "MyMod"
```

### 编排脚本
```powershell
# 使用已知别名
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills

# 直接指定虚拟路径
.\tools\scripts\modify-and-repack.ps1 -VirtualPath "P3R/Content/Xrd777/..."
```

## 关键约束

- **UE 版本**：4.27（pak version 11），UnrealPak 和 CUE4Parse 均需匹配
- **Xrd777 > Astrea**：同名资产以 Xrd777 为准
- **CUE4Parse = 1.1.1**：不要升级到 1.2.2（Zlib 初始化失败）
- **Mod PAK 命名**：`_P` 后缀 = 最高优先级
- **Crypto.json 必须简化**（不含 `$types` 字典）
- **IoStore 写回**：通过模板法解决 (见 `docs/SYSTEM_ARCHITECTURE.md`)

## 常见问题排查

### Mod 不生效

```
检查清单:
□ PAK 文件名是否以 _P.pak 结尾
□ PAK 是否放在正确的 Paks/ 目录
□ 是否有其他同名资产覆盖了你的 Mod
□ 文件系统是否为 NTFS (大小写敏感)

调试方法:
  用 FModel 加载你的 Mod PAK → 检查内部路径是否正确
  游戏启动参数加 -log → 搜索 "MountPak" → 确认 PAK 被加载
  log 中搜索你的资产路径 → 确认加载来源
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
