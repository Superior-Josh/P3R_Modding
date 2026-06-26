# P3R Mod 制作避坑指南

> 本文档收集在 P3R Mod 制作过程中**已被踩中并修复**的具体陷阱。每个条目包含：症状、根因、修复方法、自查清单。
>
> **新踩到坑 → 修复后立即往本文档追加一条**，避免后人/AI Agent 重蹈覆辙。
>
> **范围包含「文档/示例的事实性错误」**：凡是被用户纠正过的"我之前写错了"（虚构字段名、错误 ID、错误流程、错误命令），同样必须在这里立案——文档错误一旦被复制到 mod 脚本里就会变成 P-001/P-002 那种实际崩盘。

---

## 目录

- [P-001: DataTable 数组索引 == 资产 ID（不要默认改 `Data[0]`）](#p-001-datatable-数组索引--资产-id不要默认改-data0)
- [P-002: 占位空 PAK 不要部署到 Reloaded II（< 1 KB 是空头）](#p-002-占位空-pak-不要部署到-reloaded-ii)
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
Mod PAK 生成、打包、Reloaded II 加载都成功，**游戏内修改的目标完全无变化**（伤害/数值/耐性等）。

### 真实案例
T1.6 AgiMod 想把 Agi 火力从 15 提升到 999，脚本里写了：
```powershell
$json.Properties.Data[0].hpn = 999     # ❌ 改错了
```
PAK 部署后实测 Agi 伤害毫无变化。

### 根因
**P3R 的 `Dat*DataAsset` 表里，`Properties.Data[]` 的数组下标就是该资产的 ID**——不是按"第一个有意义的条目"排列的。其中前若干索引通常是**引擎占位/未使用槽**。

以 [`DatSkillNormalDataAsset`](../tools/Output/json/Battle/datskillnormaldataasset.json) 为例，总共 700 行：

| Array Index | Skill ID | 实际是什么 |
|---:|---:|---|
| `Data[0]` | 0 | 占位/未使用（`cost=0, targetrule=32, criticalratio=3`，**不对应任何游戏内技能**）|
| `Data[1]` – `Data[9]` | 1–9 | Wiki 标注 "未使用" |
| **`Data[10]`** | **10** | **Agi**（weak Fire ST，`hpn=40, cost=3, hitratio=99`）|
| `Data[11]` | 11 | Agilao |
| `Data[12]` | 12 | Agidyne |
| `Data[13]` | 13 | Maragi |
| … | … | …（见 [Persona_3_Reload_Skills.md](amicitia/md/Persona_3_Reload_Skills.md)） |

改 `Data[0]` 等于在改 ID 0 这个引擎占位行，游戏运行时根本不会读它来计算 Agi 伤害。

### 修复方法

**永远查 Wiki 取实际 ID，再用 ID 直接索引数组。**

```powershell
# ✅ 正确：把 ID 作为常量声明，注释里附 Wiki 出处
$AgiSkillId = 10   # docs/amicitia/md/Persona_3_Reload_Skills.md L52-54

$json = Get-Content $JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
$old = $json.Properties.Data[$AgiSkillId].hpn
$json.Properties.Data[$AgiSkillId].hpn = 999
$json | ConvertTo-Json -Depth 10 | Set-Content $JsonPath -Encoding UTF8
Write-Host "Set Data[$AgiSkillId].hpn: $old -> 999"
```

### 自查清单（Mod 验证前过一遍）

- [ ] 修改的索引 N，在 Wiki 对应表格中查到的 ID 是否同样是 N？
- [ ] 脚本日志是否打印了"old -> new"？老值是否符合预期？（Agi 的 hpn 应该是 40，不是 15；如果脚本打出 `15 -> 999` 说明改错行了）
- [ ] 改完后用 `& $DataTools read` 重读 Mod 输出的 JSON，再次确认目标 ID 的字段被改了

### 已确认遵循"index == id"的表
- ✅ `DatSkillNormalDataAsset`（700 行，技能数值）
- ✅ `DatSkillDataAsset`（1025 行，技能元数据；行 0 同样是占位）

### 未验证但很可能也遵循的表
以下表的 Wiki 都是按整数 ID 列出条目，**强烈怀疑**也是 index == id，但**首次修改时务必先验证**（读原始 JSON，对比 Wiki 的 ID 0/1/2 行特征）：
- `DatPersonaDataAsset` / `DatPersonaGrowthDataAsset` / `DatPersonaAffinityDataAsset`
- `DatEnemyDataAsset` / `DatEnemyAffinityDataAsset`
- `DatItemCommonDataAsset` / `DatItemWeaponDataAsset` / `DatItemArmorDataAsset` / `DatItemAccsDataAsset`
- `DatItemSkillcardDataAsset`

**验证方法**：取 Wiki 上某个特征鲜明的 ID（如 Persona 中的某个独特高级 Persona），打开对应 JSON 看 `Data[那个ID]` 的数值是否吻合。

---

## P-002: 占位空 PAK 不要部署到 Reloaded II

### 症状
`AgiMod_P.pak` 只有 **0.4 KB** 左右（仅 PAK header），Reloaded II 加载后游戏完全无反应。

### 根因
`UnrealPak.exe ... -Create=manifest.txt` 在找不到 manifest 里源文件时，**不会报错失败**，而是输出一个只含 header 的"空 PAK"（约 380–500 字节）。常见触发：
- manifest 里写的源路径是相对路径，但 `cd` 不在那个目录
- `.uasset` / `.uexp` 没生成成功（前面 P3RDataTools `create` 步骤 silent 失败）

### 修复方法
[`tools/scripts/modify-and-repack.ps1`](../tools/scripts/modify-and-repack.ps1#L84-L88) 已经加了大小校验：
```powershell
if ($pakSize -lt 1) {
    Write-Host "WARNING: PAK is suspiciously small ($pakSize KB) — may be empty!" -ForegroundColor Red
}
```
**任何手写 PAK 构建流程都必须加这个校验**。当看到 < 1 KB 警告时：
1. 检查 `manifest.txt` 里源路径是否绝对路径
2. 检查 `.uasset` 和 `.uexp` 是否成对存在
3. **不要** 把空 PAK 复制到 Reloaded II 目录

---

## P-003: 直接拷 .pak 进 `Paks/` 不会生效

### 症状
把 `MyMod_P.pak` 复制到 P3R 安装目录的 `P3R/Content/Paks/` 下，游戏启动后 Mod 完全不生效。

### 根因
P3R 主数据走 **IoStore**（`.utoc` + `.ucas`），它的传统 PAK 加载链与 mod PAK 的 mount 路径**不匹配**。游戏自身不读 `Content/Paks/` 下的散装 PAK。

### 修复方法
**只通过 Reloaded II + File Emulation Framework 加载**（[CLAUDE.md "Mod 安装" 章节](../CLAUDE.md)）：
```
<Reloaded-II>/Mods/<ModName>/
├── ModConfig.json     ← 需含 "SupportedAppId": ["p3r.exe"]
│                          + "ModDependencies": ["reloaded.universal.fileemulationframework.pak"]
└── FEmulator/PAK/<ModName>.pak
```
启动游戏必须通过 Reloaded II 启动器，不能 Steam/桌面快捷方式直接启动。

---

## P-004: 写文档/示例前先读真实 JSON 字段名

### 症状
跨多个文档（README / PRD / SYSTEM_ARCHITECTURE / DEVELOPER_GUIDE / 源码注释）出现编造的 DataTable 字段名：`Power`、`dmg`、`SPCost`、`HPCost`、`DataID`、`Accuracy`、`Critical` …这些字段**在真实 P3R DataTable 中根本不存在**。AI Agent / 新来的 Mod 作者照着写脚本，得到的是 `$json.Properties.Data[10].dmg = 999` —— 该字段不存在，赋值 silently 失败或新增一个无效字段，PAK 看似生成成功但游戏内毫无变化（与 [P-001](#p-001-datatable-数组索引--资产-id不要默认改-data0) 现象一致，但根因不同）。

### 真实案例
2026-06-24 在做 "biligame 译名标准化" 时，我顺手把示例数值从 `阿耆尼 / Data[0] / Power:15` 改为 `亚基 / Data[10] / dmg:40`。**索引/数值都对了**（biligame 与真实 JSON 一致），但 `dmg` 是我凭印象编造的——真实字段是 `hpn`。用户直接问："`dmg` 是什么意思，伤害字段不是 `hpn` 吗？" 翻 [datskillnormaldataasset.json](../tools/Output/json/Battle/datskillnormaldataasset.json#L268-L292) 才发现是我错。

更严重的是，[SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md) 之前那串 `"fields": ["DataID", "Power", "HPCost", "SPCost", "Element", "Target", "Accuracy", "Critical", ...]` 是更早留下的虚构 schema，被抄了一年没有人发现。

### 根因

1. **P3R DataTable 字段命名风格不直观**：用的是 Atlus 内部的 lowercase 短名（`hpn` / `spn` / `cost` / `costtype` / `hptype` / `koukatype` / `criticalratio` / `swoonratio` / `targetcntmin` / `untargetbadstat` …），而不是英文 wiki/教程里常见的 `Power` / `SPCost` / `Damage` / `Accuracy`。
2. **CUE4Parse 不会改字段名**：导出的 JSON 就是引擎里的真实键，不存在"友好别名"层。
3. **凭印象写示例 = 把虚构字段植入文档** → 后续被复制到 mod 脚本 / AI prompt → 静默失败。

### `DatSkillNormalDataAsset` 真实字段（24 项）

以 [`Data[10]` Agi 为例](../tools/Output/json/Battle/datskillnormaldataasset.json#L268-L292)：

| 字段 | 含义 | Agi 实测值 |
|---|---|---:|
| `flag` | 位标志 | 0 |
| `use` | 战斗/Out-of-battle 使用范围 | 2 |
| `koukatype` | 效果分类（攻击/恢复/辅助）| 2 |
| `costtype` | 消耗类型（0=无, 1=HP, 2=SP）| 2 |
| **`cost`** | **消耗值**（与 `costtype` 配对）| 3 |
| `costbase` | 消耗基数（百分比类）| 0 |
| `targettype` | 目标方（敌/我/全体）| 0 |
| `targetarea` | 目标范围（单体/全体/列）| 2 |
| `targetrule` | 选择规则 | 0 |
| `untargetbadstat` | 排除的异常状态 | 0 |
| `hitratio` | 命中率 | 99 |
| `targetcntmin` / `targetcntmax` | 命中目标数下/上限 | 1 / 1 |
| `hptype` | 伤害类型（固定/比例）| 1 |
| **`hpn`** | **伤害数值** ⭐ ⚠️ 见 [P-009](#p-009-skill-表的-hpn-字段是显示伤害的平方要改-n-倍伤害得乘-n²)：**显示伤害的平方**，N 倍伤害 → 乘 N² | 40 |
| `sptype` / `spn` | SP 伤害类型/数值 | 0 / 0 |
| `badtype` | 附加异常状态类型 | 0 |
| `badratio` | 异常状态触发率 | 0 |
| `badstatus` | 异常状态位 | 0 |
| `support` | 支援字段 | 0 |
| `program` | 关联脚本/特殊处理 ID | 0 |
| `criticalratio` | 暴击率 | 0 |
| `swoonratio` | 击倒率 | 0 |

**所以"把亚基伤害改成 999"的正确字段路径就是 `Properties.Data[10].hpn`**——`Power` / `dmg` / `damage` 不存在。

### 修复方法

**写任何"修改 `Data[i].FIELD`"的文档/示例/代码前，先读真实 JSON 验证**：

```powershell
# 1. 在 tools/Output/json/ 下找到目标表的 JSON
$j = Get-Content 'tools\Output\json\Battle\datskillnormaldataasset.json' -Raw -Encoding utf8 | ConvertFrom-Json

# 2. 打印目标行的所有字段
$j.Properties.Data[10] | ConvertTo-Json -Depth 4
# → 输出真实字段列表，从中挑选

# 3. 把真实字段名 + 当前值 写进文档/示例
```

**已知会触发本陷阱的伪字段（看到就替换）**：

| 伪字段 | 真实字段 | 表 |
|---|---|---|
| `Power` / `dmg` / `damage` | `hpn` | DatSkillNormalDataAsset |
| `SPCost` / `MPCost` | `cost`（配合 `costtype: 2`）| DatSkillNormalDataAsset |
| `HPCost` | `cost`（配合 `costtype: 1`）| DatSkillNormalDataAsset |
| `Accuracy` | `hitratio` | DatSkillNormalDataAsset |
| `Critical` / `CritRate` | `criticalratio` | DatSkillNormalDataAsset |
| `DataID` / `SkillID` | （没有显式 ID 字段，**数组下标即 ID**，见 [P-001](#p-001-datatable-数组索引--资产-id不要默认改-data0)）| 所有 `Dat*DataAsset` |
| `Element` | （不是单独字段——元素属性记录在 `DatSkillDataAsset` 的别处，不是 Normal 表）| — |

其他常用真实表的字段速查（首次引用前都应该 `Read` 一遍 JSON）：

- **DatEnemyDataAsset**：用 `power`（lowercase）、`hp` 等 — 见 [datenemydataasset.json](../tools/Output/json/Battle/datenemydataasset.json)
- **DatItemCommonDataAsset** / **DatItemWeaponDataAsset** 等：字段名也以 lowercase 短名为主 — 用前先 `Read` 一遍

### 自查清单（写/审文档示例前过一遍）

- [ ] 我写的字段名（如 `xxx`）在 `tools/Output/json/<对应表>.json` 里 grep 得到吗？
- [ ] 示例里的"当前值"（如 `hpn: 40`）是从真实 JSON 读出来的，不是猜的？
- [ ] 字段名是 lowercase 短名吗？（出现 PascalCase 的字段名 99% 是编造的）
- [ ] 如果改的是"伤害/SP 消耗"这种泛义概念，先确认对应字段——damage 在不同表里可能叫不同名字。

### 已修复污染点（2026-06-24）

| 文件 | 之前的伪字段 | 真实字段 |
|---|---|---|
| [CLAUDE.md:158](../CLAUDE.md) | `Data[10].dmg` | `Data[10].hpn` |
| [AGENTS.md:131](../AGENTS.md) | `Properties.Data[0].Power` | `Properties.Data[0].hpn` |
| [docs/zh-cn/README.md:28](zh-cn/README.md) | `Data[10].dmg` | `Data[10].hpn` |
| ~~docs/PRD_P3R_AI_AGENT.md~~（文件已删除） | `dmg` / `Power` / `SPCost` ×10 处 | `hpn` / `cost` |
| [docs/SYSTEM_ARCHITECTURE.md:477](SYSTEM_ARCHITECTURE.md) | `["DataID","Power","HPCost","SPCost",...]` schema | 真实 24 字段 |
| [tools/P3RDataTools/Program.cs:206](../tools/P3RDataTools/Program.cs) | `Properties.Data[0].Power` 注释 | `Properties.Data[10].hpn` |

---

## P-005: Mod 默认走 UnrealEssentials 散文件挂载，不是 FEmulator/PAK

### 症状

按 CLAUDE.md 旧版"FEmulator/PAK" 流程生成 `AgiMod_P.pak` 部署到 `Mods/AgiMod/FEmulator/PAK/AgiMod.pak`，PAK 大小（11 KB）也校验过不是空头（[P-002](#p-002-占位空-pak-不要部署到-reloaded-ii)），游戏内 Agi 仍无变化。同一仓库下两个工作中的 mod 形态完全不同：

```
p3rpc.ui.barionskillnames/                                    ← 改技能名
├── ModConfig.json                          ← ModDependencies: ["p3rpc.essentials"]
├── Sewer56.Update.Metadata.json
└── UnrealEssentials/P3R/Content/L10N/en/Xrd777/.../DatSkillNameDataAsset.uasset

p3r.qol.arkemultiplier/                                       ← 改经验倍率
├── ModConfig.json                          ← ModDependencies: ["UnrealEssentials"]
├── Sewer56.Update.Metadata.json
├── Changes.txt                             ← 作者笔记（不被加载）
├── ThumbXPQoL.PNG                          ← ModIcon
└── UnrealEssentials/P3R/Content/Xrd777/Blueprints/Battle/Calculations/DT_BtlDIfficultyParam.uasset
```

没有 PAK，没有 UnrealPak，没有 manifest。只是把 `.uasset` 按虚拟路径丢进 `UnrealEssentials/P3R/Content/...` 镜像目录。

### 真实案例

2026-06-24，用户指出："查看 `p3rpc.ui.barionskillnames` 的目录结构和文件命名，这是一个可运行修改技能名称的 mod，你生成的 mod 也应该具有类似的目录和文件格式"。同日又看了第二个参考 mod [`p3r.qol.arkemultiplier`](../tools/Reloaded II/Mods/p3r.qol.arkemultiplier/) 才把依赖项搞对（见下方"已修复污染点"）。复盘后发现：

- 项目里两个已验证可运行的 P3R mod 都走 **UnrealEssentials** 加载路径；
- 我们的工具链 [`modify-and-repack.ps1`](../tools/scripts/modify-and-repack.ps1) 和文档 [`CLAUDE.md`](../CLAUDE.md) 默认走 **FEmulator/PAK**（依赖 `reloaded.universal.fileemulationframework.pak`），这是 P3R 社区里**不常用**的备选路径，对齐工作多（mount path / manifest / PAK 元数据），且是 [P-002](#p-002-占位空-pak-不要部署到-reloaded-ii) 反复踩坑的源头。

### 根因

P3R modding 在 Reloaded II 上有两条独立挂载链：

| 维度 | UnrealEssentials ★默认 | FEmulator/PAK |
|---|---|---|
| 加载器 | `UnrealEssentials` 模块（也可经 `p3rpc.essentials` 间接引入） | `reloaded.universal.fileemulationframework.pak` |
| 注入点 | UE 4.27 的资产虚拟文件系统（`/Game/...`），同时 hook 传统格式 + IoStore 单文件格式 | 模拟传统 PAK 挂载 |
| 输入产物 | 单个 `.uasset`（IoStore 单文件格式）或 `.uasset+.uexp`（传统格式），两种都行 | 整包 `.pak` |
| 路径规则 | `<Mod>/UnrealEssentials/P3R/Content/<虚拟路径>` | `<Mod>/FEmulator/PAK/<Mod>.pak`（内部 mount = `../../../P3R/Content/...`） |
| 失败模式 | 路径写错 / `.uexp` 漏配对（仅传统格式）→ 静默不覆盖 | 空 PAK（[P-002](#p-002-占位空-pak-不要部署到-reloaded-ii)）/ mount path 错 / pak 版本不匹配 |
| 工具依赖 | 仅 P3RDataTools | P3RDataTools + UnrealPak(.exe) + manifest |

**关于 `ModDependencies` 该填哪个**：

- ✅ **首选 `"UnrealEssentials"`**（最小化、最准确；如参考 mod `p3r.qol.arkemultiplier`）
- ✅ 也可以填 `"p3rpc.essentials"`（P3R 特定 essentials 包，**依赖** UnrealEssentials；间接拉齐整条链）。注意它还会额外开启"去焦点暂停 / 跳开场 / 快速菜单"等运行时补丁面板（默认全关），数值 mod 没必要拉它——见 [`docs/P3RPC_ESSENTIALS_REFERENCE.md`](P3RPC_ESSENTIALS_REFERENCE.md)。
- ❌ 不要填 `"reloaded.universal.fileemulationframework.pak"`（那是 FEmulator/PAK 路径的依赖，不适用 UnrealEssentials）

**关于资产格式（`.uasset` 单文件 vs `.uasset+.uexp` 成对）**：

UnrealEssentials 同时支持两种 UE 4.27 资产序列化格式：

1. **IoStore 单文件 cooked 格式**（社区参考 mod 都用这种）：首字节是 `00 00 00 00 …`（FZenPackageSummary 头），把 names/imports/exports/bulk data 全部焊死在一个 `.uasset` 里。来源通常是直接从 `.utoc`/`.ucas` 提取原始 cooked 字节。
2. **传统 `.uasset+.uexp` 格式**（我们 [`P3RDataTools.create`](../tools/P3RDataTools/Program.cs) → [`TemplateCreator.cs`](../tools/P3RDataTools/TemplateCreator.cs) 重新序列化的产物）：首字节是 `C1 83 2A 9E`（UE 传统 magic），`.uasset` 是 header/索引（几 KB），`.uexp` 是导出体 + bulk data（几十～几百 KB），**必须成对**部署，名字（除后缀）一致。

两种都能让 UnrealEssentials 注入。**社区 P3R mod 99% 走 UnrealEssentials**（更简单，少一层打包，不会出现空 PAK 这种隐性失败）。

### 修复方法

[`tools/scripts/modify-and-repack.ps1`](../tools/scripts/modify-and-repack.ps1) 默认改为 UnrealEssentials 散文件挂载：

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -ModScript .\my-changes.ps1 -ModName "AgiMod"
# → tools/Reloaded II/Mods/AgiMod/
#     ├── ModConfig.json                                     (ModDependencies: ["p3rpc.essentials"])
#     └── UnrealEssentials/P3R/Content/Xrd777/Battle/Tables/
#         ├── DatSkillNormalDataAsset.uasset
#         └── DatSkillNormalDataAsset.uexp  ← 我们走传统格式，必须配对
```

仅当确实需要 PAK fallback 时才加 `-PackPak`：

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -ModName "AgiMod" -PackPak
# → 同时多写一份 <Mod>/FEmulator/PAK/AgiMod.pak
```

### 自查清单（新 mod 部署前）

- [ ] `<Mod>/UnrealEssentials/P3R/Content/<虚拟路径>` 下的文件名（不含后缀）与原资产**完全一致**？
- [ ] 如果产物是传统格式（`P3RDataTools.create` 产出），`.uasset` 和 `.uexp` 是否**成对**部署？（IoStore 单文件格式则只有一个 `.uasset`）
- [ ] `ModConfig.json` 的 `ModDependencies` 是 `["p3rpc.essentials"]`（项目默认，见 [P-008](#p-008-modconfigjson-默认依赖统一为-p3rpcessentials)）或 `["UnrealEssentials"]`，**不是** `["reloaded.universal.fileemulationframework.pak"]`？
- [ ] `ModConfig.json` 的 `SupportedAppId` 是 `["p3r.exe"]`？
- [ ] Reloaded II UI 里这个 mod 已经勾选启用？
- [ ] 已经通过 Reloaded-II.exe（不是 Steam）启动 P3R？

### 已修复污染点（2026-06-24）

| 文件 | 之前的默认/示例 | 现在 |
|---|---|---|
| [tools/scripts/modify-and-repack.ps1](../tools/scripts/modify-and-repack.ps1) | 走 UnrealPak → `<Mod>/FEmulator/PAK/<Mod>.pak`，依赖 `reloaded.universal.fileemulationframework.pak` | 默认 UnrealEssentials 散文件，依赖 `UnrealEssentials`；`-PackPak` 才同时打 PAK |
| [CLAUDE.md](../CLAUDE.md) "Mod 交付机制" + "Mod 安装" + "ModConfig.json 模板" | 只描述 FEmulator/PAK | 默认 UnrealEssentials，FEmulator/PAK 作为 fallback；deps 改为 `UnrealEssentials` |
| [tools/Reloaded II/Mods/AgiMod](../tools/Reloaded II/Mods/AgiMod) | `ModConfig.json` 6 行精简版 + `FEmulator/PAK/AgiMod.pak` | 完整 schema + `UnrealEssentials/P3R/Content/.../DatSkillNormalDataAsset.uasset(+.uexp)`，deps=`UnrealEssentials` |

---

## P-006: UE DataTable 字段名带 GUID 后缀，不可简化

### 症状

写 mod 脚本时按"友好名"赋值：
```powershell
$json.Rows.Normal.ExpRate = 2.0     # ❌ 看似生效，实际没有这个字段
```
JSON 静默新增一个无效字段，导出的 `.uasset` 里 `ExpRate` 不在 row struct schema 内，游戏运行时根本不读 → mod 看似部署成功，经验倍率毫无变化。**与 [P-004](#p-004-写文档示例前先读真实-json-字段名) 的"虚构字段名"症状一致，但根因不同**：这里字段名**真实存在**，只是 UE 在字段名后附加了 `_<序号>_<GUID>` 后缀。

### 真实案例

2026-06-24 检查参考 mod [`p3r.qol.arkemultiplier`](../tools/Reloaded II/Mods/p3r.qol.arkemultiplier/)（改 P3R 难度经验倍率），目标表 [`DT_BtlDIfficultyParam`](../tools/Output/json/Battle/dt_btldifficultyparam_original.json)。读出 JSON 看到：

```json
{
  "Rows": {
    "Normal": {
      "DamageRateToEnemy_8_E8218A1045468EDA04CAF1877EF40D95": 1.0,
      "ExpRate_10_8CBA31F0430A7FDD116509A4E1A38463": 1.0,
      "MoneyRateToMaterials_23_9F2533D24722C44FC66CDCA2316CC834": 1.0,
      ...
    }
  }
}
```

要改 Normal 难度经验从 1.0 改成 2.0，**正确路径**是：
```powershell
$json.Rows.Normal.'ExpRate_10_8CBA31F0430A7FDD116509A4E1A38463' = 2.0
```

而不是 `$json.Rows.Normal.ExpRate = 2.0`。

### 根因

P3R 的难度表 `DT_BtlDifficultyParam` 用的是 **UE 用户自定义结构体（UserDefinedStruct）`FBtlCalcParam`** 作为 row 类型。UE 4 的 UserDefinedStruct 编译时给每个字段加上 `_<声明序号>_<32 字符 GUID>` 后缀，目的：

1. **保留重命名时的数据**：用户在结构体编辑器里改字段名，UE 用 GUID 匹配老数据，不会因为名字变了就丢值。
2. **支持序列化时的版本兼容**：不同蓝图里引用同一字段时，靠 GUID 寻址而不是字符串名。

CUE4Parse 导出 JSON 时**原样保留**这些带 GUID 的真实键名（与 [P-004](#p-004-写文档示例前先读真实-json-字段名) 同理：CUE4Parse 不做"友好化"）。

**哪些表会触发**：

- ✅ **会触发**：以 `DT_` 前缀 + 使用 UserDefinedStruct 作为 row 类型的表（如 `DT_BtlDIfficultyParam` / 其它 `DT_*.uasset`）
- ❌ **不会触发**：`Dat*DataAsset` 系列（如 `DatSkillNormalDataAsset`），它们的 row 是 C++ 定义的 USTRUCT，字段名是原始 `hpn`/`cost`/`hitratio` 等 lowercase 短名（见 [P-004](#p-004)）

判别方法：在 JSON 里找字段名，如果出现形如 `<name>_<digits>_<32hex>` 就是 UserDefinedStruct。

### 修复方法

**写 mod 脚本前先 `Read` 一遍真实 JSON，把完整 key 复制粘贴过来。**

```powershell
# 1. 导出真实 JSON
& $DataTools read "P3R/Content/Xrd777/Blueprints/Battle/Calculations/DT_BtlDIfficultyParam.uasset" `
    .\dt_btldifficultyparam.json

# 2. 在 JSON 里找到目标字段的真实键（带 GUID）
#    grep -E 'ExpRate' .\dt_btldifficultyparam.json
#    → "ExpRate_10_8CBA31F0430A7FDD116509A4E1A38463": 1.0

# 3. mod 脚本里用单引号字符串包住完整键名
param([Parameter(Mandatory=$true)][string]$JsonPath)
$ExpRateKey = 'ExpRate_10_8CBA31F0430A7FDD116509A4E1A38463'

$json = Get-Content $JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($diff in 'Safety','Easy','Normal','Hard','Risky') {
    $old = $json.Rows.$diff.$ExpRateKey
    $json.Rows.$diff.$ExpRateKey = 2.0
    Write-Host "[$diff] $ExpRateKey: $old -> 2.0"
}
$json | ConvertTo-Json -Depth 10 | Set-Content $JsonPath -Encoding UTF8
```

**GUID 在同一游戏版本内是稳定的**——一旦从 IoStore 里读出来，可以放心写进 mod 脚本作为常量。但**P3R 大版本升级时 GUID 可能变**，所以脚本顶部留一行注释指明从哪个版本/路径读出来的，便于将来排错。

### 自查清单（写 `DT_*` 表 mod 前）

- [ ] 我用的字段名是否带 `_<digits>_<32hex>` 后缀？没有的话，去 JSON 里搜真实键
- [ ] 字段名是用**单引号字符串**包住的（PowerShell 里 `$obj.'key_with_special_chars'`）？双引号会触发字符串插值
- [ ] 修改后用 `& $DataTools read` 重读 mod 输出的 `.uasset`，确认目标 row 的目标 key（带 GUID）确实被改了

### 已修复污染点

| 文件 | 之前 | 现在 |
|---|---|---|
| [docs/MODDING_PITFALLS.md](MODDING_PITFALLS.md) | 没记录 GUID 后缀陷阱 | 新增 P-006 |

---

## P-007: UnrealEssentials IoStore 资产替换偏好 Zen 单文件

### 症状

新建一个 P3R mod，按 [`P-005`](#p-005-mod-默认走-unrealessentials-散文件挂载不是-femulatorpak) 的"散文件 + UnrealEssentials"流程跑完——`ModConfig.json` 依赖、`SupportedAppId`、目录结构、文件命名都对，Reloaded II UI 也勾选启用，从 Reloaded-II.exe 启动——**游戏内修改不生效**。`.uasset` 校验通过，`.uexp` 配对存在，文件名一致。

跟 P-005 / P-001 的现象一样，但前面所有自查项都过了。

### 真实案例

2026-06-24 通读 [UnrealEssentials 上游 README](https://github.com/AnimatedSwine37/UnrealEssentials) 时发现 [Adding Loose Assets](https://github.com/AnimatedSwine37/UnrealEssentials#adding-loose-assets) 一节有一段我们项目里之前从没注意过的硬性约束（原文）：

> *"Note that if your game uses UTOC files, any `.uasset` files you replace will have to come from a UTOC as the file format is different when they are in PAK files. This means that you will need to export them from Unreal Engine into an IO Store container (`.utoc` + `.ucas`) and then extract them if you want to use them loosely."*

翻译：**P3R 使用 UTOC，散文件替换的 `.uasset` 必须从 UTOC 容器里拆出来**——即所谓 **Zen 单文件**（FZenPackageSummary 头，首字节 `00 00 00 00`，**没有 `.uexp`**，exports 和 bulk data 内嵌在同一个 `.uasset` 里）。

我们项目的 [`P3RDataTools.create`](../tools/P3RDataTools/Program.cs) 经 [`TemplateCreator.cs`](../tools/P3RDataTools/TemplateCreator.cs) 序列化输出的是**传统 `.uasset+.uexp` 格式**——首字节 `C1 83 2A 9E`（UE 传统 magic），`.uasset` 几 KB header，`.uexp` 几十～几百 KB exports。

实测 [`tools/Reloaded II/Mods/AgiMod/.../DatSkillNormalDataAsset.uasset`](../tools/Reloaded%20II/Mods/AgiMod/UnrealEssentials/P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset) 首字节确实是 `C1 83 2A 9E`，配对 492 KB 的 `.uexp`。

**2026-06-24 实测结果**：启用 AgiMod 后**游戏在初始化阶段静默崩溃**（Reloaded II 日志能跑完到 `[P3R Essentials] Got Window, Hooking WndProc.`，之后没有任何输出，进程直接退出）。取消勾选 AgiMod 后游戏正常启动。**严格按上游 README 这种格式就是不该工作**——之前认为"可工作"是回归测试覆盖不足造成的误判。

### 根因

UE 4.27 在 IoStore 模式下用 **Zen 格式**（self-contained `.uasset`），在传统 PAK 模式下用 **legacy 格式**（`.uasset+.uexp` split），两者的 package summary、name table、export map 字节布局**完全不同**。

P3R 的 DataTable 来自 IoStore 容器。UnrealEssentials + UTOC.Stream.Emulator 的工作方式（从日志可见）：

```
[UtocEmulator] Created Emulated IO Store PAK with Path .../UnrealEssentials.pak   ← 339 字节
[UtocEmulator] Created Emulated Table of Contents .../UnrealEssentials.utoc       ← 473 字节
[UtocEmulator] Created Emulated Container .../UnrealEssentials.ucas               ← 1236 字节
```

UTOC.Stream.Emulator 不是把 mod 的文件**复制**进 emulated container，而是**为 mod 文件生成 IoStore-shape 的 TOC 指针**——游戏发起的资产读取请求落到这层 emulated `.utoc/.ucas`，UTOC.Stream.Emulator 把字节流**直接转发**给磁盘上的 mod 文件。

也就是说：**游戏从头到尾以为自己在反序列化 Zen 格式**，但我们的文件首字节是传统 magic `C1 83 2A 9E` → 反序列化器读到不期望的字节布局 → 越界 / 错误 cast → 进程崩溃，日志被截断。

整个链条上没有任何环节做格式自动转换：

- UTOC.Stream.Emulator：只做 TOC 元数据指针 + 字节流转发，**不解析包内容**
- UnrealEssentials：只挂 hook 把请求路由过来，**不修改字节**
- P3R 反序列化器：期望 Zen，拿到 legacy → 崩

### 关于之前的"AgiMod 验证过可工作"误判

那个"已工作"的印象来源是：编译流程跑完没报错 + Reloaded II UI 显示已加载 + `.uasset+.uexp` 被复制到了正确路径。**没有人真的进游戏验证 in-game 行为**。这次复测把这一项推翻。

### 修复方法（按风险等级递增，按需选用）

#### 方案 A：~~继续走传统 `.uasset+.uexp`~~（不可行）

**已证伪**：对 P3R 这种纯 IoStore 游戏，传统 `.uasset+.uexp` 散文件覆盖**会直接崩游戏**，不存在"DataTable 类资产例外"。本仓库当前的 `P3RDataTools.create` 输出**不能直接给用户用**——必须升级到 Zen 输出，或者用方案 B 临时绕开。

#### 方案 B：用 `utoc-extractor` 拆 Zen 原件 + 字节级 patch（短期 PoC 路径）

走完 P-005 自查仍不生效，且**确认不是 [P-006](#p-006-ue-datatable-字段名带-guid-后缀不可简化) 字段名带 GUID 的问题**，就按上游建议切到 Zen 格式：

1. 用 UnrealEssentials 自带的 `utoc-extractor`（见 [`docs/UNREAL_ESSENTIALS_REFERENCE.md` §4](UNREAL_ESSENTIALS_REFERENCE.md#4-utoc-extractor-工具随-unrealessentials-一起发布)）从 P3R 的 IoStore 容器里把**原始 Zen `.uasset`** 拆出来：

   ```powershell
   & "<UnrealEssentials 安装目录>\utoc-extractor.exe" unpack `
       "<P3R 安装>\P3R\Content\Paks\pakchunk0-WindowsNoEditor.utoc" `
       --include "P3R/Content/Xrd777/Battle/Tables/<目标资产>.uasset" `
       --override-version UE4_27 `
       --root-name "P3R" `
       --metadata table `
       -o ".\extracted-zen"
   ```

2. **生成的 `.uasset` 首字节应是 `00 00 00 00`**（FZenPackageSummary），且**没有 `.uexp`**。
3. **当前项目限制**：P3RDataTools 还没有"把 JSON 修改写回 Zen 字节"的能力——这一步需要新工具或第三方 Zen 序列化器。把这件事写进 Sprint backlog。
4. 临时手工补丁：用 010 Editor / HxD 在 Zen `.uasset` 里二进制定位字段并修改（仅对小改动可行）。

#### 方案 C：用整包 `.pak`

UnrealEssentials 也接受**整包 `.pak`** 放在 `<Mod>/UnrealEssentials/` 下（见 [`UNREAL_ESSENTIALS_REFERENCE.md` §2.1](UNREAL_ESSENTIALS_REFERENCE.md#21-整包full-packages)）。我们的 `-PackPak` 流程产出的 PAK 用这种方式部署应该也行（**未在本仓库验证过**，标记为待验证）。

### 验证字节序的方法

```powershell
# 检查首 4 字节，判定 Zen 还是传统格式
$bytes = [System.IO.File]::ReadAllBytes('path\to\YourAsset.uasset') | Select-Object -First 4
$hex = ($bytes | ForEach-Object { $_.ToString('X2') }) -join ' '
Write-Host "Magic: $hex"
# C1 83 2A 9E  → 传统格式（必须配 .uexp）
# 00 00 00 00  → Zen 单文件（无 .uexp）
```

### 自查清单（新表 mod 注入不生效时）

- [ ] P-005 / P-006 / P-001 / P-004 都过了吗？
- [ ] 用上面命令查产物首 4 字节——是 `C1 83 2A 9E`（传统）还是 `00 00 00 00`（Zen）？
- [ ] 如果是传统格式 + 注入不生效：先在该表"已验证可工作"列表（见下）里查——不在的话尝试切到 Zen 路线
- [ ] 切到 Zen 后 `.uasset` 旁是否生成了 `.uassetmeta` 或同目录有 `.utocmeta`？（UE 4.27 optional 但推荐）

### 已知"传统 `.uasset+.uexp` 形态可工作"的 P3R 表

> **2026-06-24 起：空**——`DatSkillNormalDataAsset` 之前以为"工作"是误判（见上方"关于之前的'AgiMod 验证过可工作'误判"）。在 P3RDataTools 加上 Zen 写回能力前，本表保持空。任何新声称"我的传统格式 mod 跑得起来"的 case **必须** 给出 Reloaded II 日志 + 进入主菜单的截图证据，才能加入本表。

| 表名 | 验证产物 | 验证 commit |
|---|---|---|
| _（暂无）_ | | |

### 已修复污染点

| 文件 | 之前 | 现在 |
|---|---|---|
| [CLAUDE.md "资产格式"](../CLAUDE.md) | 只列 `.uasset+.uexp` | 加 4 种产物形态对照表 + Zen 路线提示 |
| [docs/UNREAL_ESSENTIALS_REFERENCE.md](UNREAL_ESSENTIALS_REFERENCE.md) | 不存在 | 新建（§3 专门写 Zen vs 传统） |
| [docs/MODDING_PITFALLS.md](MODDING_PITFALLS.md) | 没记录 Zen 偏好 | 新增 P-007 |
| [docs/MODDING_PITFALLS.md P-007](MODDING_PITFALLS.md#p-007-unrealessentials-iostore-资产替换偏好-zen-单文件) | 把 AgiMod 标"已验证可工作" + 给出 3 条"为什么能工作"的猜测 | 2026-06-24 用户实测崩游戏；推翻"可工作"结论，删 3 条猜测，改写为"对 P3R 传统格式直接崩"，并把方案 A 标为"不可行" |

---

## P-008: `ModConfig.json` 默认依赖统一为 `p3rpc.essentials`

### 症状

项目内 mod 的 `ModDependencies` 不一致——脚本生成的填 `["UnrealEssentials"]`，[AgiMod 现状](../tools/Reloaded%20II/Mods/AgiMod/ModConfig.json) 是手工改过的 `["p3rpc.essentials"]`，文档前几轮在 [P-005](#p-005-mod-默认走-unrealessentials-散文件挂载不是-femulatorpak) / [`UNREAL_ESSENTIALS_REFERENCE.md` §6](UNREAL_ESSENTIALS_REFERENCE.md#6-依赖关系实际在本仓库里看到的依赖链) / [`P3RPC_ESSENTIALS_REFERENCE.md` §5](P3RPC_ESSENTIALS_REFERENCE.md#5-我们的-mod-应该依赖谁) 又推荐数值 mod 用 `["UnrealEssentials"]`。三处源头互相打架，复盘脚本会重新覆盖回错的默认。

### 真实案例

2026-06-24：在敲定 [P-005](#p-005-mod-默认走-unrealessentials-散文件挂载不是-femulatorpak) / [P-007](#p-007-unrealessentials-iostore-资产替换偏好-zen-单文件) / [P3RPC_ESSENTIALS_REFERENCE.md](P3RPC_ESSENTIALS_REFERENCE.md) 之后，用户最终拍板：**所有 P3R mod 默认走 `["p3rpc.essentials"]`**——而不是按"数值/资产/体验补丁"二分。

### 根因

之前的二分推荐"数值 mod 用 `UnrealEssentials`，体验补丁用 `p3rpc.essentials`"是**纯粹的洁癖驱动**（不想让数值 mod 的用户看到与之无关的体验补丁选项）——但实际上：

1. **`p3rpc.essentials` 的运行时补丁默认全关**（[`Config.cs`](https://github.com/AnimatedSwine37/p3rpc.essentials/blob/master/p3rpc.essentials/Config.cs) `[DefaultValue(false)]`/`[DefaultValue(IntroPart.None)]`），不勾选 = 零行为副作用。
2. **依赖图是包含关系**（`p3rpc.essentials → UnrealEssentials → UTOC.Stream.Emulator → FileEmulationFramework`），统一到 `p3rpc.essentials` 不会丢失任何资产替换能力。
3. **项目内已有参考 mod [`p3rpc.ui.barionskillnames`](../tools/Reloaded%20II/Mods/p3rpc.ui.barionskillnames/) 也是 `["p3rpc.essentials"]`**——跟着它走加载链一致、社区惯例一致。
4. **多依赖一个 mod 名带来的"UI 多一个面板"** 是可接受的视觉成本，远小于"我们的 mod 依赖项与社区主流不一致"的认知成本。

### 修复方法

#### a. 脚本默认值（已落地）

[`tools/scripts/modify-and-repack.ps1`](../tools/scripts/modify-and-repack.ps1) 已改：

```powershell
param(
    # ...
    [string[]]$ModDependencies = @('p3rpc.essentials'),  # 项目级默认
    # ...
)
```

需要极小化的少数场景可显式覆盖：

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills -ModName "MyMinimalMod" `
    -ModDependencies @('UnrealEssentials')
```

#### b. 所有文档说"`["UnrealEssentials"]` 是默认"的位置已对齐到 `["p3rpc.essentials"]`

- [CLAUDE.md "Mod 安装"](../CLAUDE.md) / "ModConfig.json 模板" 字段说明
- [docs/DEVELOPER_GUIDE.md "Mod 安装指南"](DEVELOPER_GUIDE.md)
- [docs/P3RPC_ESSENTIALS_REFERENCE.md §5](P3RPC_ESSENTIALS_REFERENCE.md#5-我们的-mod-应该依赖谁)
- [docs/UNREAL_ESSENTIALS_REFERENCE.md §6](UNREAL_ESSENTIALS_REFERENCE.md#6-依赖关系实际在本仓库里看到的依赖链)

#### c. 现有 mod 不强制迁移

只对"项目自己生成的 mod"和"接下来 AI Agent 生成的 mod"采纳新默认。[`p3r.qol.arkemultiplier`](../tools/Reloaded%20II/Mods/p3r.qol.arkemultiplier/) 等第三方 mod **不动**——它们就是 `["UnrealEssentials"]`，那是别人作者的选择，文档里照原样描述即可。

### 自查清单（写 / 审 mod 时）

- [ ] 自动生成的 `ModConfig.json` 的 `ModDependencies` 是 `["p3rpc.essentials"]`？
- [ ] 如果显式覆盖为 `["UnrealEssentials"]`，注释说明了为什么要极小化？
- [ ] 描述别人的（已存在的）参考 mod 时，如实写它**自己的** `ModDependencies`，不要被默认值"修正"？

### 已修复污染点

| 文件 | 之前 | 现在 |
|---|---|---|
| [tools/scripts/modify-and-repack.ps1](../tools/scripts/modify-and-repack.ps1#L17) | 硬编码 `$deps = @('"UnrealEssentials"')` | `param -ModDependencies = @('p3rpc.essentials')`，可覆盖 |
| [CLAUDE.md](../CLAUDE.md) "Mod 安装" + "ModConfig.json 模板" | `["UnrealEssentials"]` 为默认 | `["p3rpc.essentials"]` 为默认 |
| [docs/DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) | 同上 | 同上 |
| [docs/P3RPC_ESSENTIALS_REFERENCE.md §5 / §8](P3RPC_ESSENTIALS_REFERENCE.md) | 推荐数值 mod 用 `["UnrealEssentials"]` | 项目级统一默认 `["p3rpc.essentials"]` |
| [docs/UNREAL_ESSENTIALS_REFERENCE.md §6](UNREAL_ESSENTIALS_REFERENCE.md) | `["UnrealEssentials"]` 标 ★ 默认 | `["p3rpc.essentials"]` 标 ★ 默认 |
| [tools/Reloaded II/Mods/AgiMod](../tools/Reloaded%20II/Mods/AgiMod/) | 手工改过 `["p3rpc.essentials"]`（与脚本默认不一致） | 重新由更新后的脚本一键生成，与默认一致 |

---

## P-009: Skill 表的 `hpn` 字段是显示伤害的平方，要改 N 倍伤害得乘 N²

### 症状

按用户字面需求 *"把亚基伤害改成 100"* → 设 `hpn = 100` → 进游戏一看伤害只比 40 hpn 时高了 ~58%（√100/√40 ≈ 1.58），**远不是用户期望的 2.5 倍**。

或者反过来：想造一个"打布芙 5 倍伤害"的亚基 mod → 直觉设 `hpn = 200`（5 × 40）→ 实际只有 √(200/40) ≈ 2.24 倍。

### 真实案例

2026-06-24 AgiMod PoC 验证：把 Agi (Data[10]) 的 `hpn` 从 40 改成 **999**，用户实测"亚基伤害约为布芙 (Data[20], hpn=40) 的 5 倍"。

验算：`√(999/40) = √24.975 = 5.00` —— **精确吻合**。

进一步交叉验证整张 `DatSkillNormalDataAsset` 的设计意图：火/冰/雷/风同元素的 weak/medium/heavy/severe 四档攻击技能 hpn 序列都是 `40 → 100 → 220 → 600`。开方后：

| 档位 | hpn | √hpn | 相邻级差 |
|---:|---:|---:|---:|
| Weak (Agi/Bufu/...) | 40 | 6.32 | — |
| Medium (Agilao/Bufula/...) | 100 | 10.00 | ×1.58 |
| Heavy (Agidyne/Bufudyne/...) | 220 | 14.83 | ×1.48 |
| Severe (Ragnarok/Niflheim/...) | 600 | 24.49 | ×1.65 |

`√hpn` 序列是**线性递进**的（约等比 1.5x），说明 Atlus 设计师按"显示伤害"线性设档、然后在数据表里回写平方。这反过来证明 `hpn` 字段就是 `(显示伤害比例系数)²`。

### 根因

P3R 战斗伤害公式形如：

```
displayed_damage ≈ k × √hpn × (MAG/STR) × elementCoef × affinityCoef × theurgyBonus × ...
```

`hpn` 在公式里以 `√hpn` 入参，所以**数据表的 hpn 字段是显示伤害的平方**。这种"平方表"在 Atlus 系（P3F/P4G/P5）的旧 tbl 数据里就用过，P3R Reload 继承了同样的惯例。

### 修复方法

**翻译用户口语"想要 N 倍伤害"时，公式是：**

```
new_hpn = old_hpn × N²
```

或者反过来——**给定 new_hpn，用户实际体验到的伤害倍数是 √(new_hpn / old_hpn)**。

常用换算表（基于 weak attack hpn=40 这个基线）：

| 想要的显示伤害倍数 | hpn 需要乘 | 例：Agi (原 40) 的新 hpn |
|---:|---:|---:|
| 1.5x | 2.25x | 90 |
| 2x | 4x | 160 |
| 3x | 9x | 360 |
| 5x | 25x | 1000 |
| 10x | 100x | 4000 |
| "秒杀杂兵" | — | 取 9999 一类的大值，实际 ≈ 16x |

注意 `hpn` 是 ushort（最大 65535），所以最大显示伤害放大倍数约 `√(65535/40) = 40x`。

### 自查清单（改任何带 `hpn` 字段的技能时）

- [ ] 用户说的"N 倍伤害"翻译成 `new_hpn = old_hpn × N²` 了吗？
- [ ] 改完读 [`tools/Output/json/Battle/datskillnormaldataasset.json`](../tools/Output/json/Battle/datskillnormaldataasset.json) 看 `hpn` 是否落在合理范围（与同档其它技能比较）？
- [ ] 在 mod-script 注释里写清"old_hpn=X (≈ Yx 伤害), new_hpn=Z (≈ Wx 伤害)"，便于以后调整？

### 范围

- ✅ **确认遵循平方关系**：`DatSkillNormalDataAsset` 的 `hpn` 字段（攻击伤害类技能，`koukatype=2`）
- ❓ **未验证**：`spn`（SP 伤害）是否同样平方？`hpn` 在恢复类技能（`hptype != 0`）下是否仍然平方？`hptype` 不同时（百分比 / 固定）是否还是这套？需要按需实测。
- ❌ **不适用**：DT_BtlDIfficultyParam 等"系数表"的 float 字段是直接乘法系数，没有平方关系。

### 已修复污染点

| 文件 | 之前 | 现在 |
|---|---|---|
| [CLAUDE.md](../CLAUDE.md) AgiMod 例子 | 没注释 hpn → 显示伤害的关系 | 加 P-009 链接 |
| [docs/MODDING_PITFALLS.md P-004](MODDING_PITFALLS.md#p-004-写文档示例前先读真实-json-字段名) | 仅说"hpn = 伤害数值" | 加注 "hpn 是显示伤害的平方，详见 P-009" |
| [tools/Output/mod/agi-hpn-999.ps1](../tools/Output/mod/agi-hpn-999.ps1) | 注释 "set damage to 999" | 改注释 "set hpn=999 → ~5x weak fire base damage (√(999/40))" |

---

## P-010: 含 union 的 struct 不能直接 byte-patch——必崩 `Bad name index`

### 症状

启用 Mod 后 P3R 在 Unreal Engine 初始化阶段崩溃：

```
LowLevelFatalError [File:Unknown] [Line: 1609]
ObjectSerializationError: DatPersonaGrowthDataAsset - Bad name index 25353/21
```

从 Reloaded II 启动游戏，进程崩溃，弹窗"未响应"或直接退出。

### 真实案例

**2026-06-24 — Sprint 1.5 T1.5.10 OrpheusGrowthMod**

- 给 `DatPersonaGrowthDataAsset.uasset` 的 Orpheus (ID=1) 第 15 号 skill slot 写入 `skillId=20 (Bufu)` + `level=99`
- 字节变更：`0x166B` 写 2 字节（`00 00`→`14 00`）、`0x1636` 写 1 字节（`00`→`63`）
- 文件大小未变、Zen magic 正确、偏移验证通过
- **游戏实测直接崩溃**

### 根因

`SkillEventStruct` 包含一个 **union**（来自 `p3re_structs.bt`）：

```c
typedef struct {
    // ...
    ubyte level;
    // ...
    union {
        SkillList skillid;   // 2 bytes
        ItemList  itemid;    // 2 bytes — SAME OFFSET
    } data;
    // ...
} SkillEventStruct;
```

UE 序列化 union 时，内部有一个 **类型判别字节（discriminator）** 告诉反序列化器该用哪个类型去解析。我们只改了数据的 2 字节值 (`skillId`)，没有改 discriminator。反序列化器用错误的类型去查 FName 表 → `Bad name index N/M`。

这本质上是 byte-patch 范式的硬上限：
- ✅ **flat scalar**（ushort / uint / float / ubyte）— 值即是值，没有类型歧义 → 安全
- ❌ **union / struct-with-union** — 值带有类型标签，改值不改标签 → 反序列化器混乱

### 修复方法

**当前无通用修复**。可能的路径：

1. **逆向 union discriminator 位置**并同时 patch discriminator + value（高风险 hex 试错）
2. **走完整序列化路径**（生成新的 `.uasset` 而不是 patch 现有字节）——正在开发的完整写回器路线
3. **换一个没有 union 的表**去实现相同效果（例如改 `DatSkillDataAsset` 的 `succession` 字段让 Bufu 成为 Orpheus 可继承技能，走 AllInherit 思路）

### 自查清单

- [ ] 目标表的结构体中是否包含 `union { ... }` 类型字段？
- [ ] 010 模板中目标字段的 `typedef struct` 是否有 `union` 关键字？
- [ ] 如果包含 union，该 Mod 必须走完整序列化路径，不能走 byte-patch

### 影响范围

已知含 union 的表（byte-patch 不可达）：

| 表 | struct | 字段 |
|----|--------|------|
| `DatPersonaGrowthDataAsset` | `SkillEventStruct` | skillevent[].data (SkillList \| ItemList) |

| [CLAUDE.md](../CLAUDE.md) AgiMod 例子 | 没注释 hpn → 显示伤害的关系 | 加 P-009 链接 |

---

## P-011: 难度参数只影响对应难度行——确认当前游戏难度再验证

### 症状

`DT_BtlDIfficultyParam.uasset` 已正确 byte-patch，文件路径也正确，但游戏内看起来没有生效。

### 真实案例

**2026-06-24 — Sprint 1.5 T1.5.10 ExpMod**

- 生成 `ExpMod`，修改 `Rows.Normal.ExpRate`：`1.0 → 100.0`
- 字节验证通过：float `1.0` (`00 00 80 3F`) → `100.0` (`00 00 C8 42`)，仅 `0x086E` / `0x086F` 两字节变化
- 初次人工验证反馈“100 倍经验没生效”
- 最终确认原因：当时游戏难度不是 `Normal`
- 切到 Normal 后 100× EXP 生效 ✅

### 根因

`p3re_DT_BtlDIfficultyParam` 是 `named_rows` 表，每一行只对应一个难度：

| 目标 | 影响难度 |
|---|---|
| `Rows.Safety.ExpRate` | Safety |
| `Rows.Easy.ExpRate` | Easy |
| `Rows.Normal.ExpRate` | Normal |
| `Rows.Hard.ExpRate` | Hard |
| `Rows.Risky.ExpRate` | Risky |

只改 `Rows.Normal.ExpRate` 不会影响 Easy/Hard/Risky。验证时如果当前存档难度不是 Normal，会误判为 Mod 不生效。

### 修复方法

1. 验证单难度 Mod 前，先确认游戏当前难度。
2. 如果目标是“所有难度都改”，同时 patch 5 行：

```powershell
.\tools\scripts\modify-and-repack.ps1 -SchemaKey p3re_DT_BtlDIfficultyParam `
  -Changes @(
    @{target='Rows.Safety.ExpRate'; value=100.0},
    @{target='Rows.Easy.ExpRate'; value=100.0},
    @{target='Rows.Normal.ExpRate'; value=100.0},
    @{target='Rows.Hard.ExpRate'; value=100.0},
    @{target='Rows.Risky.ExpRate'; value=100.0}
  ) -ModName "ExpAllDifficultyMod"
```

### 自查清单

- [ ] 当前存档/游戏设置的难度是否等于你修改的 `Rows.<Difficulty>`？
- [ ] 是否有其它 Mod 也覆盖 `DT_BtlDIfficultyParam.uasset`？
- [ ] 部署路径是否是 `UnrealEssentials/P3R/Content/Xrd777/Blueprints/Battle/Calculations/DT_BtlDIfficultyParam.uasset`？
- [ ] byte diff 是否符合预期（例如 `1.0 → 100.0` 为 `00 00 80 3F → 00 00 C8 42`）？

---

```markdown
## P-NNN: 一句话标题

### 症状
（用户/测试观察到的现象——可观测、可复现）

### 真实案例
（哪个 Sprint/任务 / 哪个 Mod / 引用 git commit 或文件路径）

### 根因
（为什么会这样——具体到 数据/代码/工具行为）

### 修复方法
（具体步骤；最好带可复制的代码块）

### 自查清单
- [ ] ...
- [ ] ...
```

---

> 维护者：遇到新坑请在表头目录里加链接，并按 `P-NNN` 顺序编号。
