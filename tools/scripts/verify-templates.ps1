# P3R Template Verification Script - Sprint 0 T0.2
# Usage:
#   .\verify-templates.ps1              Full verification
#   .\verify-templates.ps1 -Quick       Basic checks only (exists+size+magic)
#   .\verify-templates.ps1 -Name "skills" Verify single template
#   .\verify-templates.ps1 -ReportOnly  Read last report
param(
    [switch]$Quick,
    [string]$Name,
    [switch]$ReportOnly
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$ScriptDir\..\.."
$TemplatesDir = "$ProjectRoot\tools\templates"
$IndexFile = "$TemplatesDir\template_index.json"
$ReportFile = "$TemplatesDir\verification_report.json"
$DataTools = "$ProjectRoot\tools\P3RDataTools\publish\P3RDataTools.exe"

if (-not (Test-Path $IndexFile)) {
    Write-Error "template_index.json not found: $IndexFile"
    Write-Host "Please complete T0.1 first: export templates via FModel GUI"
    exit 1
}

$index = Get-Content $IndexFile -Raw -Encoding UTF8 | ConvertFrom-Json

# Select verification scope
$targets = if ($Name) {
    @($index.templates | Where-Object { $_.id -eq $Name })
} else {
    @($index.templates)
}

if (-not $targets) {
    Write-Error "Template not found: $Name"
    Write-Host "Available: $($index.templates.id -join ', ')"
    exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  P3R Template Verification" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Templates: $TemplatesDir"
Write-Host "Index:     $IndexFile"
Write-Host "Count:     $($targets.Count)"
Write-Host ""

$results = @()
$totalOk = 0
$totalWarn = 0
$totalFail = 0

foreach ($tpl in $targets) {
    Write-Host "--- [$($tpl.id)] $($tpl.assetName)" -ForegroundColor White

    $result = @{
        id = $tpl.id
        assetName = $tpl.assetName
        category = $tpl.category
        checks = @{}
        overall = "PASS"
    }

    $uassetFile = Join-Path $TemplatesDir "$($tpl.assetName).uasset"
    $uexpFile = Join-Path $TemplatesDir "$($tpl.assetName).uexp"

    # Check 1: File existence
    $hasUasset = Test-Path $uassetFile
    $hasUexp = Test-Path $uexpFile

    $result.checks["fileExists"] = @{
        uasset = $hasUasset
        uexp = $hasUexp
        pass = $hasUasset -and $hasUexp
    }

    if (-not $hasUasset) {
        Write-Host "    FAIL: .uasset missing" -ForegroundColor Red
        $result.overall = "FAIL"
        $totalFail++
        $results += $result
        continue
    }
    if (-not $hasUexp) {
        Write-Host "    WARN: .uexp missing (some tables may only need .uasset)" -ForegroundColor Yellow
    }

    # Check 2: File size
    $uassetSize = (Get-Item $uassetFile).Length
    $uexpSize = if ($hasUexp) { (Get-Item $uexpFile).Length } else { 0 }
    $minSize = [int]($index.validation.expectedMinSizeBytes)
    $sizeOk = $uassetSize -ge $minSize

    $result.checks["fileSize"] = @{
        uassetBytes = $uassetSize
        uexpBytes = $uexpSize
        minExpected = $minSize
        pass = $sizeOk
    }

    if ($sizeOk) {
        Write-Host "    Size: uasset=$([math]::Round($uassetSize/1KB,1))KB uexp=$([math]::Round($uexpSize/1KB,1))KB" -ForegroundColor Green
    } else {
        Write-Host "    WARN: File too small: $uassetSize bytes (min $minSize)" -ForegroundColor Yellow
    }

    # Check 3: .uasset magic bytes (C1 83 2A 9E = UE4 Package)
    $bytes = [System.IO.File]::ReadAllBytes($uassetFile)
    if ($bytes.Length -ge 4) {
        $magic = ($bytes[0..3] | ForEach-Object { $_.ToString("X2") }) -join ""
        $expectedMagic = $index.validation.uassetMagicBytes
        $magicOk = $magic -eq $expectedMagic

        $result.checks["magicBytes"] = @{
            actual = $magic
            expected = $expectedMagic
            pass = $magicOk
        }

        if ($magicOk) {
            Write-Host "    Magic: $magic [OK]" -ForegroundColor Green
        } else {
            if ($magic -eq "00000000") {
                Write-Host "    FAIL: Magic=$magic - This is IoStore format, not traditional!" -ForegroundColor Red
                Write-Host "      Fix: FModel -> Export Folder's Packages Raw (NOT Export Data)" -ForegroundColor DarkYellow
            } else {
                Write-Host "    WARN: Magic mismatch: $magic (expected $expectedMagic)" -ForegroundColor Yellow
            }
        }
    } else {
        $result.checks["magicBytes"] = @{ pass = $false; actual = "File too small" }
        Write-Host "    FAIL: File too small to read magic bytes" -ForegroundColor Red
    }

    # Check 4: JSON cache comparison (if DataTools available)
    if (-not $Quick -and (Test-Path $DataTools)) {
        $jsonCacheFile = "$ProjectRoot\tools\Output\json\$($tpl.category)\$($tpl.assetName.ToLower()).json"

        if (Test-Path $jsonCacheFile) {
            $cacheSize = (Get-Item $jsonCacheFile).Length
            $result.checks["jsonCache"] = @{
                path = $jsonCacheFile
                sizeBytes = $cacheSize
                pass = $cacheSize -gt 0
            }
            Write-Host "    JSON cache: $([math]::Round($cacheSize/1KB,1))KB [OK]" -ForegroundColor Green
        } else {
            $result.checks["jsonCache"] = @{ pass = $false; note = "Run P3RDataTools batch to export" }
            Write-Host "    WARN: JSON cache missing" -ForegroundColor Yellow
        }
    }

    # Overall verdict for this template
    $allPass = ($result.checks.Values | Where-Object { -not $_.pass }).Count -eq 0

    if ($allPass) {
        Write-Host "    [PASS]" -ForegroundColor Green
        $totalOk++
    } elseif ($result.overall -eq "FAIL") {
        $totalFail++
    } else {
        Write-Host "    [WARN]" -ForegroundColor Yellow
        $totalWarn++
        $result.overall = "WARN"
    }

    $results += $result
    Write-Host ""
}

# Summary report
$report = @{
    generatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    projectRoot = "$ProjectRoot"
    templateIndex = $IndexFile
    summary = @{
        total = $results.Count
        pass = $totalOk
        warn = $totalWarn
        fail = $totalFail
    }
    results = $results
}

$reportJson = $report | ConvertTo-Json -Depth 5
$reportJson | Out-File $ReportFile -Encoding utf8

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Verification Complete" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Total: $($results.Count) | Pass: $totalOk | Warn: $totalWarn | Fail: $totalFail"
Write-Host ""
Write-Host "Report saved: $ReportFile"
Write-Host ""

# Guidance on failure
if ($totalFail -gt 0) {
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host "  Action Required" -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "1. Launch FModel (tools/FModel.exe)"
    Write-Host "2. Open IoStore containers: Directory -> Select Paks/"
    Write-Host "3. For each failed template:"
    Write-Host "   - Navigate to the path in FModel tree"
    Write-Host "   - Right-click .uasset -> Export Folder's Packages Raw"
    Write-Host "   - Save to tools/templates/<AssetName>.uasset"
    Write-Host "   - IMPORTANT: Use 'Packages Raw', NOT 'Data'"
    Write-Host "4. Re-run verification:"
    Write-Host "   .\tools\scripts\verify-templates.ps1"
    Write-Host ""
}

if ($totalFail -gt 0) {
    exit 1
} elseif ($totalWarn -gt 0) {
    exit 0
} else {
    Write-Host "All templates verified! Ready for Sprint 1." -ForegroundColor Green
    exit 0
}
