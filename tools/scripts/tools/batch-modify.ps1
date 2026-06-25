# P3R batch-modify.ps1 - Sprint 4 T4.3
# Build filtered bulk changes, then delegate to modify-and-repack.ps1.

param(
    [string] $TableKey,
    [string] $SchemaKey,
    [string] $VirtualPath,
    [Parameter(Mandatory=$true)][string] $Field,
    [Parameter(Mandatory=$true)] $Value,
    [string] $WhereField,
    [string] $WhereOperator = 'eq',
    $WhereValue,
    [int[]] $Ids,
    [string] $ModName = 'BatchMod',
    [string] $ModDisplayName,
    [string] $ModDescription,
    [string] $OutputChangesJson,
    [switch] $PreviewOnly,
    [switch] $NoInstall,
    [switch] $DryRun,
    [switch] $Force,
    [switch] $SkipGuard,
    [switch] $SkipConflictCheck
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\Config.ps1"

function Test-P3RCondition {
    param($Actual, [string] $Operator, $Expected)
    switch ($Operator.ToLowerInvariant()) {
        'eq' { return ([string]$Actual -eq [string]$Expected) }
        'ne' { return ([string]$Actual -ne [string]$Expected) }
        'gt' { return ([double]$Actual -gt [double]$Expected) }
        'ge' { return ([double]$Actual -ge [double]$Expected) }
        'lt' { return ([double]$Actual -lt [double]$Expected) }
        'le' { return ([double]$Actual -le [double]$Expected) }
        'match' { return ([string]$Actual -match [string]$Expected) }
        default { throw "Unsupported WhereOperator '$Operator'. Use eq/ne/gt/ge/lt/le/match." }
    }
}

function Get-JsonRows {
    param($Json, $Schema)
    $rows = New-Object System.Collections.ArrayList
    if ($Schema.tableShape -eq 'indexed_rows') {
        $data = @($Json.Properties.Data)
        for ($i = 0; $i -lt $data.Count; $i++) {
            $null = $rows.Add([PSCustomObject]@{ key=$i; value=$data[$i]; targetPrefix="Data[$i]" })
        }
    } elseif ($Schema.tableShape -eq 'named_rows') {
        foreach ($p in @($Json.Rows.PSObject.Properties)) {
            $null = $rows.Add([PSCustomObject]@{ key=$p.Name; value=$p.Value; targetPrefix="Rows.$($p.Name.ToLowerInvariant())" })
        }
    } else {
        throw "Batch modify currently supports indexed_rows and named_rows only. Schema shape=$($Schema.tableShape)"
    }
    return @($rows)
}

function Get-RowFieldValue {
    param($RowValue, [string] $FieldName)
    if (-not $RowValue) { return $null }
    $prop = @($RowValue.PSObject.Properties | Where-Object { $_.Name -ieq $FieldName -or $_.Name -like "$FieldName`_*" }) | Select-Object -First 1
    if ($prop) { return $prop.Value }
    return $null
}

$ctx = Resolve-P3RTableContext -TableKey $TableKey -SchemaKey $SchemaKey -VirtualPath $VirtualPath
if (-not $ctx.JsonCache -or -not (Test-Path $ctx.JsonCache)) { throw "JSON cache not found for table/schema: $($ctx.TableKey) / $($ctx.SchemaKey)" }
$jsonObj = Get-Content $ctx.JsonCache -Raw -Encoding UTF8 | ConvertFrom-Json

# Resolve field once so guard failures are early and target spelling is canonical.
if ($ctx.Schema.tableShape -eq 'named_rows') {
    $firstRow = @($ctx.Schema.rows | Select-Object -First 1)[0]
    $targetField = Find-P3RSchemaField -Fields $firstRow.fields -Name $Field
} else {
    $targetField = Find-P3RSchemaField -Fields $ctx.Schema.fields -Name $Field
}
if (-not $targetField) { throw "Field '$Field' not found in schema '$($ctx.SchemaKey)'" }

$rows = @(Get-JsonRows -Json $jsonObj -Schema $ctx.Schema)
if ($Ids -and $ctx.Schema.tableShape -ne 'indexed_rows') { throw '-Ids is only supported for indexed_rows schemas.' }

$changes = New-Object System.Collections.ArrayList
foreach ($row in $rows) {
    if ($Ids -and ([int]$row.key -notin $Ids)) { continue }
    if ($WhereField) {
        $actual = Get-RowFieldValue -RowValue $row.value -FieldName $WhereField
        if (-not (Test-P3RCondition -Actual $actual -Operator $WhereOperator -Expected $WhereValue)) { continue }
    }
    $null = $changes.Add([PSCustomObject]@{ target = "$($row.targetPrefix).$($targetField.name)"; value = $Value })
}

if ($changes.Count -eq 0) { throw 'No rows matched the batch filter.' }

if (-not $OutputChangesJson) {
    $outDir = Join-Path $ModOutput $ModName
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $OutputChangesJson = Join-Path $outDir 'batch-changes.json'
}
[PSCustomObject]@{ schemaKey=$ctx.SchemaKey; changes=@($changes) } | ConvertTo-Json -Depth 8 | Out-File $OutputChangesJson -Encoding UTF8

Write-Host '=== P3R Batch Modify Plan ===' -ForegroundColor Cyan
Write-Host "Table : $($ctx.TableKey)"
Write-Host "Schema: $($ctx.SchemaKey)"
Write-Host "Field : $($targetField.name) = $Value"
if ($Ids) { Write-Host "Ids   : $($Ids -join ', ')" }
if ($WhereField) { Write-Host "Where : $WhereField $WhereOperator $WhereValue" }
Write-Host "Rows  : $($changes.Count)"
Write-Host "JSON  : $OutputChangesJson"
Write-Host ''
foreach ($c in @($changes | Select-Object -First 20)) { Write-Host "  $($c.target) = $($c.value)" -ForegroundColor DarkGray }
if ($changes.Count -gt 20) { Write-Host "  ... $($changes.Count - 20) more" -ForegroundColor DarkGray }

if ($PreviewOnly) { return }

$pipeline = Join-Path (Split-Path $PSScriptRoot -Parent) 'modify-and-repack.ps1'
$args = @{
    TableKey = $ctx.TableKey
    SchemaKey = $ctx.SchemaKey
    VirtualPath = $ctx.VirtualPath
    ChangesJson = $OutputChangesJson
    ModName = $ModName
    UserInput = "batch-modify field=$($targetField.name) value=$Value filter=$WhereField/$WhereOperator/$WhereValue ids=$($Ids -join ',')"
}
if ($ModDisplayName) { $args.ModDisplayName = $ModDisplayName }
if ($ModDescription) { $args.ModDescription = $ModDescription }
if ($NoInstall) { $args.NoInstall = $true }
if ($DryRun) { $args.DryRun = $true }
if ($Force) { $args.Force = $true }
if ($SkipGuard) { $args.SkipGuard = $true }
if ($SkipConflictCheck) { $args.SkipConflictCheck = $true }

& $pipeline @args
if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
