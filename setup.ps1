# ============================================================
# P3R Modding AI Agent — 项目初始化脚本
# ============================================================
# 用法:
#   .\setup.ps1                  ← 完整初始化
#   .\setup.ps1 -SkipBuild       ← 跳过编译 (已有发布版本)
#   .\setup.ps1 -SkipVerify      ← 跳过 Paks 验证
#   .\setup.ps1 -WhatIf          ← 仅检查, 不执行
# ============================================================
param(
    [switch]$SkipBuild,
    [switch]$SkipVerify,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path "$PSScriptRoot"
$StartTime = Get-Date

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  P3R Modding AI Agent — 项目初始化" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ── 0. 加载环境变量 ────────────────────────────────────────
function Load-Env {
    Write-Host "[0/5] 加载配置..." -ForegroundColor Yellow

    $envFile = Join-Path $ProjectRoot ".env"
    if (-not (Test-Path $envFile)) {
        $exampleFile = Join-Path $ProjectRoot ".env.example"
        if (Test-Path $exampleFile) {
            Write-Host "  .env 不存在, 从 .env.example 创建默认配置" -ForegroundColor DarkYellow
            Copy-Item $exampleFile $envFile
            Write-Host "  请编辑 .env 填入你的游戏路径后重新运行 setup.ps1" -ForegroundColor DarkYellow
            Write-Host "  或通过环境变量 P3R_PAKS_DIR 指定 Paks 目录" -ForegroundColor DarkYellow
        }
    }

    if (Test-Path $envFile) {
        Get-Content $envFile | ForEach-Object {
            if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
                $key = $matches[1].Trim()
                $val = $matches[2].Trim()
                if ($key -eq "ANTHROPIC_MODEL") { return }
                if (-not (Test-Path "env:$key")) {
                    [Environment]::SetEnvironmentVariable($key, $val, "Process")
                }
            }
        }
    }

    # 默认值
    if (-not $env:P3R_PAKS_DIR) { $env:P3R_PAKS_DIR = (Join-Path $ProjectRoot "Paks") }
    if (-not $env:P3R_MOD_OUTPUT_DIR) { $env:P3R_MOD_OUTPUT_DIR = (Join-Path $ProjectRoot "tools\Output\mod") }
    if (-not $env:P3R_JSON_CACHE_DIR) { $env:P3R_JSON_CACHE_DIR = (Join-Path $ProjectRoot "tools\Output\json") }
    if (-not $env:P3R_BACKUP_DIR) { $env:P3R_BACKUP_DIR = (Join-Path $ProjectRoot "tools\Output\.backup") }

    Write-Host "  Paks 目录:       $env:P3R_PAKS_DIR"
    Write-Host "  Mod 输出:        $env:P3R_MOD_OUTPUT_DIR"
    Write-Host "  JSON 缓存:       $env:P3R_JSON_CACHE_DIR"
    Write-Host "  备份目录:        $env:P3R_BACKUP_DIR"
    Write-Host ""
}

# ── 1. 检查运行时 ────────────────────────────────────────
function Check-Runtime {
    Write-Host "[1/5] 检查运行时..." -ForegroundColor Yellow

    # 检查 .NET 8
    $dotnetVersion = $null
    try { $dotnetVersion = & dotnet --version 2>$null } catch {}

    if ($dotnetVersion -and $dotnetVersion.StartsWith("8.")) {
        Write-Host "  .NET $dotnetVersion" -ForegroundColor Green
    } elseif ($dotnetVersion) {
        Write-Host "  .NET $dotnetVersion  (需要 8.x, 但自包含发布可跳过)" -ForegroundColor DarkYellow
    } else {
        Write-Host "  .NET 未安装 (自包含发布不需要)" -ForegroundColor DarkYellow
    }

    # 检查 PowerShell 版本
    $psVersion = $PSVersionTable.PSVersion
    Write-Host "  PowerShell $psVersion" -ForegroundColor $(if ($psVersion.Major -ge 5) { "Green" } else { "Red" })

    # 检查操作系统
    $os = (Get-CimInstance Win32_OperatingSystem).Caption
    Write-Host "  操作系统: $os" -ForegroundColor Green

    Write-Host ""
}

# ── 2. 创建必要目录 ──────────────────────────────────────
function Create-Directories {
    Write-Host "[2/5] 创建项目目录..." -ForegroundColor Yellow

    $dirs = @(
        "tools\Output\mod",
        "tools\Output\.backup",
        "tools\Output\.data",
        "tools\Output\json\Battle",
        "tools\Output\json\UI_Tables",
        "tools\Output\json\Community",
        "tools\Output\json\Kernel",
        "tools\Output\json\Dictionary",
        "tools\Output\json\Tutorial",
        "tools\templates",
        "tools\scripts\tools"
    )

    foreach ($d in $dirs) {
        $p = Join-Path $ProjectRoot $d
        if ($WhatIf) {
            Write-Host "  [WhatIf] 创建: $d"
        } else {
            if (-not (Test-Path $p)) {
                New-Item -ItemType Directory -Force -Path $p | Out-Null
                Write-Host "  + $d" -ForegroundColor Green
            } else {
                Write-Host "  = $d (已存在)" -ForegroundColor DarkGray
            }
        }
    }
    Write-Host ""
}

# ── 3. 编译 P3RDataTools ──────────────────────────────────
function Build-DataTools {
    if ($SkipBuild) {
        Write-Host "[3/5] 编译工具... 跳过 (--SkipBuild)" -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    Write-Host "[3/5] 编译 P3RDataTools..." -ForegroundColor Yellow

    $srcDir = Join-Path $ProjectRoot "tools\P3RDataTools"
    if (-not (Test-Path (Join-Path $srcDir "P3RDataTools.csproj"))) {
        Write-Host "  源码目录不可用: $srcDir" -ForegroundColor Red
        Write-Host "  跳过编译 (检查 tools/P3RDataTools/publish/ 是否有已发布版本)" -ForegroundColor DarkYellow
        Write-Host ""
        return
    }

    $publishDir = Join-Path $srcDir "publish"
    $existingExe = Join-Path $publishDir "P3RDataTools.exe"

    if ($WhatIf) {
        Write-Host "  [WhatIf] dotnet publish $srcDir -c Release --self-contained -r win-x64 -o $publishDir"
    } else {
        Write-Host "  编译中... (首次需下载依赖，约 1-2 分钟)"

        # 清理旧构建产物以释放空间
        $objDir = Join-Path $srcDir "obj"
        $binDir = Join-Path $srcDir "bin"
        if (Test-Path $objDir) { Remove-Item -Recurse -Force $objDir -ErrorAction SilentlyContinue }
        if (Test-Path $binDir) { Remove-Item -Recurse -Force $binDir -ErrorAction SilentlyContinue }

        $result = & dotnet publish $srcDir -c Release --self-contained -r win-x64 -o $publishDir 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  编译成功" -ForegroundColor Green
            if (Test-Path $existingExe) {
                $size = [math]::Round((Get-Item $existingExe).Length / 1MB, 1)
                Write-Host "  P3RDataTools.exe ($size MB)" -ForegroundColor Green
            }
        } else {
            Write-Host "  编译失败!" -ForegroundColor Red
            Write-Host $result
            Write-Host ""
            Write-Host "  常见问题:" -ForegroundColor DarkYellow
            Write-Host "    1. .NET 8 SDK 未安装: https://dotnet.microsoft.com/download/dotnet/8.0"
            Write-Host "    2. 网络问题导致 NuGet 还原失败"
            Write-Host "    3. CUE4Parse 1.1.1 兼容性问题 (不可升级到 1.2.2)"
        }
    }
    Write-Host ""
}

# ── 4. 验证游戏资产 ──────────────────────────────────────
function Verify-Paks {
    if ($SkipVerify) {
        Write-Host "[4/5] 验证资产... 跳过 (--SkipVerify)" -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    Write-Host "[4/5] 验证游戏资产..." -ForegroundColor Yellow

    $paksDir = $env:P3R_PAKS_DIR
    if (-not (Test-Path $paksDir)) {
        Write-Host "  Paks 目录不存在: $paksDir" -ForegroundColor Red
        Write-Host "  请确认:" -ForegroundColor DarkYellow
        Write-Host "    - 游戏已安装 (Steam / Game Pass)"
        Write-Host "    - .env 中 P3R_PAKS_DIR 路径正确"
        Write-Host "    - 或将 Paks/ 目录复制到项目根目录"
        Write-Host ""
        return
    }

    # 检查关键 IoStore 容器
    $utocFiles = Get-ChildItem $paksDir -Filter "*.utoc" -ErrorAction SilentlyContinue
    $ucasFiles = Get-ChildItem $paksDir -Filter "*.ucas" -ErrorAction SilentlyContinue
    $pakFiles = Get-ChildItem $paksDir -Filter "*.pak" -ErrorAction SilentlyContinue

    Write-Host "  .utoc 容器:   $($utocFiles.Count) 个" -ForegroundColor $(if ($utocFiles.Count -gt 0) { "Green" } else { "Red" })
    Write-Host "  .ucas 容器:   $($ucasFiles.Count) 个" -ForegroundColor $(if ($ucasFiles.Count -gt 0) { "Green" } else { "Red" })
    Write-Host "  .pak 文件:    $($pakFiles.Count) 个" -ForegroundColor $(if ($pakFiles.Count -gt 0) { "Green" } else { "DarkGray" })

    if ($utocFiles.Count -gt 0) {
        $totalSize = ($utocFiles | Measure-Object -Property Length -Sum).Sum +
                     ($ucasFiles | Measure-Object -Property Length -Sum).Sum
        Write-Host "  总大小:       $([math]::Round($totalSize / 1GB, 1)) GB" -ForegroundColor Green
    }

    # 验证 AES 密钥可用性
    Write-Host "  AES 密钥:     内置 (0x92BADFE2...)"
    Write-Host ""
}

# ── 5. 最终检查 ──────────────────────────────────────────
function Final-Check {
    Write-Host "[5/5] 最终检查..." -ForegroundColor Yellow

    $warnings = @()
    $errors = @()

    # 检查 P3RDataTools 可用性
    $dtExe = Join-Path $ProjectRoot "tools\P3RDataTools\publish\P3RDataTools.exe"
    if (-not (Test-Path $dtExe)) {
        $errors += "P3RDataTools.exe 不存在。运行 'dotnet publish tools/P3RDataTools' 编译"
    }

    # 检查 UnrealPak 可用性
    $upExe = Join-Path $ProjectRoot "tools\UnrealPakTool\UnrealPak.exe"
    if (-not (Test-Path $upExe)) {
        $errors += "UnrealPak.exe 不存在。请将 UnrealPak 放入 tools/UnrealPakTool/"
    }

    # 检查 JSON 缓存
    $jsonDir = Join-Path $ProjectRoot "tools\Output\json\Battle"
    if (-not (Test-Path $jsonDir) -or (Get-ChildItem $jsonDir -Filter "*.json" | Measure-Object).Count -eq 0) {
        $warnings += "JSON 缓存为空。首次使用时 Agent 会自动从 IoStore 读取"
    } else {
        $jsonCount = (Get-ChildItem (Join-Path $ProjectRoot "tools\Output\json") -Recurse -Filter "*.json" | Measure-Object).Count
        Write-Host "  JSON 缓存: $jsonCount 个文件" -ForegroundColor Green
    }

    # 检查模板库
    $tplDir = Join-Path $ProjectRoot "tools\templates"
    $tplCount = (Get-ChildItem $tplDir -Filter "*.uasset" -ErrorAction SilentlyContinue | Measure-Object).Count
    if ($tplCount -eq 0) {
        $warnings += "模板库为空。需要从 FModel GUI 导出传统格式模板 (见 docs/DEVELOPER_GUIDE.md §六)"
    } else {
        Write-Host "  模板库:   $tplCount 个 .uasset (需要 $($tplCount/2) 对 .uasset+.uexp)" -ForegroundColor Green
        # 检查是否运行了验证
        $verifyScript = Join-Path $ProjectRoot "tools\scripts\verify-templates.ps1"
        if (Test-Path $verifyScript) {
            Write-Host "  验证脚本: tools\scripts\verify-templates.ps1 (运行以验证模板完整性)" -ForegroundColor Green
        }
    }

    # 检查 UnrealPak Crypto.json
    $cryptoJson = Join-Path $ProjectRoot "tools\UnrealPakTool\Crypto.json"
    if (-not (Test-Path $cryptoJson)) {
        $warnings += "Crypto.json 不存在。PAK 打包时需要 (见 CLAUDE.md)"
    }

    # 输出警告
    if ($warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "  ⚠ 警告 ($($warnings.Count)):" -ForegroundColor Yellow
        foreach ($w in $warnings) {
            Write-Host "    - $w" -ForegroundColor Yellow
        }
    }

    # 输出错误
    if ($errors.Count -gt 0) {
        Write-Host ""
        Write-Host "  ❌ 错误 ($($errors.Count)):" -ForegroundColor Red
        foreach ($e in $errors) {
            Write-Host "    - $e" -ForegroundColor Red
        }
    }

    Write-Host ""

    # 总结
    $elapsed = [math]::Round(((Get-Date) - $StartTime).TotalSeconds, 1)
    Write-Host "============================================================" -ForegroundColor Cyan

    if ($errors.Count -gt 0) {
        Write-Host "  初始化完成 (有 $($errors.Count) 个错误需要解决)" -ForegroundColor Red
    } elseif ($warnings.Count -gt 0) {
        Write-Host "  初始化完成 (有 $($warnings.Count) 个警告)" -ForegroundColor Yellow
    } else {
        Write-Host "  初始化成功!" -ForegroundColor Green
    }

    Write-Host "  耗时: ${elapsed}s" -ForegroundColor DarkGray
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    # 下一步提示
    Write-Host "下一步:" -ForegroundColor White
    Write-Host ""

    if ($tplCount -eq 0) {
        Write-Host "  1. 📋 导出模板: 用 FModel GUI 导出传统格式 .uasset+.uexp" -ForegroundColor White
        Write-Host "     详见 docs/DEVELOPER_GUIDE.md → 模板导出指南 (第六节)" -ForegroundColor DarkGray
        Write-Host "     完成后运行: .\tools\scripts\verify-templates.ps1" -ForegroundColor DarkGray
    }

    if ($jsonCount -gt 0 -and $tplCount -gt 0) {
        Write-Host "  2. 🚀 启动 Agent: 在终端输入 claude" -ForegroundColor White
        Write-Host "  3. 💬 试试: '伊邪那岐的初始技能有哪些？'" -ForegroundColor White
    } else {
        Write-Host "  2. 📊 导出 DataTable: P3RDataTools.exe batch 'Xrd777' tools\Output\json\" -ForegroundColor White
        Write-Host "  3. 🚀 启动 Agent: 在终端输入 claude" -ForegroundColor White
    }
    Write-Host ""
}

# ── 主流程 ────────────────────────────────────────────────
try {
    Load-Env
    Check-Runtime
    Create-Directories
    Build-DataTools
    Verify-Paks
    Final-Check
} catch {
    Write-Host ""
    Write-Host "❌ 初始化失败: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
    exit 1
}
