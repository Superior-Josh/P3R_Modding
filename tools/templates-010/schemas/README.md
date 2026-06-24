# Parsed schemas (T1.5.2 + T1.5.2b + T1.5.3 + T1.5.4 output)

This directory holds the JSON output of [`Parse-BtTemplate.ps1`](../../scripts/Parse-BtTemplate.ps1) (one `_schema.json` per `.bt` template) **and** the overlay from [`Calibrate-SchemaHeaders.ps1`](../../scripts/Calibrate-SchemaHeaders.ps1) + [`Test-SchemaRegression.ps1`](../../scripts/Test-SchemaRegression.ps1) that adds `headerSize` and regression fields.

**Status (2026-06-25)**:

- ✅ **38 / 41 templates parsed** (T1.5.2 + T1.5.2b)
- ✅ **34 / 38 schemas calibrated** with real `headerSize` (T1.5.3)
- ✅ **20 / 29 testable schemas pass regression** against CUE4Parse JSON (T1.5.4 + PARTIAL treatment update)
- ✅ Golden anchor: `p3re_skillNormal 120/120 fields match` (Agi.hpn=40 exact)
- ✅ Second anchor: `DT_BtlDIfficultyParam 50/50 fields match` (`Easy.ExpRate` exact)
- ✅ PARTIAL treatment metadata added: `safeWithNormalization` / `needsManualReview` / `deprecatedDuplicate` / `unsupportedUntilSchemaFix`

**Calibration result**: 34 OK / 3 DEP / 1 NOT_FOUND. Full report: [calibration-report.md](calibration-report.md).

**Regression result (T1.5.4 + PARTIAL treatment update)**: 20 PASS / 9 PARTIAL / 2 FAIL / 7 SKIP. Full report: [regression-report.md](regression-report.md).

## Schema format — 4 table shapes

Each calibrated schema has `tableShape`, `headerSize` (real), and various addressing fields. Always use `headerSize` for byte-patch math.

### Shape 1: `indexed_rows` (29 templates)

`file_offset = headerSize + rowIndex * rowSize + field.offset`

### Shape 2: `named_rows` (1 template: `DT_BtlDIfficultyParam`)

`file_offset = headerSize + row.offset + field.offset` (lookup by `rowKeys: ["safety","easy",...]`)

### Shape 3: `single_record` (5 templates)

`file_offset = headerSize + field.offset` (no row indexing)

### Shape 4: `single_record_array` (3 templates)

`file_offset = headerSize + repIndex * repeatStride + field.offset`

## Regeneration

```powershell
# Parse .bt -> schema JSON (T1.5.2 + T1.5.2b)
Get-ChildItem tools\templates-010\p3re_*.bt | Where-Object { $_.Name -notin 'p3re_enums.bt','p3re_structs.bt' } | ForEach-Object {
    $out = "tools\templates-010\schemas\$($_.BaseName)_schema.json"
    try { $null = .\tools\scripts\Parse-BtTemplate.ps1 -TemplatePath $_.FullName -OutputPath $out -ErrorAction Stop 2>&1 } catch { }
}
# Calibrate (T1.5.3) + Regress (T1.5.4)
.\tools\scripts\Calibrate-SchemaHeaders.ps1
.\tools\scripts\Test-SchemaRegression.ps1
```

## Validation chain

1. **AgiMod ground truth**: `p3re_skillNormal.bt` 21/21 manual fields + 120/120 regression fields match; Agi.hpn @ `0x0246A`
2. **arkemultiplier cross-check**: `DT_BtlDIfficultyParam.Easy.ExpRate` matches known byte-diff position, 50/50 fields pass regression

## 3 remaining template failures (not parser bugs)

| Template | Reason | Impact |
|---|---|---|
| `p3re_combineBirth.bt` | Template is a literal-zero stub | Skip |
| `p3re_datitemskillcarddataasset.bt` | Template body is empty; `p3re_itemSkillCard.bt` covers the same asset | Use `itemSkillCard` instead |
| `p3re_HeroParameterDataAsset.bt` | Multi-section flat layout; needs new `tableShape` | Only affects Courage/Charm/Academics parameters |
