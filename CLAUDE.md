# CLAUDE.md

本文件为 Claude Code 在此仓库中工作时的项目级指导。它根据当前仓库目录、工具脚本与文档状态重新生成（2026-06-25），并以现有事实为准：**P3R 当前唯一推荐写回路径是 Zen 单文件 `.uasset` byte-patch + Reloaded II / UnrealEssentials 散文件挂载**。

## 1. 项目定位

这是一个 **Persona 3 Reload (P3R) 逆向工程与 Mod 制作工作区**。仓库主要管理文档、PowerShell 工具、C# CLI 源码、010 Editor schema 与轻量配置；原版游戏资产、Reloaded II、UnrealPak、提取目录和生成产物大多被 `.gitignore` 排除。

项目目标是构建 **自然语言驱动的 P3R Mod 制作 AI Agent**，把中文/英文需求安全转换为可预览、可审计、可回滚的 P3R DataTable 修改。当前已工程化能力集中在数值类 DataTable：技能、Persona、敌人、道具/商店、难度、部分战斗系统表等。

当前边界：文本/本地化、模型、纹理、动画、音频重打包等非 DataTable 写回仍属于研究方向，不能在未验证前承诺“已支持”。

## 2. 当前仓库快照

| 项 | 当前状态 |
|---|---:|
| `tools/Output/json/**/*.json` | 约 490 个 DataTable JSON 快照 |
| `tools/templates-010/**/*.bt` | 44 个 010 Editor 模板 |
| `tools/templates-010/schemas/*_schema.json` | 34 个 schema |
| `tools/scripts/**/*.ps1` | 16 个 PowerShell 脚本 |
| `tools/scripts/**/*.psm1` | 1 个 DSL 模块 |
| Amicitia Markdown 参考页 | 37 页 |
| 中文译名 Markdown 文件 | 8 个 |

重要阶段：

- Sprint 1.5：Zen byte-patch 写回链路工程化。
- Sprint 2/3：diff、guard、backup、rollback、conflict、registry/history 接入主 pipeline。
- Sprint 4：新增 `batch-modify.ps1`、`schema-coverage-report.ps1`、覆盖/边界/验收文档；仍需持续校正 PARTIAL schema 与真实游戏内验证记录。

## 3. 必须遵守的硬规则

1. **默认写回路径只能走 Zen byte-patch**：从 IoStore/Extracted 获取 Zen 单文件 `.uasset`，用 schema 计算 offset 后字节 patch，再以 UnrealEssentials 散文件安装。
2. **不要把 `P3RDataTools create/modify/quick/create-template` 当新 Mod 主路径**：这些命令仍存在，但输出传统 `.uasset+.uexp`，P3R 实测不可靠/会崩，保留为 legacy/读取研究用途。
3. **`Data[N]` 的 N 通常等于游戏资产 ID**：不要默认修改 `Data[0]`。例：亚基 / Agi 是 Skill ID 10，应改 `Data[10]`。
4. **Skill 表 `hpn` 是显示伤害的平方语义**：用户说“伤害 N 倍”时应写回 `原 hpn × N²`，不是 `原 hpn × N`。
5. **自动写回仅限 guard 放行的定长标量字段**：1/2/4/8 字节 flat scalar 可自动 patch；string、TArray、union、nested struct array、变长字段、未复核 PARTIAL schema 默认拒绝自动写回。
6. **真实写回前必须预览 + guard + conflict check**：默认先 `-DryRun` 或 `diff-changes.ps1`；真实写入前必须通过 `guard-modify.ps1` 与冲突检查。
7. **破坏性动作必须先预览并获得明确授权**：`rollback-mod.ps1 -Force`、`-RemoveInstalled`、覆盖 Reloaded II 已安装目录、跳过 guard/conflict 等都需要明确授权。
8. **不得擅自处理用户工作区改动**：Git pre-mod backup 只在工作区干净时自动提交；工作区脏时安全跳过，不得为了触发备份而提交、重置、丢弃用户改动。
9. **不要提交原版游戏资产或本地工具二进制**：`Paks/`、`Extracted/`、`tools/Reloaded II/`、`tools/UnrealPakTool/`、`tools/Output/.data/` 等为本地/生成/忽略目录。
10. **事实性纠错要落到文档**：若用户纠正 P3R 项目事实，应在 `docs/MODDING_PITFALLS.md` 追加/更新 P-NNN 条目，而不是只写 memory。

## 4. 标准 Mod 工作流

### 4.1 中文/自然语言需求到写回

1. **定位**：用中文名/英文名/ID 查目标。
   - 中文标准译名：`docs/zh-cn/README.md` 与子文件。
   - 英文/ID 参考：`docs/amicitia/README.md`、`docs/amicitia/DATA_MAPPING.md`、`docs/amicitia/md/`。
   - 工具：`tools/scripts/tools/search-datatable.ps1`、`search-wiki.ps1`。
2. **确认字段与语义**：查 `tools/Output/json/` 真实字段名，不要凭印象写 `Power`、`SPCost`、`dmg`。
3. **预览 diff**：运行 `-DryRun` 或 `diff-changes.ps1`，确认 TableKey、target、旧值、新值、offset。
4. **安全检查**：运行 guard；真实写回前必须检查冲突。
5. **写回/安装**：用 `modify-and-repack.ps1` 生成 Zen `.uasset`，默认安装到 Reloaded II Mod 的 `UnrealEssentials/P3R/Content/...`。
6. **验证**：用户通过 Reloaded II 启动 P3R，确认 Mod 已启用；必要时记录游戏内验证。
7. **回滚**：先 `rollback-mod.ps1 -Preview`，获得授权后再 `-Force`。

### 4.2 最小 DryRun 示例

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999}) `
  -ModName 'AgiMod' -DryRun
```

### 4.3 真实生成并安装

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999}) `
  -ModName 'AgiMod'
```

### 4.4 人类可读 diff / guard / conflict

```powershell
.\tools\scripts\tools\diff-changes.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999})

.\tools\scripts\tools\guard-modify.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999})

.\tools\scripts\tools\conflict-check.ps1 -All
```

### 4.5 批量修改（Sprint 4）

`batch-modify.ps1` 会根据 ID 或 where 条件生成 `batch-changes.json`，再委托主 pipeline。

```powershell
.\tools\scripts\tools\batch-modify.ps1 -TableKey Skills `
  -Field cost -Value 1 -Ids 10,11,12 -PreviewOnly

.\tools\scripts\tools\batch-modify.ps1 -TableKey Skills `
  -Field cost -Value 1 -Ids 10,11,12 -DryRun -ModName 'CheapFireSkills'
```

批量写回仍必须遵守 guard、conflict、备份与审计规则。

## 5. Mod 交付机制

P3R 使用 **Reloaded II** 加载 Mod。项目默认采用 **UnrealEssentials 散文件挂载**：

```text
Extracted/IoStore Zen .uasset
  → Invoke-ZenPatch.ps1 byte-patch
  → <Mod>/UnrealEssentials/P3R/Content/.../<asset>.uasset
  → Reloaded II + p3rpc.essentials / UnrealEssentials
  → P3R.exe
```

### 5.1 UnrealEssentials 散文件（默认）

```text
Reloaded-II/
└── Mods/
    └── <ModName>/
        ├── ModConfig.json
        └── UnrealEssentials/
            └── P3R/
                └── Content/
                    └── Xrd777/
                        └── Battle/Tables/
                            └── DatSkillNormalDataAsset.uasset
```

规则：

- 安装路径必须完整镜像虚拟路径：`P3R/Content/.../<asset>.uasset`。
- Zen byte-patch 产物是单文件 `.uasset`，首字节通常 `00 00 00 00`，不生成 `.uexp`。
- `ModConfig.json` 必须包含 `SupportedAppId: ["p3r.exe"]`。
- 项目默认依赖 `p3rpc.essentials`，它会间接拉起 UnrealEssentials；极简资产替换也可直接依赖 `UnrealEssentials`，但要与实际安装一致。

### 5.2 FEmulator/PAK（仅 fallback）

只有 UnrealEssentials 路径排查需要时才使用 `-PackPak`。PAK 必须放在：

```text
<Mod>/FEmulator/PAK/<ModName>.pak
```

PAK 小于 1 KB 通常是空 PAK，不要部署。P3R 不能直接加载游戏 `Paks/` 目录下的自制 `.pak`；必须通过 Reloaded II 注入。

## 6. 常用入口文件与命令

| 用途 | 入口 |
|---|---|
| 主流程 | `tools/scripts/modify-and-repack.ps1` |
| Zen 字节写回引擎 | `tools/scripts/Invoke-ZenPatch.ps1` |
| DSL helper | `tools/scripts/dsl/P3RModDSL.psm1` |
| 数据定位 | `tools/scripts/tools/search-datatable.ps1`、`search-wiki.ps1` |
| 预览 | `tools/scripts/tools/diff-changes.ps1`、`modify-and-repack.ps1 -DryRun` |
| 安全检查 | `tools/scripts/tools/guard-modify.ps1`、`conflict-check.ps1` |
| 备份/回滚 | `tools/scripts/tools/backup-mod.ps1`、`rollback-mod.ps1` |
| 批量修改 | `tools/scripts/tools/batch-modify.ps1` |
| schema 覆盖报告 | `tools/scripts/tools/schema-coverage-report.ps1` |
| schema 链 | `Parse-BtTemplate.ps1`、`Calibrate-SchemaHeaders.ps1`、`Test-SchemaRegression.ps1` |
| C# 读取 CLI | `tools/P3RDataTools/` |

## 7. DSL helper

```powershell
Import-Module .\tools\scripts\dsl\P3RModDSL.psm1

Set-SkillHpn -SkillId 10 -DamageMultiplier 5.0 -OutputDir .\my-agimod\
Set-SkillCost -SkillId 10 -Cost 1 -OutputDir .\my-agimod\
Set-PersonaLevel -PersonaId 1 -Level 99 -OutputDir .\my-persona\
Set-EnemyHP -EnemyId 100 -HP 9999 -OutputDir .\my-enemy\
Set-EnemySkill -EnemyId 100 -Slot 3 -SkillId 47 -OutputDir .\my-enemy\
Set-DifficultyParam -Difficulty normal -Field ExpRate -Value 3.0 -OutputDir .\my-diff\
```

注意：DSL 底层偏向直接调用 `Invoke-ZenPatch.ps1`。用户要求完整审计/安装时优先用 `modify-and-repack.ps1` 主流程。

## 8. TableKey 快速索引

| TableKey | 虚拟路径 |
|---|---|
| `Skills` | `P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset` |
| `SkillMeta` | `P3R/Content/Xrd777/Battle/Tables/DatSkillDataAsset.uasset` |
| `Personas` | `P3R/Content/Xrd777/Battle/Tables/DatPersonaDataAsset.uasset` |
| `PersonaGrowth` | `P3R/Content/Xrd777/Battle/Tables/DatPersonaGrowthDataAsset.uasset` |
| `PersonaAffinity` | `P3R/Content/Xrd777/Battle/Tables/DatPersonaAffinityDataAsset.uasset` |
| `Enemies` | `P3R/Content/Xrd777/Battle/Tables/DatEnemyDataAsset.uasset` |
| `EnemyAffinity` | `P3R/Content/Xrd777/Battle/Tables/DatEnemyAffinityDataAsset.uasset` |
| `Encounters` | `P3R/Content/Xrd777/Battle/Tables/DatEncountTableDataAsset.uasset` |
| `Items` | `P3R/Content/Xrd777/UI/Tables/DatItemCommonDataAsset.uasset` |
| `Weapons` | `P3R/Content/Xrd777/UI/Tables/DatItemWeaponDataAsset.uasset` |
| `Armor` | `P3R/Content/Xrd777/UI/Tables/DatItemArmorDataAsset.uasset` |
| `Accessories` | `P3R/Content/Xrd777/UI/Tables/DatItemAccsDataAsset.uasset` |
| `SkillCards` | `P3R/Content/Xrd777/UI/Tables/DatItemSkillcardDataAsset.uasset` |
| `PlayerLevelup` | `P3R/Content/Xrd777/Battle/Tables/DatPlayerLevelupDataAsset.uasset` |
| `PlayerMaxHP` | `P3R/Content/Xrd777/Battle/Tables/DatPlayerMaxHPSPDataAsset.uasset` |
| `Difficulty` | `P3R/Content/Xrd777/Battle/Tables/DT_BtlDIfficultyParam.uasset` |
| `TheurgiaBoost` | `P3R/Content/Xrd777/Battle/Tables/DatBtlTheurgiaBoostDataAsset.uasset` |
| `CombineMisc` | `P3R/Content/Xrd777/System/Tables/CombineMiscDataAsset.uasset` |
| `SupportInfo` | `P3R/Content/Xrd777/Battle/Tables/DatSupportInfoCommonDataAsset.uasset` |
| `SkillLimit` | `P3R/Content/Xrd777/Battle/Tables/DatSkillLimitDataAsset.uasset` |
| `SpecialSpread` | `P3R/Content/Xrd777/Battle/Tables/SpecialSpreadDataAsset.uasset` |
| `Materials` | `P3R/Content/Xrd777/UI/Tables/DatItemMaterialDataAsset.uasset` |
| `Costumes` | `P3R/Content/Xrd777/UI/Tables/DatItemCostumeDataAsset.uasset` |
| `Shoes` | `P3R/Content/Xrd777/UI/Tables/DatItemShoesDataAsset.uasset` |

## 9. 中文译名与回复规范

中文用户常用「亚基」「俄耳甫斯」「魔术之手」等标准中文译名。处理中文需求时：

1. 先查 `docs/zh-cn/`，找到中文名对应的英文名、ID、Arcana/属性等。
2. 再查 `docs/amicitia/` 与 JSON 缓存确认 ID、字段与表。
3. 回复中文用户时优先使用标准中文译名；除非用户使用英文，否则不要只回复英文名。
4. biligame WIKI 缺失条目可先查 `Extracted/IoStore/L10N/zh-Hans/`，再退回英文名 + 中文说明。
5. 伤害倍率类需求必须解释 `hpn` 的 N² 换算。

示例：

- ✅ “已预览将 **亚基**（Agi，Skill ID 10）的 `hpn` 改为 999；这是原版显示伤害约 5 倍，而不是线性 999 点伤害。”
- ❌ “已把 Agi 的 Power 改成 999。”（字段名与中文回复都不符合项目约定）

## 10. Schema / guard 策略

自动安全原则：

| 状态 | 自动写回策略 |
|---|---|
| `regressionStatus=pass` + flat scalar | 可自动放行 |
| `disposition=safeWithNormalization` | 仅按 schema 标注的归一化规则放行 |
| `regressionStatus=partial` / `needsManualReview` | 默认人工 offset 复核 |
| `fail` / `skip` / `deprecatedDuplicate` / `unsupportedUntilSchemaFix` | 阻断或仅研究 |
| string / TArray / union / nested struct array / 变长字段 | 阻断 |

生成覆盖报告：

```powershell
.\tools\scripts\tools\schema-coverage-report.ps1
```

报告会写入 `docs/SCHEMA_COVERAGE_REPORT.md` 与 `tools/templates-010/schemas/schema-safety-coverage.json`。

## 11. 读取 DataTable

读取/导出可以使用 P3RDataTools；写回不要走 legacy 输出路径。

```powershell
. .\tools\scripts\Config.ps1
& $DataTools read "P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset" skills.json
& $DataTools batch "Xrd777/Battle/Tables" .\json\Battle\
```

工具版本约束：CUE4Parse 锁定 1.1.1，不要随意升级到 1.2.x。

## 12. 常见问题排查

### Mod 不生效

检查：

- 是否通过 Reloaded II 启动 P3R，而不是 Steam/桌面快捷方式。
- Mod 是否在 Reloaded II UI 中启用。
- `ModConfig.json` 是否包含 `SupportedAppId=["p3r.exe"]`。
- 依赖是否为 `p3rpc.essentials` 或 `UnrealEssentials`。
- `.uasset` 是否位于 `<Mod>/UnrealEssentials/P3R/Content/...` 且完整镜像虚拟路径。
- 文件是否为 Zen 单文件 `.uasset`，且没有错误部署 legacy `.uexp`。

### 游戏崩溃

优先怀疑：

- 使用了传统 `.uasset+.uexp` 产物。
- patch 了 string/TArray/union/复杂结构或错误 offset。
- schema 为 PARTIAL/FAIL/SKIP 但绕过 guard。
- 安装路径或资产名不匹配。

### 难度/倍率类修改没体现

确认当前游戏难度是否与被 patch 的 `Difficulty` 行一致；难度参数只影响对应难度行。

## 13. 推荐阅读路径

| 文档 | 用途 |
|---|---|
| `README.md` | 仓库总入口：能力概览、用户工作流、环境与初始化、安装格式 |
| `docs/MODDING_PITFALLS.md` | 已确认坑点；写脚本前必读 |
| `docs/ZEN_BYTE_PATCH_WORKFLOW.md` | 当前唯一推荐写回链路 |
| `docs/SECURITY.md` | 预览、guard、冲突、备份、回滚规则 |
| `docs/SCHEMA_COVERAGE_REPORT.md` | schema 安全覆盖与 allow/deny 边界 |
| `docs/MANUAL_TEST_TODO.md` | 人工验收 / Sprint 4 验收口径 / 边界输入与危险字段测试矩阵 |
| `docs/zh-cn/README.md` | 中文译名入口 |
| `docs/amicitia/DATA_MAPPING.md` | Amicitia Wiki ↔ 游戏文件映射 |
| `docs/ESSENTIALS_REFERENCE.md` | UnrealEssentials + p3rpc.essentials 能力、依赖与路径规则 |
| `docs/FUTURE_RESOURCE_SUPPORT.md` | 音乐/文本/模型等非 DataTable 资源未来支持路线（当前均未支持，研究方向） |
