# P3R search-wiki.ps1 — 搜索 Amicitia Wiki / zh-cn 标准译名 / DATA_MAPPING

param(
    [Parameter(Mandatory=$true)]
    [string] $Query,
    [int] $Context = 1,
    [switch] $NameOnly,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\Config.ps1"

$results = New-Object System.Collections.ArrayList
$escaped = [regex]::Escape($Query)

function Add-MatchesFromFile {
    param([string] $Path, [string] $Source)
    if (-not (Test-Path $Path)) { return }
    $lines = Get-Content $Path -Encoding UTF8
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -notmatch $escaped) { continue }
        if ($NameOnly) {
            $snippet = Split-Path $Path -Leaf
        } else {
            $from = [Math]::Max(0, $i - $Context)
            $to = [Math]::Min($lines.Count - 1, $i + $Context)
            $snippet = (($from..$to | ForEach-Object { "L$($_ + 1): $($lines[$_])" }) -join "`n")
        }
        $null = $results.Add([PSCustomObject]@{
            source = $Source
            file   = $Path.Replace($ProjectRoot, '').TrimStart('\')
            line   = $i + 1
            text   = $snippet
        })
        break
    }
}

Add-MatchesFromFile -Path $DataMappingFile -Source 'DATA_MAPPING'
Get-ChildItem $ZhCnDir -Filter '*.md' -ErrorAction SilentlyContinue | ForEach-Object {
    Add-MatchesFromFile -Path $_.FullName -Source 'zh-cn'
}
Get-ChildItem $WikiDir -Filter '*.md' -ErrorAction SilentlyContinue | ForEach-Object {
    Add-MatchesFromFile -Path $_.FullName -Source 'amicitia'
}

if ($Json) {
    $results | ConvertTo-Json -Depth 5
} else {
    Write-Host "Found $($results.Count) wiki/reference file(s) for '$Query'" -ForegroundColor Cyan
    if ($NameOnly) { $results | Format-Table source, file, line -AutoSize }
    else { $results | Format-List source, file, line, text }
}
