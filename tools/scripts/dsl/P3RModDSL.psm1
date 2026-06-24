# P3RModDSL.psm1 — Sprint 1.5 T1.5.6
#
# High-level PowerShell DSL that wraps Invoke-ZenPatch.ps1 for common modding
# operations. Each function builds a changes.json descriptor and delegates to
# Invoke-ZenPatch for byte-level patching of Zen .uasset files.
#
# Usage:
#   Import-Module .\tools\scripts\dsl\P3RModDSL.psm1
#   Set-SkillHpn -SkillId 10 -DamageMultiplier 5.0 -OutputDir .\my-mod\
#   Set-EnemySkill -EnemyId 100 -Slot 4 -SkillId 47 -OutputDir .\my-mod\

#Requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Internal state ────────────────────────────────────────────────────────────
$script:ConfigLoaded = $false
$script:ProjectRoot   = $null
$script:SchemasDir    = $null
$script:InvokeZenPatch = $null
$script:JsonOutputDir  = $null

# ── Configuration loader ─────────────────────────────────────────────────────
function _Ensure-Config {
    if ($script:ConfigLoaded) { return }
    $script:ProjectRoot = Resolve-Path "$PSScriptRoot\..\..\.."
    $script:SchemasDir  = "$script:ProjectRoot\tools\templates-010\schemas"
    $script:InvokeZenPatch = "$script:ProjectRoot\tools\scripts\Invoke-ZenPatch.ps1"
    $script:JsonOutputDir  = "$script:ProjectRoot\tools\Output\json"
    # Dot-source Config.ps1 for DataTools path
    $configPath = "$script:ProjectRoot\tools\scripts\Config.ps1"
    if (Test-Path $configPath) { . $configPath | Out-Null }
    $script:ConfigLoaded = $true
}

# ── Schema registry (templateKey -> schemaKey) ────────────────────────────────
$script:TableToSchema = @{
    Skills          = 'p3re_skillNormal'
    SkillMeta       = 'p3re_skill'
    Personas        = 'p3re_persona'
    PersonaGrowth   = 'p3re_personaGrowth'
    PersonaAffinity = 'p3re_personaAffinity'
    Enemies         = 'p3re_enemy'
    EnemyAffinity   = 'p3re_enemyAffinity'
    Encounters      = 'p3re_encountTable'
    PlayerLevelup   = 'p3re_playerLevelup'
    Difficulty      = 'p3re_DT_BtlDIfficultyParam'
    BtlTheurgia     = 'p3re_btlTheurgiaBoost'
    CombineMisc     = 'p3re_combineMisc'
    SupportInfo     = 'p3re_supportInfoCommon'
    SkillLimit      = 'p3re_skillLimit'
    SpecialSpread   = 'p3re_specialSpread'
}

# ── Internal: resolve schema + source from a table key ────────────────────────
function _Resolve-Schema {
    param([string] $SchemaKey)
    $schemaFile = Join-Path $script:SchemasDir "${SchemaKey}_schema.json"
    if (-not (Test-Path $schemaFile)) {
        throw "Schema '$SchemaKey' not found at $schemaFile. Known schemas: $($script:TableToSchema.Values | Sort-Object -Unique)"
    }
    $schema = Get-Content $schemaFile -Raw -Encoding UTF8 | ConvertFrom-Json
    return $schema
}

# ── Internal: build a changes.json temp file and invoke Invoke-ZenPatch ───────
function _Invoke-Patch {
    param(
        [string] $SchemaKey,
        [array]  $Changes,
        [string] $OutputDir
    )
    $tmpFile = [System.IO.Path]::GetTempFileName() + '.json'
    $changesObj = @{ schemaKey = $SchemaKey; changes = $Changes }
    $changesObj | ConvertTo-Json -Depth 6 | Set-Content $tmpFile -Encoding UTF8

    $params = @{
        ChangesJson = $tmpFile
        OutputDir   = $OutputDir
        PassThru    = $true
    }
    $result = & $script:InvokeZenPatch @params 2>&1
    Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue

    # Check success: Invoke-ZenPatch exits with 1 on error
    if ((Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue) -and $global:LASTEXITCODE -ne 0) {
        throw "Invoke-ZenPatch failed with exit code $global:LASTEXITCODE. Output: $result"
    }
    Write-Host $result
}

# ══════════════════════════════════════════════════════════════════════════════
# DSL Functions
# ══════════════════════════════════════════════════════════════════════════════

# ── Set-SkillData ─────────────────────────────────────────────────────────────
# Modify numeric fields on DatSkillNormalDataAsset.
#
# Parameters:
#   -SkillId           : skill ID (= Data[] index, e.g. 10 for Agi)
#   -Hpn               : raw hpn value (displayed-damage squared; see P-009)
#   -DamageMultiplier  : multiply current hpn by N² (e.g. 5.0 → hpn×25)
#                        Mutually exclusive with -Hpn.
#   -Cost              : raw MP/HP cost value
#   -HitRate           : base hit rate (0-100)
#   -CriticalRate      : critical hit rate (0-100)
#   -OutputDir         : where to write the patched .uasset
# ──────────────────────────────────────────────────────────────────────────────
function Set-SkillData {
    [CmdletBinding(DefaultParameterSetName='Direct')]
    param(
        [Parameter(Mandatory=$true)]
        [int] $SkillId,

        [Parameter(ParameterSetName='Direct')]
        [int] $Hpn,

        [Parameter(ParameterSetName='Multiplier')]
        [double] $DamageMultiplier,

        [int] $Cost = -1,
        [int] $HitRate = -1,
        [int] $CriticalRate = -1,

        [Parameter(Mandatory=$true)]
        [string] $OutputDir
    )
    _Ensure-Config

    $schemaKey = 'p3re_skillNormal'
    $changes = New-Object System.Collections.Generic.List[hashtable]

    # --- Hpn (direct or multiplier) ---
    if ($PSCmdlet.ParameterSetName -eq 'Multiplier') {
        # Read current hpn from CUE4Parse JSON cache
        $jsonPath = Join-Path $script:JsonOutputDir 'Battle\datskillnormaldataasset.json'
        if (-not (Test-Path $jsonPath)) {
            throw "JSON cache not found at $jsonPath. Run: P3RDataTools read ... skills.json"
        }
        $json = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $currentHpn = $json.Properties.Data[$SkillId].hpn
        if ($null -eq $currentHpn) {
            throw "Skill ID $SkillId not found in JSON cache (row count: $($json.Properties.Data.Count))"
        }
        $newHpn = [Math]::Round($currentHpn * $DamageMultiplier * $DamageMultiplier)
        Write-Host "  Set-SkillData: SkillId=$SkillId  currentHpn=$currentHpn  multiplier=$DamageMultiplier`×  newHpn=$newHpn" -ForegroundColor Cyan
        $changes.Add(@{ target = "Data[$SkillId].hpn"; value = $newHpn })
    } elseif ($PSBoundParameters.ContainsKey('Hpn')) {
        Write-Host "  Set-SkillData: SkillId=$SkillId  hpn=$Hpn (direct)" -ForegroundColor Cyan
        $changes.Add(@{ target = "Data[$SkillId].hpn"; value = $Hpn })
    }

    if ($Cost -ge 0) {
        Write-Host "  Set-SkillData: SkillId=$SkillId  cost=$Cost" -ForegroundColor Cyan
        $changes.Add(@{ target = "Data[$SkillId].cost"; value = $Cost })
    }
    if ($HitRate -ge 0) {
        Write-Host "  Set-SkillData: SkillId=$SkillId  hitratio=$HitRate" -ForegroundColor Cyan
        $changes.Add(@{ target = "Data[$SkillId].hitratio"; value = $HitRate })
    }
    if ($CriticalRate -ge 0) {
        Write-Host "  Set-SkillData: SkillId=$SkillId  criticalratio=$CriticalRate" -ForegroundColor Cyan
        $changes.Add(@{ target = "Data[$SkillId].criticalratio"; value = $CriticalRate })
    }

    if ($changes.Count -eq 0) {
        Write-Warning "Set-SkillData: no changes specified. Use -Hpn, -DamageMultiplier, -Cost, -HitRate, or -CriticalRate."
        return
    }

    _Invoke-Patch -SchemaKey $schemaKey -Changes $changes.ToArray() -OutputDir $OutputDir
}

<#
.SYNOPSIS
  Alias: Set-SkillHpn — sugar for Set-SkillData -Hpn or -DamageMultiplier
#>
function Set-SkillHpn {
    [CmdletBinding(DefaultParameterSetName='Direct')]
    param(
        [Parameter(Mandatory=$true)] [int] $SkillId,
        [Parameter(ParameterSetName='Direct')] [int] $Hpn,
        [Parameter(ParameterSetName='Multiplier')] [double] $DamageMultiplier,
        [Parameter(Mandatory=$true)] [string] $OutputDir
    )
    $splat = @{ SkillId = $SkillId; OutputDir = $OutputDir }
    if ($PSCmdlet.ParameterSetName -eq 'Multiplier') {
        $splat.DamageMultiplier = $DamageMultiplier
    } elseif ($PSBoundParameters.ContainsKey('Hpn')) {
        $splat.Hpn = $Hpn
    }
    Set-SkillData @splat
}

<#
.SYNOPSIS
  Alias: Set-SkillCost — sugar for Set-SkillData -Cost
#>
function Set-SkillCost {
    param(
        [Parameter(Mandatory=$true)] [int] $SkillId,
        [Parameter(Mandatory=$true)] [int] $Cost,
        [Parameter(Mandatory=$true)] [string] $OutputDir
    )
    Set-SkillData -SkillId $SkillId -Cost $Cost -OutputDir $OutputDir
}

# ── Set-PersonaStat ───────────────────────────────────────────────────────────
# Modify fields on DatPersonaDataAsset.  Fields are set via their 010 template
# names (flag, race, level, params, breakage, succession, conception, message).
#
# Parameters:
#   -PersonaId   : persona ID (= Data[] index)
#   -Level       : persona base level (ubyte, max 99)
#   -Race        : Arcana / RaceID enum value (ubyte)
#   -Params      : base stat tier (ubyte, 1-5)
#   -OutputDir   : where to write the patched .uasset
# ──────────────────────────────────────────────────────────────────────────────
function Set-PersonaStat {
    param(
        [Parameter(Mandatory=$true)] [int] $PersonaId,
        [ValidateRange(1, 99)] [int] $Level = 0,
        [ValidateRange(0, 255)] [int] $Race = -1,
        [ValidateRange(0, 255)] [int] $Params = -1,
        [Parameter(Mandatory=$true)] [string] $OutputDir
    )
    _Ensure-Config

    $schemaKey = 'p3re_persona'
    $changes = New-Object System.Collections.Generic.List[hashtable]

    if ($Level -gt 0) {
        Write-Host "  Set-PersonaStat: PersonaId=$PersonaId  level=$Level" -ForegroundColor Cyan
        $changes.Add(@{ target = "Data[$PersonaId].level"; value = $Level })
    }
    if ($Race -ge 0) {
        Write-Host "  Set-PersonaStat: PersonaId=$PersonaId  race=$Race" -ForegroundColor Cyan
        $changes.Add(@{ target = "Data[$PersonaId].race"; value = $Race })
    }
    if ($Params -ge 0) {
        Write-Host "  Set-PersonaStat: PersonaId=$PersonaId  params=$Params" -ForegroundColor Cyan
        $changes.Add(@{ target = "Data[$PersonaId].params"; value = $Params })
    }

    if ($changes.Count -eq 0) {
        Write-Warning "Set-PersonaStat: no changes specified."
        return
    }
    _Invoke-Patch -SchemaKey $schemaKey -Changes $changes.ToArray() -OutputDir $OutputDir
}

<#
.SYNOPSIS
  Alias: Set-PersonaLevel — sets just the persona level
#>
function Set-PersonaLevel {
    param(
        [Parameter(Mandatory=$true)] [int] $PersonaId,
        [Parameter(Mandatory=$true)] [ValidateRange(1, 99)] [int] $Level,
        [Parameter(Mandatory=$true)] [string] $OutputDir
    )
    Set-PersonaStat -PersonaId $PersonaId -Level $Level -OutputDir $OutputDir
}

# ── Set-EnemyStat ─────────────────────────────────────────────────────────────
# Modify HP/SP/level on DatEnemyDataAsset.
#
# Parameters:
#   -EnemyId   : enemy ID (= Data[] index)
#   -MaxHP     : new max HP (uint32)
#   -MaxSP     : new max SP (uint32)
#   -Level     : enemy level (ushort)
#   -OutputDir : where to write the patched .uasset
# ──────────────────────────────────────────────────────────────────────────────
function Set-EnemyStat {
    param(
        [Parameter(Mandatory=$true)] [int] $EnemyId,
        [uint32] $MaxHP = 0,
        [uint32] $MaxSP = 0,
        [uint16] $Level = 0,
        [Parameter(Mandatory=$true)] [string] $OutputDir
    )
    _Ensure-Config

    $schemaKey = 'p3re_enemy'
    $changes = New-Object System.Collections.Generic.List[hashtable]

    if ($MaxHP -gt 0) {
        Write-Host "  Set-EnemyStat: EnemyId=$EnemyId  maxhp=$MaxHP" -ForegroundColor Cyan
        $changes.Add(@{ target = "Data[$EnemyId].maxhp"; value = $MaxHP })
    }
    if ($MaxSP -gt 0) {
        Write-Host "  Set-EnemyStat: EnemyId=$EnemyId  maxsp=$MaxSP" -ForegroundColor Cyan
        $changes.Add(@{ target = "Data[$EnemyId].maxsp"; value = $MaxSP })
    }
    if ($Level -gt 0) {
        Write-Host "  Set-EnemyStat: EnemyId=$EnemyId  level=$Level" -ForegroundColor Cyan
        $changes.Add(@{ target = "Data[$EnemyId].level"; value = $Level })
    }

    if ($changes.Count -eq 0) {
        Write-Warning "Set-EnemyStat: no changes specified."
        return
    }
    _Invoke-Patch -SchemaKey $schemaKey -Changes $changes.ToArray() -OutputDir $OutputDir
}

<#
.SYNOPSIS
  Alias: Set-EnemyHP — sets just enemy max HP
#>
function Set-EnemyHP {
    param(
        [Parameter(Mandatory=$true)] [int] $EnemyId,
        [Parameter(Mandatory=$true)] [uint32] $MaxHP,
        [Parameter(Mandatory=$true)] [string] $OutputDir
    )
    Set-EnemyStat -EnemyId $EnemyId -MaxHP $MaxHP -OutputDir $OutputDir
}

<#
.SYNOPSIS
  Alias: Set-EnemySP — sets just enemy max SP
#>
function Set-EnemySP {
    param(
        [Parameter(Mandatory=$true)] [int] $EnemyId,
        [Parameter(Mandatory=$true)] [uint32] $MaxSP,
        [Parameter(Mandatory=$true)] [string] $OutputDir
    )
    Set-EnemyStat -EnemyId $EnemyId -MaxSP $MaxSP -OutputDir $OutputDir
}

# ── Set-EnemySkill ────────────────────────────────────────────────────────────
# Set a skill in an enemy's skill slot (DatEnemyDataAsset).
# Slots 1-8 map to fields skill, skill2, ..., skill8 (SkillList enum, ushort).
#
# Parameters:
#   -EnemyId   : enemy ID (= Data[] index)
#   -Slot      : skill slot (1-8)
#   -SkillId   : new skill ID to assign
#   -OutputDir : where to write the patched .uasset
# ──────────────────────────────────────────────────────────────────────────────
function Set-EnemySkill {
    param(
        [Parameter(Mandatory=$true)] [int] $EnemyId,
        [Parameter(Mandatory=$true)] [ValidateRange(1, 8)] [int] $Slot,
        [Parameter(Mandatory=$true)] [int] $SkillId,
        [Parameter(Mandatory=$true)] [string] $OutputDir
    )
    _Ensure-Config

    $fieldMap = @{ 1 = 'skill'; 2 = 'skill2'; 3 = 'skill3'; 4 = 'skill4'
                   5 = 'skill5'; 6 = 'skill6'; 7 = 'skill7'; 8 = 'skill8' }
    $fieldName = $fieldMap[$Slot]

    $schemaKey = 'p3re_enemy'
    Write-Host "  Set-EnemySkill: EnemyId=$EnemyId  Slot=$Slot ($fieldName)  SkillId=$SkillId" -ForegroundColor Cyan

    $changes = @(@{ target = "Data[$EnemyId].$fieldName"; value = $SkillId })
    _Invoke-Patch -SchemaKey $schemaKey -Changes $changes -OutputDir $OutputDir
}

# ── Set-DifficultyParam ───────────────────────────────────────────────────────
# Set difficulty-scaled parameters (named_rows table: DT_BtlDIfficultyParam).
#
# Row keys: safety, easy, normal, hard, risky
# Known float fields: DamageRateToEnemy, DamageRateToPlayer, ExpRate,
#   DamageRateToEnemyWeak, DamageRateToPlayerWeak, etc.
# Also supports "all" as a row key to apply the same value to all 5 rows.
#
# Parameters:
#   -Field      : field name (e.g. 'ExpRate', 'DamageRateToPlayer')
#   -Value      : new value (float)
#   -Difficulty : row key: 'safety', 'easy', 'normal', 'hard', 'risky', or 'all'
#   -OutputDir  : where to write the patched .uasset
# ──────────────────────────────────────────────────────────────────────────────
function Set-DifficultyParam {
    param(
        [Parameter(Mandatory=$true)] [string] $Field,
        [Parameter(Mandatory=$true)] [double] $Value,
        [ValidateSet('safety','easy','normal','hard','risky','all')]
        [string] $Difficulty = 'all',
        [Parameter(Mandatory=$true)] [string] $OutputDir
    )
    _Ensure-Config

    $schemaKey = 'p3re_DT_BtlDIfficultyParam'
    $allRows = @('safety', 'easy', 'normal', 'hard', 'risky')

    $targets = if ($Difficulty -eq 'all') { $allRows }
               else { @($Difficulty) }

    $changes = New-Object System.Collections.Generic.List[hashtable]
    foreach ($row in $targets) {
        Write-Host "  Set-DifficultyParam: $row.$Field = $Value" -ForegroundColor Cyan
        $changes.Add(@{ target = "Rows[""$row""].$Field"; value = $Value })
    }

    _Invoke-Patch -SchemaKey $schemaKey -Changes $changes.ToArray() -OutputDir $OutputDir
}

# ── Set-PlayerLevelup ─────────────────────────────────────────────────────────
# Modify player level-up data (DatPlayerLevelupDataAsset).
# Schema has one field: exp (uint). Level N corresponds to Data[N].
#
# Parameters:
#   -Level      : level to modify (1-99)
#   -Exp        : new experience required to reach this level from previous
#   -OutputDir  : where to write the patched .uasset
# ──────────────────────────────────────────────────────────────────────────────
function Set-PlayerLevelup {
    param(
        [Parameter(Mandatory=$true)] [ValidateRange(1, 99)] [int] $Level,
        [Parameter(Mandatory=$true)] [uint32] $Exp,
        [Parameter(Mandatory=$true)] [string] $OutputDir
    )
    _Ensure-Config

    $schemaKey = 'p3re_playerLevelup'
    Write-Host "  Set-PlayerLevelup: Level=$Level  exp=$Exp" -ForegroundColor Cyan

    $changes = @(@{ target = "Data[$Level].exp"; value = $Exp })
    _Invoke-Patch -SchemaKey $schemaKey -Changes $changes -OutputDir $OutputDir
}

# ── Set-PersonaGrowthSkill ─────────────────────────────────────────────────────
# Modify a learned-skill slot in DatPersonaGrowthDataAsset.
#
# ⚠️  WARNING: This function does DIRECT BYTE WRITE into a struct containing a
# union ({SkillList|ItemList}). Crashed game with "Bad name index 25353/21"
# on first end-to-end test (2026-06-24). The union likely references FNames
# that must be patched identically or the deserializer breaks.
#
# DO NOT USE until the union semantics are fully understood.
# This helper is kept in the codebase as a DEV-ONLY skeleton for future work.
#
# SkillEventStruct layout (from p3re_structs.bt, 145 bytes each):
#   [5]   ubyte level           ← level at which skill is learned
#   [31]  EventIDList eventId   ← 2 bytes
#   [58]  union { SkillList; ItemList; } data  ← 2 bytes (PATTERNING BREAKS HERE)
#   [60+] byte FProperty12[28] (padding to 88, + 57 inter-struct padding = 145)
#
# Parameters:
#   -PersonaId   : persona ID (= Data[] index, e.g. 1 for Orpheus)
#   -Slot        : skill slot index (0-15, 0 = first learned skill)
#   -SkillId     : new skill ID to learn at this slot
#   -Level       : optional level to learn at (default: keep existing)
#   -OutputDir   : where to write the patched .uasset
# ──────────────────────────────────────────────────────────────────────────────
function Set-PersonaGrowthSkill_DEVONLY_DONOTUSE {
    param(
        [Parameter(Mandatory=$true)] [int] $PersonaId,
        [Parameter(Mandatory=$true)] [ValidateRange(0, 15)] [int] $Slot,
        [Parameter(Mandatory=$true)] [int] $SkillId,
        [ValidateRange(1, 99)] [int] $Level = 0,
        [Parameter(Mandatory=$true)] [string] $OutputDir
    )

    _Ensure-Config

    $schemaKey = 'p3re_personaGrowth'
    $headerSize = 830
    $rowSize = 2498
    $skilleventRowOffset = 178
    $structStride = 145   # 2320 bytes / 16 slots
    $skillIdLocalOffset = 58
    $levelLocalOffset = 5

    $skillIdFileOffset = $headerSize + $PersonaId * $rowSize + $skilleventRowOffset + $Slot * $structStride + $skillIdLocalOffset
    $levelFileOffset   = $headerSize + $PersonaId * $rowSize + $skilleventRowOffset + $Slot * $structStride + $levelLocalOffset

    Write-Host "  Set-PersonaGrowthSkill: PersonaId=$PersonaId Slot=$Slot SkillId=$SkillId Level=$Level" -ForegroundColor Cyan

    $schema = _Resolve-Schema -SchemaKey $schemaKey
    $sourcePath = $schema.sourceAssetPath
    if (-not (Test-Path $sourcePath)) { throw "Source Zen file not found: $sourcePath" }

    $origBytes = [System.IO.File]::ReadAllBytes($sourcePath)
    $currentSkillId = [BitConverter]::ToUInt16($origBytes, $skillIdFileOffset)
    $currentLevel   = $origBytes[$levelFileOffset]

    $patchBytes = [byte[]]::new($origBytes.Length)
    [Array]::Copy($origBytes, $patchBytes, $origBytes.Length)

    [BitConverter]::GetBytes([uint16]$SkillId).CopyTo($patchBytes, $skillIdFileOffset)
    if ($Level -gt 0) { $patchBytes[$levelFileOffset] = [byte]$Level }

    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    $assetName = [System.IO.Path]::GetFileName($sourcePath)
    $outPath = Join-Path $OutputDir $assetName
    [System.IO.File]::WriteAllBytes($outPath, $patchBytes)

    Write-Host "    PATCHED skillId @ 0x$($skillIdFileOffset.ToString('X')): $currentSkillId -> $SkillId" -ForegroundColor Green
    if ($Level -gt 0) {
        Write-Host "    PATCHED level @ 0x$($levelFileOffset.ToString('X')): $currentLevel -> $Level" -ForegroundColor Green
    }
    Write-Host "    Output: $outPath ($($origBytes.Length) bytes, size unchanged)" -ForegroundColor Green
}

# ── New-ModChanges ────────────────────────────────────────────────────────────
# Generic helper: produce changes.json for any schema key + raw target syntax.
# Use this when the DSL functions above don't cover your use case.
#
# Parameters:
#   -SchemaKey  : schema key (e.g. 'p3re_skillNormal')
#   -Changes    : array of @{target='Data[10].hpn'; value=999} hashtables
#   -OutputDir  : where to write the patched .uasset
# ──────────────────────────────────────────────────────────────────────────────
function New-ModChanges {
    param(
        [Parameter(Mandatory=$true)] [string] $SchemaKey,
        [Parameter(Mandatory=$true)] [array] $Changes,
        [Parameter(Mandatory=$true)] [string] $OutputDir
    )
    _Ensure-Config

    Write-Host "  New-ModChanges: schemaKey=$SchemaKey  changes=$($Changes.Count)" -ForegroundColor Cyan
    foreach ($c in $Changes) {
        Write-Host "    $($c.target) = $($c.value)" -ForegroundColor DarkGray
    }

    _Invoke-Patch -SchemaKey $SchemaKey -Changes $Changes -OutputDir $OutputDir
}

# ── Module exports ────────────────────────────────────────────────────────────
Export-ModuleMember -Function @(
    'Set-SkillData', 'Set-SkillHpn', 'Set-SkillCost',
    'Set-PersonaStat', 'Set-PersonaLevel',
    'Set-EnemyStat', 'Set-EnemyHP', 'Set-EnemySP',
    'Set-EnemySkill',
    'Set-DifficultyParam',
    'Set-PlayerLevelup',
    'New-ModChanges'
)
