# P3R Mod 制作避坑指南

> 本文档收集在 P3R Mod 制作过程中**已被踩中并修复**的具体陷阱。每个条目包含：症状、根因、修复方法、自查清单。
>
> **新踩到坑 → 修复后立即往本文档追加一条**，避免后人/AI Agent 重蹈覆辙。

---

## 目录

- [P-001: DataTable 数组索引 == 资产 ID（不要默认改 `Data[0]`）](#p-001-datatable-数组索引--资产-id不要默认改-data0)
- [P-002: 占位空 PAK 不要部署到 Reloaded II（< 1 KB 是空头）](#p-002-占位空-pak-不要部署到-reloaded-ii)
- [P-003: 直接拷 .pak 进 `Paks/` 不会生效 —— 必须走 Reloaded II](#p-003-直接拷-pak-进-paks-不会生效)

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

## 模板：添加新条目

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
