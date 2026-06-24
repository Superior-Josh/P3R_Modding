# Calibrate-SchemaHeaders.ps1 — Sprint 1.5 T1.5.3
#
# For each schema in tools/templates-010/schemas/*_schema.json:
#   1. Resolve the corresponding .uasset path in Extracted/IoStore/
#      (Xrd777 path preferred over Astrea; explicit name overrides handle
#      template <-> asset name mismatches)
#   2. Compute the real header size from fileSize and the schema's body shape:
#        indexed_rows         -> fileSize - rowSize × rowCount
#        named_rows           -> fileSize - sum(rows[i].size)
#        single_record        -> fileSize - recordSize
#        single_record_array  -> fileSize - repeatStride × repeatCount
#   3. Write headerSize + calibrationStatus + sourceAssetPath fields back
#      into the schema JSON.
#
# Output:
#   - Schema files updated in-place
#   - calibration-report.md summarising results

param(
    [string] $SchemasDir = "$PSScriptRoot\..\templates-010\schemas",
    [string] $ExtractedRoot = "$PSScriptRoot\..\..\Extracted\IoStore",
    [string] $ReportPath = "$PSScriptRoot\..\templates-010\schemas\calibration-report.md"
)

$ErrorActionPreference = 'Stop'

# Schema file -> in-game .uasset name. Built from the inventory of
# Extracted/IoStore/. When the template name doesn't match, the override
# documents the deliberate decision.
$Script:AssetNameByTemplate = @{
    # === indexed_rows (29) ===
    'p3re_skillNormal'                 = 'DatSkillNormalDataAsset'
    'p3re_datskillnormaldataasset'     = 'DatSkillNormalDataAsset'
    'p3re_skill'                       = 'DatSkillDataAsset'
    'p3re_datskilldataasset'           = 'DatSkillDataAsset'
    'p3re_persona'                     = 'DatPersonaDataAsset'
    'p3re_datpersonadataasset'         = 'DatPersonaDataAsset'
    'p3re_personaGrowth'               = 'DatPersonaGrowthDataAsset'
    'p3re_datpersonagrowthdataasset'   = 'DatPersonaGrowthDataAsset'
    'p3re_personaAffinity'             = 'DatPersonaAffinityDataAsset'
    'p3re_datpersonaaffinitydataasset' = 'DatPersonaAffinityDataAsset'
    'p3re_allyPersonaGrowth'           = 'DatAllyPersonaGrowthDataAsset'
    'p3re_datallypersonagrowthdataasset' = 'DatAllyPersonaGrowthDataAsset'
    'p3re_enemy'                       = 'DatEnemyDataAsset'
    'p3re_datenemydataasset'           = 'DatEnemyDataAsset'
    'p3re_enemyAffinity'               = 'DatEnemyAffinityDataAsset'
    'p3re_enemyAnalyzeSync'            = 'DatEnemyAnalyzeSyncDataAsset'
    'p3re_encountTable'                = 'DatEncountTableDataAsset'
    'p3re_datencounttabledataasset'    = 'DatEncountTableDataAsset'
    'p3re_encountEnemyBadPercent'      = 'DatEncountEnemyBadPercentDataAsset'
    'p3re_btlMixRaidRelease'           = 'DatBtlMixraidReleaseDataAsset'  # lowercase 'r' in upstream filename
    'p3re_datbtlmixraidreleasedataasset' = 'DatBtlMixraidReleaseDataAsset'
    'p3re_DatItemShopLineupDataAsset'  = 'DatItemShopLineupDataAsset'
    'p3re_playerLevelup'               = 'DatPlayerLevelupDataAsset'
    'p3re_calcPANICUseItem'            = 'DatCalcPANICUseItemDataAsset'
    'p3re_skillLimit'                  = 'SkillLimitDataAsset'
    'p3re_specialSpread'               = 'SpecialSpreadDataAsset'         # no 'Dat' prefix
    'p3re_specialspreaddataasset'      = 'SpecialSpreadDataAsset'
    'p3re_supportInfoCommon'           = 'DatSupportInfoCommonDataAsset'
    'p3re_supportInfoNavi'             = 'DatSupportInfoNaviDataAsset'    # NOT EXTRACTED — calibration will mark as not_found

    # === named_rows (1) ===
    'p3re_DT_BtlDIfficultyParam'       = 'DT_BtlDIfficultyParam'

    # === single_record (5) ===
    'p3re_combineMisc'                 = 'CombineMiscDataAsset'
    'p3re_combinemiscdataasset'        = 'CombineMiscDataAsset'
    'p3re_calcPANICDropItem'           = 'DatCalcPANICDropItemDataAsset'
    'p3re_itemSkillCard'               = 'DatItemSkillcardDataAsset'
    'p3re_skillPack'                   = 'SkillPackDataAsset'

    # === single_record_array (3) ===
    'p3re_btlTheurgiaBoost'            = 'DatBtlTheurgiaBoostDataAsset'
    'p3re_btlTheurgiaBoost_astrea'     = 'DatBtlTheurgiaBoostDataAsset'   # the Astrea variant lives under Astrea/ folder; we'll prefer that path
    'p3re_datbtltheurgiaboostdataasset' = 'DatBtlTheurgiaBoostBossDataAsset'  # the "boss" variant uses this template
}

# Schemas where there's both a canonical (e.g. p3re_personaGrowth) and a `dat*` duplicate
# (e.g. p3re_datpersonagrowthdataasset). When their rowSize/recordSize disagree, the canonical
# one is correct and the dat-prefixed one is a stale snapshot. Tag the dat duplicates here.
$Script:DeprecatedDuplicates = @(
    'p3re_datpersonagrowthdataasset'
    'p3re_datallypersonagrowthdataasset'
    'p3re_datbtltheurgiaboostdataasset'
)

# Templates with a known wrong rowCount that overstates body size.
# rowCount overrides applied during calibration.
$Script:RowCountOverrides = @{
    'p3re_DatItemShopLineupDataAsset' = 24   # template says 1024 but real file has only ~24 entries
}

function Resolve-AssetPath {
    param([string] $AssetName, [bool] $PreferAstrea = $false)
    if (-not (Test-Path $ExtractedRoot)) { return $null }
    $candidates = Get-ChildItem $ExtractedRoot -Recurse -Filter "$AssetName.uasset" -ErrorAction SilentlyContinue
    if ($candidates.Count -eq 0) { return $null }

    if ($PreferAstrea) {
        $astrea = @($candidates | Where-Object { $_.FullName -match '\\Astrea\\' })
        if ($astrea.Count -gt 0) { return $astrea[0].FullName }
    }
    # Xrd777 > Astrea (per CLAUDE.md asset format rules)
    $xrd = @($candidates | Where-Object { $_.FullName -match '\\Xrd777\\' })
    if ($xrd.Count -gt 0) { return $xrd[0].FullName }
    return $candidates[0].FullName
}

function Get-BodySize {
    param([pscustomobject] $Schema, [string] $Key)
    # Allow row count overrides for templates with known-wrong rowCount values
    $effectiveRowCount = if ($Schema.PSObject.Properties['rowCount']) { $Schema.rowCount } else { $null }
    if ($Script:RowCountOverrides.ContainsKey($Key)) {
        $effectiveRowCount = $Script:RowCountOverrides[$Key]
    }
    switch ($Schema.tableShape) {
        'indexed_rows'        { return [int64]$Schema.rowSize * [int64]$effectiveRowCount }
        'named_rows'          { return ([int64]0 + ($Schema.rows | Measure-Object -Property size -Sum).Sum) }
        'single_record'       { return [int64]$Schema.recordSize }
        'single_record_array' { return [int64]$Schema.repeatStride * [int64]$Schema.repeatCount }
        default               { return $null }
    }
}

$schemaFiles = Get-ChildItem $SchemasDir -Filter '*_schema.json' -File | Sort-Object Name
"=== Calibrating $($schemaFiles.Count) schemas ==="

$report = New-Object System.Collections.Generic.List[hashtable]
$okCount = 0
$failCount = 0

foreach ($sf in $schemaFiles) {
    $key = $sf.BaseName -replace '_schema$', ''
    $schema = Get-Content $sf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json

    $assetName = $Script:AssetNameByTemplate[$key]
    if (-not $assetName) {
        # Fallback: derive from the schema's asset field
        $assetName = ($schema.asset -replace '\.uasset$','')
    }

    $preferAstrea = $key -match '_astrea$'
    $assetPath = Resolve-AssetPath -AssetName $assetName -PreferAstrea $preferAstrea

    $entry = @{
        template      = $sf.Name
        key           = $key
        assetName     = $assetName
        tableShape    = $schema.tableShape
        headerHint    = $schema.headerSizeHint
        bodySize      = Get-BodySize -Schema $schema -Key $key
        sourceAssetPath = $null
        fileSize      = $null
        headerSize    = $null
        delta         = $null
        status        = $null
        deprecated    = ($key -in $Script:DeprecatedDuplicates)
        rowCountOverride = if ($Script:RowCountOverrides.ContainsKey($key)) { $Script:RowCountOverrides[$key] } else { $null }
    }

    if (-not $assetPath) {
        $entry.status = 'not_found'
        $schema | Add-Member -NotePropertyName headerSize          -NotePropertyValue $schema.headerSizeHint -Force
        $schema | Add-Member -NotePropertyName calibrationStatus   -NotePropertyValue 'not_found' -Force
        $schema | Add-Member -NotePropertyName sourceAssetPath     -NotePropertyValue $null -Force
        $failCount++
    } else {
        $fileSize = (Get-Item $assetPath).Length
        $entry.sourceAssetPath = $assetPath.Substring((Resolve-Path '.').Path.Length + 1) -replace '\\','/'
        $entry.fileSize = $fileSize
        $headerCalc = $fileSize - $entry.bodySize

        $entry.headerSize = $headerCalc
        $entry.delta = $headerCalc - $schema.headerSizeHint

        if ($entry.deprecated) {
            # Deprecated dat-* duplicate — the canonical schema is the source of truth.
            $entry.status = 'deprecated'
            $schema | Add-Member -NotePropertyName headerSize        -NotePropertyValue $schema.headerSizeHint -Force
            $schema | Add-Member -NotePropertyName calibrationStatus -NotePropertyValue 'deprecated: prefer canonical schema (non-dat name)' -Force
            $failCount++
        } elseif ($headerCalc -lt 0) {
            $entry.status = 'negative_header'
            $schema | Add-Member -NotePropertyName headerSize        -NotePropertyValue $schema.headerSizeHint -Force
            $schema | Add-Member -NotePropertyName calibrationStatus -NotePropertyValue ('negative_header: file={0} body={1} header={2}' -f $fileSize, $entry.bodySize, $headerCalc) -Force
            $failCount++
        } else {
            $entry.status = 'ok'
            $schema | Add-Member -NotePropertyName headerSize        -NotePropertyValue ([int64]$headerCalc) -Force
            $schema | Add-Member -NotePropertyName calibrationStatus -NotePropertyValue 'ok' -Force
            $okCount++
        }
        $schema | Add-Member -NotePropertyName sourceAssetPath -NotePropertyValue $entry.sourceAssetPath -Force
        $schema | Add-Member -NotePropertyName fileSize        -NotePropertyValue $fileSize -Force
        if ($null -ne $entry.rowCountOverride) {
            $schema | Add-Member -NotePropertyName rowCountCalibrated -NotePropertyValue $entry.rowCountOverride -Force
        }
    }

    # Write the schema back
    $json = $schema | ConvertTo-Json -Depth 12
    [System.IO.File]::WriteAllText($sf.FullName, $json)

    $report.Add($entry)

    $statusGlyph = switch ($entry.status) {
        'ok'              { 'OK ' }
        'deprecated'      { 'DEP' }
        'negative_header' { 'XX ' }
        'not_found'       { '?? ' }
        default           { '!! ' }
    }
    $deltaStr = if ($null -ne $entry.delta) { '{0:+#;-#;0}' -f $entry.delta } else { '-' }
    $hsStr    = if ($null -ne $entry.headerSize) { '{0}' -f $entry.headerSize } else { '-' }
    $line = '  {0}  {1,-52} hint={2,4} actual={3,6} delta={4,7} shape={5}' -f `
        $statusGlyph, $sf.Name, $entry.headerHint, $hsStr, $deltaStr, $entry.tableShape
    Write-Host $line
}

Write-Host ""
Write-Host "=== Result: $okCount OK / $failCount failed (of $($schemaFiles.Count) schemas) ===" -ForegroundColor Cyan

# --- AgiMod golden anchor check ---
$agi = $report | Where-Object { $_.key -eq 'p3re_skillNormal' }
if ($agi -and $agi.headerSize -eq 1174) {
    Write-Host "Golden anchor: p3re_skillNormal headerSize = 1174 (matches AgiMod PoC)" -ForegroundColor Green
} elseif ($agi) {
    Write-Host "AGI ANCHOR FAILED: p3re_skillNormal headerSize = $($agi.headerSize), expected 1174" -ForegroundColor Red
}

# --- Report ---
$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine('# Header Calibration Report')
[void]$md.AppendLine('')
[void]$md.AppendLine('> Generated by [Calibrate-SchemaHeaders.ps1](../scripts/Calibrate-SchemaHeaders.ps1) -- Sprint 1.5 T1.5.3.')
[void]$md.AppendLine('')
[void]$md.AppendLine("**Summary**: $okCount OK / $failCount failed (of $($schemaFiles.Count) schemas).")
[void]$md.AppendLine('')
[void]$md.AppendLine("Each row shows the schema's declared ``headerSizeHint`` (from the 010 template's ``byte unk[N]``) vs. the calibrated ``headerSize`` (computed from ``fileSize - bodySize`` of the matching ``.uasset`` in ``Extracted/IoStore/``).")
[void]$md.AppendLine('')
[void]$md.AppendLine('Status legend: `[OK]` calibrated, `[DEP]` deprecated dat-prefix duplicate (prefer canonical), `[??]` asset not in Extracted/, `[XX]` negative header (schema body mismatch).')
[void]$md.AppendLine('')
[void]$md.AppendLine('| Status | Template | Asset | Shape | Hint | Actual | Delta | File size | Body size |')
[void]$md.AppendLine('|:---:|---|---|---|---:|---:|---:|---:|---:|')

foreach ($e in ($report | Sort-Object { $_.status -ne 'ok' }, key)) {
    $glyph = switch ($e.status) {
        'ok'              { '[OK]' }
        'deprecated'      { '[DEP]' }
        'not_found'       { '[??]' }
        'negative_header' { '[XX]' }
        default           { '[!!]' }
    }
    $fs = if ($null -ne $e.fileSize)   { '{0:N0}' -f $e.fileSize }   else { '-' }
    $bs = if ($null -ne $e.bodySize)   { '{0:N0}' -f $e.bodySize }   else { '-' }
    $hs = if ($null -ne $e.headerSize) { '{0:N0}' -f $e.headerSize } else { '-' }
    $d  = if ($null -ne $e.delta)      { '{0:+#;-#;0}' -f $e.delta } else { '-' }
    [void]$md.AppendLine("| $glyph | ``$($e.template)`` | $($e.assetName) | $($e.tableShape) | $($e.headerHint) | $hs | $d | $fs | $bs |")
}

[void]$md.AppendLine('')
[void]$md.AppendLine('## Golden anchor')
[void]$md.AppendLine('')
[void]$md.AppendLine('`p3re_skillNormal` must calibrate to `headerSize = 1174` to match the manual AgiMod PoC (Agi.hpn at file offset `0x0246A`).')

[System.IO.File]::WriteAllText($ReportPath, $md.ToString())
Write-Host "Report written: $ReportPath" -ForegroundColor Green
