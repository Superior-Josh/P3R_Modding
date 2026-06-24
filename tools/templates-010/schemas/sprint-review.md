# Sprint 1.5 Review Report

> **Date**: 2026-06-24 | **Status**: ✅ COMPLETE — all T1.5 tasks and manual E2E verification passed | **Review Task**: T1.5.10

## Deliverable Audit

| Task | Deliverable | Status |
|------|-------------|--------|
| T1.5.1 | `tools/templates-010/` — 41 `.bt` templates + `_enums` + `_structs` | ✅ |
| T1.5.2 | `Parse-BtTemplate.ps1` + 38 schema JSONs | ✅ |
| T1.5.3 | `Calibrate-SchemaHeaders.ps1` + calibration-report.md | ✅ |
| T1.5.4 | `Test-SchemaRegression.ps1` + regression-report.md | ✅ |
| T1.5.5 | `Invoke-ZenPatch.ps1` — schema-driven byte writeback | ✅ |
| T1.5.6 | `P3RModDSL.psm1` — 12 DSL functions, 5 schema types | ✅ |
| T1.5.7 | `modify-and-repack.ps1` — Zen patch default pipeline | ✅ |
| T1.5.8 | AgiMod regression (byte-identical + manual in-game confirm) | ✅ |
| T1.5.9 | `ZEN_BYTE_PATCH_WORKFLOW.md` + all docs updated | ✅ |

**Score: 17/17 audit items present.**

## E2E Test Results

| # | Test | Result | Detail |
|---|------|--------|--------|
| 1 | BufuMod manual in-game | ✅ | 布芙 `hpn` 40→999 @ `0x4274`; 2 byte diffs; damage increase confirmed in game |
| 2 | ExpMod manual in-game | ✅ | Normal `ExpRate` 1.0→100.0 @ `0x086C`; 2 byte diffs; 100× EXP confirmed on Normal difficulty |
| 3 | AgiMod manual in-game | ✅ | Agi `hpn` 40→999; Agi ≈5× Bufu damage confirmed |
| 4 | MultiMod (Agi+Bufu 1 call) | ✅ | 2 skills, 4 byte diffs |
| 5 | Pipeline DryRun | ✅ | Prevents write |
| 6 | DSL Smoke (12 functions) | ✅ | All run without error |

**All 12 exported DSL functions verified across 5 flat-scalar schema types:**
- `indexed_rows`: skillNormal, persona, enemy, playerLevelup
- `named_rows`: DT_BtlDIfficultyParam
- `New-ModChanges`: generic any-schema

## Known Limitations Discovered

| Limitation | Detail | 
|------------|--------|
| Union struct crash (P-010) | `personaGrowth.SkillEventStruct` union `{SkillList\|ItemList}` — byte write = `Bad name index` crash. Union discriminator must match. |
| CUE4Parse struct array gap | `personaGrowth.skillEvent[]` shows `{level:0,skillId:0}` for all rows — can't cross-validate |
| No struct sub-field in pipeline | `Data[N].structArr[slot].subField` not supported by target parser |

## Manual Verification

- ✅ BufuMod: 布芙 `hpn=999` confirmed in-game (Skill ID 20, offset `0x4274`, 2 byte diffs)
- ✅ ExpMod: Normal difficulty `ExpRate=100.0` confirmed in-game (offset `0x086C`, 2 byte diffs; note: only applies on Normal difficulty)
- ✅ AgiMod: hpn=999 confirmed in-game ≈5× Bufu damage
- ✅ Byte-identical to original PoC (539,474 bytes, 0 diffs)

## Known Limitations (not blockers)

- Enemy skills often share high byte → 1 byte diff instead of 2 (valid)
- Float values may change only 1 byte depending on mantissa (valid)
- `Set-SkillHpn -DamageMultiplier` reads current value from JSON cache; needs cache to exist
- Each DSL call writes to a fresh Zen copy; batch writes use `New-ModChanges`

## Conclusion

**Sprint 1.5 is complete.** The Zen byte-patch pipeline is end-to-end functional:
DSL / pipeline / DryRun / NoInstall all work as designed. AgiMod regression is
byte-level verified and game-tested. Ready to proceed to Sprint 2.
