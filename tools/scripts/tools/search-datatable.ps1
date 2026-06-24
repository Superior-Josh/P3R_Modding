# P3R search-datatable.ps1 — 中文译名 / ID / TableKey / SchemaKey 定位
# 返回虚拟路径、schema、行索引、字段与当前 JSON 缓存值。

param(
    [Parameter(Mandatory=$true)]
    [string] $Query,
    [string] $TableKey,
    [string] $SchemaKey,
    [string] $Field,
    [int] $Id = -1,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\Config.ps1"

$escapedQuery = [regex]::Escape($Query)
$results = New-Object System.Collections.ArrayList

function New-SearchHit {
    param(
        [string] $Kind,
        [string] $MatchedText,
        [int] $RowIndex,
        [string] $ResolvedTableKey,
        [string] $ResolvedField
    )

    $ctx = Resolve-P3RTableContext -TableKey $ResolvedTableKey -SchemaKey $SchemaKey
    $value = $null
    $rowValue = $null
    $targetValue = $null

    if ($RowIndex -ge 0) {
        $rowValue = $RowIndex
        if ($ResolvedField) {
            $targetValue = "Data[$RowIndex].$ResolvedField"
            if ($ctx.JsonCache) {
                $jsonObj = Get-Content $ctx.JsonCache -Raw -Encoding UTF8 | ConvertFrom-Json
                $rt = Resolve-P3RTarget -Target $targetValue -Schema $ctx.Schema
                $value = Get-P3RJsonValue -Json $jsonObj -ResolvedTarget $rt
            }
        }
    }

    [PSCustomObject]@{
        kind = $Kind
        query = $Query
        match = $MatchedText
        tableKey = $ctx.TableKey
        schemaKey = $ctx.SchemaKey
        virtualPath = $ctx.VirtualPath
        jsonCache = $ctx.JsonCache
        rowIndex = $rowValue
        field = $ResolvedField
        target = $targetValue
        currentValue = $value
    }
}

function Search-ZhTable {
    param([string] $Path, [string] $ResolvedTableKey)
    if (-not (Test-Path $Path)) { return }

    foreach ($line in (Get-Content $Path -Encoding UTF8)) {
        if ($line -notmatch $escapedQuery) { continue }
        if ($line -match '^\|\s*(\d+)\s*\|') {
            $row = [int]$matches[1]
            $text = ($line -replace '^\|\s*', '').Trim()
            New-SearchHit -Kind 'zh-cn' -MatchedText $text -RowIndex $row -ResolvedTableKey $ResolvedTableKey -ResolvedField $Field
        }
    }
}

if ($Id -ge 0) {
    $ctx = Resolve-P3RTableContext -TableKey $TableKey -SchemaKey $SchemaKey
    $name = Get-P3RDisplayName -TableKey $ctx.TableKey -Id $Id
    $null = $results.Add((New-SearchHit -Kind 'id' -MatchedText $name -RowIndex $Id -ResolvedTableKey $ctx.TableKey -ResolvedField $Field))
}

foreach ($key in $DataTables.Keys) {
    if ($TableKey -and $key -ine $TableKey) { continue }
    $v = $DataTables[$key]
    if ($key -match $escapedQuery -or $v -match $escapedQuery) {
        $ctx = Resolve-P3RTableContext -TableKey $key
        $null = $results.Add([PSCustomObject]@{
            kind = 'table'
            query = $Query
            match = $key
            tableKey = $ctx.TableKey
            schemaKey = $ctx.SchemaKey
            virtualPath = $ctx.VirtualPath
            jsonCache = $ctx.JsonCache
            rowIndex = $null
            field = $Field
            target = $null
            currentValue = $null
        })
    }
}

if (-not $TableKey -or $TableKey -in @('Skills','SkillMeta')) {
    Search-ZhTable -Path (Join-Path $ZhCnDir 'skills.md') -ResolvedTableKey 'Skills' | ForEach-Object {
        $null = $results.Add($_)
    }
}

if (-not $TableKey -or $TableKey -like 'Persona*') {
    $personaPath = Join-Path $ZhCnDir 'personas.md'
    if (Test-Path $personaPath) {
        foreach ($line in (Get-Content $personaPath -Encoding UTF8)) {
            if ($line -match $escapedQuery -and $line -match '^\|\s*([^|]+)\|') {
                $ctx = Resolve-P3RTableContext -TableKey 'Personas'
                $null = $results.Add([PSCustomObject]@{
                    kind = 'zh-cn'
                    query = $Query
                    match = $line.Trim()
                    tableKey = $ctx.TableKey
                    schemaKey = $ctx.SchemaKey
                    virtualPath = $ctx.VirtualPath
                    jsonCache = $ctx.JsonCache
                    rowIndex = $null
                    field = $Field
                    target = $null
                    currentValue = $null
                })
            }
        }
    }
}

if ($results.Count -eq 0) {
    if ($TableKey) {
        $ctx = Resolve-P3RTableContext -TableKey $TableKey -SchemaKey $SchemaKey
        if ($ctx.JsonCache) { $files = @(Get-Item $ctx.JsonCache) } else { $files = @() }
    } else {
        $files = @(Get-ChildItem $JsonOutput -Recurse -Filter '*.json' -ErrorAction SilentlyContinue)
    }

    foreach ($file in $files) {
        $content = Get-Content $file.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($content -and $content -match $escapedQuery) {
            $asset = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            $ctx = $null
            foreach ($key in $DataTables.Keys) {
                if ([System.IO.Path]::GetFileNameWithoutExtension($DataTables[$key]) -ieq $asset) {
                    $ctx = Resolve-P3RTableContext -TableKey $key
                    break
                }
            }

            $ctxTableKey = $null
            $ctxSchemaKey = $null
            $ctxVirtualPath = $null
            if ($ctx) {
                $ctxTableKey = $ctx.TableKey
                $ctxSchemaKey = $ctx.SchemaKey
                $ctxVirtualPath = $ctx.VirtualPath
            }

            $null = $results.Add([PSCustomObject]@{
                kind = 'json-cache'
                query = $Query
                match = $file.Name
                tableKey = $ctxTableKey
                schemaKey = $ctxSchemaKey
                virtualPath = $ctxVirtualPath
                jsonCache = $file.FullName
                rowIndex = $null
                field = $Field
                target = $null
                currentValue = $null
            })
        }
    }
}

if ($Json) {
    $results | ConvertTo-Json -Depth 8
} else {
    Write-Host "Found $($results.Count) result(s) for '$Query'" -ForegroundColor Cyan
    $results | Format-Table kind, tableKey, schemaKey, rowIndex, field, currentValue, match -AutoSize -Wrap
}
