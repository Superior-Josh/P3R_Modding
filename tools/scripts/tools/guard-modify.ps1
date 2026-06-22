# P3R guard-modify.ps1 — Safety guard before modifications
# Usage:
#   .\guard-modify.ps1 -VirtualPath "..."
#   .\guard-modify.ps1 -ModName "MyMod" -VirtualPath "..."
param(
    [Parameter(Mandatory=$true)]
    [string]$VirtualPath,
    [string]$ModName = "unnamed_mod"
)

. "$PSScriptRoot\..\Config.ps1"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Safety Guard — Pre-Modification Check" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$warnings = 0

# Check 1: Is the virtual path in the known table list?
$knownTable = $DataTables.GetEnumerator() | Where-Object { $_.Value -eq $VirtualPath }
if ($knownTable) {
    Write-Host "  [OK] Known DataTable: $($knownTable.Name)" -ForegroundColor Green
} else {
    Write-Host "  [WARNING] Unknown DataTable: $VirtualPath" -ForegroundColor Yellow
    Write-Host "    Verify this path exists before modifying." -ForegroundColor DarkYellow
    $warnings++
}

# Check 2: Does the JSON cache exist?
$assetName = [System.IO.Path]::GetFileNameWithoutExtension($VirtualPath)
$cacheFile = Get-ChildItem $JsonOutput -Recurse -Filter "$assetName.json" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($cacheFile) {
    Write-Host "  [OK] JSON cache exists: $($cacheFile.FullName)" -ForegroundColor Green
} else {
    Write-Host "  [INFO] No JSON cache. Run 'P3RDataTools read ...' to verify path." -ForegroundColor DarkYellow
}

# Check 3: Has this mod already been applied? (check backup registry)
$regFile = $ModRegistry
if (Test-Path $regFile) {
    $registry = Get-Content $regFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $existing = $registry.mods | Where-Object { $_.modName -eq $ModName -and $_.virtualPath -eq $VirtualPath }
    if ($existing) {
        Write-Host "  [WARNING] '$ModName' already modified this table on $($existing.lastModified)" -ForegroundColor Yellow
        Write-Host "    Consider rolling back first: .\tools\scripts\tools\rollback-mod.ps1 -ModName '$ModName'" -ForegroundColor DarkYellow
        $warnings++
    }
}

# Check 4: Default backup reminder
Write-Host "  [INFO] Backup automatically created by modify-and-repack.ps1" -ForegroundColor DarkGray
Write-Host ""

if ($warnings -gt 0) {
    Write-Host "  Proceed with caution ($warnings warning(s))." -ForegroundColor Yellow
} else {
    Write-Host "  All checks passed. Ready to modify." -ForegroundColor Green
}
Write-Host ""
