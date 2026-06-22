# P3R diff-changes.ps1 — Preview JSON changes before applying
# Usage:
#   .\diff-changes.ps1 -Original skills.json -Modified skills_modified.json
#   .\diff-changes.ps1 -Original skills.json -ModScript .\my-changes.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$Original,
    [string]$Modified,
    [string]$ModScript
)

. "$PSScriptRoot\..\Config.ps1"

if (-not (Test-Path $Original)) {
    Write-Error "Original file not found: $Original"
    exit 1
}

# Apply mod script if provided
if ($ModScript) {
    if (-not (Test-Path $ModScript)) {
        Write-Error "Mod script not found: $ModScript"
        exit 1
    }
    $Modified = [System.IO.Path]::GetTempFileName() + ".json"
    Copy-Item $Original $Modified -Force
    & $ModScript -JsonPath $Modified
}

if (-not $Modified -or -not (Test-Path $Modified)) {
    Write-Error "Modified file not found: $Modified"
    exit 1
}

Write-Host "=== Diff Preview ===" -ForegroundColor Cyan
Write-Host "Original: $Original"
Write-Host "Modified: $Modified"
Write-Host ""

# Load both JSONs. PowerShell 5.1 ConvertFrom-Json doesn't support -Depth, so we
# parse the raw JSON strings and diff them directly for known DataTable shape.
$origContent = Get-Content $Original -Raw -Encoding UTF8
$modContent = Get-Content $Modified -Raw -Encoding UTF8

try { $orig = $origContent | ConvertFrom-Json } catch { Write-Error "Failed to parse original JSON: $_"; exit 1 }
try { $mod = $modContent | ConvertFrom-Json } catch { Write-Error "Failed to parse modified JSON: $_"; exit 1 }

# Compare Data arrays if they exist
$origData = $orig.Properties.Data
$modData = $mod.Properties.Data

if ($origData -and $modData) {
    $changes = 0
    for ($i = 0; $i -lt [Math]::Min($origData.Count, $modData.Count); $i++) {
        $oRow = $origData[$i]
        $mRow = $modData[$i]
        foreach ($prop in $oRow.PSObject.Properties) {
            $newVal = $mRow.($prop.Name)
            $oldVal = $prop.Value
            if ("$newVal" -ne "$oldVal") {
                Write-Host "  Row[$i].$($prop.Name): $oldVal -> $newVal" -ForegroundColor Yellow
                $changes++
            }
        }
    }
    Write-Host ""
    Write-Host "$changes total changes across $([Math]::Min($origData.Count, $modData.Count)) rows"
}

# Cleanup temp file
if ($ModScript -and (Test-Path $Modified)) {
    Remove-Item $Modified -Force -ErrorAction SilentlyContinue
}
