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
$matches = @()

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    if ($content -match $Query) {
        if ($NameOnly) {
            $matches += [PSCustomObject]@{ Name = $file.Name; Path = $file.FullName }
        } else {
            $lines = $content -split "`n" | Where-Object { $_ -match $Query } | Select-Object -First 3
            $matches += [PSCustomObject]@{ File = $file.Name; Snippets = ($lines -join " | ").Substring(0, [Math]::Min(200, ($lines -join " | ").Length)) }
        }
    }
}

Write-Host "Found $($matches.Count) matching files:"
$matches | Format-List
