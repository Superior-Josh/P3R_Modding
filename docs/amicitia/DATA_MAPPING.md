# Amicitia Wiki ↔ 提取资产映射表

> 全部路径相对于 `Extracted/IoStore/P3R/Content/`
> Xrd777 为主容器（优先），Astrea 为基础层（补充）
> ⚠ 标记表示该 Wiki 页面内容对应的游戏数据存在于多个文件中
>
> 🇨🇳 **中文用户译名见 [`docs/zh-cn/`](../zh-cn/README.md)**（biligame WIKI 三语对照表）。本文件提供英文 ID 权威映射；中文输入识别/输出请走 `docs/zh-cn/`。

---

## 一、ID 数据表 → DataTable 资产

### Skills（技能）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [Skills](md/Persona_3_Reload_Skills.md) | **DatSkillDataAsset.uasset** (87 KB) | `Xrd777/Battle/Tables/` |
| | **DatSkillNormalDataAsset.uasset** (527 KB) | `Xrd777/Battle/Tables/` |
| 技能描述文本 | **BMD_SkillHelp.uasset** (95 KB) | `Xrd777/Help/` |

- `DatSkillDataAsset`: 技能元数据（ID、名称、属性类型、图标引用）
- `DatSkillNormalDataAsset`: 技能数值（伤害倍率、SP消耗、命中率、效果ID）
- Astrea 有同名副本，以 Xrd777 为准
- ⚠ **`Properties.Data[]` 的数组下标 == Skill ID**。`Data[0]..Data[9]` 多为占位/未使用，**Agi = Data[10]**。详见 [MODDING_PITFALLS.md#P-001](../MODDING_PITFALLS.md#p-001-datatable-数组索引--资产-id不要默认改-data0)

### Skill Cards（技能卡）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [Skill Cards](md/Persona_3_Reload_Skill_Cards.md) | **DatItemSkillcardDataAsset.uasset** (138 KB) | `Xrd777/UI/Tables/` |
| | **DatItemSkillcardNameDataAsset.uasset** (8 KB) | `Xrd777/UI/Tables/` |
| 技能卡描述 | **BMD_ItemSkillcardHelp.uasset** (59 KB) | `Xrd777/Help/` |

### Personas
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [Personas](md/Persona_3_Reload_Personas.md) | **DatPersonaDataAsset.uasset** (183 KB) | `Xrd777/Battle/Tables/` |
| | **DatPersonaGrowthDataAsset.uasset** (1.1 MB) | `Xrd777/Battle/Tables/` |
| | **DatPersonaAffinityDataAsset.uasset** (237 KB) | `Xrd777/Battle/Tables/` |
| Persona 描述 | **BMD_PersonaHelp.uasset** (87 KB) | `Xrd777/Help/` |

- `DatPersonaDataAsset`: Persona 基础数据（ID、名称、种族、初始等级、初始属性）
- `DatPersonaGrowthDataAsset`: Persona 成长数据（等级→习得技能、属性成长值）
- `DatPersonaAffinityDataAsset`: Persona 属性相性（斩/打/贯/火/冰/雷/风/光/暗的耐/弱/反/吸）

### Enemies（敌人）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [Enemies](md/Persona_3_Reload_Enemies.md) | **DatEnemyDataAsset.uasset** (785 KB) | `Xrd777/Battle/Tables/` |
| | **DatEnemyAffinityDataAsset.uasset** (307 KB) | `Xrd777/Battle/Tables/` |
| | **DatEnemyAnalyzeSyncDataAsset.uasset** (4 KB) | `Xrd777/Battle/Tables/` |

### Encounters（遇敌表）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [Encounters](md/Persona_3_Reload_Encounters.md) | **DatEncountTableDataAsset.uasset** (393 KB) | `Xrd777/Battle/Tables/` |
| | **DatEncountEnemyBadPercentDataAsset.uasset** (2 KB) | `Xrd777/Battle/Tables/` |

### Items（消耗道具）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [Items](md/Persona_3_Reload_Items.md) | **DatItemCommonDataAsset.uasset** (519 KB) | `Xrd777/UI/Tables/` |
| | **DatItemCommonNameDataAsset.uasset** (15 KB) | `Xrd777/UI/Tables/` |
| 道具描述 | **BMD_ItemCommonHelp.uasset** (93 KB) | `Xrd777/Help/` |
| 道具店商品 | **DatItemShopLineupDataAsset.uasset** (3 KB) | `Xrd777/UI/Tables/` |

### Weapons（武器）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [Weapons](md/Persona_3_Reload_Weapons.md) | **DatItemWeaponDataAsset.uasset** (290 KB) | `Xrd777/UI/Tables/` |
| | **DatItemWeaponNameDataAsset.uasset** (8 KB) | `Xrd777/UI/Tables/` |
| 武器描述 | **BMD_ItemWeaponHelp.uasset** (50 KB) | `Xrd777/Help/` |
| 武器店商品 | **DatWeaponShopLineupDataAsset.uasset** (30 KB) | `Xrd777/UI/Tables/` |

### Armor（防具）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [Armor](md/Persona_3_Reload_Armor.md) | **DatItemArmorDataAsset.uasset** (118 KB) | `Xrd777/UI/Tables/` |
| | **DatItemArmorNameDataAsset.uasset** (5 KB) | `Xrd777/UI/Tables/` |
| 防具描述 | **BMD_ItemArmorHelp.uasset** (44 KB) | `Xrd777/Help/` |

### Accessories（饰品）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [Accessories](md/Persona_3_Reload_Accessories.md) | **DatItemAccsDataAsset.uasset** (221 KB) | `Xrd777/UI/Tables/` |
| | **DatItemAccsNameDataAsset.uasset** (8 KB) | `Xrd777/UI/Tables/` |
| 饰品描述 | **BMD_ItemAccsHelp.uasset** (49 KB) | `Xrd777/Help/` |

### Shoes（鞋子）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| （合并于 Armor 页面） | **DatItemShoesDataAsset.uasset** (118 KB) | `Xrd777/UI/Tables/` |
| | **DatItemShoesNameDataAsset.uasset** (4 KB) | `Xrd777/UI/Tables/` |
| 鞋子描述 | **BMD_ItemShoesHelp.uasset** (24 KB) | `Xrd777/Help/` |

### Materials（交换材料）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [Materials](md/Persona_3_Reload_Materials.md) | **DatItemMaterialDataAsset.uasset** (112 KB) | `Xrd777/UI/Tables/` |
| | **DatItemMaterialNameDataAsset.uasset** (8 KB) | `Xrd777/UI/Tables/` |
| 材料描述 | **BMD_ItemMaterialHelp.uasset** (53 KB) | `Xrd777/Help/` |

### Key Items（关键道具）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [Key Items](md/Persona_3_Reload_Key_Items.md) | **DatItemEvitemDataAsset.uasset** (28 KB) | `Xrd777/UI/Tables/` |
| | **DatItemEvitemNameDataAsset.uasset** (4 KB) | `Xrd777/UI/Tables/` |
| 关键道具描述 | **BMD_ItemEvitemHelp.uasset** (26 KB) | `Xrd777/Help/` |

### Outfits（服装）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [Outfits](md/Persona_3_Reload_Outfits.md) | **DatItemCostumeDataAsset.uasset** (141 KB) | `Xrd777/UI/Tables/` |
| | **DatItemCostumeNameDataAsset.uasset** (8 KB) | `Xrd777/UI/Tables/` |
| 服装描述 | **BMD_ItemCostumeHelp.uasset** (43 KB) | `Xrd777/Help/` |

### BGM（背景音乐）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [BGM](md/Persona_3_Reload_BGM.md) | **system.uasset** (8.8 MB) | `Xrd777/CriData/CueSheet/` |
| DLC BGM | **DlcBgmAsset.uasset** (7 KB) | `Xrd777/Sound/Table/` |
| DLC BGM 表 | **DT_DlcBgm.uasset** (8 KB) | `Xrd777/Sound/Table/` |

- `system.uasset` 是 CRIWARE CueSheet 总表，包含所有 BGM/SE 的索引和播放参数
- 音频流数据分布在 `CriData/Stream/` (.awb 文件) 和各 pakchunk 的 CriData 目录

### Fields（场景/地图）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [Fields](md/Persona_3_Reload_Fields.md) | `*.umap` 文件 | `Xrd777/Maps/Field/` |
| 战斗地图 | `*.umap` | `Xrd777/Maps/Battle/` (2 files) |
| 标题画面 | `*.umap` | `Xrd777/Maps/Title/` (10 files) |
| UI 地图 | `*.umap` | `Xrd777/Maps/UI/` (6 files) |

---

## 二、模型索引 → 模型文件目录

| Wiki 页面 | 提取目录 | 完整路径 |
|------|------|------|
| [Player](md/Persona_3_Reload_Player.md) | **Characters/Player/** | `Xrd777/Characters/Player/` |
| [Personas](md/Persona_3_Reload_Personas.md) | **Characters/Persona/** | `Xrd777/Characters/Persona/` |
| [EnemyModels](md/Persona_3_Reload_EnemyModels.md) | **Characters/Enemy/** | `Xrd777/Characters/Enemy/` |
| [Mob](md/Persona_3_Reload_Mob.md) | **Characters/Mob/** | `Xrd777/Characters/Mob/` |
| [Npc](md/Persona_3_Reload_Npc.md) | **Characters/NPC/** | `Xrd777/Characters/NPC/` |
| [Sub](md/Persona_3_Reload_Sub.md) | **Characters/Sub/** | `Xrd777/Characters/Sub/` |
| [Weapons](md/Persona_3_Reload_Weapons.md) | **Characters/Weapon/** | `Xrd777/Characters/Weapon/` |
| [Anim](md/Persona_3_Reload_Anim.md) | 动画资源（嵌入模型 uasset 中） | `Xrd777/Characters/*/` 各子目录 |

> 每个角色模型由 `.uasset`（骨骼/网格元数据）+ `.uexp`（导出数据）+ `.ubulk`（顶点/纹理数据）组成。
> 模型 ID 索引参考对应的 Wiki 页面。

---

## 三、事件与脚本 → 游戏文件

### Event Main（主线事件）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [Event Main](md/Persona_3_Reload_Event_Main.md) | 事件脚本 | `Xrd777/Events/Data/` |
| 主线过场 | `.usm` 视频 | `pakchunk0/P3R/Content/Xrd777/CriData/Stream/Movie_VP9/Event/` |

> 主线事件 ID 表对应 `Events/Data/` 目录下的 `.uasset` 事件数据文件。
> 事件脚本可能使用 Atlus 自定义的 BF (Binary Flow) 格式，需要 `BfAssetPlugin` 解析。

### Event Cmmu（社群事件）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [Event Cmmu](md/Persona_3_Reload_Event_Cmmu.md) | **社群脚本** | `Xrd777/Community/Bf/` (132 files) |
| 社群参数 | **Coefficient/** | `Xrd777/Community/Coefficient/` (1 file) |
| 社群事件 | **Event/** | `Xrd777/Community/Event/` (1 file) |
| 送礼数据 | **Present/** | `Xrd777/Community/Present/` (10 files) |
| 假日数据 | **Holiday/** | `Xrd777/Community/Holiday/` |
| 季节事件 | **SeasonEvent/** | `Xrd777/Community/SeasonEvent/` |
| 社群帮助 | **Help/** | `Xrd777/Community/Help/` (2 files) |

- `BF_CmmuNPC_XXX_YYY.uasset`: 社群事件脚本（XXX=NPC编号, YYY=事件阶段）
- `BF_kfevXXX_...`: 特定日期/条件的社群分支事件

### Event Extr（额外事件）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [Event Extr](md/Persona_3_Reload_Event_Extr.md) | 额外事件脚本 | `Xrd777/Events/Data/`（与 Main 共用） |

### Event Qest（任务）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [Event Qest](md/Persona_3_Reload_Event_Qest.md) | 任务数据 | `Xrd777/Events/Data/` |
| 天鹅绒房间任务 | **VelvetRoomQuestDataAsset.uasset** (102 KB) | `Xrd777/UI/Tables/` |

### Schedule（日程系统）
| 内容 | 提取资产 | 路径 |
|------|------|------|
| 日程/时间表 | **Schedule/Data/** | `Xrd777/Schedule/Data/` (1 file) |
| 日程蓝图 | **Blueprints/Schedule/** | `Xrd777/Blueprints/Schedule/` (3 files) |

---

## 四、Flags（标志位）→ 游戏存档/状态数据

> ⚠ Flags 没有独立的 DataTable 文件。它们嵌入在**游戏存档（SaveData）**和**运行时游戏状态**中，通过蓝色 prints 和事件脚本引用。

| Wiki 页面 | 存储位置 | 修改方式 |
|------|------|------|
| [Event Flags](md/Persona_3_Reload_Event_Flags.md) | SaveData / GameState | 存档修改器 / 内存修改 |
| [Commu Flags](md/Persona_3_Reload_Commu_Flags.md) | SaveData | 存档修改器 |
| [Field Flags](md/Persona_3_Reload_Field_Flags.md) | SaveData / GameState | 存档修改器 / 内存修改 |
| [Battle Flags](md/Persona_3_Reload_Battle_Flags.md) | Battle GameState | 内存修改（运行时） |
| [System Flags](md/Persona_3_Reload_System_Flags.md) | SaveData / GameInstance | 存档修改器 |
| [Progress Flags](md/Persona_3_Reload_Progress_Flags.md) | SaveData | 存档修改器 |
| [Counters](md/Persona_3_Reload_Counters.md) | SaveData / GameState | 存档修改器 / 内存修改 |

> Flag 对应的 DataTable 可能存在于 `Kernel/Tables/` 或嵌入在蓝图 ClassDefaultObject 中，但通常不直接暴露为独立的 `.uasset` DataTable 行数据。

---

## 五、美术资源索引 → 游戏文件

### Bustups（半身立绘）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [Bustups](md/Persona_3_Reload_Bustups.md) | **BustupExistDataAsset.uasset** (540 KB) | `Xrd777/UI/Tables/` |
| | **BustupAnimDataAsset.uasset** (3 KB) | `Xrd777/UI/Tables/` |
| | **BustupEnvironmentDataAsset.uasset** (48 KB) | `Xrd777/UI/Tables/` |
| | **BustupGradationDataAsset.uasset** (7 KB) | `Xrd777/UI/Tables/` |
| 立绘纹理 | `UI/Bustup/` 目录 | `Xrd777/UI/Bustup/` |
| 支援角色立绘 | **SupportBustupDataAsset.uasset** (6 KB) | `Xrd777/UI/Tables/` |

### Cut-Ins（技能 Cut-in 特效）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [Cut-Ins](md/Persona_3_Reload_Cut-Ins.md) | Cut-in 纹理/材质 | `Xrd777/Battle/Cutin/` (14 files) |
| | Cut-in UI 数据 | `Xrd777/UI/Cutin/` |

### NPC Dialogue（NPC 对话）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [NPC Dialogue](md/Persona_3_Reload_NPC_Dialogue.md) | 对话文本 | `L10N/zh-Hans/` (3,723 files) |
| | 对话脚本 | `Xrd777/Events/Data/` |

### Social Links（社群）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [Social Links](md/Persona_3_Reload_Social_Links.md) | 社群 UI 资源 | `Xrd777/UI/Community/` |
| | 社群参数 | `Xrd777/Community/Parameter/` (3 files) |
| | 社群事件脚本 | `Xrd777/Community/Bf/` |

### Battle（战斗资源）
| Wiki 页面 | 提取资产 | 路径 |
|------|------|------|
| [Battle](md/Persona_3_Reload_Battle.md) | 战斗蓝图 | `Xrd777/Blueprints/Battle/` (1 file) |
| | 战斗 AI | `Xrd777/Battle/Enemy/` (2 files) |
| | 总攻击 | `Xrd777/Battle/Allout/` (9 files) |
| | Shift 系统 | `Xrd777/Battle/Shift/` (8 files) |
| | 神谕系统 | `Xrd777/Battle/Theurgia/` |
| | 战斗 UI | `Xrd777/UI/Battle/` |
| | 战斗编队 | `Xrd777/Battle/Formations/` (1 file) |
| | 战斗相机 | `Xrd777/Battle/Camera/` (1 file) |

---

## 六、附加系统文件

### 玩家数据
| 内容 | 提取资产 | 路径 |
|------|------|------|
| 升级曲线 | **DatPlayerLevelupDataAsset.uasset** (4 KB) | `Xrd777/Battle/Tables/` |
| HP/SP 上限 | **DatPlayerMaxHPSPDataAsset.uasset** (76 KB) | `Xrd777/Battle/Tables/` |

### 支援角色
| 内容 | 提取资产 | 路径 |
|------|------|------|
| 支援通用 | **DatSupportInfoCommonDataAsset.uasset** (43 KB) | `Xrd777/Battle/Tables/` |
| 风花支援 | **DatSupportInfoFukaDataAsset.uasset** (156 KB) | `Xrd777/Battle/Tables/` |
| 美鹤支援 | **DatSupportInfoMituruDataAsset.uasset** (156 KB) | `Xrd777/Battle/Tables/` |

### 神谕/Theurgia
| 内容 | 提取资产 | 路径 |
|------|------|------|
| Theurgia Boost | **DatBtlTheurgiaBoostDataAsset.uasset** (2 KB) | `Xrd777/Battle/Tables/` |
| Boss Theurgia | **DatBtlTheurgiaBoostBossDataAsset.uasset** (2 KB) | `Xrd777/Battle/Tables/` |
| 混合袭击解放 | **DatBtlMixraidReleaseDataAsset.uasset** (2 KB) | `Xrd777/Battle/Tables/` |
| Theurgia 描述 | **BMD_TheurgiaFlavorText.uasset** (2 KB) | `Xrd777/Help/` |
| Theurgia UI | `Xrd777/Battle/Theurgia/` | `Xrd777/UI/Theurgia/` (1 file) |

### 商店系统
| 内容 | 提取资产 | 路径 |
|------|------|------|
| 古董店 | **DatAntiqueShopLineupDataAsset.uasset** (103 KB) | `Xrd777/UI/Tables/` |
| 武器店 | **DatWeaponShopLineupDataAsset.uasset** (30 KB) | `Xrd777/UI/Tables/` |
| 道具店 | **DatItemShopLineupDataAsset.uasset** (3 KB) | `Xrd777/UI/Tables/` |

### 混乱状态物品
| 内容 | 提取资产 | 路径 |
|------|------|------|
| 混乱掉宝 | **DatCalcPANICDropItemDataAsset.uasset** (2 KB) | `Xrd777/Battle/Tables/` |
| 混乱使用道具 | **DatCalcPANICUseItemDataAsset.uasset** (1 KB) | `Xrd777/Battle/Tables/` |

### 邮件系统
| 内容 | 提取资产 | 路径 |
|------|------|------|
| 邮件数据 | **MailIncomingDataAsset.uasset** (1 MB) | `Xrd777/UI/Tables/` |

### UI 文本/布局
| 内容 | 提取资产 | 路径 |
|------|------|------|
| UI 文本 | **UITextDataAsset.uasset** (2 KB) | `Xrd777/UI/Tables/` |
| Persona 列表布局 | **PersonaListLayoutDataAsset.uasset** (282 KB) | `Xrd777/UI/Tables/` |
| Persona 状态布局 | **PersonaStatusLayoutDataAsset.uasset** (280 KB) | `Xrd777/UI/Tables/` |
| 字体调整 | **FontAdjustmentDataAsset.uasset** (31 KB) | `Xrd777/UI/Tables/` |

### 本地化文本
| 内容 | 提取资产 | 路径 |
|------|------|------|
| 13 语言 L10N | 各语言 `*.uasset` | `L10N/{lang}/` (3,700+ files/language) |
| 本地化元数据 | `.locres` 文件 | `Localization/Game/{lang}/` |

### 字典/术语
| 内容 | 提取资产 | 路径 |
|------|------|------|
| 游戏内字典 | **BMD_Dictionary_001~086.uasset** | `Xrd777/Dictionary/` (65 files) |
| 基础字典 | **BMD_Dictionary_*.uasset** | `Astrea/Dictionary/` (41 files) |
| 字典表 | `Dictionary/Tables/` | `Xrd777/Dictionary/Tables/` (2 files) |

### 数据继承（多周目）
| 内容 | 提取资产 | 路径 |
|------|------|------|
| 继承表 | **DT_DataInheritanceTable.uasset** (47 KB) | `Xrd777/Kernel/Tables/` |
| 文件名映射 | **DT_FileNameAsset*.uasset** | `Xrd777/Kernel/Tables/` (5 files) |

### 教程
| 内容 | 提取资产 | 路径 |
|------|------|------|
| 战斗教程 | `Tutorial/Battle/` (45 files) | `Xrd777/Tutorial/Battle/` |
| 合成教程 | `Tutorial/Combine/` (6 files) | `Xrd777/Tutorial/Combine/` |
| 日常教程 | `Tutorial/Daily/` (15 files) | `Xrd777/Tutorial/Daily/` |
| 迷宫教程 | `Tutorial/Dungeon/` (40 files) | `Xrd777/Tutorial/Dungeon/` |
| 系统教程 | `Tutorial/System/` (6 files) | `Xrd777/Tutorial/System/` |

---

## 七、Xrd777 vs Astrea 命名规则

两个容器有同名目录时，**Xrd777 优先级更高**：

| Xrd777 | Astrea | 说明 |
|------|------|------|
| `Battle/Tables/DatSkillDataAsset.uasset` | ✅ 有同名副本 | 以 Xrd777 为准 |
| `Battle/Tables/DatEnemyDataAsset.uasset` | ✅ 有同名副本 | 内容相同（785 KB） |
| `UI/Tables/DatItemCommonDataAsset.uasset` | ✅ 有同名副本 | 内容相同（519 KB） |
| `Kernel/Tables/DT_FileNameAsset.uasset` | ✅ 有同名副本 | 以 Xrd777 为准 |
| — | `Battle/Tables/DatPlayerMaxHPSPDataAsset.uasset` (88 KB) | Astrea 版本略大 |
| — | `Kernel/Tables/DT_FileNameAsset_PS4/PS5` | Astrea 额外平台文件 |

> 修改时优先修改 Xrd777 中的版本。如果 Xrd777 中没有，再检查 Astrea。

---

## 八、快速查找索引

```
需求                        → 找到的 DataTable
─────────────────────────────────────────────────────
修改技能伤害/SP消耗          → DatSkillNormalDataAsset.uasset
修改技能名称/描述            → DatSkillDataAsset.uasset + BMD_SkillHelp.uasset
修改 Persona 初始属性        → DatPersonaDataAsset.uasset
修改 Persona 学什么技能       → DatPersonaGrowthDataAsset.uasset
修改 Persona 弱点/耐性       → DatPersonaAffinityDataAsset.uasset
修改敌人 HP/掉落             → DatEnemyDataAsset.uasset
修改敌人弱点                 → DatEnemyAffinityDataAsset.uasset
修改遇敌表                   → DatEncountTableDataAsset.uasset
修改道具价格/效果            → DatItemCommonDataAsset.uasset
修改武器攻击力               → DatItemWeaponDataAsset.uasset
修改防具防御力               → DatItemArmorDataAsset.uasset
修改饰品属性                 → DatItemAccsDataAsset.uasset
修改技能卡内容               → DatItemSkillcardDataAsset.uasset
修改交换材料                 → DatItemMaterialDataAsset.uasset
修改服装换装数据             → DatItemCostumeDataAsset.uasset
修改玩家升级经验             → DatPlayerLevelupDataAsset.uasset
修改主角 HP/SP 上限曲线      → DatPlayerMaxHPSPDataAsset.uasset
修改风花/美鹤支援            → DatSupportInfoFukaDataAsset.uasset / Mituru
修改天鹅绒房间任务           → VelvetRoomQuestDataAsset.uasset
修改社群事件条件             → Community/Coefficient/ + Bf/*.uasset
修改 BGM 列表                → system.uasset (CriData/CueSheet/)
修改 DLC BGM                 → DT_DlcBgm.uasset
修改邮件内容                 → MailIncomingDataAsset.uasset
修改游戏内置字典             → BMD_Dictionary_*.uasset
修改教程内容                 → Tutorial/ 目录下的 .uasset
```
