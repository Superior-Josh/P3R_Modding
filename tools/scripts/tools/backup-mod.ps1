# P3R backup-mod.ps1 — Create timestamped backup of mod files
# Usage:
#   .\backup-mod.ps1 -ModName "MyMod" [-Description "Before power nerf"]
#   .\backup-mod.ps1 -Path .\tools\Output\mod\MyMod -Description "v1.0"
param(
    [string]$ModName,
    [string]$Path,
    [string]$Description = "manual backup"
)

. "$PSScriptRoot\..\Config.ps1"

$sourceDir = if ($Path) { (Resolve-Path $Path).Path } else { "$ModOutput\$ModName" }
if (-not (Test-Path $sourceDir)) {
    Write-Error "Source directory not found: $sourceDir"
    exit 1
}

$name = if ($ModName) { $ModName } else { (Split-Path $sourceDir -Leaf) }
$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$backupDir = "$BackupDir\$name"
$destDir = "$backupDir\$timestamp"
New-Item -ItemType Directory -Force $destDir | Out-Null

Copy-Item "$sourceDir\*" $destDir -Recurse -Force

# Save metadata using ConvertTo-Json (handles escaping correctly)
$meta = @{
    backupDate  = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    modName     = $name
    description = $Description
    sourcePath  = $sourceDir
    files       = (Get-ChildItem $destDir -Recurse | Where-Object { -not $_.PSIsContainer } | Measure-Object).Count
}
$meta | ConvertTo-Json -Depth 3 | Out-File "$destDir\backup_metadata.json" -Encoding UTF8

$size = [math]::Round(((Get-ChildItem $destDir -Recurse | Measure-Object -Property Length -Sum).Sum) / 1KB, 1)
Write-Host "Backup saved: $destDir ($size KB)" -ForegroundColor Green

# List recent backups
Write-Host ""
Write-Host "Recent backups for '$name':" -ForegroundColor Cyan
Get-ChildItem $backupDir -Directory | Sort-Object Name -Descending | Select-Object -First 5 | ForEach-Object {
    $metaFile = Join-Path $_.FullName "backup_metadata.json"
    $desc = if (Test-Path $metaFile) {
        try { (Get-Content $metaFile -Raw -Encoding UTF8 | ConvertFrom-Json).description } catch { "" }
    } else { "" }
    Write-Host "  $($_.Name) — $desc"
}
