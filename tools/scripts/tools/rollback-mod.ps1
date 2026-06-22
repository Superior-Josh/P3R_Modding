# P3R rollback-mod.ps1 — Rollback mod to a previous backup
# Usage:
#   .\rollback-mod.ps1 -ModName "MyMod"     (rollback to latest backup)
#   .\rollback-mod.ps1 -ModName "MyMod" -Timestamp "2026-06-22_120000"
#   .\rollback-mod.ps1 -ModName "MyMod" -List
param(
    [Parameter(Mandatory=$true)]
    [string]$ModName,
    [string]$Timestamp,
    [switch]$List
)

. "$PSScriptRoot\..\Config.ps1"

$backupDir = "$BackupDir\$ModName"
if (-not (Test-Path $backupDir)) {
    Write-Error "No backups found for: $ModName"
    exit 1
}

$backups = Get-ChildItem $backupDir -Directory | Sort-Object Name

if ($List -or ($backups.Count -eq 0)) {
    Write-Host "Available backups for '$ModName':" -ForegroundColor Cyan
    if ($backups.Count -eq 0) {
        Write-Host "  (none)" -ForegroundColor DarkGray
        exit 0
    }
    foreach ($b in $backups) {
        $metaFile = Join-Path $b.FullName "backup_metadata.json"
        $desc = if (Test-Path $metaFile) { (Get-Content $metaFile -Raw | ConvertFrom-Json).description } else { "" }
        Write-Host "  $($b.Name) — $desc"
    }
    exit 0
}

$target = if ($Timestamp) {
    $backups | Where-Object { $_.Name -eq $Timestamp } | Select-Object -First 1
} else {
    $backups | Select-Object -Last 1
}

if (-not $target) {
    Write-Error "Backup not found: $Timestamp"
    Write-Host "Available: $($backups.Name -join ', ')"
    exit 1
}

$modDir = "$ModOutput\$ModName"
Write-Host "Rolling back '$ModName' to $($target.Name)..." -ForegroundColor Yellow

# Remove current, restore from backup
if (Test-Path $modDir) { Remove-Item $modDir -Recurse -Force }
Copy-Item $target.FullName $modDir -Recurse
# Remove backup metadata from restored mod dir
Remove-Item "$modDir\backup_metadata.json" -Force -ErrorAction SilentlyContinue

Write-Host "Rollback complete: $modDir" -ForegroundColor Green
