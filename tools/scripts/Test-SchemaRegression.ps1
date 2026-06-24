# Test-SchemaRegression.ps1 — Sprint 1.5 T1.5.4
#
# For each calibrated schema in tools/templates-010/schemas/*_schema.json:
#   1. Load the Zen .uasset bytes (from the schema's sourceAssetPath)
#   2. Load the corresponding CUE4Parse JSON (from tools/Output/json/...)
#   3. Sample a handful of rows / records / array elements
#   4. Decode each field from Zen bytes per its (offset, size, type)
#   5. Compare against the JSON value; tolerate float rounding (1e-4)
#   6. Emit per-schema pass/partial/fail/skip status + mismatch details
#
# Output:
#   - Schemas updated in-place with regressionStatus / regressionPassRate
#   - regression-report.md with full details
#
# Coverage rules:
#   - Bitfield group members (kind=bitfield): JSON aggregates them into a single
#     int (e.g. 'flag', 'badstatus', 'support'); we verify the aggregate instead.
#   - Inline arrays (count > 1): JSON has an array; verify element-by-element.
#   - Fields not present in JSON (e.g. nested struct fields the template exposes
#     but CUE4Parse flattens away): marked 'not_in_json', not counted as mismatch.

param(
    [string] $SchemasDir   = "$PSScriptRoot\..\templates-010\schemas",
    [string] $JsonRoot     = "$PSScriptRoot\..\..\tools\Output\json",
    [string] $ReportPath   = "$PSScriptRoot\..\templates-010\schemas\regression-report.md"
)

$ErrorActionPreference = 'Stop'

# Schema file key -> CUE4Parse JSON file (relative to $JsonRoot).
# Built from the inventory of tools/Output/json/.
$Script:JsonByTemplate = @{
    # indexed_rows
    'p3re_skillNormal'                 = 'Battle\datskillnormaldataasset.json'
    'p3re_datskillnormaldataasset'     = 'Battle\datskillnormaldataasset.json'
    'p3re_skill'                       = 'Battle\datskilldataasset.json'
    'p3re_datskilldataasset'           = 'Battle\datskilldataasset.json'
    'p3re_persona'                     = 'Battle\datpersonadataasset.json'
    'p3re_datpersonadataasset'         = 'Battle\datpersonadataasset.json'
    'p3re_personaGrowth'               = 'Battle\datpersonagrowthdataasset.json'
    'p3re_datpersonagrowthdataasset'   = 'Battle\datpersonagrowthdataasset.json'
    'p3re_personaAffinity'             = 'Battle\datpersonaaffinitydataasset.json'
    'p3re_datpersonaaffinitydataasset' = 'Battle\datpersonaaffinitydataasset.json'
    'p3re_allyPersonaGrowth'           = 'Battle\datallypersonagrowthdataasset.json'
    'p3re_datallypersonagrowthdataasset' = 'Battle\datallypersonagrowthdataasset.json'
    'p3re_enemy'                       = 'Battle\datenemydataasset.json'
    'p3re_datenemydataasset'           = 'Battle\datenemydataasset.json'
    'p3re_enemyAffinity'               = 'Battle\datenemyaffinitydataasset.json'
    'p3re_enemyAnalyzeSync'            = 'Battle\datenemyanalyzesyncdataasset.json'
    'p3re_encountTable'                = 'Battle\datencounttabledataasset.json'
    'p3re_datencounttabledataasset'    = 'Battle\datencounttabledataasset.json'
    'p3re_encountEnemyBadPercent'      = 'Battle\datencountenemybadpercentdataasset.json'
    'p3re_btlMixRaidRelease'           = 'Battle\datbtlmixraidreleasedataasset.json'
    'p3re_datbtlmixraidreleasedataasset' = 'Battle\datbtlmixraidreleasedataasset.json'
    'p3re_DatItemShopLineupDataAsset'  = 'UI_Tables\datitemshoplineupdataasset.json'
    'p3re_playerLevelup'               = 'Battle\datplayerlevelupdataasset.json'
    'p3re_skillLimit'                  = 'UI_Tables\skilllimitdataasset.json'
    'p3re_specialSpread'               = 'UI_Tables\specialspreaddataasset.json'
    'p3re_specialspreaddataasset'      = 'UI_Tables\specialspreaddataasset.json'
    'p3re_supportInfoCommon'           = 'Battle\datsupportinfocommondataasset.json'
    # single_record
    'p3re_combineMisc'                 = 'UI_Tables\combinemiscdataasset.json'
    'p3re_combinemiscdataasset'        = 'UI_Tables\combinemiscdataasset.json'
    'p3re_itemSkillCard'               = 'UI_Tables\datitemskillcarddataasset.json'
    'p3re_skillPack'                   = 'UI_Tables\skillpackdataasset.json'
    # single_record_array
    'p3re_btlTheurgiaBoost'            = 'Battle\datbtltheurgiaboostdataasset.json'
    'p3re_btlTheurgiaBoost_astrea'     = 'Battle\datbtltheurgiaboostdataasset.json'
    # named_rows — JSON lives at a non-standard path
    'p3re_DT_BtlDIfficultyParam'       = 'Battle\dt_btldifficultyparam_original.json'
    # skipped — no JSON available
    # 'p3re_calcPANICDropItem'          (asset not in CUE4Parse output)
    # 'p3re_calcPANICUseItem'           (asset not in CUE4Parse output)
    # 'p3re_supportInfoNavi'            (asset not extracted)
}

# Schemas to skip entirely (deprecated duplicates — canonical sibling covers them)
$Script:SkipKeys = @(
    'p3re_datpersonagrowthdataasset'
    'p3re_datallypersonagrowthdataasset'
    'p3re_datbtltheurgiaboostdataasset'
)

# Golden anchors — (templateKey, rowIndex, fieldName, expectedValue)
# These MUST pass or the whole regression run is considered failed.
$Script:GoldenAnchors = @(
    @{ key='p3re_skillNormal'; row=10; field='hpn'; expected=40; label='AgiMod PoC: Agi.hpn' }
)

# Bitfield group aggregate field names (when template exposes individual bits but
# CUE4Parse JSON has a single int for the whole group). We map schema-group name
# to JSON aggregate field name. These are the only bitfield-group cases in p3re.
$Script:BitfieldAggregateMap = @{
    'FlagList'    = 'flag'
    'EffectList'  = 'badstatus'
    'SupportList' = 'support'
}

# --------------------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------------------

function ConvertTo-AsciiSafe {
    param([string] $S)
    # Replace non-ASCII with closest ASCII (good enough for report rendering on PS 5.1)
    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $S.ToCharArray()) {
        if ([int]$c -lt 128) { [void]$sb.Append($c) } else { [void]$sb.Append('?') }
    }
    return $sb.ToString()
}

function Read-ZenValue {
    param([byte[]] $Bytes, [int] $Offset, [string] $Type, [int] $Count = 1, [int] $Size = 0, [hashtable] $EnumSizes = $null)
    if ($Count -gt 1) {
        # Inline array — return array of decoded elements
        $elemSize = switch ($Type) {
            'byte'   { 1 }; 'ubyte' { 1 }; 'short' { 2 }; 'ushort' { 2 }
            'int'    { 4 }; 'uint'  { 4 }; 'int32' { 4 }; 'uint32' { 4 }; 'float' { 4 }
            default  {
                # Unknown element type (enum) — use $Size/$Count, or enumSizes lookup
                if ($EnumSizes -and $EnumSizes.ContainsKey($Type)) { $EnumSizes[$Type] }
                elseif ($Size -gt 0) { [int]($Size / $Count) }
                else { 1 }
            }
        }
        $arr = @()
        for ($i = 0; $i -lt $Count; $i++) {
            $arr += (Read-ZenValue -Bytes $Bytes -Offset ($Offset + $i * $elemSize) -Type $Type -Count 1 -Size $elemSize -EnumSizes $EnumSizes)
        }
        return $arr
    }
    # Scalar reading — prefer explicit $Size for enum types, then enumSizes, then type-intrinsic
    $effectiveSize = if ($Size -gt 0) {
        $Size
    } elseif ($EnumSizes -and $EnumSizes.ContainsKey($Type)) {
        $EnumSizes[$Type]
    } else {
        switch ($Type) {
            'byte'   { 1 }; 'ubyte' { 1 }; 'uint8' { 1 }; 'int8' { 1 }; 'char' { 1 }; 'uchar' { 1 }; 'Bool' { 1 }
            'short'  { 2 }; 'ushort' { 2 }; 'uint16' { 2 }; 'int16' { 2 }
            'int'    { 4 }; 'uint'   { 4 }; 'int32'  { 4 }; 'uint32' { 4 }; 'u32' { 4 }; 'float' { 4 }
            default  { 1 }   # unknown enum — default 1 byte
        }
    }
    # Signed vs unsigned — honor the type name
    switch ($Type) {
        'byte'    { return [sbyte]$Bytes[$Offset] }
        'short'   { return [BitConverter]::ToInt16($Bytes, $Offset) }
        'int'     { return [BitConverter]::ToInt32($Bytes, $Offset) }
        'int32'   { return [BitConverter]::ToInt32($Bytes, $Offset) }
        'float'   { return [BitConverter]::ToSingle($Bytes, $Offset) }
    }
    # Otherwise treat as unsigned by size
    switch ($effectiveSize) {
        1 { return [byte]$Bytes[$Offset] }
        2 { return [BitConverter]::ToUInt16($Bytes, $Offset) }
        4 { return [BitConverter]::ToUInt32($Bytes, $Offset) }
        8 { return [BitConverter]::ToUInt64($Bytes, $Offset) }
        default { throw "Unsupported field size: $effectiveSize (type=$Type)" }
    }
}

function Compare-Values {
    param($Expected, $Actual)
    # Float tolerance
    if ($Expected -is [double] -or $Actual -is [double] -or $Expected -is [single] -or $Actual -is [single]) {
        $ed = [double]$Expected; $ad = [double]$Actual
        if ([Math]::Abs($ed - $ad) -lt 1e-4) { return $true }
        # Also allow relative tolerance for large floats
        if ($ed -ne 0 -and ([Math]::Abs($ed - $ad) / [Math]::Abs($ed)) -lt 1e-4) { return $true }
        return $false
    }
    # Arrays — element-wise
    if ($Expected -is [System.Array] -or ($Expected -is [System.Collections.IList])) {
        if ($Actual -isnot [System.Collections.IList]) { return $false }
        if ($Expected.Count -ne $Actual.Count) { return $false }
        for ($i = 0; $i -lt $Expected.Count; $i++) {
            if (-not (Compare-Values -Expected $Expected[$i] -Actual $Actual[$i])) { return $false }
        }
        return $true
    }
    return ($Expected -eq $Actual)
}

function Find-JsonProperty {
    # Case-insensitive lookup, with optional GUID-suffix stripping for DT_* tables,
    # AND dotted-name fallback: if 'cardstruct.sortnum' isn't found, try 'sortnum'.
    # Returns the matched value, or $null if not found.
    param($Container, [string] $Name)
    if ($null -eq $Container) { return $null }
    $props = if ($Container.PSObject) { $Container.PSObject.Properties } else { $null }
    if (-not $props) { return $null }

    # 1. Exact match (case-insensitive)
    foreach ($p in $props) {
        if ($p.Name -ieq $Name) { return $p.Value }
    }
    # 2. Prefix match (strip GUID suffix: Name_10_8CBA31F0...)
    foreach ($p in $props) {
        if ($p.Name -match '^([A-Za-z0-9_]+?)_\d+_[A-F0-9]{32}$') {
            if ($matches[1] -ieq $Name) { return $p.Value }
        }
    }
    # 3. Dotted-name fallback: try last segment (e.g. 'cardstruct.sortnum' -> 'sortnum')
    if ($Name -match '\.') {
        $last = ($Name -split '\.')[-1]
        foreach ($p in $props) {
            if ($p.Name -ieq $last) { return $p.Value }
        }
        # And GUID-stripped last segment
        foreach ($p in $props) {
            if ($p.Name -match '^([A-Za-z0-9_]+?)_\d+_[A-F0-9]{32}$') {
                if ($matches[1] -ieq $last) { return $p.Value }
            }
        }
    }
    return $null
}

function Get-SampleIndices {
    param([int] $Total, [int[]] $Extra = @())
    # Always include 0, 1, middle, last; plus any extras (e.g. golden anchor row)
    $set = New-Object System.Collections.Generic.SortedSet[int]
    [void]$set.Add(0)
    if ($Total -gt 1) { [void]$set.Add(1) }
    if ($Total -gt 2) { [void]$set.Add([int]($Total / 2)) }
    if ($Total -gt 0) { [void]$set.Add($Total - 1) }
    foreach ($e in $Extra) {
        if ($e -ge 0 -and $e -lt $Total) { [void]$set.Add($e) }
    }
    return @($set)
}

# --------------------------------------------------------------------------------------
# Per-shape verifiers
# --------------------------------------------------------------------------------------

function Test-IndexedRows {
    param([byte[]] $Bytes, [pscustomobject] $Schema, $JsonProps, [hashtable] $Result, [hashtable] $EnumSizes = @{})

    $rowSize = [int]$Schema.rowSize
    $header  = [int]$Schema.headerSize
    $rowCount = [int]$Schema.rowCount
    if ($Schema.PSObject.Properties['rowCountCalibrated']) { $rowCount = [int]$Schema.rowCountCalibrated }

    $dataArr = $JsonProps.Data
    if (-not $dataArr) {
        $Result.status = 'fail'
        $Result.reason = 'JSON has no Properties.Data array'
        return
    }
    # If JSON has fewer rows than schema, cap sampling to JSON's count
    $sampleTotal = [Math]::Min($rowCount, $dataArr.Count)
    $goldenRows = @($Script:GoldenAnchors | Where-Object { $_.key -eq $Schema.templateFile -replace '\.bt$','' -replace '^p3re_','p3re_' } | ForEach-Object { $_.row })
    # Actually use the schema's templateFile to look up anchors
    $tmplKey = $Schema.templateFile -replace '\.bt$',''
    $goldenRows = @($Script:GoldenAnchors | Where-Object { $_.key -eq $tmplKey } | ForEach-Object { $_.row })
    $indices = Get-SampleIndices -Total $sampleTotal -Extra $goldenRows

    $totalFieldsChecked = 0
    $totalFieldsMatched = 0
    $mismatches = New-Object System.Collections.Generic.List[hashtable]
    $notInJson  = New-Object System.Collections.Generic.List[string]

    foreach ($rowIdx in $indices) {
        $rowStart = $header + $rowIdx * $rowSize
        $jsonRow = $dataArr[$rowIdx]
        if (-not $jsonRow) { continue }

        foreach ($f in $Schema.fields) {
            # Skip individual bitfield members — they're aggregated in JSON
            if ($f.kind -eq 'bitfield') { continue }
            # Skip container kinds (struct/anon_struct/union) — their children
            # appear as dotted-name fields in the flat list already.
            if ($f.kind -in @('struct','anon_struct','union')) { continue }

            # Determine lookup name and how to read the value
            $lookupName = $f.name
            $readType   = $f.type
            $readCount  = $f.count
            $readOffset = [int]$f.offset
            $readSize   = [int]$f.size

            if ($f.kind -eq 'bitfield_group') {
                # Aggregate: JSON has a single int for the whole group
                if ($Script:BitfieldAggregateMap.ContainsKey($f.name)) {
                    $lookupName = $Script:BitfieldAggregateMap[$f.name]
                    # Read the group as a uint32 (bitfield groups in p3re are 32 bits = 4 bytes)
                    $readType = 'uint32'
                    $readCount = 1
                } else {
                    # No aggregate known — skip
                    continue
                }
            }

            $absOffset = $rowStart + $readOffset
            $zenVal = Read-ZenValue -Bytes $Bytes -Offset $absOffset -Type $readType -Count $readCount -Size $readSize -EnumSizes $EnumSizes

            $jsonVal = Find-JsonProperty -Container $jsonRow -Name $lookupName
            if ($null -eq $jsonVal) {
                # Not in JSON — record once
                $key = "$($f.name)[$lookupName]"
                if (-not $notInJson.Contains($key)) { $notInJson.Add($key) }
                continue
            }

            $totalFieldsChecked++
            if (Compare-Values -Expected $jsonVal -Actual $zenVal) {
                $totalFieldsMatched++
            } else {
                $mismatches.Add(@{
                    row = $rowIdx; field = $f.name; offset = $absOffset
                    jsonVal = ($jsonVal | Out-String).Trim()
                    zenVal  = ($zenVal | Out-String).Trim()
                })
            }
        }
    }

    $Result.totalFieldsChecked = $totalFieldsChecked
    $Result.totalFieldsMatched = $totalFieldsMatched
    $Result.mismatches = $mismatches.ToArray()
    $Result.notInJson  = $notInJson.ToArray()
    $Result.sampledRows = $indices

    if ($totalFieldsChecked -eq 0) {
        $Result.status = 'fail'; $Result.reason = 'No fields could be checked (all not_in_json?)'
    } elseif ($mismatches.Count -eq 0) {
        $Result.status = 'pass'
    } else {
        $Result.status = 'partial'
    }
}

function Test-NamedRows {
    param([byte[]] $Bytes, [pscustomobject] $Schema, $JsonRoot2, [hashtable] $Result, [hashtable] $EnumSizes = @{})
    # JSON for DT_* is { Rows: { Safety: {...}, Easy: {...}, ... } }
    $rowsObj = $JsonRoot2.Rows
    if (-not $rowsObj) {
        $Result.status = 'fail'; $Result.reason = 'JSON has no Rows object'
        return
    }
    $header = [int]$Schema.headerSize

    $totalFieldsChecked = 0
    $totalFieldsMatched = 0
    $mismatches = New-Object System.Collections.Generic.List[hashtable]
    $notInJson  = New-Object System.Collections.Generic.List[string]

    foreach ($r in $Schema.rows) {
        $rowStart = $header + [int]$r.offset
        $jsonRow = Find-JsonProperty -Container $rowsObj -Name $r.name
        if (-not $jsonRow) {
            $Result.status = 'fail'; $Result.reason = "JSON Rows has no key '$($r.name)'"
            return
        }
        foreach ($f in $r.fields) {
            if ($f.kind -eq 'bitfield') { continue }
            if ($f.kind -in @('struct','anon_struct','union')) { continue }
            $absOffset = $rowStart + [int]$f.offset
            $zenVal = Read-ZenValue -Bytes $Bytes -Offset $absOffset -Type $f.type -Count $f.count -Size ([int]$f.size) -EnumSizes $EnumSizes
            $jsonVal = Find-JsonProperty -Container $jsonRow -Name $f.name
            if ($null -eq $jsonVal) {
                $key = "$($r.name).$($f.name)"
                if (-not $notInJson.Contains($key)) { $notInJson.Add($key) }
                continue
            }
            $totalFieldsChecked++
            if (Compare-Values -Expected $jsonVal -Actual $zenVal) {
                $totalFieldsMatched++
            } else {
                $mismatches.Add(@{
                    row = $r.name; field = $f.name; offset = $absOffset
                    jsonVal = ($jsonVal | Out-String).Trim()
                    zenVal  = ($zenVal | Out-String).Trim()
                })
            }
        }
    }
    $Result.totalFieldsChecked = $totalFieldsChecked
    $Result.totalFieldsMatched = $totalFieldsMatched
    $Result.mismatches = $mismatches.ToArray()
    $Result.notInJson  = $notInJson.ToArray()
    $Result.sampledRows = $Schema.rowKeys
    if ($totalFieldsChecked -eq 0) { $Result.status = 'fail'; $Result.reason = 'No fields checked' }
    elseif ($mismatches.Count -eq 0) { $Result.status = 'pass' }
    else { $Result.status = 'partial' }
}

function Test-SingleRecord {
    param([byte[]] $Bytes, [pscustomobject] $Schema, $JsonProps, [hashtable] $Result, [hashtable] $EnumSizes = @{})
    $header = [int]$Schema.headerSize
    $totalFieldsChecked = 0; $totalFieldsMatched = 0
    $mismatches = New-Object System.Collections.Generic.List[hashtable]
    $notInJson  = New-Object System.Collections.Generic.List[string]

    foreach ($f in $Schema.fields) {
        if ($f.kind -eq 'bitfield') { continue }
        if ($f.kind -in @('struct','anon_struct','union')) { continue }

        $lookupName = $f.name
        $readType   = $f.type
        $readCount  = $f.count
        $readOffset = [int]$f.offset
        $readSize   = [int]$f.size

        if ($f.kind -eq 'bitfield_group') {
            if ($Script:BitfieldAggregateMap.ContainsKey($f.name)) {
                $lookupName = $Script:BitfieldAggregateMap[$f.name]
                $readType = 'uint32'; $readCount = 1
            } else { continue }
        }

        $absOffset = $header + $readOffset
        $zenVal = Read-ZenValue -Bytes $Bytes -Offset $absOffset -Type $readType -Count $readCount -Size $readSize -EnumSizes $EnumSizes
        $jsonVal = Find-JsonProperty -Container $JsonProps -Name $lookupName
        if ($null -eq $jsonVal) {
            if (-not $notInJson.Contains($f.name)) { $notInJson.Add($f.name) }
            continue
        }
        $totalFieldsChecked++
        if (Compare-Values -Expected $jsonVal -Actual $zenVal) { $totalFieldsMatched++ }
        else {
            $mismatches.Add(@{
                field = $f.name; offset = $absOffset
                jsonVal = ($jsonVal | Out-String).Trim()
                zenVal  = ($zenVal | Out-String).Trim()
            })
        }
    }
    $Result.totalFieldsChecked = $totalFieldsChecked
    $Result.totalFieldsMatched = $totalFieldsMatched
    $Result.mismatches = $mismatches.ToArray()
    $Result.notInJson  = $notInJson.ToArray()
    if ($totalFieldsChecked -eq 0) { $Result.status = 'fail'; $Result.reason = 'No fields checked' }
    elseif ($mismatches.Count -eq 0) { $Result.status = 'pass' }
    else { $Result.status = 'partial' }
}

function Test-SingleRecordArray {
    param([byte[]] $Bytes, [pscustomobject] $Schema, $JsonProps, [hashtable] $Result, [hashtable] $EnumSizes = @{})
    # JSON: Properties.Data[N].Value[M]  (each entry has a single 'Value' array of 10 ushorts)
    $dataArr = $JsonProps.Data
    if (-not $dataArr) { $Result.status = 'fail'; $Result.reason = 'JSON has no Properties.Data'; return }
    $header = [int]$Schema.headerSize
    $stride = [int]$Schema.repeatStride
    $repeatCount = [int]$Schema.repeatCount
    $sampleTotal = [Math]::Min($repeatCount, $dataArr.Count)
    $indices = Get-SampleIndices -Total $sampleTotal

    $totalFieldsChecked = 0; $totalFieldsMatched = 0
    $mismatches = New-Object System.Collections.Generic.List[hashtable]

    # The schema fields are named value, value2, value3, ... value10 — each ushort.
    # JSON's Value[] has them in order. Map schema field index -> JSON array index.
    $fields = @($Schema.fields | Where-Object { $_.kind -eq 'scalar' })
    foreach ($repIdx in $indices) {
        $recStart = $header + $repIdx * $stride
        $jsonRow = $dataArr[$repIdx]
        $jsonValueArr = Find-JsonProperty -Container $jsonRow -Name 'Value'
        if (-not $jsonValueArr) {
            $Result.status = 'fail'; $Result.reason = "JSON Data[$repIdx] has no Value array"; return
        }
        for ($fi = 0; $fi -lt $fields.Count; $fi++) {
            $f = $fields[$fi]
            if ($fi -ge $jsonValueArr.Count) { break }
            $absOffset = $recStart + [int]$f.offset
            $zenVal = Read-ZenValue -Bytes $Bytes -Offset $absOffset -Type $f.type -Count 1 -Size ([int]$f.size) -EnumSizes $EnumSizes
            $jsonVal = $jsonValueArr[$fi]
            $totalFieldsChecked++
            if (Compare-Values -Expected $jsonVal -Actual $zenVal) { $totalFieldsMatched++ }
            else {
                $mismatches.Add(@{
                    repIdx = $repIdx; field = $f.name; offset = $absOffset
                    jsonVal = $jsonVal; zenVal = $zenVal
                })
            }
        }
    }
    $Result.totalFieldsChecked = $totalFieldsChecked
    $Result.totalFieldsMatched = $totalFieldsMatched
    $Result.mismatches = $mismatches.ToArray()
    $Result.sampledRows = $indices
    if ($totalFieldsChecked -eq 0) { $Result.status = 'fail'; $Result.reason = 'No fields checked' }
    elseif ($mismatches.Count -eq 0) { $Result.status = 'pass' }
    else { $Result.status = 'partial' }
}

# --------------------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------------------

$schemaFiles = Get-ChildItem $SchemasDir -Filter '*_schema.json' -File | Sort-Object Name
"=== Running regression on $($schemaFiles.Count) schemas ==="

$report = New-Object System.Collections.Generic.List[hashtable]
$passCount = 0; $partialCount = 0; $failCount = 0; $skipCount = 0
$goldenFailures = @()

foreach ($sf in $schemaFiles) {
    $key = $sf.BaseName -replace '_schema$',''
    $schema = Get-Content $sf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json

    $result = @{
        template   = $sf.Name
        key        = $key
        shape      = $schema.tableShape
        status     = $null
        reason     = $null
        totalFieldsChecked = 0
        totalFieldsMatched = 0
        mismatches = @()
        notInJson  = @()
        sampledRows = @()
    }

    if ($key -in $Script:SkipKeys) {
        $result.status = 'skip'; $result.reason = 'deprecated dat-* duplicate (canonical sibling covers it)'
        $skipCount++
        $report.Add($result)
        Write-Host ("  SKIP {0,-50}  {1}" -f $sf.Name, $result.reason) -ForegroundColor DarkGray
        # Persist status to schema
        $schema | Add-Member -NotePropertyName regressionStatus -NotePropertyValue 'skip' -Force
        $schema | Add-Member -NotePropertyName regressionReason -NotePropertyValue $result.reason -Force
        $json = $schema | ConvertTo-Json -Depth 12
        [System.IO.File]::WriteAllText($sf.FullName, $json)
        continue
    }

    if ($schema.calibrationStatus -ne 'ok') {
        $result.status = 'skip'; $result.reason = "schema not calibrated (status=$($schema.calibrationStatus))"
        $skipCount++
        $report.Add($result)
        Write-Host ("  SKIP {0,-50}  {1}" -f $sf.Name, $result.reason) -ForegroundColor DarkGray
        $schema | Add-Member -NotePropertyName regressionStatus -NotePropertyValue 'skip' -Force
        $schema | Add-Member -NotePropertyName regressionReason -NotePropertyValue $result.reason -Force
        $json = $schema | ConvertTo-Json -Depth 12
        [System.IO.File]::WriteAllText($sf.FullName, $json)
        continue
    }

    # Resolve Zen bytes
    $assetPath = $schema.sourceAssetPath
    if (-not $assetPath -or -not (Test-Path $assetPath)) {
        $result.status = 'skip'; $result.reason = "source asset not found: $assetPath"
        $skipCount++
        $report.Add($result)
        Write-Host ("  SKIP {0,-50}  {1}" -f $sf.Name, $result.reason) -ForegroundColor DarkGray
        $schema | Add-Member -NotePropertyName regressionStatus -NotePropertyValue 'skip' -Force
        $schema | Add-Member -NotePropertyName regressionReason -NotePropertyValue $result.reason -Force
        $json = $schema | ConvertTo-Json -Depth 12
        [System.IO.File]::WriteAllText($sf.FullName, $json)
        continue
    }
    $bytes = [System.IO.File]::ReadAllBytes($assetPath)

    # Resolve JSON
    $jsonRel = $Script:JsonByTemplate[$key]
    $jsonPath = if ($jsonRel) { Join-Path $JsonRoot $jsonRel } else { $null }
    if (-not $jsonPath -or -not (Test-Path $jsonPath)) {
        $result.status = 'skip'; $result.reason = "no CUE4Parse JSON available for $key"
        $skipCount++
        $report.Add($result)
        Write-Host ("  SKIP {0,-50}  {1}" -f $sf.Name, $result.reason) -ForegroundColor DarkGray
        $schema | Add-Member -NotePropertyName regressionStatus -NotePropertyValue 'skip' -Force
        $schema | Add-Member -NotePropertyName regressionReason -NotePropertyValue $result.reason -Force
        $json = $schema | ConvertTo-Json -Depth 12
        [System.IO.File]::WriteAllText($sf.FullName, $json)
        continue
    }
    $jsonObj = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $jsonProps = $jsonObj.Properties

    # Dispatch by shape
    # enumSizes comes back from JSON as PSCustomObject — convert to a real hashtable
    $enumSizes = @{}
    if ($schema.PSObject.Properties['enumSizes'] -and $schema.enumSizes) {
        foreach ($p in $schema.enumSizes.PSObject.Properties) {
            $enumSizes[$p.Name] = [int]$p.Value
        }
    }
    try {
        switch ($schema.tableShape) {
            'indexed_rows'        { Test-IndexedRows       -Bytes $bytes -Schema $schema -JsonProps $jsonProps -Result $result -EnumSizes $enumSizes }
            'named_rows'          { Test-NamedRows         -Bytes $bytes -Schema $schema -JsonRoot2 $jsonObj  -Result $result -EnumSizes $enumSizes }
            'single_record'       { Test-SingleRecord      -Bytes $bytes -Schema $schema -JsonProps $jsonProps -Result $result -EnumSizes $enumSizes }
            'single_record_array' { Test-SingleRecordArray -Bytes $bytes -Schema $schema -JsonProps $jsonProps -Result $result -EnumSizes $enumSizes }
            default { $result.status = 'fail'; $result.reason = "unknown tableShape: $($schema.tableShape)" }
        }
    } catch {
        $result.status = 'fail'; $result.reason = "exception: $($_.Exception.Message)"
    }

    # Compute pass rate
    $passRate = if ($result.totalFieldsChecked -gt 0) {
        [Math]::Round(100.0 * $result.totalFieldsMatched / $result.totalFieldsChecked, 1)
    } else { 0.0 }

    # Update counters
    switch ($result.status) {
        'pass'    { $passCount++;    $color = 'Green'  }
        'partial' { $partialCount++; $color = 'Yellow' }
        'fail'    { $failCount++;    $color = 'Red'    }
        default   { $color = 'Gray' }
    }

    # Golden anchor check
    $anchor = $Script:GoldenAnchors | Where-Object { $_.key -eq $key } | Select-Object -First 1
    $anchorStatus = 'n/a'
    if ($anchor) {
        # Find the field in mismatches
        $hit = @($result.mismatches | Where-Object { $_.row -eq $anchor.row -and $_.field -eq $anchor.field })
        if ($hit.Count -eq 0 -and $result.status -ne 'fail') {
            $anchorStatus = 'PASS'
        } else {
            $anchorStatus = 'FAIL'
            $goldenFailures += "$key : row=$($anchor.row) field=$($anchor.field) expected=$($anchor.expected)"
        }
    }

    $line = '  {0,-4} {1,-50}  shape={2,-22}  {3,5}/{4,5} ({5,5}%)  anchor={6}' -f `
        $result.status.ToUpper().Substring(0,4), $sf.Name, $schema.tableShape,
        $result.totalFieldsMatched, $result.totalFieldsChecked, $passRate, $anchorStatus
    Write-Host $line -ForegroundColor $color

    # Persist to schema JSON
    $schema | Add-Member -NotePropertyName regressionStatus   -NotePropertyValue $result.status -Force
    $schema | Add-Member -NotePropertyName regressionPassRate -NotePropertyValue $passRate -Force
    $schema | Add-Member -NotePropertyName regressionFieldsChecked -NotePropertyValue $result.totalFieldsChecked -Force
    $schema | Add-Member -NotePropertyName regressionFieldsMatched -NotePropertyValue $result.totalFieldsMatched -Force
    if ($result.mismatches.Count -gt 0) {
        $schema | Add-Member -NotePropertyName regressionMismatches -NotePropertyValue $result.mismatches -Force
    }
    if ($result.notInJson.Count -gt 0) {
        $schema | Add-Member -NotePropertyName regressionNotInJson -NotePropertyValue $result.notInJson -Force
    }
    if ($result.reason) {
        $schema | Add-Member -NotePropertyName regressionReason -NotePropertyValue $result.reason -Force
    }
    $json = $schema | ConvertTo-Json -Depth 12
    [System.IO.File]::WriteAllText($sf.FullName, $json)

    $report.Add($result)
}

Write-Host ""
Write-Host ("=== Result: {0} pass / {1} partial / {2} fail / {3} skip (of {4} schemas) ===" -f `
    $passCount, $partialCount, $failCount, $skipCount, $schemaFiles.Count) -ForegroundColor Cyan

if ($goldenFailures.Count -gt 0) {
    Write-Host ""
    Write-Host "!!! GOLDEN ANCHOR FAILURES !!!" -ForegroundColor Red
    foreach ($g in $goldenFailures) { Write-Host "  $g" -ForegroundColor Red }
} else {
    Write-Host "Golden anchors: all PASS" -ForegroundColor Green
}

# --------------------------------------------------------------------------------------
# Report
# --------------------------------------------------------------------------------------

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine('# Schema Regression Report')
[void]$md.AppendLine('')
[void]$md.AppendLine('> Generated by [Test-SchemaRegression.ps1](../scripts/Test-SchemaRegression.ps1) -- Sprint 1.5 T1.5.4.')
[void]$md.AppendLine('')
[void]$md.AppendLine("**Summary**: $passCount pass / $partialCount partial / $failCount fail / $skipCount skip (of $($schemaFiles.Count) schemas).")
[void]$md.AppendLine('')
[void]$md.AppendLine('Each calibrated schema is regression-tested by decoding fields from the Zen ``.uasset`` bytes and comparing against the CUE4Parse JSON. Sampled rows: 0, 1, middle, last, plus golden anchor rows.')
[void]$md.AppendLine('')
[void]$md.AppendLine('Status legend: `[PASS]` all sampled fields match, `[PART]` some mismatches, `[FAIL]` structural error, `[SKIP]` deprecated / not calibrated / no JSON.')
[void]$md.AppendLine('')
[void]$md.AppendLine('| Status | Template | Shape | Matched | Checked | Pass% | Notes |')
[void]$md.AppendLine('|:---:|---|---|---:|---:|---:|---|')

foreach ($r in ($report | Sort-Object @{e={$_.status -ne 'pass'}}, key)) {
    $glyph = switch ($r.status) {
        'pass'    { '[PASS]' }
        'partial' { '[PART]' }
        'fail'    { '[FAIL]' }
        'skip'    { '[SKIP]' }
        default   { '[??]' }
    }
    $passPct = if ($r.totalFieldsChecked -gt 0) { '{0:F1}' -f (100.0 * $r.totalFieldsMatched / $r.totalFieldsChecked) } else { '-' }
    $note = if ($r.reason) { (ConvertTo-AsciiSafe $r.reason) } else { '' }
    if ($r.mismatches.Count -gt 0) { $note = "$($r.mismatches.Count) mismatch(es)" }
    [void]$md.AppendLine("| $glyph | ``$($r.template)`` | $($r.shape) | $($r.totalFieldsMatched) | $($r.totalFieldsChecked) | $passPct | $note |")
}

# Mismatch detail section
$anyMismatches = $false
foreach ($r in $report) {
    if ($r.mismatches.Count -gt 0) {
        if (-not $anyMismatches) {
            [void]$md.AppendLine('')
            [void]$md.AppendLine('## Mismatch details')
            [void]$md.AppendLine('')
            $anyMismatches = $true
        }
        [void]$md.AppendLine("### ``$($r.template)`` ($($r.shape))")
        [void]$md.AppendLine('')
        [void]$md.AppendLine('| Row | Field | File offset | JSON value | Zen value |')
        [void]$md.AppendLine('|---|---|---:|---|---|')
        foreach ($m in $r.mismatches) {
            $row = if ($m.row) { $m.row } elseif ($m.repIdx) { $m.repIdx } else { '-' }
            $jv = (ConvertTo-AsciiSafe ($m.jsonVal | Out-String).Trim())
            $zv = (ConvertTo-AsciiSafe ($m.zenVal  | Out-String).Trim())
            [void]$md.AppendLine("| $row | $($m.field) | 0x$('{0:X}' -f $m.offset) | $jv | $zv |")
        }
        [void]$md.AppendLine('')
    }
}

# not_in_json section (informational)
$anyNotInJson = $false
foreach ($r in $report) {
    if ($r.notInJson.Count -gt 0) {
        if (-not $anyNotInJson) {
            [void]$md.AppendLine('')
            [void]$md.AppendLine('## Fields not present in JSON (informational, not failures)')
            [void]$md.AppendLine('')
            [void]$md.AppendLine('These schema fields have no corresponding CUE4Parse JSON key. Common reasons: bitfield group members (aggregated into a single int in JSON), nested struct fields CUE4Parse flattens away, or fields the template exposes but CUE4Parse does not.')
            [void]$md.AppendLine('')
            $anyNotInJson = $true
        }
        [void]$md.AppendLine("- ``$($r.template)``: " + (($r.notInJson | Select-Object -First 12) -join ', '))
    }
}

[void]$md.AppendLine('')
[void]$md.AppendLine('## Golden anchors')
[void]$md.AppendLine('')
[void]$md.AppendLine('These MUST pass or the regression run is considered failed:')
[void]$md.AppendLine('')
foreach ($a in $Script:GoldenAnchors) {
    $r = $report | Where-Object { $_.key -eq $a.key } | Select-Object -First 1
    $hit = if ($r) {
        $m = @($r.mismatches | Where-Object { $_.row -eq $a.row -and $_.field -eq $a.field })
        if ($m.Count -eq 0 -and $r.status -ne 'fail') { 'PASS' } else { 'FAIL' }
    } else { 'NOT RUN' }
    [void]$md.AppendLine("- ``$($a.key)`` row=$($a.row) field=$($a.field) expected=$($a.expected) -- **$hit** ($($a.label))")
}

[System.IO.File]::WriteAllText($ReportPath, $md.ToString())
Write-Host "Report written: $ReportPath" -ForegroundColor Green
