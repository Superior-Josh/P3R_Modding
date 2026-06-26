# 010 Schema Coverage and Safety Field Report

> Generated: 2026-06-26 13:55:05  
> Source: `tools/templates-010/schemas/*_schema.json` plus existing regression metadata.  
> Policy: only `regressionStatus=pass` / `safeWithNormalization` flat scalar fields enter the automatic allowlist. PARTIAL schemas remain manual-review by default.

## Summary

| Metric | Count |
|---|---:|
| Schemas | 34 |
| fail schemas | 2 |
| partial schemas | 9 |
| pass schemas | 20 |
| skip schemas | 3 |
| Auto-safe target patterns | 213 |
| Blocked/manual target patterns | 354 |

## Schema Status

| Schema | Shape | Regression | Pass% | Auto-safe fields | Blocked/manual fields | Policy | Reason |
|---|---|---:|---:|---:|---:|---|---|
| `p3re_itemSkillCard` | single_record | fail | 0 | 0 | 23 |  | No fields checked |
| `p3re_skillPack` | single_record | fail | 0 | 0 | 10 |  | No fields checked |
| `p3re_datencounttabledataasset` | indexed_rows | partial | 90.6 | 0 | 12 | fieldLevelReview | exception: Cannot process argument transformation on parameter 'EnumSizes'. Cannot convert value "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" to type "System.Collections.Hashtable". Error: "Cannot convert the "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" value of type "System.Management.Automation.PSCustomObject" to type "System.Collections.Hashtable"." |
| `p3re_datenemydataasset` | indexed_rows | partial | 94.4 | 0 | 29 | manualOnlyForSkillSlots | exception: Cannot process argument transformation on parameter 'EnumSizes'. Cannot convert value "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" to type "System.Collections.Hashtable". Error: "Cannot convert the "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" value of type "System.Management.Automation.PSCustomObject" to type "System.Collections.Hashtable"." |
| `p3re_DatItemShopLineupDataAsset` | indexed_rows | partial | 0 | 0 | 4 | blockUntilSchemaFix | exception: Unsupported type: u32 |
| `p3re_encountTable` | indexed_rows | partial | 90.6 | 0 | 12 | fieldLevelReview | exception: Cannot process argument transformation on parameter 'EnumSizes'. Cannot convert value "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" to type "System.Collections.Hashtable". Error: "Cannot convert the "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" value of type "System.Management.Automation.PSCustomObject" to type "System.Collections.Hashtable"." |
| `p3re_enemy` | indexed_rows | partial | 94.4 | 0 | 29 | manualOnlyForSkillSlots | exception: Cannot process argument transformation on parameter 'EnumSizes'. Cannot convert value "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" to type "System.Collections.Hashtable". Error: "Cannot convert the "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" value of type "System.Management.Automation.PSCustomObject" to type "System.Collections.Hashtable"." |
| `p3re_enemyAffinity` | indexed_rows | partial | 75 | 0 | 19 | manualOnly | exception: Cannot process argument transformation on parameter 'EnumSizes'. Cannot convert value "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" to type "System.Collections.Hashtable". Error: "Cannot convert the "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" value of type "System.Management.Automation.PSCustomObject" to type "System.Collections.Hashtable"." |
| `p3re_enemyAnalyzeSync` | indexed_rows | partial | 25 | 0 | 10 | manualOnly | exception: Cannot process argument transformation on parameter 'EnumSizes'. Cannot convert value "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" to type "System.Collections.Hashtable". Error: "Cannot convert the "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" value of type "System.Management.Automation.PSCustomObject" to type "System.Collections.Hashtable"." |
| `p3re_specialSpread` | indexed_rows | partial | 75 | 0 | 8 | manualOnly | exception: Cannot process argument transformation on parameter 'EnumSizes'. Cannot convert value "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" to type "System.Collections.Hashtable". Error: "Cannot convert the "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" value of type "System.Management.Automation.PSCustomObject" to type "System.Collections.Hashtable"." |
| `p3re_specialspreaddataasset` | indexed_rows | partial | 75 | 0 | 8 | manualOnly | exception: Cannot process argument transformation on parameter 'EnumSizes'. Cannot convert value "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" to type "System.Collections.Hashtable". Error: "Cannot convert the "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" value of type "System.Management.Automation.PSCustomObject" to type "System.Collections.Hashtable"." |
| `p3re_allyPersonaGrowth` | indexed_rows | pass | 100 | 2 | 3 |  | exception: Cannot process argument transformation on parameter 'EnumSizes'. Cannot convert value "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" to type "System.Collections.Hashtable". Error: "Cannot convert the "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" value of type "System.Management.Automation.PSCustomObject" to type "System.Collections.Hashtable"." |
| `p3re_btlMixRaidRelease` | indexed_rows | pass | 100 | 4 | 0 |  | exception: Cannot process argument transformation on parameter 'EnumSizes'. Cannot convert value "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" to type "System.Collections.Hashtable". Error: "Cannot convert the "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" value of type "System.Management.Automation.PSCustomObject" to type "System.Collections.Hashtable"." |
| `p3re_btlTheurgiaBoost` | single_record_array | pass | 100 | 10 | 0 |  |  |
| `p3re_btlTheurgiaBoost_astrea` | single_record_array | pass | 100 | 12 | 0 |  |  |
| `p3re_combineMisc` | single_record | pass | 100 | 6 | 2 |  |  |
| `p3re_combinemiscdataasset` | single_record | pass | 100 | 6 | 2 |  |  |
| `p3re_datbtlmixraidreleasedataasset` | indexed_rows | pass | 100 | 4 | 0 |  | exception: Cannot process argument transformation on parameter 'EnumSizes'. Cannot convert value "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" to type "System.Collections.Hashtable". Error: "Cannot convert the "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" value of type "System.Management.Automation.PSCustomObject" to type "System.Collections.Hashtable"." |
| `p3re_datpersonaaffinitydataasset` | indexed_rows | pass | 100 | 19 | 0 |  | exception: Cannot process argument transformation on parameter 'EnumSizes'. Cannot convert value "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" to type "System.Collections.Hashtable". Error: "Cannot convert the "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" value of type "System.Management.Automation.PSCustomObject" to type "System.Collections.Hashtable"." |
| `p3re_datskilldataasset` | indexed_rows | pass | 100 | 3 | 0 | allowAfterSignedByteSentinelNormalization | exception: Cannot process argument transformation on parameter 'EnumSizes'. Cannot convert value "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" to type "System.Collections.Hashtable". Error: "Cannot convert the "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" value of type "System.Management.Automation.PSCustomObject" to type "System.Collections.Hashtable"." |
| `p3re_datskillnormaldataasset` | indexed_rows | pass | 100 | 22 | 72 |  | exception: Cannot process argument transformation on parameter 'EnumSizes'. Cannot convert value "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" to type "System.Collections.Hashtable". Error: "Cannot convert the "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" value of type "System.Management.Automation.PSCustomObject" to type "System.Collections.Hashtable"." |
| `p3re_DT_BtlDIfficultyParam` | named_rows | pass | 100 | 50 | 0 |  |  |
| `p3re_encountEnemyBadPercent` | indexed_rows | pass | 100 | 5 | 0 |  |  |
| `p3re_persona` | indexed_rows | pass | 100 | 12 | 0 |  | exception: Cannot process argument transformation on parameter 'EnumSizes'. Cannot convert value "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" to type "System.Collections.Hashtable". Error: "Cannot convert the "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" value of type "System.Management.Automation.PSCustomObject" to type "System.Collections.Hashtable"." |
| `p3re_personaAffinity` | indexed_rows | pass | 100 | 19 | 0 |  | exception: Cannot process argument transformation on parameter 'EnumSizes'. Cannot convert value "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" to type "System.Collections.Hashtable". Error: "Cannot convert the "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" value of type "System.Management.Automation.PSCustomObject" to type "System.Collections.Hashtable"." |
| `p3re_personaGrowth` | indexed_rows | pass | 100 | 5 | 1 |  | exception: Cannot process argument transformation on parameter 'EnumSizes'. Cannot convert value "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" to type "System.Collections.Hashtable". Error: "Cannot convert the "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" value of type "System.Management.Automation.PSCustomObject" to type "System.Collections.Hashtable"." |
| `p3re_playerLevelup` | indexed_rows | pass | 100 | 1 | 0 |  |  |
| `p3re_skill` | indexed_rows | pass | 100 | 3 | 0 | allowAfterSignedByteSentinelNormalization | exception: Cannot process argument transformation on parameter 'EnumSizes'. Cannot convert value "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" to type "System.Collections.Hashtable". Error: "Cannot convert the "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" value of type "System.Management.Automation.PSCustomObject" to type "System.Collections.Hashtable"." |
| `p3re_skillLimit` | indexed_rows | pass | 100 | 2 | 0 |  |  |
| `p3re_skillNormal` | indexed_rows | pass | 100 | 21 | 99 |  | exception: Cannot process argument transformation on parameter 'EnumSizes'. Cannot convert value "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" to type "System.Collections.Hashtable". Error: "Cannot convert the "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" value of type "System.Management.Automation.PSCustomObject" to type "System.Collections.Hashtable"." |
| `p3re_supportInfoCommon` | indexed_rows | pass | 100 | 7 | 0 |  | exception: Cannot process argument transformation on parameter 'EnumSizes'. Cannot convert value "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" to type "System.Collections.Hashtable". Error: "Cannot convert the "@{Bool=1; ProgramEffect=1; SkillList=2; EnemyID=2; ElementalType=1; BGMID=2; CostType=1; ItemList=2; RaceID=1; SPTypeList=1; EffectType=1; AffinityStatus=2; TargetTypeList=1; SkillTargets=1; PersonaID=2; HPTypeList=1; EventIDList=2; PersonaInherit=2}" value of type "System.Management.Automation.PSCustomObject" to type "System.Collections.Hashtable"." |
| `p3re_calcPANICDropItem` | single_record | skip | - | 0 | 3 |  | no CUE4Parse JSON available for p3re_calcPANICDropItem |
| `p3re_calcPANICUseItem` | indexed_rows | skip | - | 0 | 1 |  | no CUE4Parse JSON available for p3re_calcPANICUseItem |
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
