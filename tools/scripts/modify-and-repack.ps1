# P3R Full Mod Pipeline: Zen Byte-Patch → Guard → Backup → Deploy (Sprint 2)
# Default install mode: UnrealEssentials loose files with p3rpc.essentials dependency.

param(
    # ── Schema resolution (at least one required) ─────────────────────────
    [string] $TableKey,
    [string] $SchemaKey,
    [string] $VirtualPath,

    # ── Change specification (at least one required) ──────────────────────
    [string] $ModScript,
    [string] $ChangesJson,
    [hashtable[]] $Changes,

    # ── Mod metadata ──────────────────────────────────────────────────────
    [string] $ModName = 'MyMod',
    [string] $ModDisplayName,
    [string] $ModAuthor = 'claude',
    [string] $ModDescription,
    [string[]] $ModDependencies = @('p3rpc.essentials'),

    # ── Options ───────────────────────────────────────────────────────────
    [switch] $PackPak,
    [switch] $NoInstall,
    [switch] $DryRun,
    [switch] $KeepTemp,
    [switch] $Force,
    [switch] $SkipGuard,
    [switch] $SkipConflictCheck,
    [switch] $SkipGitBackup,
    [string] $UserInput
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\Config.ps1"
$ZenPatchScript  = "$PSScriptRoot\Invoke-ZenPatch.ps1"
$DSLModule       = "$PSScriptRoot\dsl\P3RModDSL.psm1"
$GuardScript     = "$ToolsDir\guard-modify.ps1"
$DiffScript      = "$ToolsDir\diff-changes.ps1"
$BackupScript    = "$ToolsDir\backup-mod.ps1"
$ConflictScript  = "$ToolsDir\conflict-check.ps1"

function New-ModConfigObject {
    param(
        [string] $Id,
        [string] $DisplayName,
        [string] $Author,
        [string] $Description,
        [string[]] $Dependencies
    )
    [PSCustomObject]@{
        ModId = $Id
        ModName = $DisplayName
        ModAuthor = $Author
        ModVersion = '1.0.0'
        ModDescription = $Description
        ModDll = ''
        ModIcon = ''
        ModR2RManagedDll32 = ''
        ModR2RManagedDll64 = ''
        ModNativeDll32 = ''
        ModNativeDll64 = ''
        Tags = @()
        CanUnload = $null
        HasExports = $null
        IsLibrary = $false
        ReleaseMetadataFileName = "$Id.ReleaseMetadata.json"
        PluginData = $null
        IsUniversalMod = $false
        ModDependencies = @($Dependencies)
        OptionalDependencies = @()
        SupportedAppId = @('p3r.exe')
        ProjectUrl = ''
    }
}

function Get-ChangeMetadata {
    param($ChangeList, $Schema)
    $items = New-Object System.Collections.ArrayList
    foreach ($c in @($ChangeList)) {
        $target = [string]$c.target
        $value = $c.value
        try {
            $rt = Resolve-P3RTarget -Target $target -Schema $Schema
            $displayName = $null
            if ($null -ne $rt.Row) { $displayName = Get-P3RDisplayName -TableKey $ctx.TableKey -Id ([int]$rt.Row) }
            $null = $items.Add([PSCustomObject]@{
                target = $target
                value = $value
                row = $rt.Row
                rowKey = $rt.RowKey
                field = $rt.Field.name
                type = $rt.Type
                byteSize = $rt.ByteSize
                offsetHex = ('0x{0:X}' -f [int]$rt.Offset)
                displayName = $displayName
            })
        } catch {
            $null = $items.Add([PSCustomObject]@{ target = $target; value = $value; error = $_.Exception.Message })
        }
    }
    return @($items)
}

$ctx = Resolve-P3RTableContext -TableKey $TableKey -SchemaKey $SchemaKey -VirtualPath $VirtualPath
$TableKey = $ctx.TableKey
$SchemaKey = $ctx.SchemaKey
$vpath = $ctx.VirtualPath
$assetName = $ctx.AssetName

$workDir = Join-Path $ModOutput $ModName
$modPakDir = $ModOutput
New-Item -ItemType Directory -Force -Path $workDir, $modPakDir | Out-Null

Write-Host '============================================' -ForegroundColor Cyan
Write-Host ' P3R Mod Pipeline (Zen Byte-Patch + Sprint 2)' -ForegroundColor Cyan
Write-Host '============================================' -ForegroundColor Cyan
Write-Host "Asset  : $assetName"
Write-Host "Table  : $TableKey"
Write-Host "Schema : $SchemaKey"
Write-Host "VPath  : $vpath"
Write-Host "Mod    : $ModName"
Write-Host "Work   : $workDir"
Write-Host ''

Write-Host "[1/7] Schema resolved: $SchemaKey" -ForegroundColor Yellow

# ── Step 2: Prepare canonical changes.json ────────────────────────────────────
Write-Host '[2/7] Preparing changes...' -ForegroundColor Yellow
$tmpChangesFile = Join-Path $workDir "changes_$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$stableChangesFile = Join-Path $workDir 'changes.json'
$changeList = @()
$patchOutputDir = $workDir
$modScriptMode = $false

if ($ModScript) {
    if (-not (Test-Path $ModScript)) { throw "ModScript not found: $ModScript" }
    $modScriptMode = $true
    Write-Host "  ModScript: $ModScript"
    $dslAssetDir = Join-Path $workDir 'dsl_assets'
    New-Item -ItemType Directory -Force -Path $dslAssetDir | Out-Null
    Import-Module $DSLModule -Force
    . $ModScript
    $patchOutputDir = $dslAssetDir
    $dslAssets = @(Get-ChildItem $dslAssetDir -Filter '*.uasset' -ErrorAction SilentlyContinue)
    Write-Host "  DSL generated $($dslAssets.Count) asset(s)."
} elseif ($ChangesJson) {
    if (-not (Test-Path $ChangesJson)) { throw "ChangesJson not found: $ChangesJson" }
    $changesObj = Get-Content $ChangesJson -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $changesObj.schemaKey) { $changesObj | Add-Member -NotePropertyName 'schemaKey' -NotePropertyValue $SchemaKey -Force }
    $changesObj | ConvertTo-Json -Depth 8 | Out-File $stableChangesFile -Encoding UTF8
    $ChangesJson = $stableChangesFile
    $changeList = @($changesObj.changes)
    Write-Host "  Source: $ChangesJson"
} elseif ($Changes -and $Changes.Count -gt 0) {
    $changesObj = [PSCustomObject]@{ schemaKey = $SchemaKey; changes = @($Changes) }
    $changesObj | ConvertTo-Json -Depth 8 | Out-File $stableChangesFile -Encoding UTF8
    $ChangesJson = $stableChangesFile
    $changeList = @($Changes)
    foreach ($c in $changeList) { Write-Host "  $($c.target) = $($c.value)" -ForegroundColor DarkGray }
} else {
    throw 'Must specify one of: -ModScript, -ChangesJson, or -Changes'
}

# Keep timestamped copy only when requested; stable changes.json is retained for registry/conflict/rollback.
if ($ChangesJson -and $ChangesJson -ne $tmpChangesFile -and $KeepTemp) {
    Copy-Item $ChangesJson $tmpChangesFile -Force
}
Write-Host ''

# ── Step 3: Diff + guard + conflict preflight ─────────────────────────────────
Write-Host '[3/7] Preview / guard / conflict checks...' -ForegroundColor Yellow
if (-not $modScriptMode) {
    & $DiffScript -TableKey $TableKey -SchemaKey $SchemaKey -ChangesJson $ChangesJson

    if (-not $SkipGuard) {
        & $GuardScript -TableKey $TableKey -SchemaKey $SchemaKey -ChangesJson $ChangesJson -ModName $ModName -CheckBackup
        if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "guard-modify.ps1 failed with exit code $LASTEXITCODE" }
    } else {
        Write-Host '  Guard skipped (-SkipGuard).' -ForegroundColor DarkYellow
    }

    if (-not $SkipConflictCheck) {
        & $ConflictScript -ChangesJson $ChangesJson -ModName $ModName -SchemaKey $SchemaKey -VirtualPath $vpath
        if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            if ($Force) { Write-Host "  Conflict check returned $LASTEXITCODE but continuing because -Force is set." -ForegroundColor Yellow }
            else { throw "conflict-check.ps1 failed with exit code $LASTEXITCODE. Use -Force to override." }
        }
    } else {
        Write-Host '  Conflict check skipped (-SkipConflictCheck).' -ForegroundColor DarkYellow
    }
} else {
    Write-Host '  ModScript mode: changes.json guard/conflict skipped; DSL helper must enforce safety.' -ForegroundColor DarkYellow
}

if ($DryRun) {
    Write-Host ''
    Write-Host '[4/7] Executing Zen byte-patch dry run...' -ForegroundColor Yellow
    if (-not $modScriptMode) {
        & $ZenPatchScript -ChangesJson $ChangesJson -OutputDir $patchOutputDir -SchemasDir $SchemaDir -DryRun -PassThru
    } else {
        Write-Host '  DSL script already ran; no additional dry-run plan is available.' -ForegroundColor DarkYellow
    }
    Write-Host ''
    Write-Host 'Dry run complete - no files deployed.' -ForegroundColor DarkYellow
    if (-not $KeepTemp -and (Test-Path $tmpChangesFile)) { Remove-Item $tmpChangesFile -Force -ErrorAction SilentlyContinue }
    return
}

# Capture pre-change safety snapshot and optional Git checkpoint.
$preWorkSnapshot = Get-P3RDirectorySnapshot -Path $workDir
$preInstallSnapshot = if (Test-Path (Join-Path $ReloadedModsDir $ModName)) { Get-P3RDirectorySnapshot -Path (Join-Path $ReloadedModsDir $ModName) } else { @() }
$beforeHash = Get-P3RSnapshotHash -Snapshot (@($preWorkSnapshot) + @($preInstallSnapshot))
$userInputText = if ($UserInput) { $UserInput } elseif ($ChangesJson) { "ChangesJson=$ChangesJson" } elseif ($ModScript) { "ModScript=$ModScript" } else { "inline Changes ($($changeList.Count))" }

if (-not $SkipGitBackup) {
    $gitBackup = Invoke-P3RGitPreModBackup -ModName $ModName -Reason $userInputText -Paths @($stableChangesFile, (Join-Path $workDir 'mod.json'), (Join-Path $workDir 'history.json'))
    if ($gitBackup.committed) {
        Write-Host "Git pre-mod backup committed: $($gitBackup.commit)" -ForegroundColor Green
    } elseif ($gitBackup.skipped) {
        Write-Host "Git pre-mod backup skipped: $($gitBackup.reason)" -ForegroundColor DarkYellow
    }
} else {
    $gitBackup = [PSCustomObject]@{ attempted=$false; committed=$false; skipped=$true; reason='-SkipGitBackup'; commit=$null; files=@() }
    Write-Host 'Git pre-mod backup skipped (-SkipGitBackup).' -ForegroundColor DarkYellow
}

# Backup current generated/installed state before patch/deploy.
$backupDescription = "pre-mod backup before $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
if (Test-Path $workDir) {
    & $BackupScript -ModName $ModName -Path $workDir -Description $backupDescription -ChangesJson $ChangesJson -VirtualPath $vpath -SchemaKey $SchemaKey | Out-Host
}

# ── Step 4: Execute Zen patch ─────────────────────────────────────────────────
Write-Host ''
Write-Host '[4/7] Executing Zen byte-patch...' -ForegroundColor Yellow
if ($modScriptMode) {
    $assetCount = @(Get-ChildItem $patchOutputDir -Filter '*.uasset' -ErrorAction SilentlyContinue).Count
    Write-Host "  Assets already generated by DSL script in: $patchOutputDir ($assetCount file(s))"
} else {
    & $ZenPatchScript -ChangesJson $ChangesJson -OutputDir $patchOutputDir -SchemasDir $SchemaDir -PassThru
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "Invoke-ZenPatch failed with exit code $LASTEXITCODE" }
}

$patchedAssets = @(Get-ChildItem $patchOutputDir -Filter '*.uasset' -ErrorAction SilentlyContinue)
if ($patchedAssets.Count -eq 0) { throw 'No .uasset files were produced' }
foreach ($asset in $patchedAssets) {
    & $GuardScript -TableKey $TableKey -SchemaKey $SchemaKey -ChangesJson $ChangesJson -ModName $ModName -CheckOutput -OutputAsset $asset.FullName
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "post-patch guard failed for $($asset.Name) with exit code $LASTEXITCODE" }
}

# ── Step 5: Pack optional PAK fallback ────────────────────────────────────────
Write-Host ''
$pakFile = $null
if (-not $PackPak) {
    Write-Host '[5/7] PAK: skipped (default = UnrealEssentials loose files). Use -PackPak for fallback.' -ForegroundColor DarkGray
} elseif (Test-Path $UnrealPak) {
    Write-Host '[5/7] Building optional PAK artifact...' -ForegroundColor Yellow
    $pakFile = Join-Path $modPakDir "$ModName`_P.pak"
    $manifestPath = Join-Path $workDir 'manifest.txt'
    $manifestLines = $patchedAssets | ForEach-Object {
        $relPath = $_.FullName -replace [regex]::Escape($patchOutputDir), ''
        $relPath = $relPath -replace '^\\', ''
        "`"$($_.FullName)`" `"../../../P3R/Content/Xrd777/$relPath`""
    }
    $manifestLines | Out-File $manifestPath -Encoding UTF8

    $unrealPakDir = Split-Path $UnrealPak -Parent
    Push-Location $unrealPakDir
    $null = & $UnrealPak $pakFile "-Create=$manifestPath" -compress
    Pop-Location

    if ($LASTEXITCODE -eq 0 -and (Test-Path $pakFile)) {
        $pakSize = [math]::Round((Get-Item $pakFile).Length / 1KB, 1)
        if ($pakSize -lt 1) {
            Write-Host "  WARNING: PAK is suspiciously small ($pakSize KB) - may be empty!" -ForegroundColor Red
            $pakFile = $null
        } else {
            Write-Host "  PAK created: $pakFile ($pakSize KB)" -ForegroundColor Green
        }
    } else {
        Write-Host '  PAK packing may have failed.' -ForegroundColor Yellow
        $pakFile = $null
    }
} else {
    Write-Host '[5/7] UnrealPak not found. Skipping PAK build.' -ForegroundColor DarkYellow
}

# ── Step 6: Install to Reloaded II ────────────────────────────────────────────
Write-Host ''
Write-Host '[6/7] Installing to Reloaded II...' -ForegroundColor Yellow
$reloadedModDir = Join-Path $ReloadedModsDir $ModName
$displayName = if ($ModDisplayName) { $ModDisplayName } else { $ModName }
$desc = if ($ModDescription) { $ModDescription } else { "Auto-generated Zen byte-patch mod for $assetName" }
$deps = @($ModDependencies)
if ($pakFile -and (Test-Path $pakFile) -and ((Get-Item $pakFile).Length -gt 1024) -and ($deps -notcontains 'reloaded.universal.fileemulationframework.pak')) {
    $deps += 'reloaded.universal.fileemulationframework.pak'
}

if ($NoInstall) {
    Write-Host "  Skipped (-NoInstall). Assets ready in: $patchOutputDir" -ForegroundColor DarkYellow
} else {
    $vRel = $vpath -replace '^P3R/', ''
    $vRelDir = Split-Path $vRel -Parent
    $vRelDir = $vRelDir -replace '\\', '/'
    $targetDir = "$reloadedModDir\UnrealEssentials\P3R\$vRelDir" -replace '/', '\'

    if (Test-Path $reloadedModDir) {
        & $BackupScript -ModName $ModName -Path $reloadedModDir -Description 'pre-install Reloaded II backup' -ChangesJson $ChangesJson -VirtualPath $vpath -SchemaKey $SchemaKey | Out-Host
        Remove-Item -Recurse -Force -Confirm:$false $reloadedModDir
    }
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

    foreach ($asset in $patchedAssets) {
        $destName = Split-Path $vpath -Leaf
        if ($patchedAssets.Count -gt 1) { $destName = $asset.Name }
        Copy-Item $asset.FullName -Destination (Join-Path $targetDir $destName) -Force
        Write-Host "  UnrealEssentials: $(Join-Path $targetDir $destName) ($([math]::Round($asset.Length/1KB,1)) KB)" -ForegroundColor Green
    }

    if ($pakFile -and (Test-Path $pakFile) -and ((Get-Item $pakFile).Length -gt 1024)) {
        $reloadedPakDir = Join-Path $reloadedModDir 'FEmulator\PAK'
        New-Item -ItemType Directory -Force -Path $reloadedPakDir | Out-Null
        Copy-Item $pakFile -Destination (Join-Path $reloadedPakDir "$ModName.pak") -Force
        Write-Host "  FEmulator/PAK/$ModName.pak [fallback]" -ForegroundColor Green
    }

    $modConfig = New-ModConfigObject -Id $ModName -DisplayName $displayName -Author $ModAuthor -Description $desc -Dependencies $deps
    $modConfig | ConvertTo-Json -Depth 8 | Out-File (Join-Path $reloadedModDir 'ModConfig.json') -Encoding UTF8
    Write-Host '  ModConfig.json written' -ForegroundColor Green
}

# ── Step 7: Metadata / registry ───────────────────────────────────────────────
Write-Host ''
Write-Host '[7/7] Writing metadata / registry...' -ForegroundColor Yellow
$changeMeta = if (-not $modScriptMode) { Get-ChangeMetadata -ChangeList $changeList -Schema $ctx.Schema } else { @() }
$assetMeta = @($patchedAssets | ForEach-Object {
    [PSCustomObject]@{ path = $_.FullName; name = $_.Name; length = $_.Length; sha256 = (Get-FileHash $_.FullName -Algorithm SHA256).Hash }
})

$postWorkSnapshot = Get-P3RDirectorySnapshot -Path $workDir
$postInstallSnapshot = if (-not $NoInstall -and (Test-Path $reloadedModDir)) { Get-P3RDirectorySnapshot -Path $reloadedModDir } else { @() }
$afterHash = Get-P3RSnapshotHash -Snapshot (@($postWorkSnapshot) + @($postInstallSnapshot))

$modJson = [PSCustomObject]@{
    schemaVersion = 2
    modName = $ModName
    displayName = $displayName
    author = $ModAuthor
    description = $desc
    createdAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    updatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    tableKey = $TableKey
    schemaKey = $SchemaKey
    virtualPath = $vpath
    installMode = if ($NoInstall) { 'NoInstall' } else { 'UnrealEssentials' }
    workDir = $workDir
    installedDir = if ($NoInstall) { $null } else { $reloadedModDir }
    changesJson = if ($ChangesJson) { $ChangesJson } else { $null }
    changes = $changeMeta
    assets = $assetMeta
    safety = [PSCustomObject]@{
        beforeHash = $beforeHash
        afterHash = $afterHash
        gitBackup = $gitBackup
        workSnapshot = @($postWorkSnapshot)
        installedSnapshot = @($postInstallSnapshot)
    }
}
$modJson | ConvertTo-Json -Depth 12 | Out-File (Join-Path $workDir 'mod.json') -Encoding UTF8

Add-P3RHistoryEntry -ModDir $workDir -Action 'modify-and-repack' -VirtualPath $vpath -SchemaKey $SchemaKey -UserInput $userInputText -BeforeHash $beforeHash -AfterHash $afterHash -Details ([PSCustomObject]@{ dryRun=$false; noInstall=[bool]$NoInstall; changes=$changeMeta; gitBackup=$gitBackup; assets=$assetMeta }) | Out-Null

Set-P3RModEntry -Entry ([PSCustomObject]@{
    schemaVersion = 2
    modName = $ModName
    displayName = $displayName
    schemaKey = $SchemaKey
    tableKey = $TableKey
    virtualPath = $vpath
    workDir = $workDir
    installedDir = if ($NoInstall) { $null } else { $reloadedModDir }
    lastModified = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    beforeHash = $beforeHash
    afterHash = $afterHash
    changes = $changeMeta
})
Write-Host "  mod.json/history.json/registry written" -ForegroundColor Green

if (-not $KeepTemp -and (Test-Path $tmpChangesFile)) { Remove-Item $tmpChangesFile -Force -ErrorAction SilentlyContinue }

Write-Host ''
Write-Host '============================================' -ForegroundColor Green
Write-Host ' Pipeline Complete' -ForegroundColor Green
Write-Host '============================================' -ForegroundColor Green
Write-Host "Work files: $workDir"
Get-ChildItem $workDir | ForEach-Object {
    $sizeInfo = if ($_.PSIsContainer) { '[dir]' } else { "$([math]::Round($_.Length/1KB,1)) KB" }
    Write-Host "  $($_.Name)  $sizeInfo"
}
if (-not $NoInstall) {
    Write-Host ''
    Write-Host "Mod installed: $reloadedModDir"
    Write-Host '  Enable it in Reloaded II UI'
    Write-Host '  Launch P3R via Reloaded-II.exe'
}
