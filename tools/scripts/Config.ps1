# P3R Modding Configuration
# 由 setup.ps1 自动生成, 也可手动编辑
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

# ── 模板库 ────────────────────────────────────────────────
$Script:TemplatesDir = "$ProjectRoot\tools\templates"
$Script:TemplateIndex = "$ProjectRoot\tools\templates\template_index.json"

# ── 工具脚本目录 ──────────────────────────────────────────
$Script:ToolsDir = "$ProjectRoot\tools\scripts\tools"

# ── Mod 注册表 ────────────────────────────────────────────
$Script:ModRegistry = "$ProjectRoot\tools\Output\.data\mod_registry.json"

# ── Wiki 参考数据 ─────────────────────────────────────────
$Script:WikiDir = "$ProjectRoot\docs\amicitia\md"
$Script:DataMappingFile = "$ProjectRoot\docs\amicitia\DATA_MAPPING.md"

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
