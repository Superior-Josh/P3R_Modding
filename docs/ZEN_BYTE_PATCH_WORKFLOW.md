# Zen Byte-Patch 工作流（P3R Mod 写回的官方路径）

> **状态**：Sprint 1.5 全部完成 ✅；AgiMod / BufuMod / 100× ExpMod 人工实测通过 ✅
>
> 本文档是 P3R Mod 数值修改的**实际可工作路径**详解。**入门直接用 [CLAUDE.md](../CLAUDE.md#快速路径mod-dsl推荐sprint-15) 快速开始**；DSL 速查见 [README.md §4.5](../README.md#45-dsl-函数速查)；本文档保留为手工/调试/新表验证参考。

**工程化交付（Sprint 1.5，全部已完成）**：

| 任务 | 交付物 | 状态 |
|------|--------|------|
| T1.5.1 | `tools/templates-010/` — 44 个 p3re `.bt` 模板 | ✅ |
| T1.5.2–.4 | `Parse-BtTemplate / Calibrate-SchemaHeaders / Test-SchemaRegression` | ✅ |
| T1.5.5 | [`Invoke-ZenPatch.ps1`](../tools/scripts/Invoke-ZenPatch.ps1) — schema-driven 字节写回引擎 | ✅ |
| T1.5.6–.7 | [`P3RModDSL.psm1`](../tools/scripts/dsl/P3RModDSL.psm1) + [`modify-and-repack.ps1`](../tools/scripts/modify-and-repack.ps1) | ✅ |
| T1.5.8–.10 | AgiMod 回归 + BufuMod + ExpMod 人工实测 | ✅ |

---

## 1. 核心思路

P3R 是纯 IoStore 游戏，散文件覆盖的 `.uasset` 必须是 **Zen 单文件**（首字节 `00 00 00 00`、无 `.uexp`）。我们**就地修改**已有的 Zen 文件：

```
Extracted/IoStore/.../<Asset>.uasset (原始 Zen 字节)
    │  ① Invoke-ZenPatch.ps1 复制到工作目录
    ↓
<Mod>/UnrealEssentials/<虚拟路径>/<Asset>.uasset (Zen, 大小与原件一致)
    │  ② 在文件特定 byte offset 写入新值 (offset 由 010 schema 计算)
    ↓
游戏加载 → UnrealEssentials 路由 → P3R AE 反序列化器 → 数值生效
```

- ✅ 不重新序列化 → 文件**总字节数与原件完全相同**
- ✅ Zen 行内字段无 property tag，纯靠 schema 算 offset
- ✅ ushort / int32 / float / byte 等定长标量都能改
- ✅ 人工实测确认：Agi `hpn=999` ≈ 布芙 5 倍；Bufu `hpn=999` 生效；Normal `ExpRate=100.0` 生效
- ❌ 变长字段（string / TArray）暂不支持

---

## 2. 已验证 DataTable

| Asset | rowSize | headerSize | rowCount | fileSize | 验证来源 |
|---|---:|---:|---:|---:|---|
| `DatSkillNormalDataAsset` | 769 | 1174 | 700 | 539,474 | AgiMod PoC + 人工实测 ✅ |
| `DatSkillDataAsset` | 86 | 694 | 1025 | 88,844 | `AllInherit` 参考 mod |
| `DatPersonaDataAsset` | 402 | 814 | 464 | 187,342 | CUE4Parse 回归 |
| `DatPersonaGrowthDataAsset` | 2498 | 830 | 464 | 1,159,902 | CUE4Parse 回归 |
| `DatEnemyDataAsset` | 1336 | 826 | 601 | 804,022 | CUE4Parse 回归 |
| `DT_BtlDIfficultyParam` | 306/行 | 1470 | 5 | 2,983 | `arkemultiplier` 参考 mod ✅ |
| `DatPlayerLevelupDataAsset` | 37 | 702 | 99 | 4,365 | CUE4Parse 回归 |

---

## 3. 手工路径（备用 / 调试 / 新表第一次验证）

```powershell
# Step 1: 复制原件到部署目录
$src = 'Extracted\IoStore\P3R\Content\Xrd777\Battle\Tables\DatSkillNormalDataAsset.uasset'
$dst = 'tools\Reloaded II\Mods\AgiMod\UnrealEssentials\P3R\Content\Xrd777\Battle\Tables\DatSkillNormalDataAsset.uasset'
Copy-Item $src $dst -Force

# Step 2: 计算 byte offset — field_fileOffset = headerSize + (rowIndex × rowSize) + fieldOffsetInRow
# AgiMod 实例：hpn @ fileOffset = 1174 + (10 × 769) + 458 = 9322 = 0x246A

# Step 3: 写字节（PowerShell）
$bytes = [System.IO.File]::ReadAllBytes($dst)
[BitConverter]::GetBytes([uint16]999).CopyTo($bytes, 0x246A)
[System.IO.File]::WriteAllBytes($dst, $bytes)

# Step 4: 验证 — magic="00 00 00 00" / size=原件大小 / 无 .uexp / hpn @ 0x246A = 999
```

---

## 4. 字段语义陷阱

| 陷阱 | 处理 | 参考 |
|---|---|---|
| `hpn` 是显示伤害的平方 | N 倍伤害 → `newHpn = oldHpn × N²`（`hpn=999` ≈ 5 倍） | [P-009](MODDING_PITFALLS.md#p-009) |
| 数组下标 == ID | `Data[0]` 是引擎占位行，Agi 在 `Data[10]` | [P-001](MODDING_PITFALLS.md#p-001) |
| 字段名带 GUID 后缀（DT_* 表） | 010 模板友好名即可，DSL/Invoke-ZenPatch 自动匹配 | [P-006](MODDING_PITFALLS.md#p-006) |
| 真实字段名 lowercase 短名 | `hpn` 不是 `Power`，`cost` 不是 `SPCost` | [P-004](MODDING_PITFALLS.md#p-004) |
| union 字段直接改可能崩溃 | 见 §5.3 union 说明 | [P-010](MODDING_PITFALLS.md#p-010) |

---

## 5. 已知限制

| 限制 | 影响 |
|---|---|
| 无已验证 010 schema 的表 | 不能自动 patch；需先补 schema、校准 header、跑 regression |
| PARTIAL/FAIL/SKIP schema | 首次使用前需人工核查或修复 |
| union / struct-with-union | 直接 byte-patch 可能崩溃（[P-010](MODDING_PITFALLS.md#p-010)），见 §5.3 |
| nested struct array target | 当前不支持 `Data[N].arr[M].field` 语法 |
| 变长字段 | string/TArray 不能改长度，见 §5.4 |
| 跨版本 | P3R 大更新后须重新校准 `headerSize`，旧 patch 可能作废 |

> 当前 schema 回归口径：`19 PASS / 9 PARTIAL / 2 FAIL / 4 SKIP`（34 个 schema）。详细 allow/deny 数据见 [SCHEMA_COVERAGE_REPORT.md](SCHEMA_COVERAGE_REPORT.md) 与 `tools/templates-010/schemas/schema-safety-coverage.json`。

### 5.1 未解析模板

| 模板 | 原因 | 影响 |
|---|---|---|
| `p3re_combineBirth.bt` | literal-zero stub | 可跳过 |
| `p3re_datitemskillcarddataasset.bt` | 模板体为空；同资产可用 `p3re_itemSkillCard.bt` 覆盖 | 影响小 |
| `p3re_HeroParameterDataAsset.bt` | 多 section flat layout，需新增 tableShape | 影响勇气/魅力/学力参数 |

### 5.2 PARTIAL / FAIL / SKIP schema

**9 个 PARTIAL**（已写入 `disposition` / `guardPolicy` / `fieldReviewStatus` 元数据供 guard 使用）：

| schema | 回归 | 核查结论 |
|---|---|---|
| `p3re_specialspreaddataasset` / `p3re_specialSpread` | 9/12 | `.bt` 有 `sourceID`~`sourceID6` 同名，JSON 折叠为单个 `SourceID`；标记人工 |
| `p3re_datencounttabledataasset` / `p3re_encountTable` | 29/32 | 仅 `shuffleLevel` mismatch，标记人工 |
| `p3re_datenemydataasset` / `p3re_enemy` | 34/36 | `.bt` 有 `skill`~`skill8`，JSON 几乎全 `skill=0`；**不要自动写 `skill*`** |
| `p3re_enemyAffinity` | 3/4 | `.bt` 有 19 个 `attr` 槽，JSON 只暴露单个 `attr`；敌人耐性改写需先确认 19 槽映射 |
| `p3re_enemyAnalyzeSync` | 1/4 | `.bt` 有 `enemyID`~`enemyID10`，JSON 折叠为单个 `enemyID`；逐槽核查后再开放 |
| `p3re_DatItemShopLineupDataAsset` | 0/8 | header/tableShape/字段名均不可靠，需专门修 parser/schema |

> 已从 PARTIAL 移出：`p3re_skill` / `p3re_datskilldataasset`（1-byte enum sentinel 255 vs -1 归一化 → PASS，`disposition=safeWithNormalization`）。

**2 个 FAIL**：`p3re_skillPack` / `p3re_itemSkillCard`（`No fields checked`——需修复 `Test-SchemaRegression.ps1` 对 `single_record`/nested struct 字段展开）。

**4 个 SKIP**：`p3re_calcPANICUseItem` / `p3re_calcPANICDropItem`（no CUE4Parse JSON）、`p3re_DT_BtlDIfficultyParam`（named_rows，no CUE4Parse JSON）、`p3re_supportInfoNavi`（schema 未校准）。

### 5.3 union 与 nested struct array

`DatPersonaGrowthDataAsset` 的 `SkillEventStruct`（`union { SkillList skillid; ItemList itemid; }`）操作已确认崩溃案例：直接写 `skillId=20` + `level=99` 后 `ObjectSerializationError: Bad name index 25353/21`。根因：只改 value 不改 discriminator，反序列化按错误类型解释。当前 guard 规则禁止自动写 union/nested field。

### 5.4 string / TArray / 变长字段

Zen byte-patch 核心断言 `output size == original size`，只适合定长标量。不支持：string、TArray、增删 row、改 NameMap/ImportMap/ExportMap、改对象引用结构、union 语义结构。这类需求判为 `unsupported` / `requiresManualResearch`。

---

## 6. 与其它文档的关系

| 文档 | 关系 |
|---|---|
| [CLAUDE.md 快速开始](../CLAUDE.md#快速路径mod-dsl推荐sprint-15) | **推荐入口** |
| [README.md §4.5](../README.md#45-dsl-函数速查) | DSL 函数速查表 |
| [SECURITY.md](SECURITY.md) | 安全协议：备份、回滚预览、冲突分级、审计、紧急恢复 |
| [SCHEMA_COVERAGE_REPORT.md](SCHEMA_COVERAGE_REPORT.md) | schema 安全覆盖与 allow/deny 边界 |
| [MODDING_PITFALLS.md](MODDING_PITFALLS.md) | P-001~P-010 确认坑点；写脚本前必读 |
