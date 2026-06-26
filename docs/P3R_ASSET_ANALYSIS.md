# P3R 资产解包分析报告

> 生成日期：2026-06-14
> 资产来源：`Paks/` 目录下的 PAK 文件 + IoStore 容器

### 1.1 当前写回与安全基线（2026-06-25）

- **主写回路径**：`Extracted/IoStore` Zen 单文件 `.uasset` → `Invoke-ZenPatch.ps1` 字节级 patch → `<Mod>/UnrealEssentials/P3R/Content/...` 散文件挂载。
- **传统 `.uasset+.uexp` / `P3RDataTools create` 路线已弃用**：P3R 实测 boot-crash，详见 [MODDING_PITFALLS.md P-007](MODDING_PITFALLS.md#p-007-unrealessentials-iostore-资产替换偏好-zen-单文件)。
- **安全系统已完成**：`modify-and-repack.ps1` 默认执行 diff/guard/conflict/Git pre-mod backup/文件备份/post-patch guard，并写入 `mod.json` / `history.json` / `.data/mod_registry.json`；详见 [SECURITY.md](SECURITY.md)（§7 含 Sprint 3 复验结论）。

---

## 一、总体概览

P3R（Persona 3 Reload）使用 **Unreal Engine 4.27**，资产以两种容器格式并存：

| 格式 | 提取工具 | 文件数 | 大小 |
|------|---------|------|------|
| **IoStore** (.utoc/.ucas) | FModel | 138,936 | 41.2 GB |
| **传统 PAK** (.pak) | UnrealPak | 6,257 | 7.3 GB |
| **合计** | — | **145,193** | **48.4 GB** |

### AES 密钥

```
Hex:  0x92BADFE2921B376069D3DE8541696D230BA06B5E4320084DD34A26D117D2FFEE
Base64: krrf4pIbN2Bp096FQWltIwuga15DIAhN00om0RfS/+4=
```

### 文件格式总览

| 扩展名 | 数量 | 占比 | 说明 |
|------|------|------|------|
| `.uasset` | 119,899 | 89.2% | UE 资产（蓝图、DataTable、材质、纹理元数据） |
| `.ubulk` | 8,965 | 6.7% | 大块二进制数据（纹理像素、模型顶点、音频 PCM） |
| `.umap` | 3,231 | 2.4% | 关卡/地图 |
| `.awb` | 2,184 | 1.6% | CRIWARE ADX2 音频包 |
| `.usm` | 77 | 0.1% | CRIWARE 视频文件 |
| 其他 | 2,837 | 2.1% | 字体、配置、本地化、插件 |

---

## 二、IoStore 详细分析

### 2.1 顶层结构

```
IoStore/
├── Engine/
│   ├── Config/           引擎配置
│   ├── Content/           引擎资源
│   └── Plugins/           引擎插件
└── P3R/
    ├── Config/            游戏配置
    ├── Content/           游戏内容（核心）
    │   ├── Astrea/        P3R UE 项目基础层
    │   ├── L10N/          13 语言本地化资源
    │   ├── Localization/  本地化元数据
    │   └── Xrd777/        Atlus 主游戏容器（核心）
    ├── Platforms/         平台特定资源（PS4/PS5/Windows）
    └── Plugins/           游戏自定义插件
```

### 2.2 双容器架构：Astrea 与 Xrd777

游戏内容分布在两个容器中，**互为补充**：

| 容器 | 项目名 | 定位 | 内容量 |
|------|------|------|------|
| **Astrea** | P3R UE 项目 | 基础/底层内容、部分 UI、基础角色、基础效果 | 较小 |
| **Xrd777** | Atlus 内部项目代号 | **主游戏容器**，绝大部分可修改的游戏数据 | 最大 |

> 两个容器有同名子目录（如 `Battle/`、`Characters/`、`Events/`），修改时需注意：Xrd777 中的资产一般覆盖/优先于 Astrea 中的同名资产。

---

## 三、按 Mod 目标分类索引

### 3.1 数值修改

> 路径：`IoStore/P3R/Content/Xrd777/Battle/Tables/`

| 文件名 | 大小 | 修改内容 |
|------|------|------|
| `DatPersonaGrowthDataAsset.uasset` | 1.1 MB | Persona 成长：等级→技能习得、属性成长曲线 |
| `DatPersonaDataAsset.uasset` | 183 KB | Persona 基础数据：初始等级、种族、基础属性 |
| `DatPersonaAffinityDataAsset.uasset` | 237 KB | Persona 属性相性表（斩/打/贯/火/冰/雷/风/光/暗） |
| `DatEnemyDataAsset.uasset` | 785 KB | 敌人基础数据：HP、SP、等级、掉落 |
| `DatEnemyAffinityDataAsset.uasset` | 307 KB | 敌人属性相性表 |
| `DatEnemyAnalyzeSyncDataAsset.uasset` | 4 KB | 敌人分析显示同步数据 |
| `DatSkillDataAsset.uasset` | 87 KB | 技能元数据（类型、属性、图标） |
| `DatSkillNormalDataAsset.uasset` | 527 KB | **技能数值**：伤害倍率、SP 消耗、命中率、效果 |
| `DatPlayerLevelupDataAsset.uasset` | 4 KB | 玩家等级经验曲线 |
| `DatPlayerMaxHPSPDataAsset.uasset` | 76 KB | 主角 HP/SP 上限成长表 |
| `DatEncountTableDataAsset.uasset` | 393 KB | 遇敌表（区域→敌人组→出现概率） |
| `DatEncountEnemyBadPercentDataAsset.uasset` | 2 KB | 遇敌劣势概率 |
| `DatSupportInfoCommonDataAsset.uasset` | 43 KB | 支援角色通用配置 |
| `DatSupportInfoFukaDataAsset.uasset` | 156 KB | 风花支援技能数据 |
| `DatSupportInfoMituruDataAsset.uasset` | 156 KB | 美鹤支援技能数据 |
| `DatBtlTheurgiaBoostDataAsset.uasset` | 2 KB | 神谕 Boost 数据 |
| `DatBtlTheurgiaBoostBossDataAsset.uasset` | 2 KB | Boss 神谕 Boost 数据 |
| `DatBtlMixraidReleaseDataAsset.uasset` | 2 KB | 混合袭击解放条件 |
| `DatCalcPANICDropItemDataAsset.uasset` | 2 KB | 混乱状态掉宝计算 |
| `DatCalcPANICUseItemDataAsset.uasset` | 1 KB | 混乱状态使用道具计算 |

> 路径：`IoStore/P3R/Content/Xrd777/UI/Tables/`

| 文件名 | 大小 | 修改内容 |
|------|------|------|
| `DatItemCommonDataAsset.uasset` | 519 KB | **全消耗道具**：价格、效果值、使用条件 |
| `DatItemWeaponDataAsset.uasset` | 290 KB | 武器：攻击力、命中、价格、装备者 |
| `DatItemArmorDataAsset.uasset` | 118 KB | 防具：防御力、回避、价格、装备者 |
| `DatItemAccsDataAsset.uasset` | 221 KB | 饰品：属性加成、特殊效果 |
| `DatItemShoesDataAsset.uasset` | 118 KB | 鞋子：防御力、回避 |
| `DatItemCostumeDataAsset.uasset` | 141 KB | 换装数据 |
| `DatItemSkillcardDataAsset.uasset` | 138 KB | 技能卡：技能 ID、价格 |
| `DatItemMaterialDataAsset.uasset` | 112 KB | 交换材料 |
| `DatItemEvitemDataAsset.uasset` | 28 KB | 活动道具 |
| `DatAntiqueShopLineupDataAsset.uasset` | 103 KB | 古董店商品列表 |
| `DatWeaponShopLineupDataAsset.uasset` | 30 KB | 武器店商品列表 |
| `DatItemShopLineupDataAsset.uasset` | 3 KB | 道具店商品列表 |
| `VelvetRoomQuestDataAsset.uasset` | 102 KB | 天鹅绒房间任务 |

> 路径：`IoStore/P3R/Content/Xrd777/Kernel/Tables/`

| 文件名 | 大小 | 修改内容 |
|------|------|------|
| `DT_DataInheritanceTable.uasset` | 47 KB | 数据继承表（多周目继承） |
| `DT_FileNameAsset.uasset` | 22 KB | 文件名映射 |
| `DT_FileNameAsset_Win64.uasset` | 22 KB | Win64 平台文件名映射 |

---

### 3.2 敌人 AI

> IoStore 路径

| 路径 | 内容 |
|------|------|
| `IoStore/P3R/Content/Xrd777/Blueprints/Battle/` | 战斗蓝图逻辑 |
| `IoStore/P3R/Content/Xrd777/Battle/Enemy/` | 敌人配置（编队、出现条件） |
| `IoStore/P3R/Content/Xrd777/Battle/Event/` | 战斗事件脚本（Boss 战特殊机制） |
| `IoStore/P3R/Content/Xrd777/Battle/Allout/` | 总攻击相关（9 文件） |
| `IoStore/P3R/Content/Xrd777/Battle/Shift/` | Shift（换手）相关（8 文件） |
| `IoStore/P3R/Content/Xrd777/Battle/Support/` | 支援 AI（风花/美鹤） |
| `IoStore/P3R/Content/Astrea/Blueprints/Battle/` | 战斗蓝图基础层 |

---

### 3.3 文本/本地化

> L10N 目录（IoStore）

| 语言 | 路径 | 文件数 |
|------|------|------|
| 简体中文 | `IoStore/P3R/Content/L10N/zh-Hans/` | 3,723 |
| 繁体中文 | `IoStore/P3R/Content/L10N/zh-Hant/` | 3,722 |
| 日语 | `IoStore/P3R/Content/L10N/ja/` | 1 |
| 英语 | `IoStore/P3R/Content/L10N/en/` | 3,775 |
| 韩语 | `IoStore/P3R/Content/L10N/ko/` | 3,728 |
| 法语 | `IoStore/P3R/Content/L10N/fr/` | 3,914 |
| 德语 | `IoStore/P3R/Content/L10N/de/` | 3,920 |
| 意大利语 | `IoStore/P3R/Content/L10N/it/` | 3,906 |
| 西班牙语 | `IoStore/P3R/Content/L10N/es/` | 3,927 |
| 波兰语 | `IoStore/P3R/Content/L10N/pl/` | 3,920 |
| 葡萄牙语 | `IoStore/P3R/Content/L10N/pt/` | 3,923 |
| 俄语 | `IoStore/P3R/Content/L10N/ru/` | 3,953 |
| 土耳其语 | `IoStore/P3R/Content/L10N/tr/` | 3,937 |

> 本地化元数据

| 路径 | 内容 |
|------|------|
| `IoStore/P3R/Content/Localization/Game/` | 各语言 .locres（14 语言） |
| `pakchunk0/.../Localization/Game/` | PAK 中的本地化补充 |
| `pakchunk0/.../Internationalization/` | 3,463 个 .res 国际化资源 |

> 游戏内字典文本

| 路径 | 文件数 | 内容 |
|------|------|------|
| `IoStore/P3R/Content/Xrd777/Dictionary/` | 67 文件 | 游戏内术语字典 |
| `IoStore/P3R/Content/Astrea/Dictionary/` | 43 文件 | 基础字典 |

---

### 3.4 音乐/音频

> CRIWARE ADX2 音频系统

| 路径 | 文件数 | 内容 |
|------|------|------|
| `IoStore/P3R/Content/Xrd777/CriData/CueSheet/` | 51 | **音频 Cue 表**（BGM/SE/语音索引） |
| `IoStore/P3R/Content/Xrd777/CriData/Stream/` | 1,001 | 音频流文件 |
| `IoStore/P3R/Content/Astrea/CriData/CueSheet/` | 22 | 基础层 Cue 表 |
| `IoStore/P3R/Content/Xrd777/Sound/Table/` | 2 | 音频配置表 |
| `pakchunk0/P3R/.../CriData/Stream/` | 73 awb + 60 usm | PAK 音频流 |
| `pakchunk1/CriData/Stream/` | 928 awb | PAK 音频流（1.8 GB） |
| `pakchunk4/CriData/Stream/` | 69 awb | PAK 音频流（387 MB） |
| `pakchunk5/en/` | 918 awb | PAK 英语音频（1.5 GB） |

> **共计 .awb 音频文件超过 3,000 个**，分布在 IoStore 和 PAK 中。修改音频需要 CRIWARE ADX2 工具链。

---

### 3.5 模型

> 角色模型

| 路径 | 内容 |
|------|------|
| `IoStore/P3R/Content/Xrd777/Characters/Player/` | 主角模型（含武器） |
| `IoStore/P3R/Content/Xrd777/Characters/Persona/` | Persona 模型 |
| `IoStore/P3R/Content/Xrd777/Characters/Enemy/` | 敌人/Shadow 模型 |
| `IoStore/P3R/Content/Xrd777/Characters/NPC/` | NPC 模型 |
| `IoStore/P3R/Content/Xrd777/Characters/Mob/` | 路人/杂兵模型 |
| `IoStore/P3R/Content/Xrd777/Characters/Weapon/` | 武器模型 |
| `IoStore/P3R/Content/Xrd777/Characters/Sub/` | 子角色模型 |
| `IoStore/P3R/Content/Astrea/Characters/Player/` | 主角基础模型 |
| `IoStore/P3R/Content/Astrea/Characters/Persona/` | Persona 基础模型 |

> 道具/场景物件

| 路径 | 说明 |
|------|------|
| `IoStore/P3R/Content/Xrd777/Props/Pp0001/` ~ `Pp5001/` | 27 个道具组 |
| `IoStore/P3R/Content/Xrd777/Blueprints/Props/` | 278 个道具蓝图 |
| `IoStore/P3R/Content/Astrea/Props/SC0255_Gun/` | 枪械模型（9 文件） |

---

### 3.6 粒子特效

> IoStore 路径

| 路径 | 文件数 | 内容 |
|------|------|------|
| `IoStore/P3R/Content/Xrd777/Effects/Niagara/` | — | Niagara 粒子系统（UE 新粒子系统） |
| `IoStore/P3R/Content/Xrd777/Effects/Cascade/` | — | Cascade 粒子系统（UE 传统粒子） |
| `IoStore/P3R/Content/Xrd777/Effects/Materials/` | — | 特效材质 |
| `IoStore/P3R/Content/Xrd777/Effects/Meshes/` | — | 特效网格体 |
| `IoStore/P3R/Content/Xrd777/Effects/Textures/` | 508 | 特效纹理 |
| `IoStore/P3R/Content/Xrd777/FX/Niagara/` | 1 | 额外 Niagara 效果 |
| `IoStore/P3R/Content/Astrea/Effects/Niagara/` | — | 基础 Niagara 效果 |
| `IoStore/P3R/Content/Astrea/Effects/Textures/` | 70 | 基础特效纹理 |

---

### 3.7 事件/剧情

| 路径 | 内容 |
|------|------|
| `IoStore/P3R/Content/Xrd777/Events/Cinema/` | 过场动画数据 |
| `IoStore/P3R/Content/Xrd777/Events/Data/` | 事件数据（剧情脚本） |
| `IoStore/P3R/Content/Xrd777/Schedule/Data/` | 日程/时间表数据 |
| `IoStore/P3R/Content/Xrd777/Community/Bf/` | **社群事件脚本**（132 文件） |
| `IoStore/P3R/Content/Xrd777/Community/Coefficient/` | 社群系数 |
| `IoStore/P3R/Content/Xrd777/Community/Present/` | 送礼数据（10 文件） |
| `IoStore/P3R/Content/Xrd777/Movies/BMD/` | 过场视频元数据（15 文件） |
| `IoStore/P3R/Content/Astrea/Events/Cinema/` | 基础过场动画 |
| `IoStore/P3R/Content/Astrea/Events/Data/` | 基础事件数据 |
| `IoStore/P3R/Content/Astrea/Schedule/Data/` | 基础日程数据 |

> 视频文件（.usm CRIWARE 格式）

| 路径 | 文件数 |
|------|------|
| `pakchunk0/P3R/.../CriData/Stream/` | 60 usm |
| `pakchunk3/ko/` `zh-Hans/` `zh-Hant/` | 3 usm（语言特定过场） |
| `pakchunk5/en/` | 6 usm |

---

### 3.8 地图/关卡

| 路径 | 内容 |
|------|------|
| `IoStore/P3R/Content/Xrd777/Maps/Field/` | 场景地图 |
| `IoStore/P3R/Content/Xrd777/Maps/Battle/` | 战斗地图 |
| `IoStore/P3R/Content/Xrd777/Maps/Title/` | 标题画面（10 文件） |
| `IoStore/P3R/Content/Xrd777/Maps/UI/` | UI 地图（6 文件） |
| `IoStore/P3R/Content/Xrd777/Maps/Init/` | 初始化地图（2 文件） |
| `IoStore/P3R/Content/Astrea/Maps/Field/` | 场景基础地图 |
| `IoStore/P3R/Content/Astrea/Maps/Title/` | 标题基础地图（5 文件） |
| `IoStore/P3R/Content/Astrea/Maps/UI/` | UI 基础地图（4 文件） |

---

### 3.9 UI 系统

| 路径 | 文件/子目录 | 内容 |
|------|------|------|
| `Xrd777/UI/Battle/` | — | 战斗 UI（HP/SP 条、指令菜单） |
| `Xrd777/UI/Bustup/` | — | 角色半身立绘 |
| `Xrd777/UI/Camp/` | 3 | 营地菜单 |
| `Xrd777/UI/Community/` | 1 | 社群 UI |
| `Xrd777/UI/Dialog/` | 1 | 对话框 |
| `Xrd777/UI/Field/` | — | 场景 UI（小地图、提示） |
| `Xrd777/UI/Mail/` | 133 | 邮件系统 |
| `Xrd777/UI/MailTitle/` | 42 | 邮件标题 |
| `Xrd777/UI/MiniMap/` | 25 | 小地图 |
| `Xrd777/UI/PartyPanel/` | 10 | 队伍面板 |
| `Xrd777/UI/SaveLoad/` | — | 存档/读档 |
| `Xrd777/UI/StaffRoll/` | 12 | 制作人员表 |
| `Xrd777/UI/Tables/` | 41 | UI 相关数据表 |
| `Xrd777/UI/Title/` | 9 | 标题画面 |
| `Xrd777/UI/Combine/` | 4 | Persona 合成 UI |
| `Xrd777/UI/Handwriting/` | — | 手写笔迹 |

---

### 3.10 自定义插件 (Atlus 特有)

> 路径：`pakchunk0/P3R/Plugins/` + `IoStore/P3R/Plugins/`

| 插件名 | 推测功能 |
|------|------|
| `BfAssetPlugin` | 社群事件脚本 (.bf) 解析 |
| `BmdAssetPlugin` | 过场动画/文本 (.bmd) 解析 |
| `BmdAssetMsgViewer` | BMD 消息查看器 |
| `FontStyleAssetPlugin` | 字体样式资产管理 |
| `McaAssetPlugin` | 角色动画资产管理 |
| `PlgAssetPlugin` | 插件资产通用管理 |
| `SldAssetPlugin` | 幻灯片/纹理资产管理 |
| `SprAssetPlugin` | 精灵资产管理 |
| `TmxAssetPlugin` | 地图/场景资产管理 |
| `UiLayoutAssetPlugin` | UI 布局管理 |
| `UimAssetPlugin` | UI 资产管理 |
| `SoundManager` | 音频管理（CRIWARE 桥接） |
| `BuildTimeLanguagePlugin` | 构建时语言控制 |
| `SteamLanguagePlugin` | Steam 平台语言控制 |
| `PakFileManager` | PAK 文件管理（加载/卸载） |
| `InputManagerPlugin` | 输入管理 |
| `DebugMenuPlugin` | Debug 菜单 |
| `KawaiiPhysics` | 物理模拟（头发/布料） |
| `NiagaraExtends` | Niagara 粒子扩展 |
| `OrderingTablePlugin` | 排序表管理 |
| `SharedBinaryLanguagePlugin` | 二进制共享语言 |

---

## 四、PAK 分片详细分析

### 4.1 pakchunk0-WindowsNoEditor（3.2 GB，4,119 文件）

**基础引擎 + 游戏配置 + 插件 + 少量资产**

| 子目录 | 文件数 | 大小 | 内容 |
|------|------|------|------|
| `Engine/Config/` | 16 | 0.3 MB | 引擎级 .ini 配置 |
| `Engine/Content/EngineFonts/` | 6 | 4.5 MB | 引擎字体（Roboto、DroidSans） |
| `Engine/Content/Internationalization/` | 3,463 | 21 MB | .res 国际化资源文件 |
| `Engine/Content/Localization/` | 6 | 6.2 MB | 引擎本地化 |
| `Engine/Content/Slate/` | 299 | 7.1 MB | Slate UI 框架资源（.png 纹理） |
| `Engine/Plugins/` | 140 | 0.1 MB | UE 引擎标准插件（2D/AI/FX/Media 等） |
| `P3R/Config/` | 4 | — | 游戏默认配置（DefaultEngine.ini 等） |
| `P3R/Platforms/Windows/Config/` | 3 | — | Windows 平台特定配置 |
| `P3R/Content/Xrd777/Font/` | 1 | — | 日文字体 |
| `P3R/Content/Xrd777/CriData/Stream/` | 73+60 | — | .awb 音频 + .usm 视频 |
| `P3R/Plugins/` | 29 插件 | — | Atlus 自定义插件 |

### 4.2 pakchunk1-WindowsNoEditor（1.8 GB，1,032 文件）

**音频专用分片**

| 子目录 | 文件数 | 大小 | 内容 |
|------|------|------|------|
| `CriData/Stream/` | 928 awb | 1,792 MB | CRIWARE 音频流（BGM/SE/语音） |
| `Font/` | 5 ufont | 18 MB | 字体文件 |

### 4.3 pakchunk2-WindowsNoEditor（8.1 MB，3 文件）

**中文字体专用分片**

| 文件 | 大小 |
|------|------|
| `AsiaKSJ-B.ufont` | 0.5 MB |
| `DFGBJH8.ufont` | 1.4 MB |
| `DFT_C8.ufont` | 3.8 MB |

### 4.4 pakchunk3-WindowsNoEditor（34 MB，3 文件）

**语言特定过场视频**

| 文件 | 大小 | 语言 |
|------|------|------|
| `ko/Movie_VP9/Anim/MS_Event_Main_100_025.usm` | 11.2 MB | 韩语 |
| `zh-Hans/Movie_VP9/Anim/MS_Event_Main_100_025.usm` | 11.3 MB | 简体中文 |
| `zh-Hant/Movie_VP9/Anim/MS_Event_Main_100_025.usm` | 11.3 MB | 繁体中文 |

### 4.5 pakchunk4-WindowsNoEditor（397 MB，71 文件）

**补充音频 + 字体**

| 子目录 | 文件数 | 大小 |
|------|------|------|
| `CriData/Stream/` | 69 awb | 387 MB |
| `Font/` | 2 ufont | 9.5 MB |

### 4.6 pakchunk5-WindowsNoEditor（1.9 GB，1,029 文件）

**英语音频 + 多语言补充 + Astrea 视频**

| 子目录 | 文件数 | 大小 | 内容 |
|------|------|------|------|
| `Astrea/en/` | 97 | 291 MB | Astrea 英语音频 (.awb) + 视频 (.usm) |
| `en/` | 924 awb | 1,474 MB | 英语音频流 |
| `de/es/fr/it/pl/pt/ru/tr/` | 各 1 | ~11 MB/个 | 各语言补充音频 |

---

## 五、Mod 制作关键路径速查

### DataTable 修改流程（Sprint 1.5 Zen byte-patch 主路径）

```powershell
# 1. 加载配置
. .\tools\scripts\Config.ps1

# 2. 可选：读取/确认原始表（通常优先使用 tools/Output/json 缓存）
& $DataTools read "P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset" skills.json

# 3. 推荐：直接用 Zen byte-patch 管道生成 UnrealEssentials 散文件 Mod
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999}) -ModName "AgiMod"

# 4. DryRun 预览 offset / 值 / schema，不写字节
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999}) -DryRun

# 5. 复杂逻辑可走 DSL 脚本
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -ModScript .\my-changes.ps1 -ModName "MyMod"
```

主路径产物是 Zen 单 `.uasset`，部署到 `<Mod>/UnrealEssentials/P3R/Content/...`；**不生成 `.uexp`，不要求 PAK 打包**。详见 [CLAUDE.md](../CLAUDE.md)、[ZEN_BYTE_PATCH_WORKFLOW.md](ZEN_BYTE_PATCH_WORKFLOW.md) 和 [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md)。

> 传统 `P3RDataTools.exe create <vPath> <modified.json> <outDir>` + `UnrealPak.exe` 路线已被 P-007 证伪，保留为历史/fallback 说明，不用于新 DataTable Mod。

### 常用 DataTable 快速路径

| 类别 | 虚拟路径 |
|------|---------|
| 角色/Persona | `Xrd777/Battle/Tables/DatPersonaDataAsset.uasset` |
| Persona 成长 | `Xrd777/Battle/Tables/DatPersonaGrowthDataAsset.uasset` |
| 技能数值 | `Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset` |
| 敌人 | `Xrd777/Battle/Tables/DatEnemyDataAsset.uasset` |
| 道具 | `Xrd777/UI/Tables/DatItemCommonDataAsset.uasset` |
| 社群 | `Xrd777/Community/Coefficient/` |
| 文本 | `L10N/zh-Hans/` |
| BGM/音频 | `Xrd777/CriData/CueSheet/` |

### PAK 打包命令（fallback，仅排查时使用）

```powershell
# 99% 情况不需要。仅当 UnrealEssentials 散文件路径需要 fallback 排查时使用：
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -Changes @(...) -ModName "MyMod" -PackPak
```

手动 UnrealPak manifest 仍可用于历史排查，但不是 P3R DataTable 主路径：

```powershell
# 在 tools/UnrealPakTool/ 目录下执行
.\UnrealPak.exe "MyMod_P.pak" -Create="manifest.txt" -compress
```

### manifest.txt 格式（传统/fallback）

```
"相对路径/文件.uasset" "../../../目标挂载路径/文件.uasset"
"相对路径/文件.uexp"   "../../../目标挂载路径/文件.uexp"
```

> **注意**: P3R 的 DataTable 主路径偏好 IoStore Zen 单文件。传统格式 `.uasset+.uexp` / `_P.pak` 覆盖同名 IoStore DataTable 已被实测证伪，可能 boot-crash 或不生效。当前默认交付是 UnrealEssentials 散文件 Zen `.uasset`。

---

## 六、注意事项

1. **UE 版本必须匹配**：本游戏为 UE 4.27；UnrealPak 仅在 fallback PAK 路径使用
2. **DataTable 默认部署 Zen 单 `.uasset`**：从 `Extracted/IoStore` 复制原件后 byte-patch，文件大小必须不变，同目录无 `.uexp`
3. **Xrd777 优先于 Astrea**：同名资产 Xrd777 中的版本会覆盖 Astrea
4. **UnrealEssentials 路径必须完整镜像虚拟路径**：`<Mod>/UnrealEssentials/P3R/Content/.../<Asset>.uasset`
5. **PAK/FEmulator 只作 fallback**：传统 `.uasset+.uexp` PAK 覆盖 IoStore DataTable 已被 P-007 证伪
6. **schema guard 必须启用**：PASS + flat scalar 才自动写回；PARTIAL/FAIL/SKIP/union/nested/变长字段需人工核查或拒绝
7. **音频为 CRIWARE ADX2**（.awb），非标准 UE 音频格式，修改需要专用工具
8. **视频为 CRIWARE USM**（.usm），同样需要 CRIWARE 工具链
9. **加密范围**：uasset/uexp/ini/index 均加密，但 FullAsset 未加密（便于 FModel 提取）
