# P3R backup-mod.ps1 — 创建时间点备份并写入 backup.json

param(
    [string] $ModName,
    [string] $Path,
    [string] $Description = 'manual backup',
    [string] $ChangesJson,
    [string] $VirtualPath,
    [string] $SchemaKey,
    [string] $Name,
    [switch] $List,
    [string] $Compare,
    [string] $With,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\Config.ps1"

$sourceDir = if ($Path) { (Resolve-Path $Path).Path } elseif ($ModName) { "$ModOutput\$ModName" } else { throw 'Specify -ModName or -Path' }
$name = if ($ModName) { $ModName } else { Split-Path $sourceDir -Leaf }
$backupRoot = Join-Path $BackupDir $name

if ($List) {
    $items = @()
    if (Test-Path $backupRoot) {
        $items = @(Get-ChildItem $backupRoot -Directory | Sort-Object Name -Descending | ForEach-Object {
            $metaFile = Join-Path $_.FullName 'backup.json'
            $meta = if (Test-Path $metaFile) { try { Get-Content $metaFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $null } } else { $null }
            [PSCustomObject]@{ timestamp=$_.Name; path=$_.FullName; description=if($meta){$meta.description}else{''}; fileCount=if($meta){$meta.fileCount}else{0}; snapshotHash=if($meta){$meta.snapshotHash}else{$null} }
        })
    }
    if ($Json) { [PSCustomObject]@{ modName=$name; backups=$items } | ConvertTo-Json -Depth 8 }
    else {
        Write-Host "Available backups for '$name':" -ForegroundColor Cyan
        if ($items.Count -eq 0) { Write-Host '  (none)' -ForegroundColor DarkGray }
        foreach ($i in $items) { Write-Host "  $($i.timestamp) - $($i.description) [$($i.fileCount) files]" }
    }
    exit 0
}

if ($Compare) {
    $leftDir = Join-Path $backupRoot $Compare
    if (-not (Test-Path $leftDir)) { throw "Backup not found: $Compare" }
    $rightDir = if ($With) { Join-Path $backupRoot $With } else { $sourceDir }
    if (-not (Test-Path $rightDir)) { throw "Compare target not found: $rightDir" }
    $left = @(Get-P3RDirectorySnapshot -Path $leftDir | Where-Object { $_.path -notin @('backup.json','backup_metadata.json') })
    $right = @(Get-P3RDirectorySnapshot -Path $rightDir | Where-Object { $_.path -notin @('backup.json','backup_metadata.json') })
    $paths = @(@($left | ForEach-Object { $_.path }) + @($right | ForEach-Object { $_.path }) | Sort-Object -Unique)
    $diffs = @($paths | ForEach-Object {
        $p = $_
        $l = @($left | Where-Object { $_.path -eq $p }) | Select-Object -First 1
        $r = @($right | Where-Object { $_.path -eq $p }) | Select-Object -First 1
        if (-not $l) { [PSCustomObject]@{ path=$p; status='added'; left=$null; right=$r.sha256 } }
        elseif (-not $r) { [PSCustomObject]@{ path=$p; status='removed'; left=$l.sha256; right=$null } }
        elseif ($l.sha256 -ne $r.sha256 -or $l.length -ne $r.length) { [PSCustomObject]@{ path=$p; status='changed'; left=$l.sha256; right=$r.sha256 } }
    })
    if ($Json) { [PSCustomObject]@{ modName=$name; left=$Compare; right=if($With){$With}else{'current'}; differences=$diffs } | ConvertTo-Json -Depth 8 }
    else {
        Write-Host "Backup comparison: $Compare -> $(if($With){$With}else{'current'})" -ForegroundColor Cyan
        if ($diffs.Count -eq 0) { Write-Host '  No differences.' -ForegroundColor Green }
        foreach ($d in $diffs) { Write-Host "  [$($d.status)] $($d.path)" }
    }
    exit 0
}

if (-not (Test-Path $sourceDir)) { throw "Source directory not found: $sourceDir" }

$timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
if ($Name) { $timestamp = "$timestamp`_$($Name -replace '[^A-Za-z0-9_.-]', '_')" }
$destDir = Join-Path $backupRoot $timestamp
New-Item -ItemType Directory -Force -Path $destDir | Out-Null

Copy-Item "$sourceDir\*" $destDir -Recurse -Force -ErrorAction SilentlyContinue
if ($ChangesJson -and (Test-Path $ChangesJson)) { Copy-Item $ChangesJson (Join-Path $destDir 'changes.json') -Force }

$files = @(Get-ChildItem $destDir -Recurse -File -ErrorAction SilentlyContinue)
$hashes = @($files | ForEach-Object {
    [PSCustomObject]@{
        path = $_.FullName.Replace($destDir, '').TrimStart('\')
        length = $_.Length
        sha256 = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
    }
})

$snapshotHash = Get-P3RSnapshotHash -Snapshot $hashes
$meta = [PSCustomObject]@{
    schemaVersion = 2
    backupDate  = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    backupId    = $timestamp
    modName     = $name
    description = $Description
    sourcePath  = $sourceDir
    virtualPath = $VirtualPath
    schemaKey   = $SchemaKey
    fileCount   = $files.Count
    snapshotHash = $snapshotHash
    files       = $hashes
}
$meta | ConvertTo-Json -Depth 10 | Out-File (Join-Path $destDir 'backup.json') -Encoding UTF8
# legacy filename for old scripts/users
$meta | ConvertTo-Json -Depth 10 | Out-File (Join-Path $destDir 'backup_metadata.json') -Encoding UTF8

Add-P3RHistoryEntry -ModDir $sourceDir -Action 'backup' -VirtualPath $VirtualPath -SchemaKey $SchemaKey -BeforeHash $snapshotHash -AfterHash $snapshotHash -Details ([PSCustomObject]@{ backupId=$timestamp; path=$destDir; description=$Description }) | Out-Null

$size = [math]::Round((($files | Measure-Object -Property Length -Sum).Sum) / 1KB, 1)
Write-Host "Backup saved: $destDir ($size KB)" -ForegroundColor Green
Write-Host ""
Write-Host "Recent backups for '$name':" -ForegroundColor Cyan
Get-ChildItem (Join-Path $BackupDir $name) -Directory | Sort-Object Name -Descending | Select-Object -First 5 | ForEach-Object {
    $metaFile = Join-Path $_.FullName 'backup.json'
    $desc = if (Test-Path $metaFile) { try { (Get-Content $metaFile -Raw -Encoding UTF8 | ConvertFrom-Json).description } catch { '' } } else { '' }
    Write-Host "  $($_.Name) - $desc"
}
