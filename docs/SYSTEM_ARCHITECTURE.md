# P3R Modding AI Agent — 系统架构设计

> **版本**: v1.2 | **日期**: 2026-06-26
>
> 本文档是项目的**架构全景与设计 rationale**：分层总览、工具调用关系、接口契约、错误处理、扩展点与技术选型理由。
>
> - 写回工作流与核心模块详解：[`ZEN_BYTE_PATCH_WORKFLOW.md`](ZEN_BYTE_PATCH_WORKFLOW.md)
> - 安全系统（四层架构 / 元数据 / 紧急恢复）：[`SECURITY.md`](SECURITY.md)
> - 标准工作流与硬规则：[`CLAUDE.md`](../CLAUDE.md)
> - schema 覆盖与 allow/deny 边界：[`SCHEMA_COVERAGE_REPORT.md`](SCHEMA_COVERAGE_REPORT.md)
>
> 主写回路径：`Extracted/IoStore` Zen 单文件 → 010 schema 算偏移 → `Invoke-ZenPatch.ps1` 字节级 in-place patch → `<Mod>/UnrealEssentials/P3R/Content/...`。传统 `P3RDataTools create` / `.uasset+.uexp` 已弃用（[P-007](MODDING_PITFALLS.md#p-007-unrealessentials-iostore-资产替换偏好-zen-单文件)）。

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
│   ┌─────────▼───────────────────────────────▼───────────────┐   │
│   │        Reloaded II + UnrealEssentials / p3rpc.essentials  │   │
│   │        Zen loose file mirror: UnrealEssentials/P3R/Content │   │
│   │        fallback: FEmulator/PAK (仅排查)                    │   │
│   └─────────┬───────────────────────────────┬───────────────┘   │
│             │                               │                   │
├─────────────┼───────────────────────────────┼───────────────────┤
│             │         编排层 (Orchestration) │                   │
│   ┌─────────▼───────────────────────────────▼───────────────┐   │
│   │                  modify-and-repack.ps1                    │   │
│   │    解析 TableKey/SchemaKey → DryRun → guard → patch → install │
│   └─────────┬───────────────────────────────┬───────────────┘   │
│             │                               │                   │
├─────────────┼───────────────────────────────┼───────────────────┤
│             │         工具层 (Tools)         │                   │
│   ┌─────────▼──────────┐  ┌─────────────────▼──────────────┐    │
│   │  search-datatable  │  │  diff-changes / DryRun preview │    │
│   │  search-wiki       │  │  backup / rollback / conflict  │    │
│   │  guard-modify      │  │  batch-modify                  │    │
│   └─────────┬──────────┘  └─────────────────┬──────────────┘    │
│             │                               │                   │
├─────────────┼───────────────────────────────┼───────────────────┤
│             │         核心层 (Core)          │                   │
│   ┌─────────▼───────────────────────────────▼───────────────┐   │
│   │  P3RDataTools.exe read/batch (CUE4Parse) + PowerShell Zen patch │
│   │                                                          │   │
│   │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │   │
│   │  │  Reader       │  │  Schema       │  │  ZenPatcher  │   │
│   │  │  IoStore→JSON │  │  010→offset   │  │  byte patch  │   │
│   │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘   │   │
│   └─────────┼──────────────────┼──────────────────┼─────────┘   │
│             │                  │                  │             │
├─────────────┼──────────────────┼──────────────────┼─────────────┤
│             │    数据层 (Data) │                  │             │
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

## 二、核心层与工具层

核心模块（Reader / Schema / ZenPatcher）的职责、CLI 命令映射与 `Invoke-ZenPatch.ps1` 的 offset 计算流程详见 [`ZEN_BYTE_PATCH_WORKFLOW.md`](ZEN_BYTE_PATCH_WORKFLOW.md) §2-§4；入口文件速查见 [`CLAUDE.md`](../CLAUDE.md) §6。本节只记录架构图层面独有的内容。

### 2.1 脚本关系图

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

### 2.2 工具输入输出规范

所有工具脚本统一输出格式：

```json
// 成功
{ "success": true, "data": { ... }, "message": "操作完成" }

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

各工具的 `data` 字段契约：

| 工具 | 输入 | 输出 (data 字段) |
|---|---|---|
| `search-datatable` | query, category? | `{ virtualPath, assetName, rowIndex, fieldPath, currentValue, wikiName }` |
| `search-wiki` | query, topic? | `{ entries: [{ title, snippet, relatedTable, relatedIds }] }` |
| `diff-changes` | beforeJson, afterJson | `{ changes: [{ table, rowIndex, wikiName, field, oldValue, newValue }] }` |
| `backup-mod` | modName, label? | `{ backupPath, timestamp, filesBackedUp }` |
| `rollback-mod` | modName | `{ deletedFiles, verified: bool }` |
| `conflict-check` | modName | `{ hasConflict, conflicts: [{ otherMod, table, overlappingRows, severity }] }` |
| `guard-modify` | modName, changes | `{ passed: bool, checks: [{ name, passed, message }] }` |

### 2.3 接口约定

```
P3RDataTools.exe read <virtualPath> [out.json]      退出码: 0=成功, 1=加载失败, 2=序列化失败
P3RDataTools.exe batch <filter> <outDir>
Invoke-ZenPatch.ps1 -InputUasset ... -OutputUasset ... -Schema ... -ChangesJson ... [-DryRun]
modify-and-repack.ps1 -TableKey/-SchemaKey/-VirtualPath + -Changes/-ChangesJson/-ModScript + -ModName [-DryRun] [-NoInstall] [-PackPak]
```

> `P3RDataTools create/modify/quick` 仍存在但输出传统 `.uasset+.uexp`，已弃用，不作为 P3R DataTable 主写回接口。

PowerShell 工具调用约定：先 `. .\Config.ps1` 加载共享变量，再 `& .\tools\<name>.ps1 -Query ... | ConvertFrom-Json`；成功输出 JSON 到 stdout，失败 `Write-Error $errorJson; exit 1`。

---

## 三、数据层结构

```
tools/Output/
├── json/                              ← 只读快照 (Git 跟踪)：Battle / UI_Tables / Community / Kernel / Dictionary / Tutorial
├── mod/<ModName>/                     ← Mod 产物 (Git 忽略)
│   ├── mod.json                       ← schemaVersion=2 元数据 / changes / assets / safety hash
│   ├── history.json                   ← 当前运行审计；长期历史保存在 .backup 中
│   ├── changes.json                   ← schemaKey + target/value 修改计划
│   └── UnrealEssentials/P3R/Content/.../<Asset>.uasset  ← Zen 单文件，无 .uexp
├── .backup/<ModName>/<timestamp_label>/  ← 时间点备份 (Git 忽略)：backup.json + 修改前 .uasset 副本
└── .data/                             ← 运行时缓存 (Git 忽略)：schema_registry.json / mod_registry.json

tools/templates-010/                   ← 010 schema 主路径 (Git 跟踪)
├── *.bt                               ← 上游 010-Editor 模板
└── schemas/*_schema.json              ← 解析/校准后的 rowSize/headerSize/fields
```

`mod.json` / `history.json` / `mod_registry.json` 的字段定义见 [`SECURITY.md`](SECURITY.md) §2。

---

## 四、错误处理架构

### 4.1 错误分级

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

### 4.2 错误传播链

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

## 五、扩展点设计

### 5.1 新增 DataTable 类型

```
1. 导入或修复对应 010 `.bt` schema → tools/templates-010/
2. 运行 Parse-BtTemplate.ps1 生成 schema JSON
3. 运行 Calibrate-SchemaHeaders.ps1 校准 headerSize
4. 运行 Test-SchemaRegression.ps1 对照 Zen bytes 与 CUE4Parse JSON
5. 只有 PASS + flat scalar 字段进入自动 allowlist；PARTIAL/FAIL/SKIP 写入 guard metadata
6. 更新 Config.ps1 $DataTables / $SchemaMap 与 DATA_MAPPING.md
```

无需修改 C# 写回模块；Zen patch 主路径由 schema + PowerShell 引擎驱动。

### 5.2 新增 Claude Code 工具 / CLI 命令

- **新工具**：编写 `tools/scripts/tools/<name>.ps1`，在 [CLAUDE.md](../CLAUDE.md) §6 入口表登记；无需改 C#。
- **新 CLI 命令**：在 `Program.cs` switch 加 case + 实现 C# 方法 + `dotnet publish`；不影响现有命令。

---

## 六、技术选型理由

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

### 6.1 不推荐的替代方案

| 方案 | 理由 |
|------|------|
| **纯 CLI (无 AI)** | 用户需要记忆虚拟路径、字段名、行索引 — 丧失目标用户群 |
| **Python + LangChain** | CUE4Parse/UAssetAPI 都是 C# 库, Python 无法直接调用; 引入 IPC 增加复杂度 |
| **Web UI + LLM API** | 需要前端开发; Claude Code 已提供完整对话界面 |
| **本地 LLM (Ollama/Llama)** | 推理质量不足以稳定处理「模糊自然语言 → 结构化查询」的映射 |
| **自建 Agent 框架** | 需自行实现 function calling、会话管理、权限控制 — Claude Code 内置全部 |

### 6.2 Claude Code 职责边界

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
