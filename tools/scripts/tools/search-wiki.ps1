# P3R search-wiki.ps1 — Search Amicitia Wiki reference docs
# Usage:
#   .\search-wiki.ps1 -Query "SkillNormal"
#   .\search-wiki.ps1 -Query "Agi" -NameOnly
param(
    [Parameter(Mandatory=$true)]
    [string]$Query,
    [switch]$NameOnly
)

. "$PSScriptRoot\..\Config.ps1"

if (-not (Test-Path $WikiDir)) {
    Write-Error "Wiki directory not found: $WikiDir"
    exit 1
}

Write-Host "Searching Wiki docs for '$Query'..." -ForegroundColor Cyan
$files = Get-ChildItem $WikiDir -Filter "*.md" -ErrorAction SilentlyContinue
$foundList = New-Object System.Collections.ArrayList
$escapedQuery = [regex]::Escape($Query)

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    if ($content -match $escapedQuery) {
        if ($NameOnly) {
            $null = $foundList.Add([PSCustomObject]@{ Name = $file.Name; Path = $file.FullName })
        } else {
            $lines = $content -split "`n" | Where-Object { $_ -match $escapedQuery } | Select-Object -First 3
            $snippet = ($lines -join " | ")
            $snippet = $snippet.Substring(0, [Math]::Min(200, $snippet.Length))
            $null = $foundList.Add([PSCustomObject]@{ File = $file.Name; Snippets = $snippet })
        }
    }
}

Write-Host "Found $($foundList.Count) matching files:"
if ($foundList.Count -gt 0) {
    $foundList | Format-List
}
