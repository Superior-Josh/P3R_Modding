# P3R search-datatable.ps1 — Search JSON cache for data by field/ID/value
# Usage:
#   .\search-datatable.ps1 -Query "100" [-Field "ID"] [-Regex]
#   .\search-datatable.ps1 -Table skills -Query "agi"
param(
    [Parameter(Mandatory=$true)]
    [string]$Query,
    [string]$Table,
    [string]$Field,
    [switch]$Regex,
    [switch]$Quick
)

. "$PSScriptRoot\..\Config.ps1"
$start = Get-Date

$jsonFiles = if ($Table) {
    Get-ChildItem $JsonOutput -Recurse -Filter "*$Table*.json" -ErrorAction SilentlyContinue
} else {
    Get-ChildItem $JsonOutput -Recurse -Filter "*.json" -ErrorAction SilentlyContinue
}

Write-Host "Searching $($jsonFiles.Count) JSON files for '$Query'..." -ForegroundColor Cyan
$foundList = New-Object System.Collections.ArrayList

foreach ($file in $jsonFiles) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    if ($Regex) {
        if ($content -match $Query) {
            $null = $foundList.Add([PSCustomObject]@{ File = $file.Name; Match = "regex: $Query" })
        }
    } else {
        $escaped = [regex]::Escape($Query)
        if ($content -match $escaped) {
            $null = $foundList.Add([PSCustomObject]@{ File = $file.Name; Match = "match: $Query" })
        }
    }

    if ($Quick -and $foundList.Count -ge 5) { break }
}

$elapsed = [math]::Round(((Get-Date) - $start).TotalSeconds, 2)
Write-Host "Found $($foundList.Count) matches in $elapsed s"
if ($foundList.Count -gt 0) {
    $foundList | Format-Table File, Match -AutoSize
}
