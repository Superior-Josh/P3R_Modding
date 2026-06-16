# P3R Modding Configuration
$Script:ProjectRoot = Resolve-Path "$PSScriptRoot\..\.."
$Script:DataTools = "$ProjectRoot\tools\P3RDataTools\publish\P3RDataTools.exe"
$Script:UnrealPak = "$ProjectRoot\tools\UnrealPakTool\UnrealPak.exe"
$Script:CryptoJson = "$ProjectRoot\tools\UnrealPakTool\Crypto.json"
$Script:JsonOutput = "$ProjectRoot\tools\Output\json"
$Script:ModOutput = "$ProjectRoot\tools\Output\mod"

$Script:AesKey = "0x92BADFE2921B376069D3DE8541696D230BA06B5E4320084DD34A26D117D2FFEE"

# Common DataTable virtual paths
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

Write-Verbose "P3R Modding config loaded. Project root: $ProjectRoot"
