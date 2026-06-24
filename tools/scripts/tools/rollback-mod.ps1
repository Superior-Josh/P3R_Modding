# P3R rollback-mod.ps1 — 从注册表/备份回滚或移除 Reloaded II Mod

param(
    [Parameter(Mandatory=$true)]
    [string] $ModName,
    [string] $Timestamp,
    [switch] $List,
    [switch] $RemoveInstalled,
    [switch] $Preview,
    [switch] $WorkOnly,
    [switch] $InstalledOnly,
    [switch] $Force,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\Config.ps1"

$backupRoot = Join-Path $BackupDir $ModName
$backups = @()
if (Test-Path $backupRoot) { $backups = @(Get-ChildItem $backupRoot -Directory | Sort-Object Name) }

if ($List) {
    Write-Host "Available backups for '$ModName':" -ForegroundColor Cyan
    if ($backups.Count -eq 0) { Write-Host '  (none)' -ForegroundColor DarkGray }
    foreach ($b in $backups) {
        $metaFile = Join-Path $b.FullName 'backup.json'
        $desc = if (Test-Path $metaFile) { (Get-Content $metaFile -Raw -Encoding UTF8 | ConvertFrom-Json).description } else { '' }
        Write-Host "  $($b.Name) - $desc"
    }
    exit 0
}

$modDir = Join-Path $ModOutput $ModName
$installedDir = Join-Path $ReloadedModsDir $ModName

if ($RemoveInstalled) {
    $before = Get-P3RSnapshotHash -Snapshot (Get-P3RDirectorySnapshot -Path $installedDir)
    Write-Host "Removing installed mod: $installedDir" -ForegroundColor Yellow
    if ($Preview) {
        Write-Host 'Preview only: no files removed.' -ForegroundColor DarkYellow
        exit 0
    }
    if (-not $Force) { Write-Host 'Use -Force to confirm installed mod removal.' -ForegroundColor Red; exit 4 }
    if (Test-Path $installedDir) { Remove-Item $installedDir -Recurse -Force -Confirm:$false }
    Remove-P3RModEntry -ModName $ModName
    $after = Get-P3RSnapshotHash -Snapshot (Get-P3RDirectorySnapshot -Path $installedDir)
    if (Test-Path $modDir) { Add-P3RHistoryEntry -ModDir $modDir -Action 'remove-installed' -BeforeHash $before -AfterHash $after -Details ([PSCustomObject]@{ installedDir=$installedDir }) | Out-Null }
    Write-Host "Installed mod removed and registry pruned." -ForegroundColor Green
    exit 0
}

if ($backups.Count -eq 0) { throw "No backups found for: $ModName" }
$target = if ($Timestamp) { @($backups | Where-Object { $_.Name -eq $Timestamp }) | Select-Object -First 1 } else { $backups | Select-Object -Last 1 }
if (-not $target) { throw "Backup not found: $Timestamp. Available: $($backups.Name -join ', ')" }

Write-Host "Rolling back '$ModName' to $($target.Name)..." -ForegroundColor Yellow
$before = Get-P3RSnapshotHash -Snapshot (@(Get-P3RDirectorySnapshot -Path $modDir) + @(Get-P3RDirectorySnapshot -Path $installedDir))
$restoreItems = @(Get-ChildItem $target.FullName -Force | Where-Object { $_.Name -notin @('backup.json','backup_metadata.json') })
if ($Preview) {
    Write-Host "Preview: would restore $($restoreItems.Count) top-level item(s) from $($target.FullName)" -ForegroundColor Cyan
    foreach ($item in $restoreItems) { Write-Host "  $($item.Name)" }
    exit 0
}
if (-not $Force) {
    Write-Host 'Use -Force to execute rollback. Re-run with -Preview to inspect first.' -ForegroundColor Red
    exit 4
}

if (-not $InstalledOnly) {
    if (Test-Path $modDir) { Remove-Item $modDir -Recurse -Force -Confirm:$false }
    New-Item -ItemType Directory -Force -Path $modDir | Out-Null
    foreach ($item in $restoreItems) { Copy-Item $item.FullName (Join-Path $modDir $item.Name) -Recurse -Force }
}

# If an installed Reloaded II mod exists, refresh it from restored work dir only when it contains deployable metadata.
if (-not $WorkOnly -and (Test-Path $installedDir)) {
    Remove-Item $installedDir -Recurse -Force -Confirm:$false
    $ue = Join-Path $modDir 'UnrealEssentials'
    $cfg = Join-Path $modDir 'ModConfig.json'
    if ((Test-Path $ue) -or (Test-Path $cfg)) {
        New-Item -ItemType Directory -Force -Path $installedDir | Out-Null
        Copy-Item "$modDir\*" $installedDir -Recurse -Force
    }
}

$after = Get-P3RSnapshotHash -Snapshot (@(Get-P3RDirectorySnapshot -Path $modDir) + @(Get-P3RDirectorySnapshot -Path $installedDir))
Add-P3RHistoryEntry -ModDir $modDir -Action 'rollback' -BeforeHash $before -AfterHash $after -Details ([PSCustomObject]@{ backupId=$target.Name; workOnly=[bool]$WorkOnly; installedOnly=[bool]$InstalledOnly }) | Out-Null

$modJson = Join-Path $modDir 'mod.json'
if (Test-Path $modJson) {
    try {
        $mj = Get-Content $modJson -Raw -Encoding UTF8 | ConvertFrom-Json
        Set-P3RModEntry -Entry ([PSCustomObject]@{
            schemaVersion = 2
            modName = $ModName
            displayName = $mj.displayName
            schemaKey = $mj.schemaKey
            tableKey = $mj.tableKey
            virtualPath = $mj.virtualPath
            workDir = $modDir
            installedDir = if (Test-Path $installedDir) { $installedDir } else { $null }
            lastModified = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            beforeHash = $before
            afterHash = $after
            changes = @($mj.changes)
        })
    } catch {}
}

Write-Host "Rollback complete: $modDir" -ForegroundColor Green
