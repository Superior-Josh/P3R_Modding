# P3R guard-modify.ps1 — schema/field safety guard before Zen byte-patch

param(
    [string] $TableKey,
    [string] $SchemaKey,
    [string] $VirtualPath,
    [string] $ChangesJson,
    [hashtable[]] $Changes,
    [string] $ModName = 'unnamed_mod',
    [switch] $Strict,
    [switch] $CheckBackup,
    [switch] $CheckOutput,
    [string] $OutputAsset,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\Config.ps1"

if ($ChangesJson) {
    if (-not (Test-Path $ChangesJson)) { throw "ChangesJson not found: $ChangesJson" }
    $changesObj = Get-Content $ChangesJson -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($changesObj.schemaKey) { $SchemaKey = $changesObj.schemaKey }
    $changeList = @($changesObj.changes)
} elseif ($Changes) {
    $changeList = @($Changes)
} else {
    $changeList = @()
}

$ctx = Resolve-P3RTableContext -TableKey $TableKey -SchemaKey $SchemaKey -VirtualPath $VirtualPath
$schema = $ctx.Schema
$issues = New-Object System.Collections.ArrayList

function Add-Issue {
    param([string] $Level, [string] $Code, [string] $Message, [string] $Target)
    $null = $issues.Add([PSCustomObject]@{ level=$Level; code=$Code; message=$Message; target=$Target })
}

# schema-level guard
if ($schema.disposition -eq 'deprecatedDuplicate') {
    Add-Issue 'error' 'deprecatedDuplicate' "Deprecated duplicate schema. Use canonical schema: $($schema.canonicalSchema)" $null
}
if ($schema.disposition -eq 'unsupportedUntilSchemaFix' -or $schema.guardPolicy -eq 'blockUntilSchemaFix') {
    Add-Issue 'error' 'unsupportedSchema' ($schema.reason) $null
}
if ($schema.regressionStatus -in @('fail','skip')) {
    Add-Issue 'error' 'regressionNotSafe' "Schema regressionStatus=$($schema.regressionStatus); automatic write is blocked." $null
}
if ($schema.calibrationStatus -and $schema.calibrationStatus -notin @('ok','override_ok')) {
    Add-Issue 'error' 'calibrationNotOk' "Schema calibrationStatus=$($schema.calibrationStatus)." $null
}
if ($schema.regressionStatus -eq 'partial' -or $schema.disposition -eq 'needsManualReview') {
    Add-Issue 'warning' 'partialSchema' "Schema requires field-level review: $($schema.reason)" $null
}

foreach ($c in $changeList) {
    if (-not $c.target) { Add-Issue 'error' 'invalidChange' 'Change has no target.' $null; continue }
    try {
        $rt = Resolve-P3RTarget -Target ([string]$c.target) -Schema $schema
        $field = $rt.Field
        $kind = [string]$field.kind
        $type = [string]$field.type
        if ($kind -ne 'scalar') {
            Add-Issue 'error' 'nonScalarField' "Only flat scalar fields are auto-safe. Field kind=$kind." $c.target
        }
        if ($type -match 'string|FString|TArray|array|struct|union' -or $kind -match 'array|struct|union|string') {
            Add-Issue 'error' 'variableOrCompositeField' "Variable/composite fields are blocked by Sprint 2 guard." $c.target
        }
        if ([int]$rt.ByteSize -notin @(1,2,4,8)) {
            Add-Issue 'error' 'unsupportedByteSize' "Unsupported byte size: $($rt.ByteSize)." $c.target
        }

        $fieldStatus = @($schema.fieldReviewStatus | Where-Object {
            $names = @()
            if ($_.field) { $names += $_.field }
            if ($_.fields) { $names += ([string]$_.fields -split '\s*,\s*') }
            $names -contains $field.name -or $names -contains $rt.FieldName
        }) | Select-Object -First 1
        if ($fieldStatus -and $fieldStatus.status -eq 'needsManualReview') {
            Add-Issue 'error' 'fieldNeedsManualReview' $fieldStatus.reason $c.target
        }

        if ($schema.regressionStatus -eq 'partial' -and -not $fieldStatus -and $Strict) {
            Add-Issue 'error' 'partialSchemaStrict' 'Strict mode blocks unreviewed fields on PARTIAL schemas.' $c.target
        }
    } catch {
        Add-Issue 'error' 'targetResolveFailed' $_.Exception.Message $c.target
    }
}

# registry conflict hint: same mod/table already exists
if ($CheckBackup) {
    $backupRoot = Join-Path $BackupDir $ModName
    $backupCount = if (Test-Path $backupRoot) { @(Get-ChildItem $backupRoot -Directory -ErrorAction SilentlyContinue).Count } else { 0 }
    if ($backupCount -eq 0) { Add-Issue 'warning' 'noBackupFound' "No backup exists yet for '$ModName'. Pipeline will create one when a source directory exists." $null }
}

if ($CheckOutput -and $OutputAsset) {
    if (-not (Test-Path $OutputAsset)) {
        Add-Issue 'error' 'outputMissing' "Output asset not found: $OutputAsset" $null
    } else {
        if ([System.IO.Path]::GetExtension($OutputAsset) -ieq '.uexp') { Add-Issue 'error' 'uexpNotAllowed' 'Zen loose-file path must not output .uexp.' $OutputAsset }
        $source = Join-Path $ZenSourceRoot ($ctx.VirtualPath -replace '/', '\')
        if (Test-Path $source) {
            $srcLen = (Get-Item $source).Length
            $outLen = (Get-Item $OutputAsset).Length
            if ($srcLen -ne $outLen) { Add-Issue 'error' 'zenSizeChanged' "Output size changed: source=$srcLen output=$outLen." $OutputAsset }
        }
    }
}

$registry = Read-P3RRegistry
$existing = @($registry.mods | Where-Object { $_.modName -eq $ModName -and $_.virtualPath -eq $ctx.VirtualPath })
if ($existing.Count -gt 0) {
    Add-Issue 'warning' 'sameModAlreadyRegistered' "Registry already has $($existing.Count) entry for this mod/table." $null
}

$hasError = @($issues | Where-Object { $_.level -eq 'error' }).Count -gt 0
$result = [PSCustomObject]@{
    ok          = -not $hasError
    modName     = $ModName
    tableKey    = $ctx.TableKey
    schemaKey   = $ctx.SchemaKey
    virtualPath = $ctx.VirtualPath
    disposition = $schema.disposition
    guardPolicy = $schema.guardPolicy
    regressionStatus = $schema.regressionStatus
    issues      = @($issues)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 8
} else {
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  Safety Guard - Pre-Modification Check" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "Mod    : $ModName"
    Write-Host "Table  : $($ctx.TableKey)"
    Write-Host "Schema : $($ctx.SchemaKey)  regression=$($schema.regressionStatus)  disposition=$($schema.disposition)"
    Write-Host "VPath  : $($ctx.VirtualPath)"
    Write-Host ""
    if ($issues.Count -eq 0) {
        Write-Host "  [OK] Guard passed." -ForegroundColor Green
    } else {
        foreach ($i in $issues) {
            $color = if ($i.level -eq 'error') { 'Red' } else { 'Yellow' }
            Write-Host "  [$($i.level.ToUpperInvariant())] $($i.code) $($i.target)" -ForegroundColor $color
            Write-Host "    $($i.message)" -ForegroundColor $color
        }
    }
}

if ($hasError) { exit 2 }
