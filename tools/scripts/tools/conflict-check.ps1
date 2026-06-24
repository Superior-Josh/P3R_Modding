# P3R conflict-check.ps1 — 检测同一 virtualPath + target/row/field 重叠

param(
    [string] $ModName,
    [string] $ModDir,
    [string] $ChangesJson,
    [string] $VirtualPath,
    [string] $SchemaKey,
    [switch] $All,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\Config.ps1"

function Get-ChangeEntriesFromFile {
    param([string] $File, [string] $NameHint)
    if (-not (Test-Path $File)) { return @() }
    try { $obj = Get-Content $File -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return @() }
    $schema = if ($obj.schemaKey) { $obj.schemaKey } else { $SchemaKey }
    $ctx = if ($schema) { Resolve-P3RTableContext -SchemaKey $schema } elseif ($VirtualPath) { Resolve-P3RTableContext -VirtualPath $VirtualPath } else { $null }
    $vpath = $VirtualPath
    $schemaKeyForEntry = $schema
    if ($ctx) {
        $vpath = $ctx.VirtualPath
        $schemaKeyForEntry = $ctx.SchemaKey
    }
    $entries = New-Object System.Collections.ArrayList
    foreach ($c in @($obj.changes)) {
        $target = [string]$c.target
        $row = $null; $field = $null
        if ($target -match '^Data\[(\d+)\]\.(.+)$') { $row = [int]$matches[1]; $field = $matches[2] }
        elseif ($target -match '^Rows(?:\["([^"]+)"\]|\.([^\.]+))\.(.+)$') {
            if ($matches[1]) { $row = $matches[1] } else { $row = $matches[2] }
            $field = $matches[3]
        }
        elseif ($target -match '^Record\[(\d+)\]\.(.+)$') { $row = [int]$matches[1]; $field = $matches[2] }
        else { $field = $target }
        $null = $entries.Add([PSCustomObject]@{
            modName = $NameHint
            virtualPath = $vpath
            schemaKey = $schemaKeyForEntry
            target = $target
            row = $row
            field = $field
            value = $c.value
            source = $File
        })
    }
    return @($entries)
}

$entries = New-Object System.Collections.ArrayList

# registry entries
$registry = Read-P3RRegistry
foreach ($m in @($registry.mods)) {
    foreach ($ch in @($m.changes)) {
        $null = $entries.Add([PSCustomObject]@{
            modName=$m.modName; virtualPath=$m.virtualPath; schemaKey=$m.schemaKey; target=$ch.target; row=$ch.row; field=$ch.field; value=$ch.value; source='registry'
        })
    }
}

# generated mod folders with changes.json/mod.json
$scanDirs = @()
if ($All) { $scanDirs = @(Get-ChildItem $ModOutput -Directory -ErrorAction SilentlyContinue) }
elseif ($ModDir) { $scanDirs = @(Get-Item $ModDir -ErrorAction SilentlyContinue) }
elseif ($ModName) { $scanDirs = @(Get-Item (Join-Path $ModOutput $ModName) -ErrorAction SilentlyContinue) }
foreach ($dir in $scanDirs) {
    Get-ChildItem $dir.FullName -Filter 'changes*.json' -File -ErrorAction SilentlyContinue | ForEach-Object {
        Get-ChangeEntriesFromFile -File $_.FullName -NameHint $dir.Name | ForEach-Object { $null = $entries.Add($_) }
    }
    $modJson = Join-Path $dir.FullName 'mod.json'
    if (Test-Path $modJson) {
        try {
            $mj = Get-Content $modJson -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($ch in @($mj.changes)) { $null = $entries.Add($ch) }
        } catch {}
    }
}
if ($ChangesJson) {
    Get-ChangeEntriesFromFile -File $ChangesJson -NameHint $(if($ModName){$ModName}else{'candidate'}) | ForEach-Object { $null = $entries.Add($_) }
}

$conflicts = New-Object System.Collections.ArrayList
$groups = @($entries | Where-Object { $_.virtualPath -and $_.field } | Group-Object virtualPath, row, field)
foreach ($g in $groups) {
    $mods = @($g.Group | Select-Object -ExpandProperty modName -Unique)
    if ($mods.Count -gt 1) {
        $values = @($g.Group | ForEach-Object { if ($null -ne $_.value) { [string]$_.value } } | Sort-Object -Unique)
        $sameValue = $values.Count -eq 1
        $severity = if ($sameValue) { 'warning' } else { 'error' }
        $suggestion = if ($sameValue) { 'Same target and same value; keep one authoritative mod or document load-order intent.' } else { 'Same target has different values; split targets or choose exactly one mod to own this field.' }
        $null = $conflicts.Add([PSCustomObject]@{
            severity = $severity
            virtualPath = $g.Group[0].virtualPath
            row = $g.Group[0].row
            field = $g.Group[0].field
            mods = $mods
            values = $values
            suggestion = $suggestion
            targets = @($g.Group | Select-Object modName, target, value, source)
        })
    } elseif ($g.Group.Count -gt 1) {
        $null = $conflicts.Add([PSCustomObject]@{
            severity = 'info'
            virtualPath = $g.Group[0].virtualPath
            row = $g.Group[0].row
            field = $g.Group[0].field
            mods = $mods
            values = @($g.Group | ForEach-Object { if ($null -ne $_.value) { [string]$_.value } } | Sort-Object -Unique)
            suggestion = 'Duplicate entries inside one mod; verify this is intentional.'
            targets = @($g.Group | Select-Object modName, target, value, source)
        })
    }
}

if ($Json) {
    [PSCustomObject]@{ conflictCount=$conflicts.Count; conflicts=@($conflicts) } | ConvertTo-Json -Depth 8
} else {
    Write-Host "=== Mod Conflict Check ===" -ForegroundColor Cyan
    if ($conflicts.Count -eq 0) {
        Write-Host "No target-level conflicts found." -ForegroundColor Green
    } else {
        Write-Host "Found $($conflicts.Count) conflict(s):" -ForegroundColor Red
        foreach ($c in $conflicts) {
            $color = if ($c.severity -eq 'error') { 'Red' } elseif ($c.severity -eq 'warning') { 'Yellow' } else { 'DarkGray' }
            Write-Host "  [$($c.severity.ToUpperInvariant())] $($c.virtualPath) row=$($c.row) field=$($c.field): $($c.mods -join ', ')" -ForegroundColor $color
            Write-Host "    $($c.suggestion)" -ForegroundColor $color
        }
    }
}

$blocking = @($conflicts | Where-Object { $_.severity -eq 'error' }).Count
if ($blocking -gt 0) { exit 3 }