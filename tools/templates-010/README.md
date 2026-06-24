# P3R 010-Editor Templates (binary schema reference)

> **来源**: [godofknife/010-Editor-Templates](https://github.com/godofknife/010-Editor-Templates) (`main` branch)
> **抓取日期**: 2026-06-24
> **License**: 见上游仓库（本目录内文件保持原作者署名和上游 LICENSE）

## 目的

这些 `.bt` 模板是 [010 Editor](https://www.sweetscape.com/010editor/) 的二进制模板（C-like 语法），描述 P3R IoStore Zen `.uasset` 文件里**每个 DataTable 的行结构 + 字段类型 + 字段间填充**。

我们项目用它们做两件事：

1. **手工 byte-level patch** —— 按 [`docs/ZEN_BYTE_PATCH_WORKFLOW.md`](../../docs/ZEN_BYTE_PATCH_WORKFLOW.md) 流程，对照 `.bt` 算字段 offset，再用 PowerShell 写字节。
2. **自动 schema 解析器** —— Sprint 1.5 的 [`Parse-BtTemplate.ps1`](../scripts/Parse-BtTemplate.ps1) 会把 `.bt` 解析成 JSON 字段表，然后 [`Invoke-ZenPatch.ps1`](../scripts/Invoke-ZenPatch.ps1) 用这些字段表做 JSON-driven byte patch。详见 [`docs/DEVELOPMENT_PLAN.md` Sprint 1.5](../../docs/DEVELOPMENT_PLAN.md#sprint-15-zen-byte-patch-写回引擎-2026-06-24-起替代-sprint-1-传统格式写回)。

## 内容（44 个文件）

### p3re_*.bt（42 个）—— P3R 特定 DataTable schema

按主题分组（粗略对应 Reloaded II 一个 mod 想改的东西）：

| 主题 | 模板 |
|---|---|
| 技能数值 | `p3re_skillNormal.bt`, `p3re_datskillnormaldataasset.bt` |
| 技能元数据 | `p3re_skill.bt`, `p3re_datskilldataasset.bt`, `p3re_skillLimit.bt`, `p3re_skillPack.bt` |
| 人格基础 | `p3re_persona.bt`, `p3re_datpersonadataasset.bt` |
| 人格成长（含技能槽）| `p3re_personaGrowth.bt`, `p3re_datpersonagrowthdataasset.bt`, `p3re_allyPersonaGrowth.bt`, `p3re_datallypersonagrowthdataasset.bt` |
| 人格属性耐性 | `p3re_personaAffinity.bt`, `p3re_datpersonaaffinitydataasset.bt` |
| 敌人 | `p3re_enemy.bt`, `p3re_datenemydataasset.bt`, `p3re_enemyAffinity.bt`, `p3re_enemyAnalyzeSync.bt` |
| 遇敌表 | `p3re_encountTable.bt`, `p3re_datencounttabledataasset.bt`, `p3re_encountEnemyBadPercent.bt` |
| 道具 | `p3re_itemSkillCard.bt`, `p3re_datitemskillcarddataasset.bt`, `p3re_DatItemShopLineupDataAsset.bt` |
| 玩家成长 | `p3re_playerLevelup.bt`, `p3re_HeroParameterDataAsset.bt` |
| 战斗参数 | `p3re_DT_BtlDIfficultyParam.bt`, `p3re_btlTheurgiaBoost.bt`, `p3re_btlTheurgiaBoost_astrea.bt`, `p3re_btlMixRaidRelease.bt`, `p3re_datbtltheurgiaboostdataasset.bt`, `p3re_datbtlmixraidreleasedataasset.bt` |
| 合体 | `p3re_combineBirth.bt`, `p3re_combineMisc.bt`, `p3re_combinemiscdataasset.bt`, `p3re_specialSpread.bt`, `p3re_specialspreaddataasset.bt` |
| 支援 | `p3re_supportInfoCommon.bt`, `p3re_supportInfoNavi.bt` |
| PANIC（应急行动）| `p3re_calcPANICDropItem.bt`, `p3re_calcPANICUseItem.bt` |
| **公共依赖**（被 `#include`）| `p3re_enums.bt`（74 KB，全部枚举常量）, `p3re_structs.bt`（5.6 KB，跨表共享 struct）|

### UE 通用模板（5 个）—— `#include` 依赖

| 文件 | 描述 |
|---|---|
| `ue4_iopackage.bt` | UE4 IoStore package header |
| `uasset_4_27.bt` | UE 4.27 传统 `.uasset` 格式 |
| `uasset_io_4_27.bt` | UE 4.27 IoStore Zen `.uasset` 格式（**最重要**——我们写回的文件是这格式）|
| `ucas_4_27.bt` | `.ucas` 容器格式 |
| `utoc_4_27.bt` | `.utoc` 索引格式 |

### 未获取的文件（1 个）

| 文件 | 原因 | 影响 |
|---|---|---|
| `p3re_BP_BtlCalcuasset.bt` | 抓取时网络超时（重试 3 次仍失败）| 这是战斗伤害计算蓝图的 schema，**不是 DataTable**，不影响数值类 mod 的写回流程。需要时手动从上游补拉。|

## 010 模板语法子集（够用即可）

本项目的 `BtParser.cs`（待实现）只需识别这些构造：

```c
#include "other_template.bt"     // 预处理引入
LittleEndian();                  // 字节序声明

typedef struct {                 // 结构体定义
    byte   field[N] <hidden=true>;   // N 字节填充（property tag 占位）
    ubyte  field <name="Display">;   // 1 字节 unsigned
    ushort field;                    // 2 字节 unsigned LE
    uint   field;                    // 4 字节 unsigned LE
    EnumType field;                  // 1 字节 enum（看 p3re_enums.bt 定义）
    StructType field[N];             // N 个 struct 数组
    struct { ... } field;            // 内联匿名 struct
    struct {
        Bool flag : 1 <name="X">;    // 位域（bitfield）
        ...
    } FlagList;                       // 32 个 1-bit = 4 字节
    union { ... } data;              // 联合体（占用最大成员大小）
} rowStruct;

struct {                         // 文件根级 struct
    unk unknown;                 // 不定长 header（实际要用 fileSize - rowSize×rowCount 反推）
    rowStruct rows[N];           // N 个 row
} fileData;
```

**不需要支持的构造**（这 43 个 p3re 模板都没用到）：`if` / `while` / `for` / `local` / 函数定义 / `Switch` / 自适应大小数组（`while (!FEof()) {...}`）。这让解析器实现复杂度大幅降低。

## 已实测的字段表（已校准 header）

| Asset | rowSize | headerSize | rowCount | file_size | 来源 |
|---|---:|---:|---:|---:|---|
| `DatSkillNormalDataAsset.uasset` | 769 | 1174 | 700 | 539,474 | AgiMod PoC（21 字段全部对上 CUE4Parse JSON）|
| `DatSkillDataAsset.uasset` | 86 | 694 | 1025 | 88,844 | `AllInherit` 字节差分实证 |
| `DatPersonaGrowthDataAsset.uasset` | 2498 | 830 | 464 | 1,159,902 | Orpheus 11 个技能槽实证 |

更多表的字段表 + header 校准已在 Sprint 1.5 完成，结果写入 `tools/templates-010/schemas/*_schema.json`，报告见 `tools/templates-010/schemas/calibration-report.md` 与 `regression-report.md`。

## 同步策略

godofknife 仓库还在更新。建议：

- **不要直接 fork** —— 文件量少（48 个），手动按需重抓更可控
- 项目里固化的 commit hash 记录在本 README（首次抓取 = 2026-06-24，[main 当时的 HEAD](https://github.com/godofknife/010-Editor-Templates/tree/main)）
- P3R 大版本更新后**重新抓**（行 struct 可能改）

## License

每个 `.bt` 文件首部的注释块（`Authors: Light8227`、`Version: X.Y`）是原作者署名。本目录文件**不修改**这些注释块。我们只**使用**这些 schema 做字节级 patch，不重新发行模板文件。
