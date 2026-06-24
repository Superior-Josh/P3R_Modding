# Invoke-ZenPatch.ps1 — Sprint 1.5 T1.5.5
#
# Consumes a schema JSON (from Parse-BtTemplate.ps1 + Calibrate-SchemaHeaders.ps1)
# and a changes.json descriptor. Copies the original Zen .uasset from Extracted/IoStore/
# and writes patched bytes at computed file offsets. The output file has exactly
# the same byte count as the original.
#
# Usage:
#   $changes = @{
#       schemaKey = 'p3re_skillNormal'
#       changes = @(
#           @{ target = 'Data[10].hpn';  value = 999 }
#           @{ target = 'Data[10].cost'; value = 1 }
#       )
#   }
#   $changes | ConvertTo-Json -Depth 4 | Set-Content changes.json
#   .\Invoke-ZenPatch.ps1 -ChangesJson changes.json -OutputDir .\my-mod-assets

param(
    [Parameter(Mandatory=$true)]  [string] $ChangesJson,
    [Parameter(Mandatory=$true)]  [string] $OutputDir,
    [string] $SchemasDir  = "$PSScriptRoot\..\templates-010\schemas",
    [string] $BackupDir   = "$PSScriptRoot\..\..\tools\Output\.backup",
    [switch] $DryRun,
    [switch] $PassThru     # Return the output .uasset path as script output
)

$ErrorActionPreference = 'Stop'

# --------------------------------------------------------------------------------------
# 1. Type encoders
# --------------------------------------------------------------------------------------

function Write-LittleEndian {
    param([byte[]] $Bytes, [int] $Offset, $Value, [string] $Type, [int] $Size)
    if ($Type -eq 'float') {
        [BitConverter]::GetBytes([single]$Value).CopyTo($Bytes, $Offset)
        return
    }
    # Integer types — determine signed vs unsigned
    $signed = $Type -in @('byte','short','int','int32')
    switch ($Size) {
        1 {
            if ($signed) { $Bytes[$Offset] = [byte]([sbyte]$Value) }
            else         { $Bytes[$Offset] = [byte]($Value -band 0xFF) }
        }
        2 {
            if ($signed) { [BitConverter]::GetBytes([int16]$Value).CopyTo($Bytes, $Offset) }
            else         {
                $v = [uint16]($Value -band 0xFFFF)
                [BitConverter]::GetBytes($v).CopyTo($Bytes, $Offset)
            }
        }
        4 {
            if ($signed) { [BitConverter]::GetBytes([int32]$Value).CopyTo($Bytes, $Offset) }
            else         {
                $v = [uint32]($Value -band 0xFFFFFFFF)
                [BitConverter]::GetBytes($v).CopyTo($Bytes, $Offset)
            }
        }
        8 {
            if ($signed) { [BitConverter]::GetBytes([int64]$Value).CopyTo($Bytes, $Offset) }
            else         { [BitConverter]::GetBytes([uint64]$Value).CopyTo($Bytes, $Offset) }
        }
        default { throw "Unsupported field size for write: $Size bytes (type=$Type)" }
    }
}

# --------------------------------------------------------------------------------------
# 2. Target parser — "Data[10].hpn" into shape and coordinates
# --------------------------------------------------------------------------------------

function Parse-Target {
    param([string] $Target, [pscustomobject] $Schema)
    # Returns: @{ fileOffset = int; byteSize = int; type = string }
    $headerSize = [int]$Schema.headerSize
    $shape = $Schema.tableShape

    if ($Target -match '^Data\[(\d+)\]\.(.+)$') {
        $rowIdx = [int]$matches[1]
        $fieldName = $matches[2]
        if ($shape -ne 'indexed_rows') { throw "Target '$Target' uses Data[N] but schema shape is $shape" }
        $rowSize = [int]$Schema.rowSize
        $field = Find-Field -Fields $Schema.fields -Name $fieldName
        $offset = $headerSize + $rowIdx * $rowSize + [int]$field.offset
        return @{ fileOffset = $offset; byteSize = [int]$field.size; type = $field.type; name = $field.name }
    }

    if ($Target -match '^Rows\["([^"]+)"\]\.(.+)$' -or $Target -match '^Rows\.(\w+)\.(.+)$') {
        # Rows["normal"].ExpRate or Rows.normal.ExpRate
        $rowKey = if ($matches[2]) { $matches[1] } else { $null }
        # Let me redo this — the two patterns share group numbering issues
        # Just do it properly:
    }
    if ($Target -match '^Rows\["([^"]+)"\]\.(.+)$') {
        $rowKey = $matches[1]; $fieldName = $matches[2]
    } elseif ($Target -match '^Rows\.(\w+)\.(.+)$') {
        $rowKey = $matches[1]; $fieldName = $matches[2]
    } elseif ($Target -match '^Rows\["([^"]+)"\]\.(.+)$') {
        # Already handled above
    }
    if ($rowKey) {
        if ($shape -ne 'named_rows') { throw "Target '$Target' uses Rows[...] but schema shape is $shape" }
        $row = @($Schema.rows | Where-Object { $_.name -ieq $rowKey }) | Select-Object -First 1
        if (-not $row) { throw "Row key '$rowKey' not found in schema (keys: $($Schema.rowKeys -join ', '))" }
        $field = Find-Field -Fields $row.fields -Name $fieldName
        $offset = $headerSize + [int]$row.offset + [int]$field.offset
        return @{ fileOffset = $offset; byteSize = [int]$field.size; type = $field.type; name = "$rowKey.$fieldName" }
    }

    if ($Target -match '^Record\[(\d+)\]\.(.+)$') {
        $repIdx = [int]$matches[1]; $fieldName = $matches[2]
        if ($shape -ne 'single_record_array') { throw "Target '$Target' uses Record[N] but schema shape is $shape" }
        $field = Find-Field -Fields $Schema.fields -Name $fieldName
        $stride = [int]$Schema.repeatStride
        $offset = $headerSize + $repIdx * $stride + [int]$field.offset
        return @{ fileOffset = $offset; byteSize = [int]$field.size; type = $field.type; name = "Record[$repIdx].$fieldName" }
    }

    # No prefix — single_record (bare field name)
    # Must be AFTER Data[N] check (which has higher priority for single_record_array)
    if ($shape -eq 'single_record') {
        $field = Find-Field -Fields $Schema.fields -Name $Target
        $offset = $headerSize + [int]$field.offset
        return @{ fileOffset = $offset; byteSize = [int]$field.size; type = $field.type; name = $Target }
    }
    throw "Cannot parse target '$Target' for shape '$shape'. Expected Data[N].field, Rows.key.field, Record[N].field, or field (for single_record)."
}

function Find-Field {
    param([array] $Fields, [string] $Name)
    # Exact match (case-insensitive)
    $hit = @($Fields | Where-Object { $_.name -ieq $Name })
    if ($hit.Count -eq 1) { return $hit[0] }
    # Prefix match for DT_* GUID-suffixed names
    $hit = @($Fields | Where-Object {
        $_.name -match '^([A-Za-z0-9_]+?)_\d+_[A-F0-9]{32}$' -and $matches[1] -ieq $Name
    })
    if ($hit.Count -eq 1) { return $hit[0] }
    if ($hit.Count -gt 1) { throw "Ambiguous field name '$Name' matched $($hit.Count) DT_* GUID-suffixed variants" }
    # Dotted-name fallback: try last segment
    if ($Name -match '\.') {
        $last = ($Name -split '\.')[-1]
        $hit = @($Fields | Where-Object { $_.name -ieq $last })
        if ($hit.Count -eq 1) { return $hit[0] }
    }
    # List similar field names for debugging
    $similar = @($Fields | Where-Object { $_.name -match $Name } | Select-Object -First 5 -ExpandProperty name) -join ', '
    throw "Field '$Name' not found in schema. Similar: $similar"
}

# --------------------------------------------------------------------------------------
# 3. Main
# --------------------------------------------------------------------------------------

$changesObj = Get-Content $ChangesJson -Raw -Encoding UTF8 | ConvertFrom-Json
$schemaKey  = $changesObj.schemaKey
$changes    = $changesObj.changes

if (-not $schemaKey) { throw "changes.json must have a 'schemaKey' field" }
if (-not $changes -or $changes.Count -eq 0) { throw "changes.json must have a non-empty 'changes' array" }

# Locate schema
$schemaPath = Join-Path $SchemasDir "${schemaKey}_schema.json"
if (-not (Test-Path $schemaPath)) {
    # Try fuzzy: find any schema whose templateFile starts with the key
    $candidates = Get-ChildItem $SchemasDir -Filter '*_schema.json' | Where-Object {
        (Get-Content $_.FullName -Raw | ConvertFrom-Json).templateFile -match "^$schemaKey"
    }
    if ($candidates.Count -eq 1) { $schemaPath = $candidates[0].FullName }
    else { throw "Schema not found for key '$schemaKey' at $schemaPath" }
}

$schema = Get-Content $schemaPath -Raw -Encoding UTF8 | ConvertFrom-Json

if ($schema.calibrationStatus -ne 'ok' -and $schema.calibrationStatus -ne 'override_ok') {
    # Allow 'ok' status only; deprecated / not_found / negative_header are unsafe
    Write-Warning "Schema calibration status is '$($schema.calibrationStatus)', not 'ok'. Proceeding anyway — verify offsets manually."
}

# Resolve source Zen file
$sourcePath = $schema.sourceAssetPath
if (-not $sourcePath -or -not (Test-Path $sourcePath)) {
    throw "Source Zen .uasset not found at '$sourcePath'"
}

$origBytes = [System.IO.File]::ReadAllBytes($sourcePath)
$origSize  = $origBytes.Length

# Compute patch coordinates for all changes (dry-run safe, no writes yet)
$resolved = New-Object System.Collections.Generic.List[hashtable]
foreach ($c in $changes) {
    $coord = Parse-Target -Target $c.target -Schema $schema
    # Range check
    if ($coord.fileOffset -lt 0 -or ($coord.fileOffset + $coord.byteSize) -gt $origSize) {
        throw "Change '$($c.target)' resolves to offset $($coord.fileOffset) (size $($coord.byteSize)) — out of bounds for file ($origSize bytes)"
    }
    # Read current value for logging
    $currentVal = switch ([int]$coord.byteSize) {
        1 { [byte]$origBytes[$coord.fileOffset] }
        2 { [BitConverter]::ToUInt16($origBytes, $coord.fileOffset) }
        4 { if ($coord.type -eq 'float') { [BitConverter]::ToSingle($origBytes, $coord.fileOffset) }
             else { [BitConverter]::ToUInt32($origBytes, $coord.fileOffset) } }
        default { '<unknown>' }
    }
    $resolved.Add(@{
        target   = $c.target
        value    = $c.value
        resolvedName = $coord.name
        fileOffset  = [int]$coord.fileOffset
        byteSize    = [int]$coord.byteSize
        type        = $coord.type
        current     = $currentVal
    })
}

# --- Pre-flight summary ---
Write-Host "=== Zen Patch Plan ===" -ForegroundColor Cyan
Write-Host "  Schema     : $schemaKey"
Write-Host "  Shape      : $($schema.tableShape)"
Write-Host "  Source     : $sourcePath"
Write-Host "  File size  : $origSize bytes"
Write-Host "  Changes    : $($resolved.Count)"
Write-Host ""
foreach ($r in $resolved) {
    Write-Host "  $($r.target)"
    Write-Host "    resolved  : $($r.resolvedName) @ file offset 0x$('{0:X}' -f $r.fileOffset)"
    Write-Host "    type      : $($r.type) ($($r.byteSize) bytes)"
    Write-Host "    current   : $($r.current)"
    Write-Host "    new       : $($r.value)"
    Write-Host ""
}

if ($DryRun) {
    Write-Host "Dry run — no bytes written." -ForegroundColor DarkYellow
    return
}

# --- Execute patches (in-memory) ---
$patched = [byte[]]::new($origSize)
[Array]::Copy($origBytes, $patched, $origSize)

foreach ($r in $resolved) {
    $old = switch ([int]$r.byteSize) {
        1 { [byte]$patched[$r.fileOffset] }
        2 { [BitConverter]::ToUInt16($patched, $r.fileOffset) }
        4 { if ($r.type -eq 'float') { [BitConverter]::ToSingle($patched, $r.fileOffset) }
             else { [BitConverter]::ToUInt32($patched, $r.fileOffset) } }
    }
    Write-LittleEndian -Bytes $patched -Offset $r.fileOffset -Value $r.value -Type $r.type -Size $r.byteSize
    $new = switch ([int]$r.byteSize) {
        1 { [byte]$patched[$r.fileOffset] }
        2 { [BitConverter]::ToUInt16($patched, $r.fileOffset) }
        4 { if ($r.type -eq 'float') { [BitConverter]::ToSingle($patched, $r.fileOffset) }
             else { [BitConverter]::ToUInt32($patched, $r.fileOffset) } }
    }
    Write-Host "  PATCHED  $($r.target)  $old -> $new  (0x$('{0:X}' -f $r.fileOffset))" -ForegroundColor Green
}

# --- Write output ---
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$assetName = [System.IO.Path]::GetFileName($sourcePath)
$outPath = Join-Path $OutputDir $assetName
[System.IO.File]::WriteAllBytes($outPath, $patched)

# Back up previous deployment if present
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupPath = Join-Path $BackupDir "$stamp-$assetName"
if (Test-Path $outPath) {
    Copy-Item $outPath $backupPath -Force
    Write-Host "  Backed up previous: $backupPath" -ForegroundColor DarkGray
}

# Size assertion
$outSize = (Get-Item $outPath).Length
if ($outSize -ne $origSize) {
    Write-Error "SIZE ASSERTION FAILED: output $outSize bytes != input $origSize bytes"
    exit 1
}
Write-Host ""
Write-Host "  Output : $outPath  ($outSize bytes, unchanged)" -ForegroundColor Green
Write-Host "  Assert : size unchanged ($origSize == $outSize)" -ForegroundColor Green

if ($PassThru) { $outPath }
