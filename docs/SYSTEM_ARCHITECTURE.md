# P3R Modding AI Agent — 系统架构设计

> **版本**: v1.0 | **日期**: 2026-06-17 | **目标**: MVP 阶段

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
│   │              Reloaded II + File Emulation Framework       │   │
│   │            P3R 官方 Mod 加载器 — PAK 注入游戏              │   │
│   │            依赖: P3R Essentials + Inaba EXE Patcher       │   │
│   └─────────┬───────────────────────────────┬───────────────┘   │
│             │                               │                   │
├─────────────┼───────────────────────────────┼───────────────────┤
│             │         编排层 (Orchestration) │                   │
│             │                               │                   │
│   ┌─────────▼───────────────────────────────▼───────────────┐   │
│   │                  modify-and-repack.ps1                    │   │
│   │              全流程编排: 读 → 改 → 预览 → 写 → 打包       │   │
│   └─────────┬───────────────────────────────┬───────────────┘   │
│             │                               │                   │
├─────────────┼───────────────────────────────┼───────────────────┤
│             │         工具层 (Tools)         │                   │
│             │                               │                   │
│   ┌─────────▼──────────┐  ┌─────────────────▼──────────────┐    │
│   │  search-datatable  │  │  diff-changes                  │    │
│   │  search-wiki       │  │  backup / rollback / conflict  │    │
│   │  guard-modify      │  │  batch-modify                  │    │
│   └─────────┬──────────┘  └─────────────────┬──────────────┘    │
│             │                               │                   │
├─────────────┼───────────────────────────────┼───────────────────┤
│             │         核心层 (Core)          │                   │
│             │                               │                   │
│   ┌─────────▼───────────────────────────────▼───────────────┐   │
│   │                    P3RDataTools.exe                       │   │
│   │                                                          │   │
│   │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │   │
│   │  │  Reader       │  │  Writer         │  │  CLI Router  │   │   │
│   │  │  (CUE4Parse)  │  │  (TemplateCreat)│  │  (Commands)  │   │   │
│   │  │  IoStore→JSON │  │  二进制序列化→pak│  │              │   │   │
│   │  └──────┬───────┘  └──────┬───────┘  └──────────────┘   │   │
│   └─────────┼──────────────────┼────────────────────────────┘   │
│             │                  │                                 │
├─────────────┼──────────────────┼─────────────────────────────────┤
│             │    数据层 (Data) │                                 │
│             │                  │                                 │
│   ┌─────────▼──────────────────▼───────────────────────────┐    │
│   │                                                          │    │
│   │  ┌──────────┐  ┌───────────┐  ┌──────────┐  ┌────────┐ │    │
│   │  │ Paks/    │  │ Output/   │  │ templates│  │ docs/  │ │    │
│   │  │ (20GB)   │  │ json/     │  │ (.uasset │  │ amicitia│ │    │
│   │  │ 只读容器  │  │ mod/      │  │ +.uexp)  │  │ (37 MD) │ │    │
│   │  │          │  │ .backup/  │  │ 模板库   │  │ 知识库   │ │    │
│   │  └──────────┘  └───────────┘  └──────────┘  └────────┘ │    │
│   └──────────────────────────────────────────────────────────┘    │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐   │
│   │              外部工具 (External Tools)                     │   │
│   │  UnrealPak.exe  │  FModel.exe (一次性)  │  Git           │   │
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
P3RDataTools.exe
│
├── Program.cs                    ← 入口: CLI 路由 + 参数解析
│
├── Reader/                        ← 读取模块 (已有)
│   ├── ProviderFactory.cs        ← DefaultFileProvider 工厂 (AES + UE4.27)
│   └── DataTableReader.cs        ← LoadAllObjects → JSON 序列化
│       ├── ReadToJson()          ← 单文件导出
│       └── BatchExport()         ← 批量导出
│
├── Writer/                        ← 写入模块 (新增)
│   ├── TemplateLoader.cs         ← 模板加载与管理
│   ├── DataTablePatcher.cs       ← 行数据替换引擎
│   └── AssetWriter.cs            ← UAssetAPI 写回 + manifest 生成
│
└── Common/                        ← 公共工具
    ├── VirtualPathResolver.cs    ← 虚拟路径 ↔ 本地路径转换
    └── JsonHelper.cs             ← JSON 深度克隆 / 路径解析 / 合并
```

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

### 2.3 `Writer/TemplateLoader.cs`（新增）

```
职责: 管理传统格式模板，根据 JSON 类型匹配对应模板

┌──────────────────────────────────────┐
│  TemplateLoader                       │
├──────────────────────────────────────┤
│ Fields:                               │
│   - _templateDir: string              │  → "tools/templates/"
│   - _index: TemplateIndex             │  → 模板索引 (从 template_index.json)
│                                       │
│ Methods:                              │
│   + LoadIndex(): void                 │  → 读取 template_index.json
│   + FindTemplate(jsonType): Template  │  → 根据 DataTable Type 字段匹配模板
│   + LoadAsset(template): UAsset       │  → UAssetAPI.UAsset.Load(path)
│   + ValidateTemplate(template): bool  │  → 检查文件头 / Export 完整性
│                                       │
│ Template (data class):                │
│   - Type: string          ← "DatSkillNormalTable"   │
│   - UassetPath: string    ← "templates/DatSkillNormalTable.uasset" │
│   - UexpPath: string      ← "templates/DatSkillNormalTable.uexp"   │
│   - AssetName: string     ← 资产内部名称                           │
│   - ExportIndex: int      ← DataTableExport 在 Export 列表中的索引 │
└──────────────────────────────────────┘

匹配逻辑:
  jsonData.Properties.Data 的每一行 { "Type": "DatSkillNormalTable", ... }
                                         ↓
  在 template_index.json 中查找 Type == "DatSkillNormalTable" 的模板
                                         ↓
  返回 Template 对象 (含 .uasset/.uexp 路径)
```

### 2.4 `Writer/DataTablePatcher.cs`（新增）

```
职责: 将修改后的 JSON 数据写回 UAsset 的 DataTableExport 中

┌──────────────────────────────────────────────────┐
│  DataTablePatcher                                 │
├──────────────────────────────────────────────────┤
│ Fields:                                           │
│   - _asset: UAsset                                │
│                                                   │
│ Methods:                                          │
│   + LoadAsset(template): void                     │
│   + PatchData(modifiedJson, originalJson): void   │
│   + ValidateRowCount(newCount, oldCount): bool    │
│                                                   │
│ Private:                                          │
│   - FindDataTableExport(): NormalExport           │
│   - ReplaceRowData(rowIndex, oldRow, newRow)      │
│   - CloneRow(templateRow): StructPropertyData     │
│   - RemoveExtraRows(count): void                  │
│   - RecalculateSize(): void                       │
└──────────────────────────────────────────────────┘

数据流:
  modified.json (JToken)
       │
       ▼
  ① LoadAsset(template.uasset)          → UAsset 对象 (NameMap + Imports + Exports)
       │
       ▼
  ② FindDataTableExport()               → NormalExport (含 DataTableExport.Table.Data)
       │                                   遍历 Exports, 找到 ExportType == "DataTable"
       ▼
  ③ 遍历 modified.Data[]                 → 对每一行:
     - 定位 Table.Data[rowIndex]
     - 遍历该行的 StructPropertyData.Properties
     - 找到 fieldPath 对应的 Property
     - 替换 Property.Value = newValue
       │
       ▼
  ④ 行数变化处理:
     - 新增: CloneRow(最后一行) → 修改值 → 追加到 Table.Data
     - 删除: RemoveAt(rowIndex) → 调整后续索引
       │
       ▼
  ⑤ RecalculateSize()                   → 更新 Export.Size + 文件头偏移
```

### 2.5 `Writer/AssetWriter.cs`（新增）

```
职责: 将修改后的 UAsset 写出为 .uasset + .uexp 文件对

┌─────────────────────────────────────┐
│  AssetWriter                         │
├─────────────────────────────────────┤
│ Methods:                             │
│   + Write(asset, outDir, name): void │
│   + GenerateManifest(outDir, name,   │
│       vPath): string                 │
│                                     │
│ 输出:                                │
│   outDir/                            │
│     ├── AssetName.uasset             │
│     ├── AssetName.uexp               │
│     └── manifest.txt                 │
│                                     │
│ 验证:                                │
│   - .uasset 文件头 = C1 83 2A 9E    │
│   - .uexp 大小 > 0                   │
│   - .uasset 能被 UAssetAPI 重新加载  │
└─────────────────────────────────────┘

manifest.txt 格式:
  "AssetName.uasset" "../../../P3R/Content/Xrd777/Battle/Tables/AssetName.uasset"
  "AssetName.uexp" "../../../P3R/Content/Xrd777/Battle/Tables/AssetName.uexp"

  挂载路径 = ../../../ + 原始虚拟路径去掉 P3R/ 前缀的相对路径
```

### 2.6 CLI 命令映射

```
P3RDataTools.exe
│
├── read    <vPath> [out.json]         ← DataTableReader.ReadToJson()
├── batch   <filter> <outDir>          ← DataTableReader.BatchExport()
├── quick   <vPath> <jPath> <val> <dir> ← ModifyAsset(isQuick=true)
├── modify  <vPath> <json>    <dir>    ← ModifyAsset(isQuick=false)
└── create  <vPath> <json>    <dir>    ← TemplateLoader + DataTablePatcher + AssetWriter
                                          ↑ 新增命令, Sprint 1 实现
```

---

## 三、工具层详细设计

### 3.1 脚本关系图

```
Config.ps1 ──────────────────────────────── 共享配置 (源)
    │
    ├── modify-and-repack.ps1 ───────────── 主编排脚本 (消费者)
    │       │
    │       ├──→ P3RDataTools.exe read ───── 读取
    │       ├──→ P3RDataTools.exe create ─── 写回
    │       ├──→ guard-modify.ps1 ───────── 安全屏障
    │       ├──→ UnrealPak.exe ───────────── 打包
    │       └──→ backup-mod.ps1 ─────────── 自动备份
    │
    ├── search-datatable.ps1 ────────────── 独立工具 (只读)
    │       └──→ DATA_MAPPING.md + Wiki MD
    │
    ├── search-wiki.ps1 ─────────────────── 独立工具 (只读)
    │       └──→ docs/amicitia/md/
    │
    ├── diff-changes.ps1 ────────────────── 独立工具 (只读)
    │       └──→ search-datatable.ps1 (ID→名称翻译)
    │
    ├── backup-mod.ps1 ──────────────────── 安全工具
    │       └──→ tools/Output/.backup/
    │
    ├── rollback-mod.ps1 ────────────────── 安全工具
    │       ├──→ backup-mod.ps1
    │       └──→ mod.json (注册表)
    │
    ├── conflict-check.ps1 ──────────────── 安全工具
    │       └──→ tools/Output/mod/*/mod.json
    │
    └── guard-modify.ps1 ────────────────── 安全屏障
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
│       ├── mod.json                   ← 元数据 (名称/描述/修改列表/时间)
│       ├── history.json               ← 操作审计
│       ├── <AssetName>.uasset         ← 写回产物
│       ├── <AssetName>.uexp           ← 批量数据
│       ├── manifest.txt               ← PAK 文件清单
│       └── <ModName>_P.pak            ← 最终 PAK (可选输出位置)
│
├── .backup/                           ← 时间点备份 (Git 忽略)
│   └── <YYYY-MM-DD_HHmm>_<label>/
│       ├── backup.json                ← 备份元数据
│       └── *_original.json            ← 修改前的原始 JSON
│
└── .data/                             ← 运行时缓存 (Git 忽略)
    ├── template_index.json            ← 模板索引 (从 tools/templates/ 生成)
    └── mod_registry.json              ← Mod 注册表 (扁平索引，加速查询)

tools/templates/                       ← 模板库 (Git 跟踪)
├── template_index.json                ← 索引: { types: { "DatSkillNormalTable": {...}, ... } }
├── DatSkillNormalTable.uasset         ← 技能数值模板
├── DatSkillNormalTable.uexp
├── DatSkillTable.uasset               ← 技能元数据模板
├── DatSkillTable.uexp
├── DatPersonaTable.uasset             ← Persona 基础模板
├── DatPersonaTable.uexp
├── ... (18 种类型, 每类一对)
```

### 4.2 mod.json 格式

```json
{
  "name": "SuperAgi",
  "version": "1.0.0",
  "description": "阿耆尼伤害增强",
  "author": "user",
  "created": "2026-06-17T14:30:00+08:00",
  "updated": "2026-06-17T14:30:00+08:00",
  "gameVersion": "1.0",
  "tables": [
    {
      "virtualPath": "P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset",
      "assetName": "DatSkillNormalDataAsset",
      "template": "DatSkillNormalTable",
      "changes": [
        {
          "rowIndex": 0,
          "wikiName": "阿耆尼 (Agi)",
          "fields": {
            "Power": { "from": 15, "to": 500 },
            "SPCost": { "from": 4, "to": 2 }
          }
        }
      ]
    }
  ],
  "pakFile": "SuperAgi_P.pak",
  "gitCommit": "a1b2c3d",
  "backupRef": ".backup/2026-06-17_1430_SuperAgi/"
}
```

### 4.3 template_index.json 格式

```json
{
  "version": "1.0",
  "created": "2026-06-17",
  "templates": {
    "DatSkillNormalTable": {
      "uasset": "tools/templates/DatSkillNormalTable.uasset",
      "uexp": "tools/templates/DatSkillNormalTable.uexp",
      "sourceAsset": "DatSkillNormalDataAsset.uasset",
      "rowCount": 435,
      "fields": ["DataID", "Power", "HPCost", "SPCost", "Element", "Target", "Accuracy", "Critical", "AttackUp", "DefenceUp", "HitUp", "AvoidUp", "AddDamage", "BadStatus", "BadStatusProbability", "Panel", "SkillSE"],
      "verified": true
    },
    "DatSkillTable": {
      "uasset": "tools/templates/DatSkillTable.uasset",
      "uexp": "tools/templates/DatSkillTable.uexp",
      "sourceAsset": "DatSkillDataAsset.uasset",
      "rowCount": 435,
      "fields": ["SkillID", "Name", "Description", "Icon", "Category", "SkillType"],
      "verified": true
    }
  }
}
```

---

## 五、数据流

### 5.1 完整请求生命周期

```
用户输入: "把阿耆尼的伤害改成 999"
────────────────────────────────────────

Phase 1: 解析 (Claude Code + 工具层)
  ┌─────────────────────────────────────────────────────────┐
  │ 1. Claude Code 理解意图                                 │
  │    实体: 阿耆尼 → 技能                                   │
  │    操作: 修改 → 数值                                     │
  │    参数: 伤害 → Power 字段, value = 999                  │
  │                                                        │
  │ 2. 调用 search-datatable.ps1 "阿耆尼" skills            │
  │    ↓                                                   │
  │    读取 DATA_MAPPING.md                                 │
  │      → 技能数值 → DatSkillNormalDataAsset               │
  │    读取 docs/amicitia/md/ 技能列表                       │
  │      → 阿耆尼 = Agi, skill ID = 0                       │
  │    读取 tools/Output/json/Battle/                        │
  │      → row[0].Power = 15                               │
  │    ↓                                                   │
  │    输出: { virtualPath: "...DatSkillNormal...",         │
  │            rowIndex: 0, fieldPath: "Data[0].Power",     │
  │            currentValue: 15 }                            │
  └─────────────────────────────────────────────────────────┘

Phase 2: 预览 (工具层)
  ┌─────────────────────────────────────────────────────────┐
  │ 3. 调用 diff-changes.ps1                                │
  │    ↓                                                   │
  │    对比 before/after JSON → 翻译 ID → 人类可读格式       │
  │    ↓                                                   │
  │    展示: "阿耆尼 (Agi, ID:0): Power: 15 → 999"         │
  │                                                        │
  │ 4. Claude Code 等待用户确认                              │
  └─────────────────────────────────────────────────────────┘

Phase 3: 执行 (编排层 + 核心层)
  ┌─────────────────────────────────────────────────────────┐
  │ [用户确认 Y]                                            │
  │                                                        │
  │ 5. 调用 guard-modify.ps1 "SuperAgi"                    │
  │    ├── 检查备份存在? ✓                                   │
  │    ├── 检查无冲突? ✓                                     │
  │    └── 检查值合法? ✓                                     │
  │                                                        │
  │ 6. 调用 backup-mod.ps1 "SuperAgi"                      │
  │    └── 复制原始 JSON → .backup/2026-06-17_1430_SuperAgi/ │
  │                                                        │
  │ 7. 调用 modify-and-repack.ps1                          │
  │    ├── P3RDataTools.exe read → skills_original.json     │
  │    ├── 克隆原始 JSON → 修改 Data[0].Power = 999         │
  │    ├── P3RDataTools.exe create →                        │
  │    │   ├── TemplateLoader.FindTemplate("DatSkillNormalTable") │
  │    │   ├── UAssetAPI.LoadAsset(template.uasset)         │
  │    │   ├── DataTablePatcher.PatchData(modifiedJson)     │
  │    │   └── AssetWriter.Write(asset, outDir, name)       │
  │    │       → DatSkillNormalDataAsset.uasset              │
  │    │       → DatSkillNormalDataAsset.uexp                │
  │    │       → manifest.txt                                │
  │    └── UnrealPak "SuperAgi_P.pak" -Create=manifest.txt  │
  └─────────────────────────────────────────────────────────┘

Phase 4: 完成
  ┌─────────────────────────────────────────────────────────┐
  │ 8. 写入 mod.json + history.json                          │
  │                                                        │
  │ 9. Claude Code 展示结果                                  │
  │    ✅ SuperAgi_P.pak (3.2 KB)                           │
  │    位置: tools/Output/mod/SuperAgi/                     │
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

  ❌ 不经过: guard-modify → backup → modify → UnrealPak
  ✅ 直接返回, 无需确认
```

---

## 六、接口定义

### 6.1 P3RDataTools CLI 接口

```
命令: read
  输入: P3RDataTools.exe read <virtualPath> [outputPath]
  输出: stdout = JSON 字符串 | 文件 = JSON 文件
  退出码: 0=成功, 1=加载失败, 2=序列化失败

命令: create
  输入: P3RDataTools.exe create <virtualPath> <modifiedJson> <outDir>
  输入文件:
    <modifiedJson>: 修改后的完整 JSON (与原始结构一致, 仅数值不同)
  输出:
    stdout = { success: true, assetName, uassetPath, uexpPath }
    stdout = { success: false, error: { code, message, suggestion } }
  输出文件:
    <outDir>/<AssetName>.uasset
    <outDir>/<AssetName>.uexp
    <outDir>/manifest.txt
  退出码: 0=成功, 1=模板未找到, 2=数据替换失败, 3=写入失败

命令: quick
  输入: P3RDataTools.exe quick <virtualPath> <jsonPath> <value> <outDir>
  行为: 自动调用 read → 修改 → create (单字段快捷方式)
  输出: 同 create
```

### 6.2 PowerShell 工具接口

```
脚本调用约定:
  . .\Config.ps1                              ← 必须先加载
  $result = & .\tools\search-datatable.ps1    ← 通过 & 调用
            -Query "阿耆尼"
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
示例: search_data_table("阿耆尼", category="skills")
      → { virtualPath: "...DatSkillNormalDataAsset.uasset", rowIndex: 0, ... }
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
│ .ps1         │     ├─ 备份存在性检查
│              │     ├─ 冲突检测 (调用 conflict-check)
│              │     └─ 值合法性检查 (范围/引用)
└──────┬───────┘
       │ 全部通过
       ▼
┌──────────────┐
│ backup-mod   │  ← 3. 创建备份
│ .ps1         │     └─ 复制原始 JSON → .backup/
└──────┬───────┘
       ▼
┌──────────────┐
│ modify +     │  ← 4. 执行修改 (见 5.1 数据流)
│ pack         │
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
│ 删除 PAK 文件    │  ← Remove-Item SuperAgi_P.pak
└────────┬────────┘
         ▼
┌─────────────────┐
│ 清理产物         │  ← Remove-Item *.uasset, *.uexp, manifest.txt
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
  ├─ 模板未找到 (需补充模板)
  ├─ 虚拟路径无效 (需确认文件名)
  ├─ JSON 格式不匹配 (需修正修改内容)
  └─ UnrealPak 打包失败

WARN    — 操作成功, 但有风险提示
  ├─ 修改值超出常见范围 (> 正常值 10 倍)
  ├─ 引用了不存在的技能 ID
  └─ 与已有 Mod 冲突 (但继续执行)

INFO    — 正常操作信息
  ├─ 读取耗时
  ├─ 打包大小
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
  1. FModel 导出该类型传统格式 .uasset+.uexp → tools/templates/
  2. 更新 template_index.json: 添加类型条目
  3. 更新 Config.ps1 $DataTables: 添加虚拟路径别名
  4. 更新 DATA_MAPPING.md: 添加该表的功能描述

无需修改任何 C# 或 PS 代码。模板加载器自动扫描 template_index.json。
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
| **写入** | UAssetAPI 1.1.0 (C#) | 唯一支持 .NET 的 UE4 Package 读写库, 模板法绕过 IoStore 限制 |
| **打包** | UnrealPak 4.27 (C++) | UE4 官方打包工具, 必须匹配游戏版本 |
| **编排** | PowerShell 5.1 | Windows 原生, 已有 Config.ps1 + modify-and-repack.ps1 基础 |
| **数据交换** | JSON (Newtonsoft.Json) | 人可读 / LLM 可解析 / diff 友好 / 无 schema 依赖 |
| **版本管理** | Git | 仓库已配置, 天然适合 mod 版本追踪 |
| **知识库** | Markdown 文件系统 | 37 个 Wiki MD 已就绪, 无需向量数据库即可被 grep/LLM 检索 |
| **模板** | 传统 .uasset+.uexp | 一次性 FModel 导出, 存储在仓库中, 不需要运行时生成 |

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
✅ 从 Wiki MD 检索游戏知识              ❌ 执行 PAK 打包 (交给 UnrealPak)
✅ 识别异常并给出修复建议                ❌ 验证 .uasset 文件格式有效性
✅ 管理多轮对话上下文                   ❌ 维护 Git 历史 (交给 git 命令)
```

**关键原则**: Claude Code 类似一个「智能 Shell」— 理解你说的话，调用正确的命令行工具，但不碰文件。它是**唯一的用户接触面** — 用户不需要知道 P3RDataTools、UAssetAPI、UnrealPak 的存在。
