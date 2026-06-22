# P3R Full Mod Pipeline: Read -> Modify -> Create .uasset/.uexp -> Pack
# Sprint 1: Fully automated, no manual steps
param(
    [string]$TableKey,              # Config key: Skills, Personas, Items, etc.
    [string]$VirtualPath,           # Or direct virtual path to the .uasset
    [string]$ModScript,             # Path to PowerShell script that modifies the JSON
    [string]$ModName = "MyMod",     # Output PAK name (without _P suffix)
    [switch]$NoPack                 # Skip PAK packing (just create .uasset+.uexp)
)

. "$PSScriptRoot\Config.ps1"

# Determine the virtual path
$vpath = if ($VirtualPath) { $VirtualPath }
         elseif ($DataTables[$TableKey]) { $DataTables[$TableKey] }
         else { throw "Unknown table: $TableKey. Use -VirtualPath or a known -TableKey" }

$assetName = [System.IO.Path]::GetFileNameWithoutExtension($vpath)
$workDir = "$ModOutput\$assetName"
$modPakDir = "$ProjectRoot\tools\Output\mod"
New-Item -ItemType Directory -Force -Path $workDir, $modPakDir | Out-Null

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " P3R Mod Pipeline: $assetName" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Virtual path: $vpath"
Write-Host "Work dir:     $workDir"
Write-Host ""

# Step 1: Read original asset to JSON
Write-Host "[1/4] Reading original DataTable..." -ForegroundColor Yellow
$originalJson = "$workDir\$assetName`_original.json"
& $DataTools read $vpath $originalJson 2>&1 | Select-Object -Last 2
if (-not (Test-Path $originalJson)) {
    Write-Error "Failed to read DataTable"
    exit 1
}
Write-Host "  Original: $originalJson ($([math]::Round((Get-Item $originalJson).Length/1KB,1)) KB)"
Write-Host ""

# Step 2: Apply modifications
Write-Host "[2/4] Applying modifications..." -ForegroundColor Yellow
$modifiedJson = "$workDir\$assetName`_modified.json"

if ($ModScript -and (Test-Path $ModScript)) {
    # ModScript receives -JsonPath and modifies the file in-place
    Write-Host "  Running mod script: $ModScript"
    Copy-Item $originalJson $modifiedJson -Force
    & $ModScript -JsonPath $modifiedJson
} else {
    # No script: copy original to modified, user edits manually
    Copy-Item $originalJson $modifiedJson -Force
    Write-Host "  No mod script provided. Edit the JSON manually:"
    Write-Host "    $modifiedJson"
}
Write-Host ""

# Step 3: Create .uasset + .uexp from modified JSON
Write-Host "[3/4] Creating .uasset+.uexp from modified JSON..." -ForegroundColor Yellow
& $DataTools create $modifiedJson $workDir 2>&1 | Select-Object -Last 5
if (-not (Test-Path "$workDir\$assetName.uasset")) {
    Write-Error "Failed to create .uasset+.uexp"
    exit 1
}
Write-Host ""

# Step 4: Pack with UnrealPak
Write-Host "[4/4] Packing PAK..." -ForegroundColor Yellow
if ($NoPack) {
    Write-Host "  Skipped (--NoPack). Files ready in: $workDir" -ForegroundColor DarkYellow
} elseif (Test-Path $UnrealPak) {
    $pakFile = "$modPakDir\$ModName`_P.pak"
    $manifestFile = "$workDir\manifest.txt"

    # UnrealPak resolves source file paths relative to its EXE directory,
    # NOT the current working directory. We need absolute source paths.
    # Strategy: create a temp manifest with absolute paths, pack from UnrealPak dir.
    $absManifestFile = "$workDir\manifest_abs.txt"
    $absUasset = (Resolve-Path "$workDir\$assetName.uasset").Path
    $absUexp = (Resolve-Path "$workDir\$assetName.uexp").Path
    # Extract mount path from the original manifest (it has the right format)
    $mountLines = Get-Content $manifestFile
    $mountUasset = ($mountLines[0] -split '"')[3]
    $mountUexp = ($mountLines[1] -split '"')[3]
    @"
"$absUasset" "$mountUasset"
"$absUexp" "$mountUexp"
"@ | Out-File $absManifestFile -Encoding ASCII

    $unrealPakDir = Split-Path $UnrealPak -Parent
    Push-Location $unrealPakDir
    $result = & $UnrealPak $pakFile "-Create=$absManifestFile" -compress 2>&1
    Pop-Location

    if ($LASTEXITCODE -eq 0 -and (Test-Path $pakFile)) {
        $pakSize = [math]::Round((Get-Item $pakFile).Length / 1KB, 1)
        # Empty PAK is ~0.4 KB (header only). A real PAK with data is > 5 KB.
        if ($pakSize -lt 1) {
            Write-Host "  WARNING: PAK is suspiciously small ($pakSize KB) — may be empty!" -ForegroundColor Red
            Write-Host "  UnrealPak likely couldn't find the source files." -ForegroundColor Red
            Write-Host "  Check that .uasset and .uexp exist: $workDir" -ForegroundColor DarkYellow
        } else {
            Write-Host "  PAK created: $pakFile ($pakSize KB)" -ForegroundColor Green
        }
    } else {
        Write-Host "  PAK packing may have failed. Check output above." -ForegroundColor Yellow
        Write-Host "  Manifest: $manifestFile" -ForegroundColor DarkYellow
        Write-Host "  UnrealPak output: $result" -ForegroundColor DarkYellow
    }
} else {
    Write-Host "  UnrealPak not found. Manual pack:" -ForegroundColor DarkYellow
    Write-Host "    cd $workDir"
    Write-Host "    UnrealPak.exe `"../$ModName`_P.pak`" -Create=`"manifest.txt`" -compress"
}

# Summary + Install to Reloaded II
$reloadedModDir = "$ProjectRoot\tools\Reloaded II\Mods\$ModName"
$reloadedPakDir = "$reloadedModDir\FEmulator\PAK"

# Create Reloaded II Mod directory
if (Test-Path $reloadedModDir) { Remove-Item -Recurse -Force $reloadedModDir }
New-Item -ItemType Directory -Force $reloadedPakDir | Out-Null

# Copy PAK only if it has meaningful content (>1KB)
$srcPak = "$modPakDir\$ModName`_P.pak"
if ((Test-Path $srcPak) -and ((Get-Item $srcPak).Length -gt 1024)) {
    Copy-Item $srcPak -Destination "$reloadedPakDir\$ModName.pak" -Force
    Write-Host "  FEmulator/PAK/$ModName.pak ($([math]::Round((Get-Item "$reloadedPakDir\$ModName.pak").Length/1KB,1)) KB)"
} elseif (Test-Path $srcPak) {
    Write-Host "  WARNING: PAK too small, skipping Reloaded II install" -ForegroundColor Red
    Write-Host "  Manual pack required: cd $workDir; UnrealPak.exe ..." -ForegroundColor Red
}

# Write canonical ModConfig.json
@"
{
  "ModId": "$ModName",
  "ModName": "$ModName",
  "ModAuthor": "claude",
  "ModVersion": "1.0.0",
  "ModDescription": "Auto-generated mod for $assetName",
  "SupportedAppId": ["p3r.exe"],
  "ModDependencies": ["reloaded.universal.fileemulationframework.pak"]
}
"@ | Out-File "$reloadedModDir\ModConfig.json" -Encoding UTF8

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " Pipeline Complete" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Output files in: $workDir"
Get-ChildItem $workDir | ForEach-Object { Write-Host "  $($_.Name) ($([math]::Round($_.Length/1KB,1)) KB)" }
if (-not $NoPack -and (Test-Path $UnrealPak)) {
    Write-Host ""
    Write-Host "Reloaded II Mod installed: $reloadedModDir"
    Write-Host "  FEmulator/PAK/$ModName.pak ($([math]::Round((Get-Item "$reloadedPakDir\$ModName.pak").Length/1KB,1)) KB)"
    Write-Host ""
    Write-Host "Install: Copy $ModName_P.pak to Reloaded II Mods/$ModName/FEmulator/PAK/"
}
