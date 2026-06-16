# P3R Full Mod Pipeline: Read → Modify → Generate → Pack
param(
    [string]$TableKey,              # Config key: Skills, Personas, Items, etc.
    [string]$VirtualPath,           # Or direct virtual path to the .uasset
    [string]$ModScript,             # Path to PowerShell script that modifies the JSON
    [string]$ModName = "MyMod"      # Output PAK name (without _P suffix)
)

. "$PSScriptRoot\Config.ps1"

# Determine the virtual path
$vpath = if ($VirtualPath) { $VirtualPath }
         elseif ($DataTables[$TableKey]) { $DataTables[$TableKey] }
         else { throw "Unknown table: $TableKey. Use -VirtualPath or a known -TableKey" }

$assetName = [System.IO.Path]::GetFileNameWithoutExtension($vpath)
$workDir = "$ModOutput\$assetName"
$modPakDir = "$ProjectRoot\ModOutput"
New-Item -ItemType Directory -Force -Path $workDir, $modPakDir | Out-Null

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " P3R Mod Pipeline: $assetName" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Virtual path: $vpath"
Write-Host "Work dir:     $workDir"
Write-Host ""

# Step 1: Read original asset to JSON
Write-Host "[1/3] Reading original DataTable..." -ForegroundColor Yellow
$originalJson = "$workDir\$assetName`_original.json"
& $DataTools read $vpath $originalJson 2>&1 | Select-Object -Last 2
if (-not (Test-Path $originalJson)) {
    Write-Error "Failed to read DataTable"
    exit 1
}
Write-Host "  Original: $originalJson ($([math]::Round((Get-Item $originalJson).Length/1KB,1)) KB)"
Write-Host ""

# Step 2: Apply modifications
Write-Host "[2/3] Applying modifications..." -ForegroundColor Yellow
$modifiedJson = "$workDir\$assetName`_modified.json"
Copy-Item $originalJson $modifiedJson -Force

if ($ModScript -and (Test-Path $ModScript)) {
    Write-Host "  Running mod script: $ModScript"
    & $ModScript -JsonPath $modifiedJson
} else {
    Write-Host "  No mod script provided. Edit the JSON manually:"
    Write-Host "    $modifiedJson"
}
Write-Host ""

# Step 3: Generate manifest and pack instructions
Write-Host "[3/3] Preparing mod PAK..." -ForegroundColor Yellow

# Generate manifest.txt
$manifestFile = "$workDir\manifest.txt"
$mountBase = "../../../$vpath"
@"
"$assetName.uasset" "$mountBase"
"$assetName.uexp" "$($mountBase -replace '\.uasset$','.uexp')"
"@ | Out-File $manifestFile -Encoding utf8
Write-Host "  Manifest: $manifestFile"

# Output summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " JSON files ready" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Modified JSON: $modifiedJson"
Write-Host "Manifest:      $manifestFile"
Write-Host ""
Write-Host "MANUAL STEP (one-time): Convert JSON to .uasset + .uexp"
Write-Host "  Use UAssetGUI or FModel to create the .uasset/.uexp pair from the modified JSON."
Write-Host "  Place the resulting .uasset and .uexp files in: $workDir"
Write-Host ""
Write-Host "Then pack with UnrealPak:"
Write-Host "  cd $workDir"
Write-Host "  $UnrealPak `"$modPakDir\$ModName`_P.pak`" -Create=`"$manifestFile`" -compress"
Write-Host ""
Write-Host "Install: Copy $ModName`_P.pak to the game's Content\Paks\ directory"
