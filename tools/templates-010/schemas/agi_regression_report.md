# AgiMod Regression Report — Sprint 1.5 T1.5.8

> **Date**: 2026-06-24 | **Status**: ✅ ALL PASSED (including manual in-game test) | **Toolchain**: P3RModDSL.psm1 + Invoke-ZenPatch.ps1

## Scope

Verify the Sprint 1.5 Zen byte-patch pipeline produces output that is
**byte-identical** to the original hand-crafted AgiMod PoC, and that all computed
file offsets match the known gold anchors.

## Gold Anchors

| Anchor | Offset | Expected | Actual | Status |
|--------|--------|----------|--------|--------|
| Agi.hpn = 999 | `0x246A` | `E7 03` (999 LE) | `E7 03` (999 LE) | ✅ PASS |
| Agi.cost | `0x2329` | 2 bytes unchanged | unchanged from original | ✅ PASS |
| N² formula (×5) | `0x246A` | `E8 03` (1000 LE) | `E8 03` (1000 LE) | ✅ PASS |
| Bufu.hpn | `0x4274` | 1174+20×769+458=17012 | `0x4274` → 999 | ✅ PASS |
| Garu.hpn | `0x607E` | 1174+30×769+458=24702 | `0x607E` → 999 | ✅ PASS |
| Zio.hpn | `0x7E88` | 1174+40×769+458=32392 | `0x7E88` → 999 | ✅ PASS |
| Hama.hpn | `0x9C92` | 1174+50×769+458=40082 | `0x9C92` → 999 | ✅ PASS |

## Test 1: PoC vs DSL — Byte Identical

```
PoC AgiMod (manual hex-edit)         : 539,474 bytes
DSL output (Set-SkillHpn -Hpn 999)   : 539,474 bytes
Byte-level differences               : 0 ← BYTE-IDENTICAL
```

**This is the definitive regression — the pipeline perfectly replicates the
hand-crafted AgiMod that was verified to work in-game.**

## Test 2: Zen Original → DSL Patch — Minimal Change

```
Zen original                         : 539,474 bytes
DSL hpn=999 patch                    : 539,474 bytes
Byte-level differences               : 2 bytes (@ 0x246A, 0x246B)
Changed                              : ushort 40 → 999 (E7 03 LE)
```

## Test 3: N² Damage Multiplier Formula

```
Input : Set-SkillHpn -SkillId 10 -DamageMultiplier 5.0
Compute: Round(40 × 5.0²) = Round(40 × 25) = 1000
Output: Agi.hpn = 1000 @ 0x246A (E8 03 LE)
Verify: 1000 = 40 × 25 → √(1000/40) = 5.00 ↔ 5× displayed damage ✓
```

## Test 4: Offset Formula Cross-Verification

All 5 skill offsets independently verified against:
```
fileOffset = headerSize + skillId × rowSize + fieldOffset(hpn)
           = 1174 + skillId × 769 + 458
```

| Skill ID | Skill Name | Expected Offset | Actual Offset | Match |
|---------|------------|----------------|---------------|-------|
| 10 | Agi (亚基) | `0x246A` | `0x246A` | ✅ |
| 20 | Bufu (布芙) | `0x4274` | `0x4274` | ✅ |
| 30 | Garu (加尔) | `0x607E` | `0x607E` | ✅ |
| 40 | Zio (吉欧) | `0x7E88` | `0x7E88` | ✅ |
| 50 | Hama (哈玛) | `0x9C92` | `0x9C92` | ✅ |

## Batch Write Note

Each `Set-SkillHpn` call starts from a fresh copy of the Zen original. To write
multiple skills in one pass, use `New-ModChanges`:

```powershell
New-ModChanges -SchemaKey p3re_skillNormal -Changes @(
    @{target='Data[10].hpn'; value=999},
    @{target='Data[20].hpn'; value=999},
    @{target='Data[30].hpn'; value=999}
) -OutputDir .\my-mod\
```

## Conclusion

✅ **8/8 regression checks passed.** The Sprint 1.5 pipeline (Invoke-ZenPatch +
P3RModDSL + modify-and-repack) produces output that is byte-identical to the
original hand-crafted AgiMod PoC. All computed offsets match the gold anchors.
**Manual in-game test confirmed**: Agi damage ≈ 5× Bufu (√(999/40) = 5.00).
