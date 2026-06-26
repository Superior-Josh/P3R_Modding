# 010 Schema Coverage and Safety Field Report

> Generated: 2026-06-26 20:40:39  
> Source: `tools/templates-010/schemas/*_schema.json` plus existing regression metadata.  
> Policy: only `regressionStatus=pass` / `safeWithNormalization` flat scalar fields enter the automatic allowlist. PARTIAL schemas remain manual-review by default.

## Summary

| Metric | Count |
|---|---:|
| Schemas | 34 |
| fail schemas | 2 |
| partial schemas | 9 |
| pass schemas | 19 |
| skip schemas | 4 |
| Auto-safe target patterns | 163 |
| Blocked/manual target patterns | 404 |

## Schema Status

| Schema | Shape | Regression | Pass% | Auto-safe fields | Blocked/manual fields | Policy | Reason |
|---|---|---:|---:|---:|---:|---|---|
| `p3re_itemSkillCard` | single_record | fail | 0 | 0 | 23 |  | No fields checked |
| `p3re_skillPack` | single_record | fail | 0 | 0 | 10 |  | No fields checked |
| `p3re_datencounttabledataasset` | indexed_rows | partial | 90.6 | 0 | 12 | fieldLevelReview | Same encountTable shuffleLevel mismatch as p3re_encountTable. |
| `p3re_datenemydataasset` | indexed_rows | partial | 94.4 | 0 | 29 | manualOnlyForSkillSlots | Same enemy skill slot issue as p3re_enemy. |
| `p3re_DatItemShopLineupDataAsset` | indexed_rows | partial | 0 | 0 | 4 | blockUntilSchemaFix | exception: Unsupported type: u32 |
| `p3re_encountTable` | indexed_rows | partial | 90.6 | 0 | 12 | fieldLevelReview | Only shuffleLevel mismatches; other sampled fields mostly verify. |
| `p3re_enemy` | indexed_rows | partial | 94.4 | 0 | 29 | manualOnlyForSkillSlots | 010 template exposes skill..skill8, but CUE4Parse JSON usually reports skill=0 and cannot represent actual enemy skill slots. |
| `p3re_enemyAffinity` | indexed_rows | partial | 75 | 0 | 19 | manualOnly | 010 template exposes 19 AffinityStatus slots; CUE4Parse JSON exposes one attr key, likely folding slot/bit semantics. |
| `p3re_enemyAnalyzeSync` | indexed_rows | partial | 25 | 0 | 10 | manualOnly | 010 template exposes enemyID..enemyID10 with the same display name; CUE4Parse JSON folds them into one enemyID key. |
| `p3re_specialSpread` | indexed_rows | partial | 75 | 0 | 8 | manualOnly | 010 template exposes sourceID..sourceID6 with the same display name SourceID; CUE4Parse JSON folds them into one SourceID key. |
| `p3re_specialspreaddataasset` | indexed_rows | partial | 75 | 0 | 8 | manualOnly | Same SpecialSpread sourceID slot folding as p3re_specialSpread. |
| `p3re_allyPersonaGrowth` | indexed_rows | pass | 100 | 2 | 3 |  |  |
| `p3re_btlMixRaidRelease` | indexed_rows | pass | 100 | 4 | 0 |  |  |
| `p3re_btlTheurgiaBoost` | single_record_array | pass | 100 | 10 | 0 |  |  |
| `p3re_btlTheurgiaBoost_astrea` | single_record_array | pass | 100 | 12 | 0 |  |  |
| `p3re_combineMisc` | single_record | pass | 100 | 6 | 2 |  |  |
| `p3re_combinemiscdataasset` | single_record | pass | 100 | 6 | 2 |  |  |
| `p3re_datbtlmixraidreleasedataasset` | indexed_rows | pass | 100 | 4 | 0 |  |  |
| `p3re_datpersonaaffinitydataasset` | indexed_rows | pass | 100 | 19 | 0 |  |  |
| `p3re_datskilldataasset` | indexed_rows | pass | 100 | 3 | 0 | allowAfterSignedByteSentinelNormalization | Duplicate spelling of p3re_skill; same 1-byte enum sentinel normalization applies. |
| `p3re_datskillnormaldataasset` | indexed_rows | pass | 100 | 22 | 72 |  |  |
| `p3re_encountEnemyBadPercent` | indexed_rows | pass | 100 | 5 | 0 |  |  |
| `p3re_persona` | indexed_rows | pass | 100 | 12 | 0 |  |  |
| `p3re_personaAffinity` | indexed_rows | pass | 100 | 19 | 0 |  |  |
| `p3re_personaGrowth` | indexed_rows | pass | 100 | 5 | 1 |  |  |
| `p3re_playerLevelup` | indexed_rows | pass | 100 | 1 | 0 |  |  |
| `p3re_skill` | indexed_rows | pass | 100 | 3 | 0 | allowAfterSignedByteSentinelNormalization | 1-byte enum sentinel: CUE4Parse displays raw 0xFF as -1 for attr. |
| `p3re_skillLimit` | indexed_rows | pass | 100 | 2 | 0 |  |  |
| `p3re_skillNormal` | indexed_rows | pass | 100 | 21 | 99 |  |  |
| `p3re_supportInfoCommon` | indexed_rows | pass | 100 | 7 | 0 |  |  |
| `p3re_calcPANICDropItem` | single_record | skip | - | 0 | 3 |  | no CUE4Parse JSON available for p3re_calcPANICDropItem |
| `p3re_calcPANICUseItem` | indexed_rows | skip | - | 0 | 1 |  | no CUE4Parse JSON available for p3re_calcPANICUseItem |
| `p3re_DT_BtlDIfficultyParam` | named_rows | skip | 100 | 0 | 50 |  | no CUE4Parse JSON available for p3re_DT_BtlDIfficultyParam |
| `p3re_supportInfoNavi` | indexed_rows | skip | - | 0 | 7 |  | schema not calibrated (status=not_found) |

## Automatic Allowlist Excerpt

Full JSON: `tools/templates-010/schemas/schema-safety-coverage.json`.

| Schema | Target pattern | Type | Size |
|---|---|---|---:|
| `p3re_allyPersonaGrowth` | `Data[N].playerId` | ubyte | 1 |
| `p3re_allyPersonaGrowth` | `Data[N].levelMax` | ubyte | 1 |
| `p3re_btlMixRaidRelease` | `Data[N].personaAID` | PersonaID | 2 |
| `p3re_btlMixRaidRelease` | `Data[N].personaBID` | PersonaID | 2 |
| `p3re_btlMixRaidRelease` | `Data[N].flag` | uint | 4 |
| `p3re_btlMixRaidRelease` | `Data[N].skill` | ushort | 2 |
| `p3re_btlTheurgiaBoost_astrea` | `Record[N].value` | ushort | 2 |
| `p3re_btlTheurgiaBoost_astrea` | `Record[N].value2` | ushort | 2 |
| `p3re_btlTheurgiaBoost_astrea` | `Record[N].value3` | ushort | 2 |
| `p3re_btlTheurgiaBoost_astrea` | `Record[N].value4` | ushort | 2 |
| `p3re_btlTheurgiaBoost_astrea` | `Record[N].value5` | ushort | 2 |
| `p3re_btlTheurgiaBoost_astrea` | `Record[N].value6` | ushort | 2 |
| `p3re_btlTheurgiaBoost_astrea` | `Record[N].value7` | ushort | 2 |
| `p3re_btlTheurgiaBoost_astrea` | `Record[N].value8` | ushort | 2 |
| `p3re_btlTheurgiaBoost_astrea` | `Record[N].value9` | ushort | 2 |
| `p3re_btlTheurgiaBoost_astrea` | `Record[N].value10` | ushort | 2 |
| `p3re_btlTheurgiaBoost_astrea` | `Record[N].value11` | ushort | 2 |
| `p3re_btlTheurgiaBoost_astrea` | `Record[N].value12` | ushort | 2 |
| `p3re_btlTheurgiaBoost` | `Record[N].value` | ushort | 2 |
| `p3re_btlTheurgiaBoost` | `Record[N].value2` | ushort | 2 |
| `p3re_btlTheurgiaBoost` | `Record[N].value3` | ushort | 2 |
| `p3re_btlTheurgiaBoost` | `Record[N].value4` | ushort | 2 |
| `p3re_btlTheurgiaBoost` | `Record[N].value5` | ushort | 2 |
| `p3re_btlTheurgiaBoost` | `Record[N].value6` | ushort | 2 |
| `p3re_btlTheurgiaBoost` | `Record[N].value7` | ushort | 2 |
| `p3re_btlTheurgiaBoost` | `Record[N].value8` | ushort | 2 |
| `p3re_btlTheurgiaBoost` | `Record[N].value9` | ushort | 2 |
| `p3re_btlTheurgiaBoost` | `Record[N].value10` | ushort | 2 |
| `p3re_combineMisc` | `accidentBaseRate` | float | 4 |
| `p3re_combineMisc` | `foolAccidentRate` | float | 4 |
| `p3re_combineMisc` | `accidentMinLv` | short | 2 |
| `p3re_combineMisc` | `accidentMaxLv` | ushort | 2 |
| `p3re_combineMisc` | `skillChangeBaseRate` | float | 4 |
| `p3re_combineMisc` | `skillBuildUpRate` | float | 4 |
| `p3re_combinemiscdataasset` | `accidentBaseRate` | float | 4 |
| `p3re_combinemiscdataasset` | `foolAccidentRate` | float | 4 |
| `p3re_combinemiscdataasset` | `accidentMinLv` | short | 2 |
| `p3re_combinemiscdataasset` | `accidentMaxLv` | ushort | 2 |
| `p3re_combinemiscdataasset` | `skillChangeBaseRate` | float | 4 |
| `p3re_combinemiscdataasset` | `skillBuildUpRate` | float | 4 |
| `p3re_datbtlmixraidreleasedataasset` | `Data[N].personaAID` | PersonaID | 2 |
| `p3re_datbtlmixraidreleasedataasset` | `Data[N].personaBID` | PersonaID | 2 |
| `p3re_datbtlmixraidreleasedataasset` | `Data[N].flag` | uint | 4 |
| `p3re_datbtlmixraidreleasedataasset` | `Data[N].skill` | ushort | 2 |
| `p3re_datpersonaaffinitydataasset` | `Data[N].attr` | AffinityStatus | 2 |
| `p3re_datpersonaaffinitydataasset` | `Data[N].attr2` | AffinityStatus | 2 |
| `p3re_datpersonaaffinitydataasset` | `Data[N].attr3` | AffinityStatus | 2 |
| `p3re_datpersonaaffinitydataasset` | `Data[N].attr4` | AffinityStatus | 2 |
| `p3re_datpersonaaffinitydataasset` | `Data[N].attr5` | AffinityStatus | 2 |
| `p3re_datpersonaaffinitydataasset` | `Data[N].attr6` | AffinityStatus | 2 |
| `p3re_datpersonaaffinitydataasset` | `Data[N].attr7` | AffinityStatus | 2 |
| `p3re_datpersonaaffinitydataasset` | `Data[N].attr8` | AffinityStatus | 2 |
| `p3re_datpersonaaffinitydataasset` | `Data[N].attr9` | AffinityStatus | 2 |
| `p3re_datpersonaaffinitydataasset` | `Data[N].attr10` | AffinityStatus | 2 |
| `p3re_datpersonaaffinitydataasset` | `Data[N].attr11` | AffinityStatus | 2 |
| `p3re_datpersonaaffinitydataasset` | `Data[N].attr12` | AffinityStatus | 2 |
| `p3re_datpersonaaffinitydataasset` | `Data[N].attr13` | AffinityStatus | 2 |
| `p3re_datpersonaaffinitydataasset` | `Data[N].attr14` | AffinityStatus | 2 |
| `p3re_datpersonaaffinitydataasset` | `Data[N].attr15` | AffinityStatus | 2 |
| `p3re_datpersonaaffinitydataasset` | `Data[N].attr16` | AffinityStatus | 2 |
| `p3re_datpersonaaffinitydataasset` | `Data[N].attr17` | AffinityStatus | 2 |
| `p3re_datpersonaaffinitydataasset` | `Data[N].attr18` | AffinityStatus | 2 |
| `p3re_datpersonaaffinitydataasset` | `Data[N].attr19` | AffinityStatus | 2 |
| `p3re_datskilldataasset` | `Data[N].attr` | ElementalType | 1 |
| `p3re_datskilldataasset` | `Data[N].type` | ubyte | 1 |
| `p3re_datskilldataasset` | `Data[N].targetLv` | ubyte | 1 |
| `p3re_datskillnormaldataasset` | `Data[N].use` | ubyte | 1 |
| `p3re_datskillnormaldataasset` | `Data[N].koukatype` | ubyte | 1 |
| `p3re_datskillnormaldataasset` | `Data[N].costtype` | CostType | 1 |
| `p3re_datskillnormaldataasset` | `Data[N].cost` | ubyte | 1 |
| `p3re_datskillnormaldataasset` | `Data[N].costbase` | ubyte | 1 |
| `p3re_datskillnormaldataasset` | `Data[N].targettype` | TargetTypeList | 1 |
| `p3re_datskillnormaldataasset` | `Data[N].targetarea` | SkillTargets | 1 |
| `p3re_datskillnormaldataasset` | `Data[N].targetrule` | ubyte | 1 |
| `p3re_datskillnormaldataasset` | `Data[N].untargetbadstat` | uint | 4 |
| `p3re_datskillnormaldataasset` | `Data[N].hitratio` | ubyte | 1 |
| `p3re_datskillnormaldataasset` | `Data[N].targetcntmin` | ubyte | 1 |
| `p3re_datskillnormaldataasset` | `Data[N].targetcntmax` | ubyte | 1 |
| `p3re_datskillnormaldataasset` | `Data[N].hptype` | HPTypeList | 1 |
| `p3re_datskillnormaldataasset` | `Data[N].hpn` | ushort | 2 |
| ... | ... | ... | ... |

## Manual Review / Denylist Rules

- `partial` schemas are not automatically allowed, even when a field looks scalar; manually verify offsets or improve regression metadata first.
- `fail` / `skip` / `deprecatedDuplicate` / `unsupportedUntilSchemaFix` block automatic writes.
- `kind != scalar`, `string`, `TArray`, `struct`, `union`, and non 1/2/4/8-byte fields block automatic writes.
- Fields with `fieldReviewStatus.status=needsManualReview` require manual review.

## Deferred Manual Items

See `docs/MANUAL_TEST_TODO.md` MT-104 / MT-105. This report is static coverage analysis and does not replace in-game validation.
