# Zen Byte-Patch 工作流（P3R Mod 写回的官方路径）

> **状态**：2026-06-24 — Sprint 1.5 全部完成 ✅；AgiMod / BufuMod / 100× ExpMod 人工实测通过 ✅
>
> **定位**：这是 P3R Mod 数值修改的**实际可工作路径**，替代 [`docs/MODDING_PITFALLS.md` P-007](MODDING_PITFALLS.md#p-007-unrealessentials-iostore-资产替换偏好-zen-单文件) 推翻的传统 `.uasset+.uexp` 路径。
>
> **工程化交付（Sprint 1.5，全部已完成）**：
> | 任务 | 交付物 | 状态 |
> |------|--------|------|
> | T1.5.1 | `tools/templates-010/` — 41 个 p3re `.bt` 模板 | ✅ |
> | T1.5.2 | `Parse-BtTemplate.ps1` — `.bt` 解析器，38/41 schema | ✅ |
> | T1.5.3 | `Calibrate-SchemaHeaders.ps1` — Header 校准，34/38 ok | ✅ |
> | T1.5.4 | `Test-SchemaRegression.ps1` — Schema 回归，18/30 PASS | ✅ |
> | T1.5.5 | [`Invoke-ZenPatch.ps1`](../tools/scripts/Invoke-ZenPatch.ps1) — schema-driven 字节写回引擎 | ✅ |
> | T1.5.6 | [`P3RModDSL.psm1`](../tools/scripts/dsl/P3RModDSL.psm1) — 12 个 DSL helper | ✅ |
> | T1.5.7 | [`modify-and-repack.ps1`](../tools/scripts/modify-and-repack.ps1) — 全流程管道（Zen patch 默认）| ✅ |
> | T1.5.8 | AgiMod 回归 — PoC vs DSL 字节完全一致 + 人工实测通过 | ✅ |
> | T1.5.9 | 文档更新 — ZEN_BYTE_PATCH_WORKFLOW / DEVELOPMENT_PLAN / DEVELOPER_GUIDE / CLAUDE.md 同步 | ✅ |
> | T1.5.10 | Sprint 评审 — BufuMod (`hpn=999`) + ExpMod (`ExpRate=100.0`) 人工实测通过 | ✅ |
>
> **无需再手工执行字节 patch**。本文档保留作为参考和手工 fallback，**推荐直接看 [CLAUDE.md](../CLAUDE.md#快速路径mod-dsl推荐sprint-15) 快速开始**。

---

## 1. 核心思路

P3R 是纯 IoStore 游戏，散文件覆盖的 `.uasset` 必须是 **Zen 单文件**（首字节 `00 00 00 00`、无 `.uexp`）。我们**就地修改**已有的 Zen 文件。

```
Extracted/IoStore/.../<Asset>.uasset (原始 Zen 字节)
        │
        │  ① Invoke-ZenPatch.ps1 复制到工作目录
        ↓
<Mod>/UnrealEssentials/<虚拟路径>/<Asset>.uasset (Zen, 大小与原件一致)
        │
        │  ② 在文件特定 byte offset 写入新值 (offset 由 010 schema 计算)
        ↓
游戏加载 → UnrealEssentials 路由 → P3R AE 反序列化器 → 数值生效
```

**关键事实**：
- ✅ 不重新序列化 → 文件**总字节数与原件完全相同**
- ✅ Zen 行内字段无 property tag，可以纯靠 schema 算 offset
- ✅ ushort / int32 / float / byte 等定长标量都能改
- ✅ 2026-06-24 **人工实测确认**：Agi `hpn=999` 游戏中伤害约为布芙 5 倍；Bufu `hpn=999` 生效；Normal `ExpRate=100.0` 生效
- ❌ 变长字段（string / TArray）暂不支持

---

## 2. 快速开始（Sprint 1.5 自动化路径）

### 方案 A：DSL（最方便，一行搞定）

```powershell
Import-Module .\tools\scripts\dsl\P3RModDSL.psm1

# 亚基伤害翻 5 倍（自动 N²）
Set-SkillHpn -SkillId 10 -DamageMultiplier 5.0 -OutputDir .\my-agimod\

# 改 Persona 等级
Set-PersonaLevel -PersonaId 1 -Level 99 -OutputDir .\my-persona\

# 改敌人技能槽
Set-EnemySkill -EnemyId 100 -Slot 3 -SkillId 47 -OutputDir .\my-enemy\

# 改难度经验倍率
Set-DifficultyParam -Difficulty easy -Field ExpRate -Value 3.0 -OutputDir .\my-diff\
```

### 方案 B：内联 changes（管道一行）

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999}) -ModName "AgiMod"
```

### 方案 C：changes.json 文件

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -ChangesJson .\changes.json -ModName "MyMod"
```

### 方案 D：DSL 脚本

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -ModScript .\my-changes.ps1 -ModName "MyMod"
```

### DryRun 预览

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -Changes @(...) -DryRun
```

### NoInstall（只产出 .uasset 不部署）

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -Changes @(...) -NoInstall
```

### 目标语法（按 tableShape）

| Shape | 目标语法 | 对应 schema |
|---|---|---|
| `indexed_rows` | `Data[10].hpn` | `p3re_skillNormal` 等 29 张表 |
| `named_rows` | `Rows.normal.ExpRate` 或 `Rows["normal"].ExpRate` | `p3re_DT_BtlDIfficultyParam` |
| `single_record` | `accidentBaseRate`（裸字段名） | `p3re_combineMisc` 等 5 张表 |
| `single_record_array` | `Record[0].value` | `p3re_btlTheurgiaBoost` 等 3 张表 |

---

## 3. 前置条件（每张表只做一次，已完成）

### 3.1 010-Editor 模板库

来源：[godofknife/010-Editor-Templates](https://github.com/godofknife/010-Editor-Templates)，41 个 p3re 模板已固化在 `tools/templates-010/`（T1.5.1 ✅）。

### 3.2 Schema 解析

`Parse-BtTemplate.ps1`（T1.5.2 ✅）已解析 38/41 模板，schema JSON 在 `tools/templates-010/schemas/`。

### 3.3 Header 校准

`Calibrate-SchemaHeaders.ps1`（T1.5.3 ✅）已校准 34/38 schema，黄金锚点 `p3re_skillNormal headerSize=1174` 与 AgiMod PoC 完全吻合。

### 3.4 Schema 回归

`Test-SchemaRegression.ps1`（T1.5.4 ✅）回归 18/30 PASS，`p3re_skillNormal` 120/120 字段全对。

### 3.5 已验证的 DataTable

| Asset | rowSize | headerSize | rowCount | fileSize | 验证来源 |
|---|---:|---:|---:|---:|---|
| `DatSkillNormalDataAsset.uasset` | 769 | 1174 | 700 | 539,474 | AgiMod PoC + 人工实测 ✅ |
| `DatSkillDataAsset.uasset` | 86 | 694 | 1025 | 88,844 | `AllInherit` 参考 mod |
| `DatPersonaDataAsset.uasset` | 402 | 814 | 464 | 187,342 | CUE4Parse 回归 |
| `DatPersonaGrowthDataAsset.uasset` | 2498 | 830 | 464 | 1,159,902 | CUE4Parse 回归 |
| `DatEnemyDataAsset.uasset` | 1336 | 826 | 601 | 804,022 | CUE4Parse 回归 |
| `DT_BtlDIfficultyParam.uasset` | 306/行 | 1470 | 5 | 2,983 | `arkemultiplier` 参考 mod ✅ |
| `DatPlayerLevelupDataAsset.uasset` | 37 | 702 | 99 | 4,365 | CUE4Parse 回归 |

---

## 4. 手工路径（备用 / 调试 / 新表第一次验证）

### Step 1: 复制原件到部署目录

```powershell
$src = 'Extracted\IoStore\P3R\Content\Xrd777\Battle\Tables\DatSkillNormalDataAsset.uasset'
$dst = 'tools\Reloaded II\Mods\AgiMod\UnrealEssentials\P3R\Content\Xrd777\Battle\Tables\DatSkillNormalDataAsset.uasset'
Copy-Item $src $dst -Force
```

### Step 2: 计算 byte offset

```
field_file_offset = headerSize + (rowIndex × rowSize) + fieldOffsetInRow
```

AgiMod 实例：

| 变量 | 值 | 来源 |
|---|---:|---|
| `headerSize` | 1174 | schema JSON 校准值 |
| `rowSize` | 769 | schema JSON |
| `rowIndex` | 10 | Agi 的 Skill ID |
| `fieldOffsetInRow` | 458 | schema JSON（hpn 字段） |
| **`fileOffset`** | **0x246A = 9322** | **1174 + 10×769 + 458** |

### Step 3: 写字节

```powershell
$bytes = [System.IO.File]::ReadAllBytes($dst)
[BitConverter]::GetBytes([uint16]999).CopyTo($bytes, 0x246A)
[System.IO.File]::WriteAllBytes($dst, $bytes)
```

### Step 4: 验证

```powershell
$check = [System.IO.File]::ReadAllBytes($dst)
# magic = "00 00 00 00"    ← Zen 单文件
# 大小 = 原件大小            ← 539,474 bytes
# 同目录无 .uexp
# hpn @ 0x246A = 999
```

---

## 5. 字段语义陷阱

### 5.1 `hpn` 是显示伤害的平方 ⚠️

详见 [P-009](MODDING_PITFALLS.md#p-009)。N 倍伤害 → `newHpn = oldHpn × N²`。实测 hpn=999 ≈ 亚基 5 倍伤害（√(999/40)=5.00）。

### 5.2 数组下标 == ID

详见 [P-001](MODDING_PITFALLS.md#p-001)。`Data[0]` 是引擎占位行，Agi 在 `Data[10]`。

### 5.3 字段名带 GUID 后缀（DT_* 表）

详见 [P-006](MODDING_PITFALLS.md#p-006)。010 模板友好名即可，DSL/Invoke-ZenPatch 自动匹配。

### 5.4 真实字段名

详见 [P-004](MODDING_PITFALLS.md#p-004)。P3R 用 lowercase 短名：`hpn` 不是 `Power`，`cost` 不是 `SPCost`。

---

## 6. 已知限制

| 限制 | 影响 |
|---|---|
| 模板未覆盖的表 | 武器/防具/饰品无模板，无法 patch |
| 3 个模板未解析 | `combineBirth` / `datitemskillcard` / `HeroParameterDataAsset`，详见 [SPRINT_1_5_TODO.md](SPRINT_1_5_TODO.md) |
| PARTIAL/FAIL/SKIP schema | 首次使用前需人工核查或修复，详见 [SPRINT_1_5_TODO.md](SPRINT_1_5_TODO.md) |
| union / struct-with-union | 直接 byte-patch 可能崩溃（P-010），详见 [SPRINT_1_5_TODO.md](SPRINT_1_5_TODO.md) |
| nested struct array target | 当前不支持 `Data[N].arr[M].field` 语法 |
| 变长字段 | 字符串/数组改长度不行 |
| 跨版本 | P3R 大更新后须重新校准 `headerSize`，旧 patch 可能作废 |

---

## 7. 与其它文档的关系

| 文档 | 关系 |
|---|---|
| [CLAUDE.md 快速开始](../CLAUDE.md#快速路径mod-dsl推荐sprint-15) | **推荐入口** |
| [DEVELOPER_GUIDE.md §五](DEVELOPER_GUIDE.md#五日常开发工作流) | DSL 函数速查表 |
| [MODDING_PITFALLS.md P-007](MODDING_PITFALLS.md#p-007) | 传统格式崩游戏的论据 |
| [MODDING_PITFALLS.md P-009](MODDING_PITFALLS.md#p-009) | hpn 平方语义 |
| [DEVELOPMENT_PLAN.md Sprint 1.5](DEVELOPMENT_PLAN.md#sprint-15-zen-byte-patch-写回引擎-2026-06-24-起替代-sprint-1-传统格式写回) | 工程化进度 |
| [SPRINT_1_5_TODO.md](SPRINT_1_5_TODO.md) | 剩余限制 / 后续待办 / Sprint 2 guard 输入 |
| [agi_regression_report.md](../tools/templates-010/schemas/agi_regression_report.md) | T1.5.8 详细回归数据 |
