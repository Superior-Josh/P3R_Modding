# P3R Modding AI Agent — 系统架构设计

> **版本**: v1.1 | **日期**: 2026-06-25 | **目标**: MVP 阶段
>
> ## ✅ 2026-06-25 架构基线
>
> 本文档已按 Sprint 1.5 后事实更新：**传统 `P3RDataTools create` / TemplateCreator.cs / UAssetAPI 重新序列化 / 传统 `.uasset+.uexp` 模板法已降级为弃用 fallback**。该路线已被实测证伪：产物在 P3R 上启动崩游戏（详见 [`docs/MODDING_PITFALLS.md` P-007](MODDING_PITFALLS.md#p-007-unrealessentials-iostore-资产替换偏好-zen-单文件)）。
>
> **当前主写回路径**：从 [`Extracted/IoStore/`](../Extracted/) 复制 Zen 单文件原件 → 用 [godofknife/010-Editor-Templates](https://github.com/godofknife/010-Editor-Templates) 的 p3re schema 算字段偏移 → `Invoke-ZenPatch.ps1` 字节级 in-place patch → 部署到 `<Mod>/UnrealEssentials/P3R/Content/...`。
>
> **完整新工作流**：[`docs/ZEN_BYTE_PATCH_WORKFLOW.md`](ZEN_BYTE_PATCH_WORKFLOW.md)；后续 Sprint 2+ 的重点是自然语言工具、schema/field guard、备份/回滚/冲突检测，而不是恢复传统 `.uasset+.uexp` 写回。

---

## 一、架构总览

### 1.1 分层架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                        表示层 (Presentation)                     │
│                                                                 │
│   ┌─────────────────────┐    ┌─────────────────────────────┐    │
│   │   Claude Code 对话   │    │   PowerShell CLI (高级用户)  │    │
│   │   自然语言 → 工具调用  │    │   直接调用脚本，跳过 LLM     │    │
│   └─────────┬───────────┘    └──────────────┬──────────────┘    │
│             │                               │                   │
├─────────────┼───────────────────────────────┼───────────────────┤
│             │         交付层 (Delivery)      │                   │
│             │                               │                   │
│   ┌─────────▼───────────────────────────────▼───────────────┐   │
│   │        Reloaded II + UnrealEssentials / p3rpc.essentials  │   │
│   │        Zen loose file mirror: UnrealEssentials/P3R/Content │   │
│   │        fallback: FEmulator/PAK (仅排查)                    │   │
│   └─────────┬───────────────────────────────┬───────────────┘   │
│             │                               │                   │
├─────────────┼───────────────────────────────┼───────────────────┤
│             │         编排层 (Orchestration) │                   │
│             │                               │                   │
│   ┌─────────▼───────────────────────────────▼───────────────┐   │
│   │                  modify-and-repack.ps1                    │   │
│   │    解析 TableKey/SchemaKey → DryRun → guard → patch → install │
│   └─────────┬───────────────────────────────┬───────────────┘   │
│             │                               │                   │
├─────────────┼───────────────────────────────┼───────────────────┤
│             │         工具层 (Tools)         │                   │
│             │                               │                   │
│   ┌─────────▼──────────┐  ┌─────────────────▼──────────────┐    │
│   │  search-datatable  │  │  diff-changes / DryRun preview │    │
│   │  search-wiki       │  │  backup / rollback / conflict  │    │
│   │  guard-modify      │  │  batch-modify                  │    │
│   └─────────┬──────────┘  └─────────────────┬──────────────┘    │
│             │                               │                   │
├─────────────┼───────────────────────────────┼───────────────────┤
│             │         核心层 (Core)          │                   │
│             │                               │                   │
│   ┌─────────▼───────────────────────────────▼───────────────┐   │
│   │  P3RDataTools.exe read/batch (CUE4Parse) + PowerShell Zen patch │
│   │                                                          │   │
│   │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │   │
│   │  │  Reader       │  │  Schema       │  │  ZenPatcher  │   │   │
│   │  │  IoStore→JSON │  │  010→offset   │  │  byte patch  │   │   │
│   │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘   │   │
│   └─────────┼──────────────────┼──────────────────┼─────────┘   │
│             │                  │                  │             │
├─────────────┼──────────────────┼──────────────────┼─────────────┤
│             │    数据层 (Data) │                  │             │
│             │                  │                  │             │
│   ┌─────────▼──────────────────▼──────────────────▼────────┐    │
│   │  Paks/ 只读容器 │ Extracted/IoStore Zen 原件 │ templates-010 │
│   │  Output/json 缓存 │ Output/mod 产物/备份 │ docs 知识库       │
│   └──────────────────────────────────────────────────────────┘    │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐   │
│   │              外部工具 (External Tools)                     │   │
│   │  FModel.exe (浏览/提取) │ Reloaded II │ Git │ UnrealPak fallback │
│   └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 设计原则

| 原则 | 说明 |
|------|------|
| **关注点分离** | 表示层（对话/CLI）、编排层（流程）、工具层（独立脚本）、核心层（C# 引擎）、数据层（文件系统）严格分离 |
| **最小依赖** | 每层只依赖下层，不跨层调用。工具脚本互相独立，可单独调用 |
| **故障隔离** | 一个工具脚本失败不影响其他脚本。C# 引擎崩溃有独立错误码和恢复路径 |
| **降级可用** | Claude Code 不可用时，PowerShell 脚本仍可独立使用 |
| **文件即接口** | 层间通过 JSON 文件 + 标准输出传递数据，无内部 API/网络调用 |

---

## 二、核心层详细设计 (P3RDataTools)

### 2.1 模块架构

```
当前主路径（Sprint 1.5+）

P3RDataTools.exe
│
├── Program.cs                    ← CLI 路由 + 参数解析
│
├── Reader/                        ← 读取模块
│   ├── ProviderFactory.cs        ← DefaultFileProvider 工厂 (AES + UE4.27)
│   └── DataTableReader.cs        ← LoadAllObjects → JSON 序列化
│       ├── ReadToJson()          ← 单文件导出
│       └── BatchExport()         ← 批量导出
│
└── Legacy Writer/                 ← 弃用 fallback
    └── TemplateCreator.cs        ← 传统 .uasset+.uexp 输出；P3R 主路径禁用

PowerShell Zen patch layer
│
├── Parse-BtTemplate.ps1           ← 010 .bt → schema JSON
├── Calibrate-SchemaHeaders.ps1    ← headerSize 校准
├── Test-SchemaRegression.ps1      ← Zen bytes ↔ CUE4Parse JSON 回归
├── Invoke-ZenPatch.ps1            ← schema-driven byte-patch 引擎
├── dsl/P3RModDSL.psm1             ← DSL helper
└── modify-and-repack.ps1          ← TableKey/SchemaKey 解析 + patch + UnrealEssentials 部署
```

> 旧设计中的 `TemplateLoader.cs` / `DataTablePatcher.cs` / `AssetWriter.cs` 未成为主路径；如需重新研究完整资产重写，应以 IoStore/Zen-aware writer 为目标，而不是恢复传统 `.uasset+.uexp`。
### 2.2 `Reader/DataTableReader.cs`（已有，重构）

```
职责: 通过 CUE4Parse 加载 IoStore DataTable → 输出 JSON

┌─────────────────────┐
│  DataTableReader     │
├─────────────────────┤
│ + Read(vPath): JSON  │────── 输入: 虚拟路径 "P3R/Content/.../XXX.uasset"
│ + Batch(filter, dir) │────── 输出: JSON 字符串 (写文件 / stdout)
│ + GetSchema(vPath)   │────── 获取表结构元数据 (字段名 → 类型映射)
└─────────────────────┘
         │
         ▼
┌─────────────────────┐
│  ProviderFactory     │
├─────────────────────┤
│ + Create(dir, key)   │────── DefaultFileProvider (CUE4Parse)
│   .Files: 140K       │────── AES 解密 → 挂载 IoStore 容器
│   .Versions: UE4.27  │
└─────────────────────┘
```

### 2.3 `Parse-BtTemplate.ps1` / schema registry

```
职责: 把 010 `.bt` 模板转换成 Zen byte-patch 可消费的 schema

┌──────────────────────────────────────┐
│  Schema JSON                          │
├──────────────────────────────────────┤
│ Metadata:                             │
│   - schemaKey: p3re_skillNormal       │
│   - sourceAssetPath: P3R/Content/...  │
│   - tableShape: indexed_rows          │
│   - rowSize / rowCount / headerSize   │
│   - regressionStatus: PASS/PARTIAL/...│
│                                      │
│ Fields:                               │
│   - name: hpn                         │
│   - offsetInRow: 458                  │
│   - byteSize: 2                       │
│   - type: ushort                      │
│   - guardPolicy: safe / review / deny │
└──────────────────────────────────────┘

支持 tableShape:
  - indexed_rows: Data[N].field
  - named_rows: Rows.normal.ExpRate
  - single_record: bareField
  - single_record_array: Record[N].field
```

### 2.4 `Invoke-ZenPatch.ps1`

```
职责: 复制 Zen 原件并按 schema 进行定长标量 in-place patch

输入:
  - InputUasset: Extracted/IoStore/.../<Asset>.uasset
  - OutputUasset: <Mod>/UnrealEssentials/P3R/Content/.../<Asset>.uasset
  - Schema: tools/templates-010/schemas/*_schema.json
  - Changes: [{ target: "Data[10].hpn", value: 999 }]

流程:
  ① 校验 schema 状态 / tableShape / target 语法
  ② 计算 fileOffset = headerSize + rowIndex × rowSize + offsetInRow
  ③ 读取旧值并做类型/范围检查
  ④ 写入 little-endian bytes
  ⑤ 断言 output file size == input file size
  ⑥ 输出 writes[] 供 diff / history / 审计使用
```

### 2.5 `P3RModDSL.psm1`

```
职责: 把常见 Mod 意图封装成安全 changes

示例:
  Set-SkillHpn -SkillId 10 -DamageMultiplier 5.0
    → 自动读取旧 hpn=40，按 P-009 写入 40×5²=1000 附近的目标值

  Set-DifficultyParam -Difficulty normal -Field ExpRate -Value 100.0
    → Rows.normal.ExpRate = 100.0
```

### 2.6 CLI 命令映射

```
读取:
  P3RDataTools.exe read <vPath> [out.json]
  P3RDataTools.exe batch <filter> <outDir>

写回主路径:
  Invoke-ZenPatch.ps1 -InputUasset ... -OutputUasset ... -Schema ... -ChangesJson ... [-DryRun]
  modify-and-repack.ps1 -TableKey Skills -Changes @(...) -ModName MyMod [-DryRun] [-NoInstall]

弃用命令:
  P3RDataTools.exe create/modify/quick  ← 输出传统 .uasset+.uexp；不用于 P3R 主写回
```

---

## 三、工具层详细设计

### 3.1 脚本关系图

```
Config.ps1 ──────────────────────────────── 共享配置 / registry / history / snapshot helper (源)
    │
    ├── modify-and-repack.ps1 ───────────── 主编排脚本 (消费者)
    │       │
    │       ├──→ TableKey/VirtualPath/SchemaKey resolver
    │       ├──→ diff-changes.ps1 ───────── 人类可读预览 + offset
    │       ├──→ guard-modify.ps1 ───────── schema/field/value 安全屏障
    │       ├──→ conflict-check.ps1 ─────── target 冲突分级 (error/warning/info)
    │       ├──→ Git pre-mod backup ─────── 工作区干净才自动 checkpoint，脏工作区安全跳过
    │       ├──→ backup-mod.ps1 ─────────── 命名备份 / snapshot hash / backup.json
    │       ├──→ Invoke-ZenPatch.ps1 ────── Zen byte-patch 写回
    │       ├──→ post-patch guard ───────── 输出大小不变 / 禁 .uexp
    │       ├──→ UnrealEssentials install ─ 镜像到 <Mod>/UnrealEssentials/P3R/Content/...
    │       └──→ mod.json + history.json + mod_registry.json
    │
    ├── search-datatable.ps1 ────────────── 独立工具 (只读)
    │       └──→ DATA_MAPPING.md + docs/zh-cn + Wiki MD + JSON 缓存
    │
    ├── search-wiki.ps1 ─────────────────── 独立工具 (只读)
    │       └──→ docs/amicitia/md/ + docs/zh-cn/
    │
    ├── diff-changes.ps1 ────────────────── 独立工具 (只读)
    │       └──→ changes.json + schema offset + ID→名称翻译
    │
    ├── backup-mod.ps1 ──────────────────── 安全工具
    │       └──→ tools/Output/.backup/
    │
    ├── rollback-mod.ps1 ────────────────── 安全工具
    │       ├──→ backup-mod.ps1
    │       └──→ mod.json (注册表)
    │
    ├── conflict-check.ps1 ──────────────── 安全工具
    │       └──→ tools/Output/mod/*/mod.json / changes.json
    │
    └── guard-modify.ps1 ────────────────── 安全屏障
            ├──→ schema regression metadata (PASS/PARTIAL/FAIL/SKIP)
            ├──→ field-level status (safe/needsManualReview/unsupported)
            ├──→ conflict-check.ps1
            └──→ backup-mod.ps1

调用规则:
  - 工具脚本 (.ps1) 必须由 Config.ps1 加载后使用共享变量
  - 互相调用: 通过 & $PSScriptRoot\tools\<name>.ps1
  - 返回格式: JSON 字符串 (stdout) — 供 Claude Code 解析
  - 错误格式: JSON { "error": "message" } (stderr)
```

### 3.2 标准输出格式

所有工具脚本统一输出格式：

```json
// 成功
{
  "success": true,
  "data": { ... },            // 工具特定数据
  "message": "操作完成"
}

// 失败
{
  "success": false,
  "error": {
    "code": "TEMPLATE_NOT_FOUND",
    "message": "未找到类型为 DatSkillNormalTable 的模板",
    "suggestion": "请确保 tools/templates/ 目录中存在对应模板文件"
  }
}
```

### 3.3 工具输入输出规范

```
┌────────────────────┬──────────────────┬─────────────────────┐
│ 工具               │ 输入              │ 输出 (data 字段)     │
├────────────────────┼──────────────────┼─────────────────────┤
│ search-datatable   │ query (string)    │ { virtualPath,      │
│                    │ category? (enum)  │   assetName,        │
│                    │                   │   rowIndex,         │
│                    │                   │   fieldPath,        │
│                    │                   │   currentValue,     │
│                    │                   │   wikiName }        │
├────────────────────┼──────────────────┼─────────────────────┤
│ search-wiki        │ query (string)    │ { entries: [{       │
│                    │ topic? (string)   │   title,            │
│                    │                   │   snippet,          │
│                    │                   │   relatedTable,     │
│                    │                   │   relatedIds }] }   │
├────────────────────┼──────────────────┼─────────────────────┤
│ diff-changes       │ beforeJson (path) │ { changes: [{       │
│                    │ afterJson (path)  │   table,            │
│                    │                   │   rowIndex,         │
│                    │                   │   wikiName,         │
│                    │                   │   field,            │
│                    │                   │   oldValue,         │
│                    │                   │   newValue }] }     │
├────────────────────┼──────────────────┼─────────────────────┤
│ backup-mod         │ modName (string)  │ { backupPath,       │
│                    │ label? (string)   │   timestamp,        │
│                    │                   │   filesBackedUp }   │
├────────────────────┼──────────────────┼─────────────────────┤
│ rollback-mod       │ modName (string)  │ { deletedFiles,     │
│                    │                   │   verified: bool }  │
├────────────────────┼──────────────────┼─────────────────────┤
│ conflict-check     │ modName (string)  │ { hasConflict,      │
│                    │                   │   conflicts: [{     │
│                    │                   │     otherMod,       │
│                    │                   │     table,          │
│                    │                   │     overlappingRows │
│                    │                   │     severity }] }   │
├────────────────────┼──────────────────┼─────────────────────┤
│ guard-modify       │ modName (string)  │ { passed: bool,     │
│                    │ changes (array)   │   checks: [{        │
│                    │                   │     name,           │
│                    │                   │     passed,         │
│                    │                   │     message }] }    │
└────────────────────┴──────────────────┴─────────────────────┘
```

---

## 四、数据层设计

### 4.1 文件系统结构

```
tools/Output/
├── json/                              ← 只读快照 (Git 跟踪)
│   ├── Battle/     (35 files)         ← 技能 / Persona / 敌人 / 遇敌
│   ├── UI_Tables/  (161 files)        ← 道具 / 武器 / 防具 / 商店
│   ├── Community/  (276 files)        ← 社群事件
│   ├── Kernel/      (5 files)         ← 文件名映射
│   ├── Dictionary/  (2 files)         ← 游戏字典
│   └── Tutorial/   (10 files)         ← 教程文本
│
├── mod/                               ← Mod 产物 (Git 忽略)
│   └── <ModName>/
│       ├── mod.json                   ← schemaVersion=2 元数据 / changes / assets / safety hash
│       ├── history.json               ← 当前运行审计（backup + modify/rollback）；长期历史保存在 .backup 中
│       ├── changes.json               ← schemaKey + target/value 修改计划
│       └── UnrealEssentials/
│           └── P3R/
│               └── Content/
│                   └── Xrd777/...
│                       └── <AssetName>.uasset  ← Zen 单文件，无 .uexp
│
├── .backup/                           ← 时间点备份 (Git 忽略)
│   └── <ModName>/
│       └── <YYYY-MM-DD_HHmmss_label>/
│           ├── backup.json            ← 备份元数据 / snapshotHash / 文件 hash
│           ├── mod.json               ← 备份时的 Mod 元数据（如存在）
│           ├── history.json           ← 备份时的审计日志（如存在）
│           ├── changes.json           ← 当次修改计划
│           └── *.uasset               ← 修改前 Zen 产物副本（如存在）
│
└── .data/                             ← 运行时缓存 (Git 忽略)
    ├── schema_registry.json           ← Schema 状态/字段 allowlist 缓存
    └── mod_registry.json              ← Mod 注册表 (扁平索引，加速查询)

tools/templates-010/                   ← 010 schema 主路径 (Git 跟踪)
├── *.bt                               ← 上游 010-Editor 模板
└── schemas/
    ├── *_schema.json                  ← 解析/校准后的 rowSize/headerSize/fields
    ├── calibration-report.md
    └── regression-report.md

tools/templates/                       ← 传统模板库 (Git 跟踪，已弃用/fallback)
├── template_index.json
└── *.uasset + *.uexp
```

### 4.2 mod.json 格式（Sprint 3 schemaVersion=2）

```json
{
  "schemaVersion": 2,
  "modName": "SuperAgi",
  "displayName": "SuperAgi",
  "author": "claude",
  "description": "亚基伤害增强",
  "createdAt": "2026-06-25 14:30:00",
  "updatedAt": "2026-06-25 14:30:00",
  "tableKey": "Skills",
  "schemaKey": "p3re_skillNormal",
  "virtualPath": "P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset",
  "installMode": "UnrealEssentials",
  "workDir": "tools/Output/mod/SuperAgi",
  "installedDir": "tools/Reloaded II/Mods/SuperAgi",
  "changesJson": "tools/Output/mod/SuperAgi/changes.json",
  "changes": [
    {
      "target": "Data[10].hpn",
      "value": 999,
      "row": 10,
      "field": "hpn",
      "type": "ushort",
      "byteSize": 2,
      "offsetHex": "0x246A",
      "displayName": "亚基 / Agi"
    }
  ],
  "assets": [
    {
      "path": "tools/Output/mod/SuperAgi/DatSkillNormalDataAsset.uasset",
      "name": "DatSkillNormalDataAsset.uasset",
      "length": 539474,
      "sha256": "..."
    }
  ],
  "safety": {
    "beforeHash": "...",
    "afterHash": "...",
    "gitBackup": {
      "attempted": false,
      "committed": false,
      "skipped": true,
      "reason": "working tree has existing changes; refusing to auto-commit unrelated work"
    },
    "workSnapshot": [],
    "installedSnapshot": []
  }
}
```

### 4.3 schema registry 格式（运行时缓存）

```json
{
  "version": "1.0",
  "generatedFrom": "tools/templates-010/schemas/regression-report.md",
  "schemas": {
    "p3re_skillNormal": {
      "schemaPath": "tools/templates-010/schemas/p3re_skillNormal_schema.json",
      "virtualPath": "P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset",
      "status": "PASS",
      "tableShape": "indexed_rows",
      "rowSize": 769,
      "headerSize": 1174,
      "safeFields": ["hpn", "cost", "hitratio"],
      "deniedReasons": []
    }
  }
}
```

---

## 五、数据流

### 5.1 完整请求生命周期

```
用户输入: "把亚基的伤害改成 999"
────────────────────────────────────────

Phase 1: 解析 (Claude Code + 工具层)
  ┌─────────────────────────────────────────────────────────┐
  │ 1. Claude Code 理解意图                                 │
  │    实体: 亚基 → 技能                                     │
  │    操作: 修改 → 数值                                     │
  │    参数: 伤害 → hpn 字段, value = 999                    │
  │                                                        │
  │ 2. 调用 search-datatable.ps1 "亚基" skills              │
  │    ↓                                                   │
  │    读取 DATA_MAPPING.md                                 │
  │      → 技能数值 → DatSkillNormalDataAsset               │
  │    读取 docs/zh-cn/skills.md                            │
  │      → 亚基 = Agi, skill ID = 10                        │
  │    读取 tools/Output/json/Battle/                        │
  │      → Data[10].hpn = 40                               │
  │    ↓                                                   │
  │    输出: { virtualPath: "...DatSkillNormal...",         │
  │            rowIndex: 10, fieldPath: "Data[10].hpn",     │
  │            currentValue: 40 }                            │
  └─────────────────────────────────────────────────────────┘

Phase 2: 预览 (工具层)
  ┌─────────────────────────────────────────────────────────┐
  │ 3. 调用 diff-changes.ps1                                │
  │    ↓                                                   │
  │    对比 before/after JSON → 翻译 ID → 人类可读格式       │
  │    ↓                                                   │
  │    展示: "亚基 (Agi, ID:10): hpn: 40 → 999"            │
  │                                                        │
  │ 4. Claude Code 等待用户确认                              │
  └─────────────────────────────────────────────────────────┘

Phase 3: 执行 (编排层 + Zen patch 核心)
  ┌─────────────────────────────────────────────────────────┐
  │ [用户确认 Y]                                            │
  │                                                        │
  │ 5. 调用 guard-modify.ps1 "SuperAgi"                    │
  │    ├── 检查 schema=PASS / field=flat scalar ✓           │
  │    ├── 检查非 union / 非 nested / 非变长 ✓               │
  │    ├── 检查备份存在? ✓                                   │
  │    ├── 检查无冲突? ✓                                     │
  │    └── 检查值合法? ✓                                     │
  │                                                        │
  │ 6. 调用 backup-mod.ps1 "SuperAgi"                      │
  │    └── 复制当前 workdir/installed dir → .backup/<Mod>/  │
  │       写 backup.json + snapshotHash                     │
  │                                                        │
  │ 7. 调用 modify-and-repack.ps1                          │
  │    ├── 解析 TableKey=Skills → VirtualPath + SchemaKey   │
  │    ├── DryRun: Data[10].hpn @ 0x246A: 40 → 999          │
  │    ├── 复制 Extracted/IoStore 原始 Zen .uasset           │
  │    ├── Invoke-ZenPatch.ps1 写入 ushort 999              │
  │    ├── 断言 output size == original size                │
  │    └── 部署到 UnrealEssentials/P3R/Content/...          │
  └─────────────────────────────────────────────────────────┘

Phase 4: 完成
  ┌─────────────────────────────────────────────────────────┐
  │ 8. 写入 mod.json + history.json + mod_registry.json        │
  │                                                        │
  │ 9. Claude Code 展示结果                                  │
  │    ✅ SuperAgi Zen loose file Mod                         │
  │    位置: tools/Output/mod/SuperAgi/UnrealEssentials/...   │
  └─────────────────────────────────────────────────────────┘
```

### 5.2 只读查询（无副作用路径）

```
用户: "伊邪那岐的初始技能有哪些？"
────────────────────────────────────

  Claude Code (意图: 查询 Persona ID=0 的技能列表)
       │
       ├──→ search-wiki.ps1 "伊邪那岐"
       │      └──→ 返回: Persona ID=0, 技能列表在 DatPersonaGrowthDataAsset
       │
       └──→ read_datatable (从缓存 JSON 读取)
              └──→ tools/Output/json/Battle/datpersonagrowthdataasset.json
                     → row[0].SkillList = [0,1,2,3,4]
                     → 查 Wiki 翻译 ID → 名称
                     → 格式化输出

  ❌ 不经过: guard-modify → backup → modify/patch
  ✅ 直接返回, 无需确认
```

---

## 六、接口定义

### 6.1 P3RDataTools 与 Zen patch CLI 接口

```
命令: P3RDataTools read
  输入: P3RDataTools.exe read <virtualPath> [outputPath]
  输出: stdout = JSON 字符串 | 文件 = JSON 文件
  退出码: 0=成功, 1=加载失败, 2=序列化失败

命令: P3RDataTools batch
  输入: P3RDataTools.exe batch <filter> <outputDir>
  输出: DataTable JSON 缓存

命令: Invoke-ZenPatch.ps1
  输入: -InputUasset <Zen原件> -OutputUasset <目标> -Schema <schema.json> -ChangesJson <changes.json> [-DryRun]
  输入文件:
    <changes.json>: [{ target: "Data[10].hpn", value: 999 }, ...]
  输出:
    stdout = { success: true, schemaKey, writes:[{target, offset, oldValue, newValue, byteSize}] }
    stdout = { success: false, error: { code, message, suggestion } }
  输出文件:
    <OutputUasset>，大小必须等于 <InputUasset>，同目录无 .uexp
  退出码: 0=成功, 非0=schema/target/value/IO 失败

命令: modify-and-repack.ps1
  输入: -TableKey/-SchemaKey/-VirtualPath + -Changes/-ChangesJson/-ModScript + -ModName [-DryRun] [-NoInstall] [-PackPak]
  行为: 解析路径 → guard → Invoke-ZenPatch → UnrealEssentials 部署；-PackPak 仅 fallback
```

> `P3RDataTools create/modify/quick` 仍存在于 CLI 中，但输出传统 `.uasset+.uexp`，已弃用，不作为 P3R DataTable 主写回接口。
### 6.2 PowerShell 工具接口

```
脚本调用约定:
  . .\Config.ps1                              ← 必须先加载
  $result = & .\tools\search-datatable.ps1    ← 通过 & 调用
            -Query "亚基"
            -Category "skills"
  $obj = $result | ConvertFrom-Json           ← 解析 JSON 输出

输出约定:
  - 成功: Write-Output $jsonString
  - 失败: Write-Error $errorJson; exit 1
  - 始终输出 JSON (便于 Claude Code 解析)
```

### 6.3 Claude Code 工具定义接口

```
// CLAUDE.md 中的工具注册 (Markdown 格式, Claude Code 自动解析)

### search_data_table
用途: 根据中文名称定位 DataTable 文件和字段
调用: tools/scripts/tools/search-datatable.ps1 -Query <query> [-Category <category>]
参数:
  -Query    必需, 中文/日文/英文名称或描述
  -Category 可选, 限定搜索范围: skills|personas|enemies|items|weapons|armor
返回: { virtualPath, assetName, rowIndex, fieldPath, currentValue, wikiName }
示例: search_data_table("亚基", category="skills")
      → { virtualPath: "...DatSkillNormalDataAsset.uasset", rowIndex: 10, ... }
```

---

## 七、安全架构

### 7.1 安全决策点

```
每次修改请求经过以下安全决策点:

用户请求 "修改X"
      │
      ▼
┌──────────────┐    否     ┌──────────────┐
│ 是否只读操作? │─────────→│ 直接执行      │
└──────┬───────┘           │ 无需确认      │
       │是                 └──────────────┘
       ▼
┌──────────────┐
│ generate     │  ← 1. 生成 diff 预览 (展示修改内容)
│ diff preview │
└──────┬───────┘
       ▼
┌──────────────┐    否     ┌──────────────┐
│ 用户确认?     │─────────→│ 取消操作      │
└──────┬───────┘           └──────────────┘
       │是
       ▼
┌──────────────┐
│ guard-modify │  ← 2. 安全屏障
│ .ps1         │     ├─ schema 状态检查 (PASS/PARTIAL/FAIL/SKIP)
│              │     ├─ field-level 检查 (flat scalar / union / nested / 变长)
│              │     ├─ 备份存在性检查
│              │     ├─ 冲突检测 (调用 conflict-check)
│              │     └─ 值合法性检查 (范围/引用)
└──────┬───────┘
       │ 全部通过
       ▼
┌──────────────┐
│ backup-mod   │  ← 3. 创建备份
│ .ps1         │     └─ 复制原始 Zen .uasset + changes.json → .backup/
└──────┬───────┘
       ▼
┌──────────────┐
│ modify +     │  ← 4. 执行 Zen byte-patch (见 5.1 数据流)
│ install      │
└──────┬───────┘
       ▼
┌──────────────┐
│ write mod +  │  ← 5. 记录审计
│ history.json │     └─ mod.json + history.json + git commit
└──────────────┘
```

### 7.2 回滚数据流

```
rollback_mod("SuperAgi")
      │
      ▼
┌─────────────────┐
│ 查找 mod.json    │  ← 读取 tools/Output/mod/SuperAgi/mod.json
│ 展示修改内容      │
└────────┬────────┘
         ▼
    用户确认? ── 否 ──→ 取消
         │是
         ▼
┌─────────────────┐
│ 删除 Mod 目录    │  ← Remove-Item <Mod>/UnrealEssentials/... 或整个 Mod 目录
└────────┬────────┘
         ▼
┌─────────────────┐
│ 清理产物         │  ← Remove-Item Zen .uasset / changes.json / generated metadata
└────────┬────────┘
         ▼
┌─────────────────┐
│ 验证原始值       │  ← P3RDataTools read → 确认值已恢复
└────────┬────────┘
         ▼
┌─────────────────┐
│ 记录回滚事件     │  ← history.json 追加 rollback 条目
└────────┬────────┘
         ▼
       ✅ 完成
```

---

## 八、错误处理架构

### 8.1 错误分级

```
FATAL   — 系统无法继续, 需人工介入
  ├─ Paks/ 目录缺失或损坏
  ├─ AES 密钥不匹配
  └─ CUE4Parse 初始化失败

ERROR   — 操作失败, 但系统可恢复
  ├─ schema 未找到或未校准
  ├─ schema 状态为 FAIL/SKIP
  ├─ target 指向 union / nested struct array / 变长字段
  ├─ 虚拟路径无效 (需确认文件名)
  ├─ output file size mismatch
  └─ UnrealEssentials 路径/ModConfig 生成失败

WARN    — 操作成功, 但有风险提示
  ├─ 修改值超出常见范围 (> 正常值 10 倍)
  ├─ 引用了不存在的技能 ID
  ├─ schema 为 PARTIAL，需要人工复核
  └─ 与已有 Mod 冲突 (但继续执行)

INFO    — 正常操作信息
  ├─ 读取耗时
  ├─ patch offset / byteSize
  ├─ UnrealEssentials 输出路径
  └─ 备份位置
```

### 8.2 错误传播链

```
C# 层异常
  → Program.cs catch → Console.Error.WriteLine → exit code ≠ 0
    → PowerShell $LASTEXITCODE ≠ 0 → 解析 stderr → JSON error 输出
      → Claude Code 接收 JSON error → 格式化人类可读建议 → 提示用户

示例:
  C#: "TemplateNotFoundException: No template found for type 'DatUnknownTable'"
    → exit code 1
  PS: 捕获 exit 1 → { success: false, error: { code: "TEMPLATE_NOT_FOUND",
       message: "未找到类型为 DatUnknownTable 的模板",
       suggestion: "可用模板类型: DatSkillNormalTable, DatSkillTable, ..." } }
  用户看到: "❌ 找不到对应的模板。当前支持的 DataTable 类型有 18 种，请确认表类型是否正确。"
```

---

## 九、扩展点设计

### 9.1 新增 DataTable 类型

```
步骤:
  1. 导入或修复对应 010 `.bt` schema → tools/templates-010/
  2. 运行 Parse-BtTemplate.ps1 生成 schema JSON
  3. 运行 Calibrate-SchemaHeaders.ps1 校准 headerSize
  4. 运行 Test-SchemaRegression.ps1 对照 Zen bytes 与 CUE4Parse JSON
  5. 只有 PASS + flat scalar 字段进入自动 allowlist；PARTIAL/FAIL/SKIP 写入 guard metadata
  6. 更新 Config.ps1 $DataTables / $SchemaMap 与 DATA_MAPPING.md

无需修改 C# 写回模块；Zen patch 主路径由 schema + PowerShell 引擎驱动。
```

### 9.2 新增 Claude Code 工具

```
步骤:
  1. 编写 PowerShell 脚本 → tools/scripts/tools/<name>.ps1
  2. 在 CLAUDE.md 中添加工具定义 (Markdown 格式)
  3. Claude Code 重新加载后自动可用

无需修改 P3RDataTools C# 代码。工具完全独立。
```

### 9.3 新增 CLI 命令

```
步骤:
  1. 在 Program.cs switch 中添加 case
  2. 实现对应的 C# 方法 (可复用 Reader/Writer 模块)
  3. 重新编译: dotnet publish

不影响现有命令。
```

---

## 十、技术选型理由总结

| 层 | 技术 | 理由 |
|----|------|------|
| **AI** | Claude Code (Anthropic) | 原生 tool_use / 会话管理 / 权限系统 / Git 集成, 无需自己实现 Agent 框架 |
| **读取** | CUE4Parse 1.1.1 (C#) | 唯一支持 IoStore 的 .NET 库, 已验证 140K 文件挂载 |
| **写入** | Zen byte-patch + 010 schema (PowerShell) | P3R 已验证可工作；复制 IoStore Zen 原件并定长标量 in-place patch，避免传统重序列化崩溃 |
| **交付** | Reloaded II + UnrealEssentials 散文件 | 默认加载链；镜像 `<Mod>/UnrealEssentials/P3R/Content/...`，无 `.uexp` |
| **打包 fallback** | UnrealPak 4.27 / FEmulator | 仅排查或备份路径；不作为 DataTable 主交付方式 |
| **编排** | PowerShell 5.1 | Windows 原生, 已有 Config.ps1 + modify-and-repack.ps1 基础 |
| **数据交换** | JSON (Newtonsoft.Json) | 人可读 / LLM 可解析 / diff 友好 / 无 schema 依赖 |
| **版本管理** | Git | 仓库已配置, 天然适合 mod 版本追踪 |
| **知识库** | Markdown 文件系统 | 37 个 Wiki MD 已就绪, 无需向量数据库即可被 grep/LLM 检索 |
| **模板/schema** | 010 `.bt` schema + regression metadata | 提供 rowSize/headerSize/field offset；guard 按 PASS/PARTIAL/FAIL/SKIP 控制开放范围 |

### 10.1 不推荐的替代方案

| 方案 | 理由 |
|------|------|
| **纯 CLI (无 AI)** | 用户需要记忆虚拟路径、字段名、行索引 — 丧失目标用户群 |
| **Python + LangChain** | CUE4Parse/UAssetAPI 都是 C# 库, Python 无法直接调用; 引入 IPC 增加复杂度 |
| **Web UI + LLM API** | 需要前端开发; Claude Code 已提供完整对话界面 |
| **本地 LLM (Ollama/Llama)** | 推理质量不足以稳定处理「模糊自然语言 → 结构化查询」的映射 |
| **自建 Agent 框架** | 需自行实现 function calling、会话管理、权限控制 — Claude Code 内置全部 |

### 10.2 Claude Code 职责边界

```
Claude Code 负责:                     Claude Code 不负责:
─────────────────                     ──────────────────
✅ 理解模糊的自然语言                   ❌ 读取 .uasset 文件
✅ 决定调用哪些工具及顺序                ❌ 写入二进制数据
✅ 格式化输出给用户看                    ❌ 直接操作 Paks/ 目录
✅ 判断操作是否需要用户确认              ❌ 管理 AES 密钥 (内置在 P3RDataTools)
✅ 从 Wiki MD 检索游戏知识              ❌ 直接手写二进制 offset（交给 Invoke-ZenPatch）
✅ 识别异常并给出修复建议                ❌ 验证 .uasset 文件格式有效性
✅ 管理多轮对话上下文                   ❌ 维护 Git 历史 (交给 git 命令)
```

**关键原则**: Claude Code 类似一个「智能 Shell」— 理解你说的话，调用正确的命令行工具，但不碰文件。它是**唯一的用户接触面** — 用户不需要知道 P3RDataTools、UAssetAPI、UnrealPak 的存在。
