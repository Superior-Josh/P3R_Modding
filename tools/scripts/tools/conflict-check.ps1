# P3R conflict-check.ps1 — Check for mod conflicts by comparing DataTable targets
# Usage:
#   .\conflict-check.ps1 -ModName "MyMod"
#   .\conflict-check.ps1 -ModDir ".\tools\Output\mod\MyMod"
#   .\conflict-check.ps1 -All
param(
    [string]$ModName,
    [string]$ModDir,
    [switch]$All
)

. "$PSScriptRoot\..\Config.ps1"

$modDirs = @()

if ($All) {
    $modDirs = Get-ChildItem $ModOutput -Directory -ErrorAction SilentlyContinue
} elseif ($ModDir) {
    $modDirs = @(Get-Item $ModDir -ErrorAction SilentlyContinue)
} elseif ($ModName) {
    $modDirs = @(Get-Item "$ModOutput\$ModName" -ErrorAction SilentlyContinue)
} else {
    Write-Error "Specify -ModName, -ModDir, or -All"
    exit 1
}

if ($modDirs.Count -eq 0) {
    Write-Host "No mods found." -ForegroundColor DarkGray
    exit 0
}

Write-Host "=== Mod Conflict Check ===" -ForegroundColor Cyan

# Build map: virtualPath -> mod list
$vpathMap = @{}
foreach ($mod in $modDirs) {
    $manifestPath = Join-Path $mod.FullName "manifest.txt"
    if (-not (Test-Path $manifestPath)) { continue }
    $lines = Get-Content $manifestPath
    foreach ($line in $lines) {
        if ($line -match '"([^"]+)"\s+"([^"]+)"') {
            $mountPath = $matches[2]
            if (-not $vpathMap.ContainsKey($mountPath)) {
                $vpathMap[$mountPath] = @()
            }
            $vpathMap[$mountPath] += $mod.Name
        }
    }
}

$conflicts = $vpathMap.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 } | Sort-Object { $_.Value.Count } -Descending

if ($conflicts.Count -eq 0) {
    Write-Host "No conflicts found among installed mods." -ForegroundColor Green
} else {
    Write-Host "Found $($conflicts.Count) conflicting paths:" -ForegroundColor Red
    foreach ($c in $conflicts) {
        Write-Host "  $($c.Key): $($c.Value -join ', ')" -ForegroundColor Yellow
    }
}
