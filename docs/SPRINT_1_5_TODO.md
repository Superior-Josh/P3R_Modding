# Sprint 1.5 剩余待办 / 限制清单

> **状态日期**: 2026-06-24  
> **定位**: Sprint 1.5 已完成主线交付（Zen byte-patch → DSL → pipeline → AgiMod / BufuMod / 100× ExpMod 人工验证）。本文只记录**未纳入完成定义**的剩余限制，供 Sprint 2+ 安全 guard、自然语言 Agent 能力边界和后续修复排期使用。

## 总览

| # | 项目 | 当前状态 | 处理建议 |
|---:|---|---|---|
| 1 | 3 个 010 模板未解析 | 先搁置 | 不阻塞数值类主路径，按需求再补 |
| 2 | 12 个 schema 回归 PARTIAL | 需人工核查 | 首次使用前逐字段核对 offset / signedness / JSON 映射 |
| 3 | 2 个 schema 回归 FAIL | 待修复 | 修复 schema / 回归框架后再开放给 DSL |
| 4 | 6 个 schema SKIP | 待修复 | 补 JSON / 补资产 / 处理 deprecated duplicate 标记 |
| 5 | union / struct-with-union 不能直接 byte-patch | 待修复 | 需要逆向 discriminator 或改走完整序列化 |
| 6 | struct array 子字段 target 语法不支持 | 待修复 | 扩展 `Invoke-ZenPatch.ps1` target parser |
| 7 | string / TArray / 变长字段不能改 | 待实现 | 需要完整资产重写或固定容量策略 |

---

## 1. 3 个 010 模板未解析

**状态**: 先搁置

当前解析覆盖率：`38 / 41 templates parsed`。

| 模板 | 原因 | 影响 |
|---|---|---|
| `p3re_combineBirth.bt` | literal-zero stub | 可跳过 |
| `p3re_datitemskillcarddataasset.bt` | 模板体为空；同资产可用 `p3re_itemSkillCard.bt` 覆盖 | 影响小 |
| `p3re_HeroParameterDataAsset.bt` | 多 section flat layout，需要新增 tableShape | 影响勇气/魅力/学力参数 |

**处理建议**: 不进入 Sprint 2 blocker。等出现明确需求（例如“改勇气/魅力/学力参数”）时，再为 `HeroParameterDataAsset` 增加新的 tableShape。

---

## 2. 12 个 schema 回归 PARTIAL

**状态**: 需人工核查

这些 schema 有部分字段和 CUE4Parse JSON 对不上。它们不一定错误，但首次用于写回前必须逐字段核查。

| schema | 回归情况 | 主要风险 |
|---|---:|---|
| `p3re_specialSpread_schema.json` | 9/12 | `sourceID` 等字段 mismatch |
| `p3re_specialspreaddataasset_schema.json` | 9/12 | `sourceID` 等字段 mismatch |
| `p3re_skill_schema.json` | 10/12 | enum signedness / JSON 展示差异（如 `255` vs `-1`） |
| `p3re_datskilldataasset_schema.json` | 10/12 | 同上 |
| `p3re_datpersonadataasset_schema.json` | 12/32 | 多字段 mismatch，疑似 duplicate / layout 不可靠 |
| `p3re_datencounttabledataasset_schema.json` | 29/32 | `shuffleLevel` mismatch |
| `p3re_encountTable_schema.json` | 29/32 | `shuffleLevel` mismatch |
| `p3re_datenemydataasset_schema.json` | 34/36 | 部分 `skill` 字段 mismatch |
| `p3re_enemy_schema.json` | 34/36 | 部分 `skill` 字段 mismatch |
| `p3re_enemyAffinity_schema.json` | 3/4 | `attr` mismatch |
| `p3re_enemyAnalyzeSync_schema.json` | 1/4 | `enemyID` mismatch |
| `p3re_DatItemShopLineupDataAsset_schema.json` | 0/8 | mismatch 多，不应直接开放 |

**处理建议**:

1. 保持 schema 可存在，但不要把这些表标为“自动安全可改”。
2. Sprint 2 guard 中应把 PARTIAL schema 标记为 `needsManualReview`。
3. 如果用户明确要改这些表，先做单字段 offset 复核：
   - 对照 010 模板
   - 对照 CUE4Parse JSON
   - 对照原始 Zen bytes
   - 必要时做只改 1 字段的 in-game smoke test

---

## 3. 2 个 schema 回归 FAIL

**状态**: 待修复

| schema | 当前问题 |
|---|---|
| `p3re_skillPack_schema.json` | No fields checked |
| `p3re_itemSkillCard_schema.json` | No fields checked |

**处理建议**:

- 修复 `Test-SchemaRegression.ps1` 对 `single_record` / nested struct 的字段展开逻辑。
- 如果是 schema layout 不完整，则回到 `.bt` 模板解析阶段补 nested field flattening。
- 修复前不要开放 DSL helper。

---

## 4. 6 个 schema SKIP

**状态**: 待修复

| schema | SKIP 原因 | 处理方向 |
|---|---|---|
| `p3re_calcPANICUseItem_schema.json` | no CUE4Parse JSON available | 补导 JSON 或标记为无法回归 |
| `p3re_calcPANICDropItem_schema.json` | no CUE4Parse JSON available | 补导 JSON 或标记为无法回归 |
| `p3re_supportInfoNavi_schema.json` | schema not calibrated / asset not found | 补资产路径或确认未提取原因 |
| `p3re_datbtltheurgiaboostdataasset_schema.json` | deprecated dat-* duplicate | 保持 skip，canonical sibling 覆盖 |
| `p3re_datpersonagrowthdataasset_schema.json` | deprecated dat-* duplicate | 保持 skip，canonical sibling 覆盖 |
| `p3re_datallypersonagrowthdataasset_schema.json` | deprecated dat-* duplicate | 保持 skip，canonical sibling 覆盖 |

**处理建议**:

- no JSON：补导 JSON 后重新跑 regression。
- not_found：确认 `Extracted/IoStore/` 是否缺资产，或 schema 的 `sourceAssetPath` 是否错误。
- deprecated duplicates：保留 skip，但在 schema resolver 中继续优先 canonical `p3re_*` 非 `p3re_dat*` 文件。

---

## 5. union / struct-with-union 不能直接 byte-patch

**状态**: 待修复

已知失败案例：`DatPersonaGrowthDataAsset` 的 `SkillEventStruct`。

```c
typedef struct {
    ubyte level;
    union {
        SkillList skillid;
        ItemList  itemid;
    } data;
} SkillEventStruct;
```

真实测试：OrpheusGrowthMod 直接写 `skillId=20 (Bufu)` + `level=99` 后，游戏崩溃：

```text
ObjectSerializationError: DatPersonaGrowthDataAsset - Bad name index 25353/21
```

**根因**: union 字段除了 value 之外，还依赖 UE 序列化上下文里的类型判别信息。只改 value，不改 discriminator，反序列化会按错误类型解释。

**处理方向**:

1. 逆向 union discriminator 位置并同时 patch discriminator + value。
2. 或实现完整资产重写，不再依赖 in-place byte-patch。
3. 在 guard 中禁止对 `union` 字段自动写回。

---

## 6. struct array 子字段 target 语法不支持

**状态**: 待修复

当前 `Invoke-ZenPatch.ps1` 支持：

```text
Data[N].field
Rows.Normal.ExpRate
Record[N].field
bareField
```

暂不支持：

```text
Data[N].skillEvent[slot].skillId
Data[N].structArr[slot].subField
```

**影响**:

- PersonaGrowth 学技能槽无法通过正式 target 语法表达。
- 即使手算 offset，也会遇到 P-010 union 风险。

**处理方向**:

- 扩展 schema field model，表达 nested struct / fixed array element。
- 扩展 target parser：`Data[N].field[M].subField`。
- 扩展 regression：nested sub-field 能和 JSON / raw bytes 对比。
- 对含 union 的 nested field 仍必须 guard 禁止或进入专门修复流程。

---

## 7. string / TArray / 变长字段不能改

**状态**: 待实现

Zen byte-patch 的核心断言是：

```text
output file size == original file size
```

因此当前只适合定长标量：

- `ubyte` / `byte`
- `ushort` / `short`
- `uint` / `int`
- `float`
- enum 底层整数
- 固定 offset 的 flat scalar

暂不支持：

- string
- TArray 变长数组
- 增删 row
- 改 NameMap / ImportMap / ExportMap
- 改对象引用结构
- 改 union 语义结构

**处理方向**:

1. 实现完整 UE Zen asset writer / serializer。
2. 或设计“固定容量内替换”策略，仅允许不改变长度的字符串/数组内容。
3. 在自然语言 Agent 中将此类需求判为 `unsupported` 或 `requiresManualResearch`。

---

## Sprint 2 guard 建议

自然语言 Agent 在生成 patch 前，应根据 schema 状态做拦截：

| schema/字段状态 | Agent 行为 |
|---|---|
| PASS + flat scalar | 允许自动生成 |
| PARTIAL | 要求人工确认或先跑 offset 复核 |
| FAIL / SKIP | 默认拒绝自动写回，提示待修复 |
| contains union | 默认拒绝自动写回，引用 P-010 |
| nested struct array | 默认拒绝自动写回，提示 target parser 待扩展 |
| string / TArray / 变长 | 默认拒绝自动写回，提示完整写回器待实现 |
