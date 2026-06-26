# pP3R Mod 制作避坑指南

> 本文档收集在 P3R Mod 制作中**已被踩中并修复**的具体陷阱。每条：症状、根因、修复、自查。
>
> **新踩到坑 → 修复后立即追加一条**。范围含"文档/示例的事实性错误"——被用户纠正过的虚构字段名、错误 ID/流程/命令同样立案，因为文档错误一旦被复制进 mod 脚本就会变成 P-001/P-002 那种实际崩盘。

## 目录

- [P-001: DataTable 数组索引 == 资产 ID（不要默认改 `Data[0]`）](#p-001-datatable-数组索引--资产-id不要默认改-data0)
- [P-002: 占位空 PAK 不要部署到 Reloaded II（&lt; 1 KB 是空头）](#p-002-占位空-pak-不要部署到-reloaded-ii)
- [P-003: 直接拷 .pak 进 `Paks/` 不会生效 —— 必须走 Reloaded II](#p-003-直接拷-pak-进-paks-不会生效)
- [P-004: 写文档/示例前先读真实 JSON 字段名（伤害是 `hpn`，不是 `dmg`/`Power`）](#p-004-写文档示例前先读真实-json-字段名)
- [P-005: Mod 默认走 UnrealEssentials 散文件挂载，不是 FEmulator/PAK](#p-005-mod-默认走-unrealessentials-散文件挂载不是-femulatorpak)
- [P-006: UE DataTable 字段名带 GUID 后缀，不可简化](#p-006-ue-datatable-字段名带-guid-后缀不可简化)
- [P-007: UnrealEssentials IoStore 资产替换偏好 Zen 单文件（不是传统 `.uasset+.uexp`）](#p-007-unrealessentials-iostore-资产替换偏好-zen-单文件)
- [P-008: `ModConfig.json` 默认依赖统一为 `p3rpc.essentials`](#p-008-modconfigjson-默认依赖统一为-p3rpcessentials)
- [P-009: Skill 表的 `hpn` 字段是显示伤害的**平方**，要改 N 倍伤害得乘 N²](#p-009-skill-表的-hpn-字段是显示伤害的平方要改-n-倍伤害得乘-n²)
- [P-010: 含 union 的 struct 不能直接 byte-patch——必崩 `Bad name index`](#p-010-含-union-的-struct-不能直接-byte-patch必崩-bad-name-index)
- [P-011: 难度参数只影响对应难度行——确认当前游戏难度再验证](#p-011-难度参数只影响对应难度行确认当前游戏难度再验证)

---

## P-001: DataTable 数组索引 == 资产 ID（不要默认改 `Data[0]`）

### 症状

PAK 生成、打包、Reloaded II 加载都成功，**游戏内修改目标完全无变化**。

### 根因

P3R 的 `Dat*DataAsset` 表里，`Properties.Data[]` 的下标就是该资产的 ID，前若干索引通常是引擎占位/未使用槽。以 [`DatSkillNormalDataAsset`](../tools/Output/json/Battle/datskillnormaldataasset.json) 为例：`Data[0]` 是占位行（不对应任何游戏内技能），**`Data[10]` 才是 Agi**（`hpn=40, cost=3`），`Data[11]`=Agilao，`Data[12]`=Agidyne…（见 [Persona_3_Reload_Skills.md](amicitia/md/Persona_3_Reload_Skills.md)）。改 `Data[0]` 等于改 ID 0 占位行，游戏根本不读它。

### 修复

永远查 Wiki 取实际 ID，再用 ID 直接索引：

```powershell
$AgiSkillId = 10   # docs/amicitia/md/Persona_3_Reload_Skills.md
$json.Properties.Data[$AgiSkillId].hpn = 999
```

已确认 `index == id`：`DatSkillNormalDataAsset`、`DatSkillDataAsset`。其余 `DatPersona*` / `DatEnemy*` / `DatItem*` 强烈怀疑同样遵循，但**首次修改时务必读原始 JSON 验证**（取 Wiki 上某特征鲜明的 ID，对比 `Data[该ID]` 数值是否吻合）。

### 自查

- [ ] 修改的索引 N，在 Wiki 表格里查到的 ID 同样是 N？
- [ ] 脚本日志打印了 "old -> new"？老值符合预期？（Agi 的 hpn 应是 40；若打出 `15 -> 999` 说明改错行）
- [ ] 改完后用 `& $DataTools read` 重读 mod 输出，确认目标 ID 字段被改

---

## P-002: 占位空 PAK 不要部署到 Reloaded II

### 症状

`AgiMod_P.pak` 只有 ~0.4 KB（仅 PAK header），Reloaded II 加载后游戏无反应。

### 根因

`UnrealPak.exe ... -Create=manifest.txt` 在 manifest 里源文件找不到时**不报错**，而是输出只含 header 的空 PAK（380–500 字节）。常见触发：manifest 写的是相对路径但 `cd` 不对；`.uasset`/`.uexp` 前置步骤 silent 失败。

### 修复

[`modify-and-repack.ps1`](../tools/scripts/modify-and-repack.ps1) 已加大小校验（`< 1 KB` 红字警告）。任何手写 PAK 构建都必须加。看到警告时：① 检查 manifest 源路径用绝对路径；② 检查 `.uasset`/`.uexp` 成对存在；③ **不要**把空 PAK 复制到 Reloaded II 目录。

---

## P-003: 直接拷 .pak 进 `Paks/` 不会生效

### 症状

把 `MyMod_P.pak` 复制到 P3R 安装目录 `P3R/Content/Paks/`，Mod 完全不生效。

### 根因

P3R 主数据走 **IoStore**（`.utoc`+`.ucas`），游戏自身不读 `Content/Paks/` 下的散装 PAK，传统 PAK 加载链与 mod PAK 的 mount 路径不匹配。

### 修复

**只通过 Reloaded II + File Emulation Framework 加载**：PAK 放 `<Mod>/FEmulator/PAK/<ModName>.pak`，`ModConfig.json` 含 `SupportedAppId:["p3r.exe"]` + `ModDependencies:["reloaded.universal.fileemulationframework.pak"]`。启动游戏必须走 Reloaded II 启动器，不能 Steam/快捷方式直接启动。

---

## P-004: 写文档/示例前先读真实 JSON 字段名

### 症状

跨多个文档出现编造字段名：`Power`、`dmg`、`SPCost`、`HPCost`、`DataID`、`Accuracy`、`Critical`——**真实 P3R DataTable 中根本不存在**。照着写脚本得到 `$json.Properties.Data[10].dmg = 999`，赋值 silently 失败或新增无效字段，PAK 看似成功但游戏内无变化（现象同 [P-001](#p-001-datatable-数组索引--资产-id不要默认改-data0)，根因不同）。

### 根因

1. P3R DataTable 用 Atlus 内部 lowercase 短名（`hpn`/`spn`/`cost`/`costtype`/`hptype`/`koukatype`/`criticalratio`/`swoonratio`/`targetcntmin`/`untargetbadstat`…），不是英文 wiki 常见的 `Power`/`SPCost`/`Damage`。
2. CUE4Parse 导出的 JSON 就是引擎真实键，无"友好别名"层。
3. 凭印象写示例 = 把虚构字段植入文档 → 被复制进 mod 脚本/AI prompt → 静默失败。

### 修复

写任何 `Data[i].FIELD` 文档/示例/代码前，先读真实 JSON：

```powershell
$j = Get-Content 'tools\Output\json\Battle\datskillnormaldataasset.json' -Raw -Encoding utf8 | ConvertFrom-Json
$j.Properties.Data[10] | ConvertTo-Json -Depth 4   # 打印真实字段，从中挑选
```

`DatSkillNormalDataAsset` 共 24 个字段，攻击伤害类技能的关键字段：`costtype`(0/1/2=无/HP/SP)、`cost`、`hitratio`、`hptype`、**`hpn`**(伤害数值 ⚠ 见 [P-009](#p-009-skill-表的-hpn-字段是显示伤害的平方要改-n-倍伤害得乘-n²))、`criticalratio`、`swoonratio`。完整列表直接读 JSON。

**已知伪字段 → 真实字段**：

| 伪字段                           | 真实字段                                                                                                 | 表                      |
| -------------------------------- | -------------------------------------------------------------------------------------------------------- | ----------------------- |
| `Power` / `dmg` / `damage` | `hpn`                                                                                                  | DatSkillNormalDataAsset |
| `SPCost` / `MPCost`          | `cost`（配合 `costtype:2`）                                                                          | DatSkillNormalDataAsset |
| `HPCost`                       | `cost`（配合 `costtype:1`）                                                                          | DatSkillNormalDataAsset |
| `Accuracy`                     | `hitratio`                                                                                             | DatSkillNormalDataAsset |
| `Critical` / `CritRate`      | `criticalratio`                                                                                        | DatSkillNormalDataAsset |
| `DataID` / `SkillID`         | （无显式 ID 字段，**数组下标即 ID**，见 [P-001](#p-001-datatable-数组索引--资产-id不要默认改-data0)） | 所有`Dat*DataAsset`   |

其他常用表（`DatEnemyDataAsset` 用 `power`/`hp` lowercase；`DatItem*DataAsset` 同样 lowercase 短名）首次引用前都 `Read` 一遍 JSON。

### 自查

- [ ] 写的字段名在 `tools/Output/json/<对应表>.json` 里 grep 得到？
- [ ] 示例里的"当前值"是从真实 JSON 读出来的，不是猜的？
- [ ] 字段名是 lowercase 短名？（PascalCase 字段名 99% 是编造的）

---

## P-005: Mod 默认走 UnrealEssentials 散文件挂载，不是 FEmulator/PAK

### 症状

按旧版 FEmulator/PAK 流程生成 `AgiMod_P.pak` 部署到 `Mods/AgiMod/FEmulator/PAK/AgiMod.pak`，PAK 大小校验过不是空头（[P-002](#p-002-占位空-pak-不要部署到-reloaded-ii)），游戏内仍无变化。

### 根因

P3R modding 在 Reloaded II 上有两条独立挂载链：

| 维度     | UnrealEssentials ★默认                                    | FEmulator/PAK                                     |
| -------- | ---------------------------------------------------------- | ------------------------------------------------- |
| 加载器   | `UnrealEssentials`（可经 `p3rpc.essentials` 间接引入） | `reloaded.universal.fileemulationframework.pak` |
| 注入点   | UE 4.27 资产虚拟文件系统，hook 传统 + IoStore 单文件       | 模拟传统 PAK 挂载                                 |
| 输入产物 | 单`.uasset`（IoStore）或 `.uasset+.uexp`（传统）       | 整包`.pak`                                      |
| 路径规则 | `<Mod>/UnrealEssentials/P3R/Content/<虚拟路径>`          | `<Mod>/FEmulator/PAK/<Mod>.pak`                 |
| 失败模式 | 路径错 /`.uexp` 漏配对（仅传统）→ 静默不覆盖            | 空 PAK / mount path 错 / pak 版本不匹配           |
| 工具依赖 | 仅 P3RDataTools                                            | P3RDataTools + UnrealPak + manifest               |

社区 P3R mod 99% 走 UnrealEssentials（更简单，少一层打包，不会出现空 PAK 隐性失败）。仓库内两个已验证参考 mod（[`p3rpc.ui.barionskillnames`](../tools/Reloaded%20II/Mods/p3rpc.ui.barionskillnames/)、[`p3r.qol.arkemultiplier`](../tools/Reloaded%20II/Mods/p3r.qol.arkemultiplier/)）都走这条。

**资产格式**：UnrealEssentials 同时支持 ① IoStore 单文件 cooked（首字节 `00 00 00 00`，FZenPackageSummary，无 `.uexp`，社区参考 mod 都用这种）② 传统 `.uasset+.uexp`（首字节 `C1 83 2A 9E`，必须成对部署）。但**对 P3R 这种纯 IoStore 游戏，传统格式散文件覆盖会直接崩游戏**——见 [P-007](#p-007-unrealessentials-iostore-资产替换偏好-zen-单文件)。

### 修复

[`modify-and-repack.ps1`](../tools/scripts/modify-and-repack.ps1) 默认 UnrealEssentials 散文件挂载。仅当需要 PAK fallback 时加 `-PackPak`（产出 `<Mod>/FEmulator/PAK/<Mod>.pak`）。

### 自查

- [ ] `<Mod>/UnrealEssentials/P3R/Content/<虚拟路径>` 下文件名（不含后缀）与原资产**完全一致**？
- [ ] 传统格式产物 `.uasset`/`.uexp` **成对**部署？（IoStore 单文件则只有一个 `.uasset`）
- [ ] `ModConfig.json` 的 `ModDependencies` 是 `["p3rpc.essentials"]`（项目默认，见 [P-008](#p-008-modconfigjson-默认依赖统一为-p3rpcessentials)）或 `["UnrealEssentials"]`，**不是** `["reloaded.universal.fileemulationframework.pak"]`？
- [ ] `SupportedAppId` 是 `["p3r.exe"]`？Reloaded II UI 已勾选启用？通过 Reloaded-II.exe（不是 Steam）启动？

---

## P-006: UE DataTable 字段名带 GUID 后缀，不可简化

### 症状

按"友好名"赋值 `$json.Rows.Normal.ExpRate = 2.0`——JSON 静默新增无效字段，导出的 `.uasset` 里 `ExpRate` 不在 row struct schema 内，游戏不读 → mod 部署成功但经验倍率无变化。现象同 [P-004](#p-004-写文档示例前先读真实-json-字段名)，但这里字段名**真实存在**，只是 UE 附加了 `_<序号>_<GUID>` 后缀。

### 根因

`DT_BtlDifficultyParam` 用 UE **UserDefinedStruct `FBtlCalcParam`** 作 row 类型，编译时给每个字段加 `_<声明序号>_<32hex GUID>` 后缀（用于重命名时保留数据 + 序列化版本兼容）。CUE4Parse 原样保留这些键。

真实 JSON 形如：

```json
"Normal": {
  "ExpRate_10_8CBA31F0430A7FDD116509A4E1A38463": 1.0,
  "MoneyRateToMaterials_23_9F2533D24722C44FC66CDCA2316CC834": 1.0
}
```

**判别**：字段名形如 `<name>_<digits>_<32hex>` 即 UserDefinedStruct。`DT_*` 前缀的表会触发；`Dat*DataAsset` 系列不会（C++ USTRUCT，字段名是原始 lowercase 短名，见 [P-004](#p-004-写文档示例前先读真实-json-字段名)）。

### 修复

写 mod 脚本前读真实 JSON，把完整 key 复制过来，用**单引号字符串**包住：

```powershell
$ExpRateKey = 'ExpRate_10_8CBA31F0430A7FDD116509A4E1A38463'
foreach ($diff in 'Safety','Easy','Normal','Hard','Risky') {
    $json.Rows.$diff.$ExpRateKey = 2.0
}
```

GUID 在同一游戏版本内稳定，可放心写进脚本常量；**P3R 大版本升级时 GUID 可能变**，脚本顶部留注释指明来源版本/路径。

### 自查

- [ ] 字段名带 `_<digits>_<32hex>` 后缀？没有就去 JSON 里搜真实键
- [ ] 用**单引号**包住完整键名？（双引号会触发字符串插值）
- [ ] 修改后 `& $DataTools read` 重读，确认目标 row 的目标 key（带 GUID）被改

---

## P-007: UnrealEssentials IoStore 资产替换偏好 Zen 单文件

### 症状

按 [P-005](#p-005-mod-默认走-unrealessentials-散文件挂载not-femulatorpak) 散文件 + UnrealEssentials 流程跑完，`ModConfig.json` 依赖/`SupportedAppId`/目录结构/文件命名都对，Reloaded II 已勾选启用，从 Reloaded-II.exe 启动——**游戏在初始化阶段静默崩溃**（Reloaded II 日志跑到 `[P3R Essentials] Got Window, Hooking WndProc.` 后无输出，进程退出）。取消勾选该 mod 后游戏正常启动。

### 根因

[UnrealEssentials 上游 README](https://github.com/AnimatedSwine37/UnrealEssentials#adding-loose-assets) 明确：

> *"if your game uses UTOC files, any `.uasset` files you replace will have to come from a UTOC as the file format is different when they are in PAK files... you will need to export them from Unreal Engine into an IO Store container (`.utoc` + `.ucas`) and then extract them if you want to use them loosely."*

P3R 使用 UTOC，散文件替换的 `.uasset` 必须从 UTOC 容器拆出——即 **Zen 单文件**（FZenPackageSummary 头，首字节 `00 00 00 00`，**无 `.uexp`**，exports/bulk data 内嵌）。项目里 [`P3RDataTools.create`](../tools/P3RDataTools/Program.cs) 经 `TemplateCreator.cs` 序列化输出的是**传统 `.uasset+.uexp`**（首字节 `C1 83 2A 9E`）。

UTOC.Stream.Emulator 为 mod 文件生成 IoStore-shape 的 TOC 指针并把字节流**直接转发**给磁盘文件——游戏从头到尾以为自己在反序列化 Zen 格式，但文件首字节是传统 magic → 字节布局不匹配 → 越界/cast 错误 → 进程崩溃。链条上没有任何环节做格式自动转换。**对 P3R 这种纯 IoStore 游戏，传统 `.uasset+.uexp` 散文件覆盖会直接崩游戏，不存在"DataTable 类资产例外"。**

> 之前"AgiMod 验证过可工作"是误判：来源是编译流程跑完没报错 + Reloaded II UI 显示已加载 + 文件复制到正确路径，**没人真的进游戏验证 in-game 行为**。2026-06-24 复测推翻。

### 修复

**当前唯一可工作路径是 Zen byte-patch**（见 [`ZEN_BYTE_PATCH_WORKFLOW.md`](ZEN_BYTE_PATCH_WORKFLOW.md)）：从 `Extracted/IoStore/` 取 Zen 单文件原件，用 010-Editor 模板算 offset 后字节级 patch，再以 UnrealEssentials 散文件安装。`P3RDataTools.create` 的传统格式输出**不能直接给用户用**。

验证字节序：

```powershell
$bytes = [System.IO.File]::ReadAllBytes('path\to\YourAsset.uasset') | Select-Object -First 4
($bytes | ForEach-Object { $_.ToString('X2') }) -join ' '
# C1 83 2A 9E → 传统格式（必须配 .uexp，P3R 会崩）
# 00 00 00 00 → Zen 单文件（无 .uexp，正确）
```

### 自查

- [ ] P-005/P-006/P-001/P-004 都过了？
- [ ] 产物首 4 字节是 `00 00 00 00`（Zen）还是 `C1 83 2A 9E`（传统）？传统格式在 P3R 必崩
- [ ] 传统格式声称"可工作"的 case，必须给出 Reloaded II 日志 + 进入主菜单截图证据才能采信

---

## P-008: `ModConfig.json` 默认依赖统一为 `p3rpc.essentials`

### 症状

项目内 mod 的 `ModDependencies` 不一致——脚本生成填 `["UnrealEssentials"]`，手工改过的 mod 是 `["p3rpc.essentials"]`，文档多处又推荐数值 mod 用 `["UnrealEssentials"]`，三处源头打架，复盘脚本会重新覆盖回错的默认。

### 根因

之前的二分推荐"数值 mod 用 `UnrealEssentials`，体验补丁用 `p3rpc.essentials`"是纯洁癖驱动。实际上：① `p3rpc.essentials` 的运行时补丁**默认全关**（[Config.cs](https://github.com/AnimatedSwine37/p3rpc.essentials/blob/master/p3rpc.essentials/Config.cs) `[DefaultValue(false)]`），零行为副作用；② 依赖图是包含关系（`p3rpc.essentials → UnrealEssentials → UTOC.Stream.Emulator → FileEmulationFramework`），统一到 `p3rpc.essentials` 不丢任何资产替换能力；③ 仓库参考 mod [`p3rpc.ui.barionskillnames`](../tools/Reloaded%20II/Mods/p3rpc.ui.barionskillnames/) 也是 `["p3rpc.essentials"]`；④ 多一个 UI 面板的视觉成本远小于"依赖与社区主流不一致"的认知成本。

### 修复

[`modify-and-repack.ps1`](../tools/scripts/modify-and-repack.ps1) 默认 `@('p3rpc.essentials')`。需要极小化时显式覆盖 `-ModDependencies @('UnrealEssentials')`。第三方 mod（如 `p3r.qol.arkemultiplier`）**不动**，照原样描述它自己的依赖。

### 自查

- [ ] 自动生成的 `ModConfig.json` 的 `ModDependencies` 是 `["p3rpc.essentials"]`？
- [ ] 显式覆盖为 `["UnrealEssentials"]` 时，注释说明了为什么要极小化？
- [ ] 描述别人的参考 mod 时，如实写它**自己的**依赖，不被默认值"修正"？

---

## P-009: Skill 表的 `hpn` 字段是显示伤害的平方，要改 N 倍伤害得乘 N²

### 症状

用户说"把亚基伤害改成 100" → 设 `hpn=100` → 进游戏伤害只比 40 hpn 时高 ~58%（√100/√40≈1.58），不是期望的 2.5 倍。或想造"5 倍伤害"mod → 直觉设 `hpn=200`（5×40）→ 实际只有 √(200/40)≈2.24 倍。

### 根因

P3R 伤害公式形如 `displayed ≈ k × √hpn × (MAG/STR) × elementCoef × affinityCoef × …`，`hpn` 以 `√hpn` 入参，**数据表的 hpn 字段就是显示伤害的平方**。2026-06-24 AgiMod PoC 实测：Agi `hpn` 40→999，伤害约为布芙（hpn=40）的 5 倍，`√(999/40)=5.00` 精确吻合。火/冰/雷/风 weak/medium/heavy/severe 四档 hpn 序列 `40→100→220→600` 开方后线性递进（约 1.5x 等比），印证 Atlus 按"显示伤害"线性设档、数据表回写平方。这种平方表在 Atlus 系（P3F/P4G/P5）旧 tbl 就用过，P3R 继承。

### 修复

**"想要 N 倍伤害" → `new_hpn = old_hpn × N²`**；反过来，给定 new_hpn 实际体验倍数是 `√(new_hpn / old_hpn)`。

| 想要的显示伤害倍数 | hpn 乘 | 例：Agi(原 40) 新 hpn |
| -----------------: | -----: | --------------------: |
|               1.5x |  2.25x |                    90 |
|                 2x |     4x |                   160 |
|                 3x |     9x |                   360 |
|                 5x |    25x |                  1000 |
|                10x |   100x |                  4000 |

`hpn` 是 ushort（max 65535），最大放大约 `√(65535/40)=40x`。

### 范围

- ✅ 确认平方：`DatSkillNormalDataAsset` 的 `hpn`（攻击伤害类，`koukatype=2`）
- ❓ 未验证：`spn`（SP 伤害）是否同样平方？恢复类（`hptype!=0`）下是否仍平方？需按需实测
- ❌ 不适用：`DT_BtlDIfficultyParam` 等"系数表"的 float 字段是直接乘法系数，无平方关系

### 自查

- [ ] "N 倍伤害"翻译成 `new_hpn = old_hpn × N²`？
- [ ] 改完读 JSON 看 `hpn` 是否落在合理范围（与同档其它技能比较）？
- [ ] mod-script 注释写清 "old_hpn=X (≈Yx), new_hpn=Z (≈Wx)"？

---

## P-010: 含 union 的 struct 不能直接 byte-patch——必崩 `Bad name index`

### 症状

启用 Mod 后 P3R 在 UE 初始化阶段崩溃：

```
ObjectSerializationError: DatPersonaGrowthDataAsset - Bad name index 25353/21
```

### 真实案例

Sprint 1.5 T1.5.10 OrpheusGrowthMod：给 `DatPersonaGrowthDataAsset` 的 Orpheus(ID=1) 第 15 号 skill slot 写 `skillId=20(Bufu)`+`level=99`，字节变更 `0x166B` 写 2 字节、`0x1636` 写 1 字节，文件大小未变、Zen magic 正确、偏移验证通过——**游戏实测直接崩溃**。

### 根因

`SkillEventStruct` 包含 union（来自 `p3re_structs.bt`）：

```c
typedef struct {
    ubyte level;
    union {
        SkillList skillid;   // 2 bytes
        ItemList  itemid;    // 2 bytes — SAME OFFSET
    } data;
} SkillEventStruct;
```

UE 序列化 union 时内部有**类型判别字节（discriminator）**告诉反序列化器用哪个类型解析。只改了数据的 2 字节值（`skillId`），没改 discriminator → 反序列化器用错误类型查 FName 表 → `Bad name index N/M`。

这是 byte-patch 范式的硬上限：✅ flat scalar（ushort/uint/float/ubyte）值即是值，无类型歧义，安全；❌ union/struct-with-union 值带类型标签，改值不改标签 → 反序列化器混乱。

### 修复

当前无通用修复。可能路径：① 逆向 union discriminator 位置并同时 patch discriminator+value（高风险 hex 试错）；② 走完整序列化路径（生成新 `.uasset` 而非 patch 字节，完整写回器路线）；③ 换没有 union 的表实现相同效果（如改 `DatSkillDataAsset` 的 `succession` 字段走 AllInherit 思路）。

已知含 union 的表：`DatPersonaGrowthDataAsset` 的 `SkillEventStruct.skillevent[].data (SkillList | ItemList)`。

### 自查

- [ ] 目标表结构体是否含 `union { ... }` 字段？010 模板里 `typedef struct` 是否有 `union` 关键字？
- [ ] 含 union 则该 Mod 必须走完整序列化路径，不能走 byte-patch

---

## P-011: 难度参数只影响对应难度行——确认当前游戏难度再验证

### 症状

`DT_BtlDIfficultyParam.uasset` 已正确 byte-patch、路径正确，游戏内看起来没生效。

### 真实案例

Sprint 1.5 T1.5.10 ExpMod：改 `Rows.Normal.ExpRate` `1.0→100.0`，字节验证通过（`00 00 80 3F`→`00 00 C8 42`），初次反馈"100 倍经验没生效"——原因是当时游戏难度不是 `Normal`，切到 Normal 后生效 ✅。

### 根因

`p3re_DT_BtlDIfficultyParam` 是 `named_rows` 表，每行只对应一个难度：`Rows.Safety/Easy/Normal/Hard/Risky.ExpRate` 只影响对应难度。只改 `Rows.Normal.ExpRate` 不会影响其它难度。

### 修复

验证单难度 Mod 前先确认游戏当前难度。要"所有难度都改"则同时 patch 5 行：

```powershell
.\tools\scripts\modify-and-repack.ps1 -SchemaKey p3re_DT_BtlDIfficultyParam `
  -Changes @(
    @{target='Rows.Safety.ExpRate';  value=100.0},
    @{target='Rows.Easy.ExpRate';    value=100.0},
    @{target='Rows.Normal.ExpRate';  value=100.0},
    @{target='Rows.Hard.ExpRate';    value=100.0},
    @{target='Rows.Risky.ExpRate';   value=100.0}
  ) -ModName "ExpAllDifficultyMod"
```

### 自查

- [ ] 当前存档/游戏难度等于你修改的 `Rows.<Difficulty>`？
- [ ] 是否有其它 Mod 也覆盖 `DT_BtlDIfficultyParam.uasset`？
- [ ] 部署路径是 `UnrealEssentials/P3R/Content/Xrd777/Blueprints/Battle/Calculations/DT_BtlDIfficultyParam.uasset`？
- [ ] byte diff 符合预期（`1.0→100.0` 为 `00 00 80 3F → 00 00 C8 42`）？

---

> 新坑按 `P-NNN` 顺序编号，在表头目录加链接。条目模板：症状 → 根因 → 修复（带可复制代码）→ 自查清单。
