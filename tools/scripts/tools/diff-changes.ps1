# P3R diff-changes.ps1 — changes.json / inline changes 人类可读预览
# 展示 schemaKey、target、中文/Wiki 名称、旧值→新值与 DryRun offset 信息。

param(
    [string] $TableKey,
    [string] $SchemaKey,
    [string] $VirtualPath,
    [string] $ChangesJson,
    [hashtable[]] $Changes,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\Config.ps1"

$ctx = Resolve-P3RTableContext -TableKey $TableKey -SchemaKey $SchemaKey -VirtualPath $VirtualPath

if ($ChangesJson) {
    if (-not (Test-Path $ChangesJson)) { throw "ChangesJson not found: $ChangesJson" }
    $changesObj = Get-Content $ChangesJson -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($changesObj.schemaKey) { $ctx = Resolve-P3RTableContext -SchemaKey $changesObj.schemaKey }
    $changeList = @($changesObj.changes)
} elseif ($Changes -and $Changes.Count -gt 0) {
    $changeList = @($Changes)
} else {
    throw "Specify -ChangesJson or -Changes"
}

$jsonObj = $null
if ($ctx.JsonCache) {
    $jsonObj = Get-Content $ctx.JsonCache -Raw -Encoding UTF8 | ConvertFrom-Json
}

$preview = New-Object System.Collections.ArrayList
foreach ($c in $changeList) {
    $target = [string]$c.target
    $newValue = $c.value
    $resolved = Resolve-P3RTarget -Target $target -Schema $ctx.Schema
    $oldValue = Get-P3RJsonValue -Json $jsonObj -ResolvedTarget $resolved
    $displayName = $null
    if ($null -ne $resolved.Row) { $displayName = Get-P3RDisplayName -TableKey $ctx.TableKey -Id ([int]$resolved.Row) }
    $risk = if ($resolved.Field.kind -in @('scalar') -and [int]$resolved.ByteSize -in @(1,2,4,8)) { 'scalar' } else { $resolved.Field.kind }

    $null = $preview.Add([PSCustomObject]@{
        tableKey    = $ctx.TableKey
        schemaKey   = $ctx.SchemaKey
        virtualPath = $ctx.VirtualPath
        target      = $target
        row         = $resolved.Row
        name        = $displayName
        field       = $resolved.Field.name
        type        = $resolved.Type
        bytes       = $resolved.ByteSize
        offsetHex   = ('0x{0:X}' -f [int]$resolved.Offset)
        oldValue    = $oldValue
        newValue    = $newValue
        risk        = $risk
    })
}

if ($Json) {
    $preview | ConvertTo-Json -Depth 8
} else {
    Write-Host "=== P3R Change Preview ===" -ForegroundColor Cyan
    Write-Host "Table : $($ctx.TableKey)"
    Write-Host "Schema: $($ctx.SchemaKey)"
    Write-Host "VPath : $($ctx.VirtualPath)"
    Write-Host "Cache : $($ctx.JsonCache)"
    Write-Host ""
    foreach ($p in $preview) {
        $label = if ($p.name) { " [$($p.name)]" } else { '' }
        Write-Host "  $($p.target)$label" -ForegroundColor Yellow
        Write-Host "    field : $($p.field)  type=$($p.type)  bytes=$($p.bytes)  offset=$($p.offsetHex)"
        Write-Host "    value : $($p.oldValue) -> $($p.newValue)"
        Write-Host "    risk  : $($p.risk)"
    }
    Write-Host ""
    Write-Host "$($preview.Count) change(s) previewed. Run modify-and-repack.ps1 -DryRun for engine-level confirmation." -ForegroundColor Cyan
}
