# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此仓库中工作时提供指导。

## 项目概述

这是一个 **Persona 3 Reload (P3R) 逆向工程与 Mod 制作工作区**，而非传统的软件项目。无构建系统、包管理器或测试套件。仓库使用 Git 进行版本控制，仅跟踪文档和脚本（`.gitignore` 排除了二进制资产和工具）。

### 项目目标

对 P3R（女神异闻录 3 Reload）进行 Mod 制作，包括但不限于：

- **数值**：角色属性、技能数值、经验曲线、掉落率等 DataTable 数据
- **敌人 AI**：敌方行为树、战斗逻辑、技能使用策略
- **文本**：对话文本、UI 文字、技能描述、本地化内容
- **音乐/音频**：BGM 替换、音效修改、语音包
- **模型**：角色模型、武器模型、场景道具的网格体与材质
- **粒子特效**：技能特效、环境粒子、UI 动效
- **事件/剧情**：事件脚本、过场动画、任务触发条件

## 已提取资产

游戏资产已全部提取至 `Extracted/`（145,193 文件，48.4 GB）：

```
Extracted/
├── IoStore/P3R/Content/        ← FModel 导出（主游戏资产，138,936 files，41.2 GB）
│   ├── Astrea/                 基础内容层（P3R UE 项目名）
│   └── Xrd777/                 主内容层（Atlus 内部项目代号，修改时优先此目录）
├── pakchunk0-WindowsNoEditor/  ← UnrealPak 导出（引擎+插件+配置+部分音频，3.2 GB）
├── pakchunk1-WindowsNoEditor/  ← 音频流（1.8 GB）
├── pakchunk2-WindowsNoEditor/  ← 中文字体（8 MB）
├── pakchunk3-WindowsNoEditor/  ← 语言特定过场视频（34 MB）
├── pakchunk4-WindowsNoEditor/  ← 补充音频+字体（397 MB）
└── pakchunk5-WindowsNoEditor/  ← 英语音频+Astrea视频（1.9 GB）
```

**Xrd777 vs Astrea 优先级**：同名资产 Xrd777 中的版本覆盖 Astrea。修改时修改 Xrd777 版本。

## 文档结构

| 文档 | 用途 |
|------|------|
| `docs/UE_MODDING_GUIDE.md` | 完整的 UE Mod 制作中文指南（1,220 行） |
| `docs/P3R_ASSET_ANALYSIS.md` | 所有提取资产的详细分析报告（按 Mod 目标分类） |
| `docs/amicitia/README.md` | Amicitia Wiki 37 个参考页面的索引 |
| **`docs/amicitia/DATA_MAPPING.md`** | **Wiki 页面 ↔ 提取游戏文件的精确映射（修改资产时的核心参考）** |
| `docs/amicitia/md/` | Amicitia Wiki 的 Markdown 版本（37 个 ID 表/参考页面） |
| `docs/amicitia/html/` | 原始 HTML 备份 |

### 查找要修改的文件

当用户说"修改某个数据"时，按以下顺序查找：

1. **查 `docs/amicitia/DATA_MAPPING.md`** — 按需求类别（技能/Persona/道具/敌人等）定位对应的 `.uasset` 文件名
2. **查 `docs/amicitia/md/`** — 获取具体的 ID 表数据（如技能 ID、道具 ID）
3. **在 `Extracted/IoStore/P3R/Content/Xrd777/` 中定位文件** — 核心 DataTable 在 `Battle/Tables/` 和 `UI/Tables/`

### 最常修改的 DataTable（快速索引）

```
技能数值                      → Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset
技能元数据                    → Xrd777/Battle/Tables/DatSkillDataAsset.uasset
Persona 基础/成长             → Xrd777/Battle/Tables/DatPersonaDataAsset.uasset / DatPersonaGrowthDataAsset.uasset
Persona 耐性                  → Xrd777/Battle/Tables/DatPersonaAffinityDataAsset.uasset
敌人属性                      → Xrd777/Battle/Tables/DatEnemyDataAsset.uasset
敌人耐性                      → Xrd777/Battle/Tables/DatEnemyAffinityDataAsset.uasset
遇敌表                        → Xrd777/Battle/Tables/DatEncountTableDataAsset.uasset
道具/价格/效果                → Xrd777/UI/Tables/DatItemCommonDataAsset.uasset
武器                          → Xrd777/UI/Tables/DatItemWeaponDataAsset.uasset
防具                          → Xrd777/UI/Tables/DatItemArmorDataAsset.uasset
饰品                          → Xrd777/UI/Tables/DatItemAccsDataAsset.uasset
技能卡                        → Xrd777/UI/Tables/DatItemSkillcardDataAsset.uasset
服装                          → Xrd777/UI/Tables/DatItemCostumeDataAsset.uasset
玩家升级/HP上限               → Xrd777/Battle/Tables/DatPlayerLevelupDataAsset.uasset / DatPlayerMaxHPSPDataAsset.uasset
社群事件                      → Xrd777/Community/Bf/ (132 .uasset)
BGM                           → Xrd777/CriData/CueSheet/system.uasset
```

## 资产存储格式

游戏以**两种并行的容器格式**存储资产（UE4/UE5 混合）：

| 格式 | 文件 | 说明 |
|--------|-------|-------------|
| **传统 PAK** | `.pak` | UE4 时代归档格式，AES-256 加密，Zlib/Oodle 压缩 |
| **IoStore** | `.ucas` + `.utoc` | UE5 时代容器格式；`.utoc` = 目录索引，`.ucas` = 原始数据 |

PAK 文件已被 UnrealPak 提取；IoStore 已被 FModel 导出。原始 `Paks/` 目录保留但已加入 `.gitignore`。

## 工具链

### FModel (`tools/FModel.exe`)
GUI 应用，用于浏览和导出 UE 资产。支持 `.pak` 和 IoStore。用于：
- 浏览资产树、导出 DataTable 为 JSON、提取纹理为 PNG
- FModel 默认导出到 `tools/Output/Exports/`

### UnrealPak (`tools/UnrealPakTool/UnrealPak.exe`)
UE 4.27 命令行 PAK 工具。**必须从 `tools/UnrealPakTool/` 目录执行**，配套 DLL 需在同一目录。

```powershell
# 在 tools/UnrealPakTool/ 下执行：

# 带解密提取（Crypto.json 格式必须简化——见下方说明）
.\UnrealPak.exe "..\..\Paks\pakchunk0-WindowsNoEditor.pak" -Extract "Output" -cryptokeys=Crypto.json

# 列出内容
.\UnrealPak.exe "..\..\Paks\pakchunk0-WindowsNoEditor.pak" -List -cryptokeys=Crypto.json

# 创建 Mod PAK（需在 Mod 工作目录准备 manifest.txt）
.\UnrealPak.exe "MyMod_P.pak" -Create="manifest.txt" -compress
```

## AES 密钥

```
Hex:  0x92BADFE2921B376069D3DE8541696D230BA06B5E4320084DD34A26D117D2FFEE
Base64: krrf4pIbN2Bp096FQWltIwuga15DIAhN00om0RfS/+4=
```

**Crypto.json 格式要求**（`tools/UnrealPakTool/Crypto.json`）：必须是简化格式，复杂格式会导致 `Failed to find requested encryption key`。当前正确格式：

```json
{
  "EncryptionKey": {
    "Name": "null",
    "Guid": "null",
    "Key": "krrf4pIbN2Bp096FQWltIwuga15DIAhN00om0RfS/+4="
  }
}
```

## Mod 制作流程

### 1. 资产修改
- **DataTable** → FModel 导出为 JSON → 编辑数值 → UAssetGUI 导回 `.uasset` + `.uexp`
- **纹理** → FModel 导出 PNG → 编辑 → UAssetGUI 替换 BulkData 引用
- **蓝图属性** → UAssetGUI 打开 `.uasset` + `.uexp` → 修改 ClassDefaultObject
- 修改时必须同时打包 `.uasset` + `.uexp`（有 BulkData 时还需 `.ubulk`）

### 2. 创建 manifest.txt
```
"相对路径/文件.uasset" "../../../Game/目标路径/文件.uasset"
"相对路径/文件.uexp"   "../../../Game/目标路径/文件.uexp"
```

### 3. 打包与加载
```powershell
.\UnrealPak.exe "MyMod_P.pak" -Create="manifest.txt" -compress
# 将 MyMod_P.pak 放到游戏的 Content\Paks\ 目录
```
`_P` 后缀 = 最高加载优先级，覆盖所有原始 PAK。

## 文件格式

| 扩展名 | 说明 |
|------|------|
| `.uasset` | UE 资产头（元数据、导入/导出表、属性） |
| `.uexp` | UE 资产导出数据（与 .uasset 成对） |
| `.ubulk` | 大块二进制数据（纹理像素、模型顶点、音频 PCM） |
| `.umap` | 关卡/地图 |
| `.awb` | CRIWARE ADX2 音频包（BGM/SE/语音） |
| `.usm` | CRIWARE 视频文件 |

## 关键约束

- **UE 版本**：4.27（pak version 11）。UnrealPak 版本必须匹配。
- **Xrd777 > Astrea**：同名资产以 Xrd777 为准。
- **Mod PAK 命名**：`_P` 后缀 = 最高优先级。
- **Crypto.json 必须是简化格式**（不含 `$types` 字典和 `$type` 字段）。
- **IoStore 提取**：UE 4.27 UnrealPak 无法处理 `.utoc`，必须用 FModel。
