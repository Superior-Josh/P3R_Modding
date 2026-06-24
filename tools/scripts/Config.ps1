# P3R Modding Configuration
# 共享路径、TableKey/SchemaKey 解析与 Sprint 2 工具 helper。

$Script:ProjectRoot = Resolve-Path "$PSScriptRoot\..\.."

# ── 核心工具路径 ──────────────────────────────────────────
$Script:DataTools = "$ProjectRoot\tools\P3RDataTools\publish\P3RDataTools.exe"
$Script:UnrealPak = "$ProjectRoot\tools\UnrealPakTool\UnrealPak.exe"
$Script:CryptoJson = "$ProjectRoot\tools\UnrealPakTool\Crypto.json"

# ── 数据目录 ──────────────────────────────────────────────
$Script:JsonOutput = "$ProjectRoot\tools\Output\json"
$Script:ModOutput = "$ProjectRoot\tools\Output\mod"
$Script:BackupDir = "$ProjectRoot\tools\Output\.backup"
$Script:DataDir    = "$ProjectRoot\tools\Output\.data"
$Script:ZenSourceRoot = "$ProjectRoot\Extracted\IoStore"

# ── 010 schema / 模板库 ───────────────────────────────────
$Script:TemplatesDir = "$ProjectRoot\tools\templates"
$Script:TemplateIndex = "$ProjectRoot\tools\templates\template_index.json"
$Script:SchemaDir = "$ProjectRoot\tools\templates-010\schemas"
$Script:SchemasDir = $Script:SchemaDir

# ── 工具脚本目录 ──────────────────────────────────────────
$Script:ToolsDir = "$ProjectRoot\tools\scripts\tools"

# ── Mod 注册表 / Reloaded II ──────────────────────────────
$Script:ModRegistry = "$ProjectRoot\tools\Output\.data\mod_registry.json"
$Script:ReloadedModsDir = "$ProjectRoot\tools\Reloaded II\Mods"

# ── Wiki 参考数据 ─────────────────────────────────────────
$Script:WikiDir = "$ProjectRoot\docs\amicitia\md"
$Script:DataMappingFile = "$ProjectRoot\docs\amicitia\DATA_MAPPING.md"
$Script:ZhCnDir = "$ProjectRoot\docs\zh-cn"

# ── AES 密钥 (UE 4.27 IoStore) ────────────────────────────
$Script:AesKey = "0x92BADFE2921B376069D3DE8541696D230BA06B5E4320084DD34A26D117D2FFEE"

# ── DataTable 虚拟路径别名 ────────────────────────────────
$Script:DataTables = @{
    Skills          = "P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset"
    SkillMeta       = "P3R/Content/Xrd777/Battle/Tables/DatSkillDataAsset.uasset"
    Personas        = "P3R/Content/Xrd777/Battle/Tables/DatPersonaDataAsset.uasset"
    PersonaGrowth   = "P3R/Content/Xrd777/Battle/Tables/DatPersonaGrowthDataAsset.uasset"
    PersonaAffinity = "P3R/Content/Xrd777/Battle/Tables/DatPersonaAffinityDataAsset.uasset"
    Enemies         = "P3R/Content/Xrd777/Battle/Tables/DatEnemyDataAsset.uasset"
    EnemyAffinity   = "P3R/Content/Xrd777/Battle/Tables/DatEnemyAffinityDataAsset.uasset"
    Encounters      = "P3R/Content/Xrd777/Battle/Tables/DatEncountTableDataAsset.uasset"
    Items           = "P3R/Content/Xrd777/UI/Tables/DatItemCommonDataAsset.uasset"
    Weapons         = "P3R/Content/Xrd777/UI/Tables/DatItemWeaponDataAsset.uasset"
    Armor           = "P3R/Content/Xrd777/UI/Tables/DatItemArmorDataAsset.uasset"
    Accessories     = "P3R/Content/Xrd777/UI/Tables/DatItemAccsDataAsset.uasset"
    SkillCards      = "P3R/Content/Xrd777/UI/Tables/DatItemSkillcardDataAsset.uasset"
    PlayerLevelup   = "P3R/Content/Xrd777/Battle/Tables/DatPlayerLevelupDataAsset.uasset"
    PlayerMaxHP     = "P3R/Content/Xrd777/Battle/Tables/DatPlayerMaxHPSPDataAsset.uasset"
    Difficulty      = "P3R/Content/Xrd777/Battle/Tables/DT_BtlDIfficultyParam.uasset"
    TheurgiaBoost   = "P3R/Content/Xrd777/Battle/Tables/DatBtlTheurgiaBoostDataAsset.uasset"
    CombineMisc     = "P3R/Content/Xrd777/System/Tables/CombineMiscDataAsset.uasset"
    SupportInfo     = "P3R/Content/Xrd777/Battle/Tables/DatSupportInfoCommonDataAsset.uasset"
    SkillLimit      = "P3R/Content/Xrd777/Battle/Tables/DatSkillLimitDataAsset.uasset"
    SpecialSpread   = "P3R/Content/Xrd777/Battle/Tables/SpecialSpreadDataAsset.uasset"
    Materials       = "P3R/Content/Xrd777/UI/Tables/DatItemMaterialDataAsset.uasset"
    Costumes        = "P3R/Content/Xrd777/UI/Tables/DatItemCostumeDataAsset.uasset"
    Shoes           = "P3R/Content/Xrd777/UI/Tables/DatItemShoesDataAsset.uasset"
}

# ── TableKey → canonical SchemaKey ────────────────────────
$Script:TableSchemas = @{
    Skills          = 'p3re_skillNormal'
    SkillMeta       = 'p3re_skill'
    Personas        = 'p3re_persona'
    PersonaGrowth   = 'p3re_personaGrowth'
    PersonaAffinity = 'p3re_personaAffinity'
    Enemies         = 'p3re_enemy'
    EnemyAffinity   = 'p3re_enemyAffinity'
    Encounters      = 'p3re_encountTable'
    SkillCards      = 'p3re_itemSkillCard'
    PlayerLevelup   = 'p3re_playerLevelup'
    Difficulty      = 'p3re_DT_BtlDIfficultyParam'
    TheurgiaBoost   = 'p3re_btlTheurgiaBoost'
    CombineMisc     = 'p3re_combineMisc'
    SupportInfo     = 'p3re_supportInfoCommon'
    SkillLimit      = 'p3re_skillLimit'
    SpecialSpread   = 'p3re_specialSpread'
}

function ConvertTo-P3RVirtualPath {
    param([Parameter(Mandatory=$true)][string] $Path)
    $v = $Path -replace '\\', '/'
    $v = $v -replace '^.*?/Extracted/IoStore/', ''
    if ($v -match '(P3R/Content/.+)$') { $v = $matches[1] }
    return $v
}

function Get-P3RSchemaPath {
    param([Parameter(Mandatory=$true)][string] $SchemaKey)
    $direct = Join-Path $Script:SchemaDir "${SchemaKey}_schema.json"
    if (Test-Path $direct) { return $direct }

    $hits = @(Get-ChildItem $Script:SchemaDir -Filter '*_schema.json' -ErrorAction SilentlyContinue | Where-Object {
        try {
            $s = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            ($s.templateFile -replace '\.bt$', '') -ieq $SchemaKey
        } catch { $false }
    })
    if ($hits.Count -eq 1) { return $hits[0].FullName }
    throw "Schema '$SchemaKey' not found under $Script:SchemaDir"
}

function Get-P3RSchemaObject {
    param([Parameter(Mandatory=$true)][string] $SchemaKey)
    $path = Get-P3RSchemaPath -SchemaKey $SchemaKey
    return (Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Find-P3RJsonCache {
    param([string] $VirtualPath, [string] $AssetName)
    if (-not $AssetName -and $VirtualPath) { $AssetName = [System.IO.Path]::GetFileNameWithoutExtension($VirtualPath) }
    if (-not $AssetName) { return $null }
    $candidates = @(
        "$AssetName.json"
        "$($AssetName.ToLowerInvariant()).json"
    ) | Select-Object -Unique
    foreach ($name in $candidates) {
        $hit = Get-ChildItem $Script:JsonOutput -Recurse -Filter $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

function Resolve-P3RTableContext {
    param(
        [string] $TableKey,
        [string] $SchemaKey,
        [string] $VirtualPath
    )

    if ($TableKey -and -not $Script:DataTables.ContainsKey($TableKey)) {
        $match = @($Script:DataTables.Keys | Where-Object { $_ -ieq $TableKey -or $_ -like "*$TableKey*" }) | Select-Object -First 1
        if ($match) { $TableKey = $match } else { throw "Unknown TableKey '$TableKey'. Known: $($Script:DataTables.Keys -join ', ')" }
    }

    if (-not $VirtualPath -and $TableKey) { $VirtualPath = $Script:DataTables[$TableKey] }
    if (-not $SchemaKey -and $TableKey -and $Script:TableSchemas.ContainsKey($TableKey)) { $SchemaKey = $Script:TableSchemas[$TableKey] }

    if ($SchemaKey) {
        $schema = Get-P3RSchemaObject -SchemaKey $SchemaKey
        if (-not $VirtualPath -and $schema.sourceAssetPath) { $VirtualPath = ConvertTo-P3RVirtualPath $schema.sourceAssetPath }
    }

    if ($VirtualPath) { $VirtualPath = ConvertTo-P3RVirtualPath $VirtualPath }

    if (-not $SchemaKey -and $VirtualPath) {
        $asset = [System.IO.Path]::GetFileName($VirtualPath)
        $schemas = @(Get-ChildItem $Script:SchemaDir -Filter '*_schema.json' -ErrorAction SilentlyContinue)
        foreach ($sf in $schemas) {
            try {
                $s = Get-Content $sf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($s.disposition -eq 'deprecatedDuplicate') { continue }
                $sv = if ($s.sourceAssetPath) { ConvertTo-P3RVirtualPath $s.sourceAssetPath } else { '' }
                if (($sv -and $sv -ieq $VirtualPath) -or ($s.asset -and $s.asset -ieq $asset)) {
                    $SchemaKey = $s.templateFile -replace '\.bt$', ''
                    $schema = $s
                    break
                }
            } catch {}
        }
    }

    if (-not $SchemaKey) { throw "Cannot resolve SchemaKey. Supply -TableKey, -SchemaKey, or a known -VirtualPath." }
    if (-not $schema) { $schema = Get-P3RSchemaObject -SchemaKey $SchemaKey }
    $schemaPath = Get-P3RSchemaPath -SchemaKey $SchemaKey
    if (-not $VirtualPath -and $schema.sourceAssetPath) { $VirtualPath = ConvertTo-P3RVirtualPath $schema.sourceAssetPath }

    if (-not $TableKey -and $VirtualPath) {
        foreach ($kv in $Script:DataTables.GetEnumerator()) {
            if ((ConvertTo-P3RVirtualPath $kv.Value) -ieq $VirtualPath) { $TableKey = $kv.Key; break }
        }
    }

    $assetName = if ($VirtualPath) { [System.IO.Path]::GetFileNameWithoutExtension($VirtualPath) } elseif ($schema.asset) { [System.IO.Path]::GetFileNameWithoutExtension($schema.asset) } else { $SchemaKey }
    $jsonCache = Find-P3RJsonCache -VirtualPath $VirtualPath -AssetName $assetName

    return [PSCustomObject]@{
        TableKey    = $TableKey
        SchemaKey   = $SchemaKey
        SchemaPath  = $schemaPath
        Schema      = $schema
        VirtualPath = $VirtualPath
        AssetName   = $assetName
        JsonCache   = $jsonCache
    }
}

function Find-P3RSchemaField {
    param([array] $Fields, [Parameter(Mandatory=$true)][string] $Name)
    $hit = @($Fields | Where-Object { $_.name -ieq $Name })
    if ($hit.Count -eq 1) { return $hit[0] }

    $hit = @($Fields | Where-Object {
        $_.name -match '^([A-Za-z0-9_]+?)_\d+_[A-F0-9]{32}$' -and $matches[1] -ieq $Name
    })
    if ($hit.Count -eq 1) { return $hit[0] }
    if ($hit.Count -gt 1) { throw "Ambiguous field '$Name' matched $($hit.Count) GUID-suffixed fields" }

    if ($Name -match '\.') {
        $last = ($Name -split '\.')[-1]
        $hit = @($Fields | Where-Object { $_.name -ieq $last })
        if ($hit.Count -eq 1) { return $hit[0] }
    }
    return $null
}

function Resolve-P3RTarget {
    param(
        [Parameter(Mandatory=$true)][string] $Target,
        [Parameter(Mandatory=$true)] $Schema
    )
    $shape = $Schema.tableShape
    $headerSize = [int]$Schema.headerSize

    if ($Target -match '^Data\[(\d+)\]\.(.+)$') {
        if ($shape -ne 'indexed_rows') { throw "Target '$Target' uses Data[N], but schema shape is $shape" }
        $row = [int]$matches[1]
        $fieldName = $matches[2]
        $field = Find-P3RSchemaField -Fields $Schema.fields -Name $fieldName
        if (-not $field) { throw "Field '$fieldName' not found in schema" }
        return [PSCustomObject]@{ Kind='Data'; Row=$row; RowKey=$null; FieldName=$fieldName; Field=$field; Offset=$headerSize + $row * [int]$Schema.rowSize + [int]$field.offset; ByteSize=[int]$field.size; Type=$field.type }
    }

    if ($Target -match '^Rows\["([^"]+)"\]\.(.+)$' -or $Target -match '^Rows\.([^\.]+)\.(.+)$') {
        if ($shape -ne 'named_rows') { throw "Target '$Target' uses Rows, but schema shape is $shape" }
        $rowKey = $matches[1]
        $fieldName = $matches[2]
        $row = @($Schema.rows | Where-Object { $_.name -ieq $rowKey }) | Select-Object -First 1
        if (-not $row) { throw "Row '$rowKey' not found. Known: $($Schema.rowKeys -join ', ')" }
        $field = Find-P3RSchemaField -Fields $row.fields -Name $fieldName
        if (-not $field) { throw "Field '$fieldName' not found in row '$rowKey'" }
        return [PSCustomObject]@{ Kind='Rows'; Row=$null; RowKey=$rowKey; FieldName=$fieldName; Field=$field; Offset=$headerSize + [int]$row.offset + [int]$field.offset; ByteSize=[int]$field.size; Type=$field.type }
    }

    if ($Target -match '^Record\[(\d+)\]\.(.+)$') {
        if ($shape -ne 'single_record_array') { throw "Target '$Target' uses Record[N], but schema shape is $shape" }
        $row = [int]$matches[1]
        $fieldName = $matches[2]
        $field = Find-P3RSchemaField -Fields $Schema.fields -Name $fieldName
        if (-not $field) { throw "Field '$fieldName' not found in schema" }
        return [PSCustomObject]@{ Kind='Record'; Row=$row; RowKey=$null; FieldName=$fieldName; Field=$field; Offset=$headerSize + $row * [int]$Schema.repeatStride + [int]$field.offset; ByteSize=[int]$field.size; Type=$field.type }
    }

    if ($shape -eq 'single_record') {
        $field = Find-P3RSchemaField -Fields $Schema.fields -Name $Target
        if (-not $field) { throw "Field '$Target' not found in schema" }
        return [PSCustomObject]@{ Kind='Field'; Row=$null; RowKey=$null; FieldName=$Target; Field=$field; Offset=$headerSize + [int]$field.offset; ByteSize=[int]$field.size; Type=$field.type }
    }

    throw "Cannot parse target '$Target' for schema shape '$shape'"
}

function Get-P3RJsonValue {
    param($Json, $ResolvedTarget)
    if (-not $Json -or -not $ResolvedTarget) { return $null }
    $field = $ResolvedTarget.FieldName
    if ($ResolvedTarget.Kind -eq 'Data' -and $Json.Properties.Data) {
        $row = $Json.Properties.Data[$ResolvedTarget.Row]
        if ($null -eq $row) { return $null }
        $prop = @($row.PSObject.Properties | Where-Object { $_.Name -ieq $field }) | Select-Object -First 1
        if ($prop) { return $prop.Value }
    }
    if ($ResolvedTarget.Kind -eq 'Rows' -and $Json.Rows) {
        $rowProp = @($Json.Rows.PSObject.Properties | Where-Object { $_.Name -ieq $ResolvedTarget.RowKey }) | Select-Object -First 1
        if ($rowProp) {
            $prop = @($rowProp.Value.PSObject.Properties | Where-Object { $_.Name -ieq $field -or $_.Name -like "$field`_*" }) | Select-Object -First 1
            if ($prop) { return $prop.Value }
        }
    }
    return $null
}

function Get-P3RDisplayName {
    param([string] $TableKey, [Nullable[int]] $Id)
    if ($null -eq $Id) { return $null }
    $file = $null
    if ($TableKey -in @('Skills','SkillMeta')) { $file = Join-Path $Script:ZhCnDir 'skills.md' }
    elseif ($TableKey -like 'Persona*') { $file = Join-Path $Script:ZhCnDir 'personas.md' }
    elseif ($TableKey -like 'Enem*') { $file = Join-Path $Script:ZhCnDir 'enemies.md' }
    if (-not $file -or -not (Test-Path $file)) { return $null }

    foreach ($line in (Get-Content $file -Encoding UTF8)) {
        if ($line -match '^\|\s*(\d+)\s*\|\s*([^|]+?)\s*\|.*?\|\s*([^|]+?)\s*\|') {
            if ([int]$matches[1] -eq [int]$Id) { return (($matches[2].Trim()) + ' / ' + ($matches[3].Trim())) }
        }
    }
    return $null
}

function Read-P3RRegistry {
    if (Test-Path $Script:ModRegistry) {
        try { return (Get-Content $Script:ModRegistry -Raw -Encoding UTF8 | ConvertFrom-Json) } catch {}
    }
    return [PSCustomObject]@{ version = 1; mods = @() }
}

function Write-P3RRegistry {
    param($Registry)
    New-Item -ItemType Directory -Force -Path (Split-Path $Script:ModRegistry -Parent) | Out-Null
    if (-not $Registry.version) { $Registry | Add-Member -NotePropertyName version -NotePropertyValue 2 -Force }
    if (-not $Registry.mods) { $Registry | Add-Member -NotePropertyName mods -NotePropertyValue @() -Force }
    $Registry | Add-Member -NotePropertyName updatedAt -NotePropertyValue (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -Force
    $Registry | ConvertTo-Json -Depth 12 | Out-File $Script:ModRegistry -Encoding UTF8
}

function Get-P3RModWorkDir {
    param([Parameter(Mandatory=$true)][string] $ModName)
    return (Join-Path $Script:ModOutput $ModName)
}

function Get-P3RInstalledModDir {
    param([Parameter(Mandatory=$true)][string] $ModName)
    return (Join-Path $Script:ReloadedModsDir $ModName)
}

function Get-P3RDirectorySnapshot {
    param([string] $Path)
    if (-not $Path -or -not (Test-Path $Path)) { return @() }
    $root = (Resolve-Path $Path).Path
    return @(Get-ChildItem $root -Recurse -File -ErrorAction SilentlyContinue | Sort-Object FullName | ForEach-Object {
        [PSCustomObject]@{
            path = $_.FullName.Replace($root, '').TrimStart('\\')
            length = $_.Length
            sha256 = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
        }
    })
}

function Get-P3RSnapshotHash {
    param([array] $Snapshot)
    if (-not $Snapshot -or $Snapshot.Count -eq 0) { return $null }
    $joined = (($Snapshot | Sort-Object path | ForEach-Object { "$($_.path)|$($_.length)|$($_.sha256)" }) -join "`n")
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($joined)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '') } finally { $sha.Dispose() }
}

function Read-P3RHistory {
    param([Parameter(Mandatory=$true)][string] $ModDir)
    $path = Join-Path $ModDir 'history.json'
    if (-not (Test-Path $path)) { return @() }
    try {
        $raw = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($raw.entries) { return @($raw.entries) }
        return @($raw)
    } catch { return @() }
}

function Write-P3RHistory {
    param(
        [Parameter(Mandatory=$true)][string] $ModDir,
        [array] $Entries = @()
    )
    New-Item -ItemType Directory -Force -Path $ModDir | Out-Null
    $path = Join-Path $ModDir 'history.json'
    @($Entries | Where-Object { $null -ne $_ }) | ConvertTo-Json -Depth 12 | Out-File $path -Encoding UTF8
}

function Add-P3RHistoryEntry {
    param(
        [Parameter(Mandatory=$true)][string] $ModDir,
        [Parameter(Mandatory=$true)][string] $Action,
        [string] $VirtualPath,
        [string] $SchemaKey,
        [string] $UserInput,
        [string] $BeforeHash,
        [string] $AfterHash,
        $Details
    )
    $entries = @(Read-P3RHistory -ModDir $ModDir)
    $entry = [PSCustomObject]@{
        action = $Action
        timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        beforeHash = $BeforeHash
        afterHash = $AfterHash
        virtualPath = $VirtualPath
        schemaKey = $SchemaKey
        userInput = $UserInput
        details = $Details
    }
    $entries += $entry
    Write-P3RHistory -ModDir $ModDir -Entries $entries
    return $entry
}

function Get-P3RModEntry {
    param([Parameter(Mandatory=$true)][string] $ModName, [string] $VirtualPath)
    $registry = Read-P3RRegistry
    $hits = @($registry.mods | Where-Object { $_.modName -eq $ModName -and ((-not $VirtualPath) -or $_.virtualPath -eq $VirtualPath) })
    return $hits
}

function Set-P3RModEntry {
    param([Parameter(Mandatory=$true)] $Entry)
    $registry = Read-P3RRegistry
    $mods = @($registry.mods | Where-Object { -not ($_.modName -eq $Entry.modName -and $_.virtualPath -eq $Entry.virtualPath) })
    $mods += $Entry
    $registry.version = 2
    $registry.mods = @($mods | Sort-Object modName, virtualPath)
    Write-P3RRegistry -Registry $registry
}

function Remove-P3RModEntry {
    param([Parameter(Mandatory=$true)][string] $ModName, [string] $VirtualPath)
    $registry = Read-P3RRegistry
    $registry.mods = @($registry.mods | Where-Object { -not ($_.modName -eq $ModName -and ((-not $VirtualPath) -or $_.virtualPath -eq $VirtualPath)) })
    Write-P3RRegistry -Registry $registry
}

function Invoke-P3RGitPreModBackup {
    param(
        [Parameter(Mandatory=$true)][string] $ModName,
        [string] $Reason = 'pre-mod backup',
        [string[]] $Paths = @()
    )
    $result = [PSCustomObject]@{ attempted=$false; committed=$false; skipped=$false; reason=$null; commit=$null; files=@() }
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) { $result.skipped = $true; $result.reason = 'git not found'; return $result }

    Push-Location $Script:ProjectRoot
    try {
        $inside = (& git rev-parse --is-inside-work-tree 2>$null)
        if ($LASTEXITCODE -ne 0 -or $inside -ne 'true') { $result.skipped = $true; $result.reason = 'not a git work tree'; return $result }
        $status = @(& git status --porcelain)
        if ($status.Count -gt 0) {
            $result.skipped = $true
            $result.reason = 'working tree has existing changes; refusing to auto-commit unrelated work'
            return $result
        }

        $existing = @($Paths | Where-Object { $_ -and (Test-Path $_) })
        if ($existing.Count -eq 0) { $result.skipped = $true; $result.reason = 'no existing files to snapshot'; return $result }

        $result.attempted = $true
        foreach ($p in $existing) { & git add -- $p | Out-Null }
        $staged = @(& git diff --cached --name-only)
        if ($staged.Count -eq 0) { $result.skipped = $true; $result.reason = 'no git-tracked changes to commit'; return $result }
        & git commit -m "auto: pre-mod backup for $ModName" -m $Reason | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $result.committed = $true
            $result.commit = (& git rev-parse --short HEAD)
            $result.files = @($staged)
        } else {
            $result.skipped = $true
            $result.reason = 'git commit failed'
        }
        return $result
    } finally {
        Pop-Location
    }
}

# ── 运行时检查 ────────────────────────────────────────────
$toolsOk = @()
if (Test-Path $DataTools) { $toolsOk += "P3RDataTools" }
if (Test-Path $UnrealPak) { $toolsOk += "UnrealPak" }
if ($toolsOk.Count -eq 2) {
    Write-Verbose "Tools ready: $($toolsOk -join ', ')"
} else {
    $missing = @("P3RDataTools", "UnrealPak") | Where-Object { $_ -notin $toolsOk }
    Write-Warning "Missing tools: $($missing -join ', '). Run setup.ps1 to initialize."
}

Write-Verbose "P3R Modding config loaded. Project root: $ProjectRoot"
