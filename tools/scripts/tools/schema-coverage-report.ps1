# P3R schema-coverage-report.ps1 - Sprint 4 T4.2
# Summarize 010 schema regression status and generate conservative field allow/deny lists.

param(
    [string] $OutputMarkdown = "$PSScriptRoot\..\..\..\docs\SCHEMA_COVERAGE_REPORT.md",
    [string] $OutputJson = "$PSScriptRoot\..\..\templates-010\schemas\schema-safety-coverage.json",
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\Config.ps1"

function Get-FieldReviewStatus {
    param($Schema, [string] $FieldName)
    foreach ($item in @($Schema.fieldReviewStatus)) {
        $names = @()
        if ($item.field) { $names += [string]$item.field }
        if ($item.fields) { $names += ([string]$item.fields -split '\s*,\s*') }
        if ($names -contains $FieldName) { return $item }
    }
    return $null
}

function Test-AutoSafeField {
    param($Schema, $Field)
    $kind = [string]$Field.kind
    $type = [string]$Field.type
    $size = [int]$Field.size
    if ($kind -ne 'scalar') { return $false }
    if ($size -notin @(1,2,4,8)) { return $false }
    if ($type -match 'string|FString|TArray|array|struct|union') { return $false }
    if ($kind -match 'array|struct|union|string') { return $false }
    $fieldStatus = Get-FieldReviewStatus -Schema $Schema -FieldName ([string]$Field.name)
    if ($fieldStatus -and $fieldStatus.status -eq 'needsManualReview') { return $false }
    if ($Schema.disposition -eq 'deprecatedDuplicate') { return $false }
    if ($Schema.disposition -eq 'unsupportedUntilSchemaFix' -or $Schema.guardPolicy -eq 'blockUntilSchemaFix') { return $false }
    if ($Schema.regressionStatus -in @('fail','skip')) { return $false }
    if ($Schema.calibrationStatus -and $Schema.calibrationStatus -notin @('ok','override_ok')) { return $false }
    if ($Schema.regressionStatus -eq 'partial') { return $false }
    return ($Schema.regressionStatus -eq 'pass' -or $Schema.disposition -eq 'safeWithNormalization')
}

function Get-SchemaFields {
    param($Schema)
    $items = New-Object System.Collections.ArrayList
    if ($Schema.tableShape -eq 'named_rows') {
        foreach ($row in @($Schema.rows)) {
            foreach ($field in @($row.fields)) {
                $null = $items.Add([PSCustomObject]@{ targetPattern = "Rows.$($row.name).$($field.name)"; row = $row.name; field = $field })
            }
        }
    } elseif ($Schema.tableShape -eq 'single_record_array') {
        foreach ($field in @($Schema.fields)) {
            $null = $items.Add([PSCustomObject]@{ targetPattern = "Record[N].$($field.name)"; row = 'N'; field = $field })
        }
    } elseif ($Schema.tableShape -eq 'single_record') {
        foreach ($field in @($Schema.fields)) {
            $null = $items.Add([PSCustomObject]@{ targetPattern = $field.name; row = $null; field = $field })
        }
    } else {
        foreach ($field in @($Schema.fields)) {
            $null = $items.Add([PSCustomObject]@{ targetPattern = "Data[N].$($field.name)"; row = 'N'; field = $field })
        }
    }
    return @($items)
}

$schemaFiles = @(Get-ChildItem $SchemaDir -Filter '*_schema.json' -File | Sort-Object Name)
$schemas = New-Object System.Collections.ArrayList
$allow = New-Object System.Collections.ArrayList
$deny = New-Object System.Collections.ArrayList

foreach ($file in $schemaFiles) {
    $schema = Get-Content $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $fields = @(Get-SchemaFields -Schema $schema)
    $autoSafe = New-Object System.Collections.ArrayList
    $blocked = New-Object System.Collections.ArrayList

    foreach ($entry in $fields) {
        $field = $entry.field
        $review = Get-FieldReviewStatus -Schema $schema -FieldName ([string]$field.name)
        $isSafe = Test-AutoSafeField -Schema $schema -Field $field
        $record = [PSCustomObject]@{
            schema = ($file.Name -replace '_schema\.json$', '')
            targetPattern = $entry.targetPattern
            field = $field.name
            type = $field.type
            kind = $field.kind
            size = $field.size
            status = if ($isSafe) { 'autoSafe' } elseif ($review) { $review.status } elseif ($schema.regressionStatus -eq 'partial') { 'needsManualReview' } else { 'blocked' }
            reason = if ($isSafe) { 'schema pass + flat scalar' } elseif ($review -and $review.reason) { $review.reason } elseif ($schema.regressionReason) { $schema.regressionReason } elseif ($schema.reason) { $schema.reason } else { "schema regressionStatus=$($schema.regressionStatus) disposition=$($schema.disposition)" }
        }
        if ($isSafe) { $null = $autoSafe.Add($record); $null = $allow.Add($record) }
        else { $null = $blocked.Add($record); $null = $deny.Add($record) }
    }

    $null = $schemas.Add([PSCustomObject]@{
        schema = ($file.Name -replace '_schema\.json$', '')
        file = $file.Name
        templateFile = $schema.templateFile
        tableShape = $schema.tableShape
        regressionStatus = $schema.regressionStatus
        regressionPassRate = $schema.regressionPassRate
        calibrationStatus = $schema.calibrationStatus
        disposition = $schema.disposition
        guardPolicy = $schema.guardPolicy
        totalFields = $fields.Count
        autoSafeFields = $autoSafe.Count
        blockedFields = $blocked.Count
        reason = if ($schema.regressionReason) { $schema.regressionReason } else { $schema.reason }
    })
}

$statusGroups = @($schemas | Group-Object regressionStatus | Sort-Object Name | ForEach-Object { [PSCustomObject]@{ status=$_.Name; count=$_.Count } })
$result = [PSCustomObject]@{
    generatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    schemaCount = $schemas.Count
    statusSummary = $statusGroups
    autoSafeFieldCount = $allow.Count
    blockedFieldCount = $deny.Count
    schemas = @($schemas)
    allowlist = @($allow)
    denylist = @($deny)
}

New-Item -ItemType Directory -Force -Path (Split-Path $OutputJson -Parent) | Out-Null
$result | ConvertTo-Json -Depth 12 | Out-File $OutputJson -Encoding UTF8

$lines = New-Object System.Collections.ArrayList
$null = $lines.Add('# 010 Schema Coverage and Safety Field Report')
$null = $lines.Add('')
$null = $lines.Add('> Generated: ' + $result.generatedAt + '  ')
$null = $lines.Add('> Source: `tools/templates-010/schemas/*_schema.json` plus existing regression metadata.  ')
$null = $lines.Add('> Policy: only `regressionStatus=pass` / `safeWithNormalization` flat scalar fields enter the automatic allowlist. PARTIAL schemas remain manual-review by default.')
$null = $lines.Add('')
$null = $lines.Add('## Summary')
$null = $lines.Add('')
$null = $lines.Add('| Metric | Count |')
$null = $lines.Add('|---|---:|')
$null = $lines.Add("| Schemas | $($result.schemaCount) |")
foreach ($g in $statusGroups) { $null = $lines.Add("| $($g.status) schemas | $($g.count) |") }
$null = $lines.Add("| Auto-safe target patterns | $($result.autoSafeFieldCount) |")
$null = $lines.Add("| Blocked/manual target patterns | $($result.blockedFieldCount) |")
$null = $lines.Add('')
$null = $lines.Add('## Schema Status')
$null = $lines.Add('')
$null = $lines.Add('| Schema | Shape | Regression | Pass% | Auto-safe fields | Blocked/manual fields | Policy | Reason |')
$null = $lines.Add('|---|---|---:|---:|---:|---:|---|---|')
foreach ($s in @($schemas | Sort-Object regressionStatus, schema)) {
    $passRate = if ($null -ne $s.regressionPassRate) { $s.regressionPassRate } else { '-' }
    $policy = if ($s.guardPolicy) { $s.guardPolicy } elseif ($s.disposition) { $s.disposition } else { '' }
    $reason = if ($s.reason) { ([string]$s.reason).Replace('|','/') } else { '' }
    $null = $lines.Add("| ``$($s.schema)`` | $($s.tableShape) | $($s.regressionStatus) | $passRate | $($s.autoSafeFields) | $($s.blockedFields) | $policy | $reason |")
}
$null = $lines.Add('')
$null = $lines.Add('## Automatic Allowlist Excerpt')
$null = $lines.Add('')
$null = $lines.Add('Full JSON: `tools/templates-010/schemas/schema-safety-coverage.json`.')
$null = $lines.Add('')
$null = $lines.Add('| Schema | Target pattern | Type | Size |')
$null = $lines.Add('|---|---|---|---:|')
foreach ($a in @($allow | Select-Object -First 80)) {
    $null = $lines.Add("| ``$($a.schema)`` | ``$($a.targetPattern)`` | $($a.type) | $($a.size) |")
}
if ($allow.Count -gt 80) { $null = $lines.Add('| ... | ... | ... | ... |') }
$null = $lines.Add('')
$null = $lines.Add('## Manual Review / Denylist Rules')
$null = $lines.Add('')
$null = $lines.Add('- `partial` schemas are not automatically allowed, even when a field looks scalar; manually verify offsets or improve regression metadata first.')
$null = $lines.Add('- `fail` / `skip` / `deprecatedDuplicate` / `unsupportedUntilSchemaFix` block automatic writes.')
$null = $lines.Add('- `kind != scalar`, `string`, `TArray`, `struct`, `union`, and non 1/2/4/8-byte fields block automatic writes.')
$null = $lines.Add('- Fields with `fieldReviewStatus.status=needsManualReview` require manual review.')
$null = $lines.Add('')
$null = $lines.Add('## Deferred Manual Items')
$null = $lines.Add('')
$null = $lines.Add('See `docs/MANUAL_TEST_TODO.md` MT-104 / MT-105. This report is static coverage analysis and does not replace in-game validation.')

New-Item -ItemType Directory -Force -Path (Split-Path $OutputMarkdown -Parent) | Out-Null
$lines | Out-File $OutputMarkdown -Encoding UTF8

if ($Json) { $result | ConvertTo-Json -Depth 12 }
else {
    Write-Host "Schema coverage report written:" -ForegroundColor Green
    Write-Host "  $OutputMarkdown"
    Write-Host "  $OutputJson"
    Write-Host "Summary: $($result.schemaCount) schemas, $($result.autoSafeFieldCount) auto-safe target patterns, $($result.blockedFieldCount) blocked/manual target patterns."
}
