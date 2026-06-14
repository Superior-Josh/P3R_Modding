# P3R Modding 参考数据（Amicitia Wiki）

> 来源：https://amicitia.miraheze.org/wiki/Persona_3_Reload
> 下载日期：2026-06-15
> 格式：Markdown（原始 HTML 备份在 `html/` 目录）

## 目录索引

### ID 数据表

| 文档 | 大小 | 内容 |
|------|------|------|
| [Skills](md/Persona_3_Reload_Skills.md) | 51.6 KB | 技能 ID 表（名称、描述、属性、SP 消耗） |
| [Skill Cards](md/Persona_3_Reload_Skill_Cards.md) | 32.6 KB | 技能卡 ID 表 |
| [Personas](md/Persona_3_Reload_Personas.md) | 13.1 KB | Persona ID 表（种族、等级、属性、技能） |
| [Enemies](md/Persona_3_Reload_Enemies.md) | 14.2 KB | 敌人/Shadow ID 表 |
| [Encounters](md/Persona_3_Reload_Encounters.md) | 61 KB | 遇敌表（区域→敌人组→出现条件） |
| [Items](md/Persona_3_Reload_Items.md) | 22.3 KB | 消耗道具 ID 表 |
| [Weapons](md/Persona_3_Reload_Weapons.md) | 11.6 KB | 武器 ID 表 |
| [Armor](md/Persona_3_Reload_Armor.md) | 11.8 KB | 防具 ID 表 |
| [Accessories](md/Persona_3_Reload_Accessories.md) | 11.9 KB | 饰品 ID 表 |
| [Materials](md/Persona_3_Reload_Materials.md) | 16.9 KB | 交换材料 ID 表 |
| [Key Items](md/Persona_3_Reload_Key_Items.md) | 6.5 KB | 关键道具 ID 表 |
| [Outfits](md/Persona_3_Reload_Outfits.md) | 21.6 KB | 服装/换装 ID 表 |
| [BGM](md/Persona_3_Reload_BGM.md) | 8.7 KB | BGM ID 表 |
| [Fields](md/Persona_3_Reload_Fields.md) | 5 KB | 场景/地图 ID 表 |

### 模型索引

| 文档 | 大小 | 内容 |
|------|------|------|
| [Player](md/Persona_3_Reload_Player.md) | 1.6 KB | 主角模型列表 |
| [Personas](md/Persona_3_Reload_Personas.md) | 13.1 KB | Persona 模型 + 数据 |
| [EnemyModels](md/Persona_3_Reload_EnemyModels.md) | 2.5 KB | 敌人模型列表 |
| [Mob](md/Persona_3_Reload_Mob.md) | 1.7 KB | 路人/杂兵模型 |
| [Npc](md/Persona_3_Reload_Npc.md) | 1.6 KB | NPC 模型列表 |
| [Sub](md/Persona_3_Reload_Sub.md) | 2.2 KB | 子角色模型 |
| [Weapons](md/Persona_3_Reload_Weapons.md) | 11.6 KB | 武器模型 + 数据 |
| [Anim](md/Persona_3_Reload_Anim.md) | 2.5 KB | 动画索引 |
| [Battle](md/Persona_3_Reload_Battle.md) | 1.8 KB | 战斗相关资源索引 |

### 事件与脚本

| 文档 | 大小 | 内容 |
|------|------|------|
| [Event Main](md/Persona_3_Reload_Event_Main.md) | 12.1 KB | 主线事件 ID 表 |
| [Event Cmmu](md/Persona_3_Reload_Event_Cmmu.md) | 24.9 KB | 社群（Community）事件 ID |
| [Event Extr](md/Persona_3_Reload_Event_Extr.md) | 4.4 KB | 额外事件 ID |
| [Event Qest](md/Persona_3_Reload_Event_Qest.md) | 1.9 KB | 任务/支线事件 ID |
| [Event](md/Persona_3_Reload_Event.md) | 1.6 KB | 事件系统概览 |

### Flags（标志位）

| 文档 | 大小 | 内容 |
|------|------|------|
| [Event Flags](md/Persona_3_Reload_Event_Flags.md) | 63.5 KB | 事件标志位（触发条件） |
| [Commu Flags](md/Persona_3_Reload_Commu_Flags.md) | 70.9 KB | 社群标志位 |
| [Field Flags](md/Persona_3_Reload_Field_Flags.md) | 161.4 KB | 场景标志位 |
| [Battle Flags](md/Persona_3_Reload_Battle_Flags.md) | 13.7 KB | 战斗标志位 |
| [System Flags](md/Persona_3_Reload_System_Flags.md) | 16.2 KB | 系统标志位 |
| [Progress Flags](md/Persona_3_Reload_Progress_Flags.md) | 12.3 KB | 进度标志位 |
| [Counters](md/Persona_3_Reload_Counters.md) | 11.6 KB | 计数器 |

### 美术资源

| 文档 | 大小 | 内容 |
|------|------|------|
| [Bustups](md/Persona_3_Reload_Bustups.md) | 2.5 KB | 角色半身立绘索引 |
| [Cut-Ins](md/Persona_3_Reload_Cut-Ins.md) | 4 KB | Cut-in 特效索引 |
| [NPC Dialogue](md/Persona_3_Reload_NPC_Dialogue.md) | 3.1 KB | NPC 对话资源 |
| [Social Links](md/Persona_3_Reload_Social_Links.md) | 2.5 KB | 社群相关美术 |

## 最常用参考数据

进行 Mod 制作时，以下文档最常使用：

1. **Skills** — 技能 ID、名称、描述、伤害公式
2. **Personas** — Persona ID、种族、初始等级、耐性
3. **Items** — 道具 ID、效果、价格
4. **Enemies** — 敌人 ID、HP、掉落
5. **Event Flags** — 剧情触发条件标志位
6. **BGM** — 背景音乐 ID

## 与 DataTable 的对应关系

Amicitia Wiki 中的 ID 表对应游戏中的 DataTable 资产（`IoStore/P3R/Content/Xrd777/Battle/Tables/` 和 `UI/Tables/`）：

| Wiki 页面 | 对应 DataTable |
|------|------|
| Skills | `DatSkillDataAsset.uasset` + `DatSkillNormalDataAsset.uasset` |
| Personas | `DatPersonaDataAsset.uasset` + `DatPersonaGrowthDataAsset.uasset` |
| Enemies | `DatEnemyDataAsset.uasset` |
| Items | `DatItemCommonDataAsset.uasset` |
| Weapons | `DatItemWeaponDataAsset.uasset` |
| Armor | `DatItemArmorDataAsset.uasset` |
| Accessories | `DatItemAccsDataAsset.uasset` |
| Encounters | `DatEncountTableDataAsset.uasset` |
