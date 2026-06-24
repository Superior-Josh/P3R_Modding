# P3R Full Mod Pipeline: Zen Byte-Patch → Deploy (Sprint 1.5 T1.5.7)
#
# Replaces the old P3RDataTools.create path with the Zen byte-patch pipeline.
# Default install mode: UnrealEssentials (loose-file path-mirroring).
# Default ModDependencies: ["p3rpc.essentials"] (project-wide convention from
# 2026-06-24; see docs/MODDING_PITFALLS.md P-008).
# Optional -PackPak also builds a FEmulator/PAK as a fallback artifact.
#
# Usage — schema key + inline changes:
#   .\modify-and-repack.ps1 -SchemaKey p3re_skillNormal `
#     -Changes @(@{target='Data[10].hpn'; value=999}) -ModName "AgiMod"
#
# Usage — table key alias:
#   .\modify-and-repack.ps1 -TableKey Skills `
#     -Changes @(@{target='Data[10].hpn'; value=999}) -ModName "AgiMod"
#
# Usage — changes.json file:
#   .\modify-and-repack.ps1 -TableKey Skills -ChangesJson .\changes.json
#
# Usage — DSL script (dot-sources P3RModDSL.psm1 and calls DSL functions):
#   .\modify-and-repack.ps1 -ModScript .\agi-buff.ps1 -ModName "AgiMod"
#
# Usage — dry run (preview plan, no writes):
#   .\modify-and-repack.ps1 -TableKey Skills -Changes @(...) -DryRun

param(
    # ── Schema resolution (at least one required) ─────────────────────────
    [string] $TableKey,              # Config key: Skills, Personas, Items, etc.
    [string] $SchemaKey,             # Direct schema key: p3re_skillNormal
    [string] $VirtualPath,           # Or direct virtual path to the .uasset

    # ── Change specification (at least one required) ──────────────────────
    [string] $ModScript,             # Path to .ps1 that calls DSL functions (imports P3RModDSL.psm1)
    [string] $ChangesJson,           # Path to pre-built changes.json (Invoke-ZenPatch format)
    [hashtable[]] $Changes,          # Inline array of @{target='Data[10].hpn'; value=999} hashtables

    # ── Mod metadata ──────────────────────────────────────────────────────
    [string] $ModName = "MyMod",
    [string] $ModDisplayName,
    [string] $ModAuthor = "claude",
    [string] $ModDescription,
    [string[]] $ModDependencies = @('p3rpc.essentials'),

    # ── Options ───────────────────────────────────────────────────────────
    [switch] $PackPak,               # Also build a FEmulator/PAK fallback artifact
    [switch] $NoInstall,             # Skip copying into Reloaded II Mods/
    [switch] $DryRun,                # Preview changes without writing bytes
    [switch] $KeepTemp,              # Keep temporary changes.json for inspection
    [switch] $Force                  # Skip confirmation prompt for destructive operations
)

$ErrorActionPreference = 'Stop'

# ── Dot-source config + locate scripts ────────────────────────────────────────
. "$PSScriptRoot\Config.ps1"
$ProjectRoot = Resolve-Path "$PSScriptRoot\..\.."
$ZenPatchScript  = "$PSScriptRoot\Invoke-ZenPatch.ps1"
$DSLModule       = "$PSScriptRoot\dsl\P3RModDSL.psm1"
$SchemasDir      = "$ProjectRoot\tools\templates-010\schemas"

# ── Schema -> virtual path / asset name resolution ────────────────────────────
if ($VirtualPath) {
    $vpath = $VirtualPath
} elseif ($DataTables[$TableKey]) {
    $vpath = $DataTables[$TableKey]
} elseif ($SchemaKey) {
    # Try to resolve from schema JSON
    $schemaFile = Join-Path $SchemasDir "${SchemaKey}_schema.json"
    if (-not (Test-Path $schemaFile)) {
        throw "Schema '$SchemaKey' not found. Use -TableKey, -VirtualPath, or a known -SchemaKey"
    }
    $schemaObj = Get-Content $schemaFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $vpath = $schemaObj.sourceAssetPath
    if ($vpath -match [regex]::Escape('Extracted\IoStore\') + '(P3R\\.+)') {
        $vpath = $matches[1]
    }
} else {
    throw "Must specify one of: -TableKey, -SchemaKey, or -VirtualPath"
}

# Normalize virtual path: strip Extracted/IoStore/ prefix if present
$vpath = $vpath -replace '^.*?\\P3R\\Content\\', 'P3R/Content/'
$vpath = $vpath -replace '\\', '/'

# Also strip Extracted/IoStore/ prefix that might appear in paths like Blueprints/
if ($vpath -notmatch '^P3R/') {
    if ($vpath -match 'Extracted/IoStore/(P3R/.+)') {
        $vpath = $matches[1]
    }
}

$assetName = [System.IO.Path]::GetFileNameWithoutExtension($vpath)
$workDir   = "$ModOutput\$ModName"
$modPakDir = "$ModOutput"
New-Item -ItemType Directory -Force -Path $workDir, $modPakDir | Out-Null

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " P3R Mod Pipeline (Zen Byte-Patch)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Asset  : $assetName"
Write-Host "VPath  : $vpath"
Write-Host "Mod    : $ModName"
Write-Host "Work   : $workDir"
Write-Host ""

# ── Step 1: Resolve schema key ────────────────────────────────────────────────
if (-not $SchemaKey) {
    # Walk all schemas to find which one's sourceAssetPath matches this virtual path.
    # Skip deprecated duplicates (dat-* schemas that shadow canonical p3re_* ones).
    $allSchemas = @(Get-ChildItem $SchemasDir -Filter '*_schema.json' | Where-Object {
        $_.Name -notmatch '^p3re_dat'   # deprecated duplicates; canonical schemas use p3re_ prefix
    })
    foreach ($sf in $allSchemas) {
        $s = Get-Content $sf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($s.sourceAssetPath -and $s.sourceAssetPath -match [regex]::Escape($vpath)) {
            $SchemaKey = $s.templateFile -replace '\.bt$', ''
            break
        }
    }
    if (-not $SchemaKey) {
        # Fallback: try matching by asset name (also skip deprecated)
        foreach ($sf in $allSchemas) {
            $s = Get-Content $sf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($s.asset -and $s.asset -ieq "$assetName.uasset") {
                $SchemaKey = $s.templateFile -replace '\.bt$', ''
                break
            }
        }
    }
    if (-not $SchemaKey) {
        throw "Cannot resolve schema key for '$assetName'. No schema has matching sourceAssetPath or asset name. Use -SchemaKey to specify directly."
    }
}
Write-Host "[1/4] Schema resolved: $SchemaKey" -ForegroundColor Yellow

# ── Step 2: Prepare changes.json ──────────────────────────────────────────────
$tmpChangesFile = "$workDir\changes_$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

Write-Host "[2/4] Preparing changes..." -ForegroundColor Yellow

if ($ModScript) {
    # ModScript is a .ps1 that uses DSL functions. We dot-source the DSL module
    # and run the script; the script must call DSL functions with -OutputDir pointing
    # to a temp asset directory, then we collect all generated .uasset files.
    Write-Host "  ModScript: $ModScript"
    $dslAssetDir = "$workDir\dsl_assets"
    New-Item -ItemType Directory -Force -Path $dslAssetDir | Out-Null

    Import-Module $DSLModule -Force
    . $ModScript

    # After the script runs, collect any .uasset files it generated
    $dslAssets = Get-ChildItem $dslAssetDir -Filter '*.uasset' -ErrorAction SilentlyContinue
    if ($dslAssets.Count -eq 0) {
        Write-Warning "  ModScript did not produce any .uasset files in $dslAssetDir."
        Write-Warning "  Make sure the script calls DSL functions with -OutputDir '$dslAssetDir'."
    } else {
        Write-Host "  DSL generated $($dslAssets.Count) asset(s):"
        $dslAssets | ForEach-Object { Write-Host "    $($_.Name) ($([math]::Round($_.Length/1KB,1)) KB)" }
    }
    # DSL path → assets already in dsl_assets, proceed to install
    $patchOutputDir = $dslAssetDir
}
elseif ($ChangesJson) {
    # Pre-built changes.json → call Invoke-ZenPatch directly
    if (-not (Test-Path $ChangesJson)) {
        throw "ChangesJson not found: $ChangesJson"
    }
    Write-Host "  Source: $ChangesJson"
    $changesObj = Get-Content $ChangesJson -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $changesObj.schemaKey) {
        # Inject schema key if missing
        $changesObj | Add-Member -NotePropertyName 'schemaKey' -NotePropertyValue $SchemaKey -Force
        $changesObj | ConvertTo-Json -Depth 6 | Set-Content $tmpChangesFile -Encoding UTF8
        $ChangesJson = $tmpChangesFile
    }
    $patchOutputDir = $workDir
}
elseif ($Changes -and $Changes.Count -gt 0) {
    # Inline changes → build changes.json
    $changesObj = @{ schemaKey = $SchemaKey; changes = $Changes }
    $changesObj | ConvertTo-Json -Depth 6 | Set-Content $tmpChangesFile -Encoding UTF8
    $ChangesJson = $tmpChangesFile
    Write-Host "  $($Changes.Count) change(s) specified inline:"
    foreach ($c in $Changes) {
        Write-Host "    $($c.target) = $($c.value)" -ForegroundColor DarkGray
    }
    $patchOutputDir = $workDir
}
else {
    throw "Must specify one of: -ModScript, -ChangesJson, or -Changes"
}

Write-Host ""

# ── Step 3: Execute Zen patch (or DSL script which already produced assets) ───
Write-Host "[3/4] Executing Zen byte-patch..." -ForegroundColor Yellow

if ($ModScript) {
    # DSL already ran and produced assets — skip Invoke-ZenPatch
    Write-Host "  Assets already generated by DSL script in: $patchOutputDir"
    $assetCount = @(Get-ChildItem $patchOutputDir -Filter '*.uasset' -ErrorAction SilentlyContinue).Count
    Write-Host "  Found $assetCount .uasset file(s)"
} else {
    # Run Invoke-ZenPatch
    $zenParams = @{
        ChangesJson = $ChangesJson
        OutputDir   = $patchOutputDir
        SchemasDir  = $SchemasDir
        PassThru    = $true
    }
    if ($DryRun) { $zenParams.DryRun = $true }

    $result = & $ZenPatchScript @zenParams 2>&1
    Write-Host $result
    # Invoke-ZenPatch exits cleanly for DryRun; it only sets LASTEXITCODE on process errors
    if ((Test-Path variable:global:LASTEXITCODE) -and ($global:LASTEXITCODE -ne 0)) {
        Write-Error "Invoke-ZenPatch failed with exit code $global:LASTEXITCODE"
        exit 1
    }
}

if ($DryRun) {
    Write-Host ""
    Write-Host "  Dry run complete — no files deployed." -ForegroundColor DarkYellow
    if (-not $KeepTemp) { Remove-Item $tmpChangesFile -Force -ErrorAction SilentlyContinue }
    return
}

# Collect all patched .uasset files
$patchedAssets = @(Get-ChildItem $patchOutputDir -Filter '*.uasset' -ErrorAction SilentlyContinue)
if ($patchedAssets.Count -eq 0) {
    Write-Error "No .uasset files were produced"
    exit 1
}

Write-Host ""

# ── Step 4: Pack PAK (optional fallback) ──────────────────────────────────────
$pakFile = $null
if (-not $PackPak) {
    Write-Host "[4/4] PAK: skipped (default = UnrealEssentials loose files). Use -PackPak for PAK fallback." -ForegroundColor DarkGray
} elseif (Test-Path $UnrealPak) {
    Write-Host "[4/4] Building optional PAK artifact..." -ForegroundColor Yellow
    $pakFile = "$modPakDir\$ModName`_P.pak"

    # Build manifest from all .uasset files in the work dir
    $manifestPath = "$workDir\manifest.txt"
    $manifestLines = $patchedAssets | ForEach-Object {
        $relPath = $_.FullName -replace [regex]::Escape($patchOutputDir), ''
        $relPath = $relPath -replace '^\\', ''
        "`"$($_.FullName)`" `"../../../P3R/Content/Xrd777/$relPath`""
    }
    $manifestLines | Out-File $manifestPath -Encoding UTF8

    $unrealPakDir = Split-Path $UnrealPak -Parent
    Push-Location $unrealPakDir
    $null = & $UnrealPak $pakFile "-Create=$manifestPath" -compress 2>&1
    Pop-Location

    if ($LASTEXITCODE -eq 0 -and (Test-Path $pakFile)) {
        $pakSize = [math]::Round((Get-Item $pakFile).Length / 1KB, 1)
        if ($pakSize -lt 1) {
            Write-Host "  WARNING: PAK is suspiciously small ($pakSize KB) — may be empty!" -ForegroundColor Red
            $pakFile = $null
        } else {
            Write-Host "  PAK created: $pakFile ($pakSize KB)" -ForegroundColor Green
        }
    } else {
        Write-Host "  PAK packing may have failed." -ForegroundColor Yellow
        $pakFile = $null
    }
} else {
    Write-Host "  UnrealPak not found. Skipping PAK build." -ForegroundColor DarkYellow
}

# ── Step 5: Install to Reloaded II ────────────────────────────────────────────
Write-Host ""
Write-Host "[5/5] Installing to Reloaded II..." -ForegroundColor Yellow

$reloadedModDir = "$ProjectRoot\tools\Reloaded II\Mods\$ModName"

if ($NoInstall) {
    Write-Host "  Skipped (-NoInstall). Assets ready in: $patchOutputDir" -ForegroundColor DarkYellow
} else {
    # Resolve in-game content path: P3R/Content/Xrd777/... (strip the .uasset filename)
    $vRel = $vpath -replace '^P3R/', ''
    $vRelDir = Split-Path $vRel -Parent
    $vRelDir = $vRelDir -replace '\\', '/'

    # UnrealEssentials: <Mod>/UnrealEssentials/P3R/Content/.../<file>.uasset
    $targetDir = "$reloadedModDir\UnrealEssentials\P3R\$vRelDir" -replace '/', '\'

    # Clean previous install
    if (Test-Path $reloadedModDir) {
        if (-not $Force) {
            Write-Host "  Overwriting existing mod: $reloadedModDir" -ForegroundColor DarkGray
        }
        Remove-Item -Recurse -Force $reloadedModDir
    }
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

    # Copy all patched .uasset files
    foreach ($asset in $patchedAssets) {
        $destName = Split-Path $vpath -Leaf
        # If multiple assets, use each one's own name
        if ($patchedAssets.Count -gt 1) {
            $destName = $asset.Name
        }
        Copy-Item $asset.FullName -Destination "$targetDir\$destName" -Force
        Write-Host "  UnrealEssentials: $targetDir\$destName ($([math]::Round($asset.Length/1KB,1)) KB)" -ForegroundColor Green
    }

    # Optional PAK fallback
    if ($pakFile -and (Test-Path $pakFile) -and ((Get-Item $pakFile).Length -gt 1024)) {
        $reloadedPakDir = "$reloadedModDir\FEmulator\PAK"
        New-Item -ItemType Directory -Force -Path $reloadedPakDir | Out-Null
        Copy-Item $pakFile -Destination "$reloadedPakDir\$ModName.pak" -Force
        Write-Host "  FEmulator/PAK/$ModName.pak ($([math]::Round((Get-Item "$reloadedPakDir\$ModName.pak").Length/1KB,1)) KB) [fallback]" -ForegroundColor Green
    }

    # Write ModConfig.json
    $desc = if ($ModDescription) { $ModDescription } else { "Auto-generated mod for $assetName" }
    $deps = @($ModDependencies | ForEach-Object { '"' + $_ + '"' })
    if ($pakFile -and (Test-Path $pakFile) -and ((Get-Item $pakFile).Length -gt 1024) -and
        ($ModDependencies -notcontains 'reloaded.universal.fileemulationframework.pak')) {
        $deps += '"reloaded.universal.fileemulationframework.pak"'
    }
    $depsJson = $deps -join ', '

    $displayName = if ($ModDisplayName) { $ModDisplayName } else { $ModName }

    @"
{
  "ModId": "$ModName",
  "ModName": "$displayName",
  "ModAuthor": "$ModAuthor",
  "ModVersion": "1.0.0",
  "ModDescription": "$desc",
  "ModDll": "",
  "ModIcon": "",
  "ModR2RManagedDll32": "",
  "ModR2RManagedDll64": "",
  "ModNativeDll32": "",
  "ModNativeDll64": "",
  "Tags": [],
  "CanUnload": null,
  "HasExports": null,
  "IsLibrary": false,
  "ReleaseMetadataFileName": "$ModName.ReleaseMetadata.json",
  "PluginData": null,
  "IsUniversalMod": false,
  "ModDependencies": [$depsJson],
  "OptionalDependencies": [],
  "SupportedAppId": ["p3r.exe"],
  "ProjectUrl": ""
}
"@ | Out-File "$reloadedModDir\ModConfig.json" -Encoding UTF8

    Write-Host "  ModConfig.json written" -ForegroundColor Green
}

# ── Cleanup ───────────────────────────────────────────────────────────────────
if (-not $KeepTemp) {
    Remove-Item $tmpChangesFile -Force -ErrorAction SilentlyContinue
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " Pipeline Complete" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Work files: $workDir"
Get-ChildItem $workDir | ForEach-Object {
    $sizeInfo = if ($_.PSIsContainer) { "[dir]" } else { "$([math]::Round($_.Length/1KB,1)) KB" }
    Write-Host "  $($_.Name)  $sizeInfo"
}
if (-not $NoInstall) {
    Write-Host ""
    Write-Host "Mod installed: $reloadedModDir"
    Write-Host "  ✓ Enable it in Reloaded II UI"
    Write-Host "  ✓ Launch P3R via Reloaded-II.exe"
    Write-Host ""
    Write-Host "Quick verify:"
    Write-Host "  Dir '$reloadedModDir\UnrealEssentials' -Recurse -File"
}
