# P3R Modding AI Agent — 产品需求文档 (PRD)

> **版本**: v1.1 | **日期**: 2026-06-25 | **状态**: MVP 阶段（Sprint 1.5 后更新）
>
> **2026-06-24/25 重大路线更新**：Sprint 0/1 的传统 `.uasset+.uexp` / `P3RDataTools create` / PAK 写回路线已被 P-007 证伪，P3R 启动会崩溃。当前产品主路径是 **Zen byte-patch + UnrealEssentials 散文件部署**：从 `Extracted/IoStore` 复制 Zen 单 `.uasset` 原件，用 010 schema 计算字段 offset，`Invoke-ZenPatch.ps1` 就地字节 patch，部署到 `<Mod>/UnrealEssentials/P3R/Content/...`。PAK/FEmulator 只作为 fallback/排查路径。

---

## 一、项目概述与目标

### 1.1 项目背景

Persona 3 Reload (P3R) 是基于 Unreal Engine 4.27 的 JRPG 重制作品。当前 Mod 制作流程存在严重的技术门槛：

- 游戏资产以 IoStore 格式加密存储（.utoc/.ucas 容器），读取需要 CUE4Parse / FModel / AES 密钥
- **已验证事实**：P3R 的 DataTable 写回不能走传统 `.uasset+.uexp` 重新序列化路线；当前唯一可工作的主路径是复制 IoStore 提取出的 **Zen 单文件 `.uasset`**，按 010 schema 计算 offset 后做 in-place byte-patch，再通过 Reloaded II + UnrealEssentials 散文件加载
- 修改某个数值（如技能伤害）需要知道：游戏机制 → DataTable 文件名 → 虚拟路径 → 中文/英文 ID → JSON 字段名 → 010 schema 字段 → file offset → 合法值范围 — 整个链条对普通玩家不可见
- 现有工具分散：CUE4Parse (C#)、010-Editor 模板、PowerShell patch 脚本、Reloaded II/UnrealEssentials、FModel (GUI)，无统一自然语言入口

### 1.2 产品愿景

构建一个**自然语言驱动的 P3R Mod 制作 AI Agent**，让硬核玩家/模组爱好者只需说出想要的效果（如"把亚基的伤害改成 999"），Agent 自动完成：定位文件 → 读取当前值 → 生成差分和 DryRun offset 预览 → schema/field guard → Zen byte-patch 写回 → UnrealEssentials 散文件安装 — **全程无需手动操作**。

### 1.3 核心目标

| 目标 | 衡量指标 |
|------|---------|
| **零门槛 Mod 制作** | 用户无需了解 UE 文件格式、AES 加密、DataTable 结构 |
| **全自动闭环** | 从需求到 Reloaded II 可加载的 UnrealEssentials 散文件 Mod，全程无需 GUI 操作 |
| **安全可逆** | 每次修改可预览、可撤销、可回滚 |
| **可扩展** | 覆盖全部 15-20 种 DataTable 类型，支持多表联合修改 |

### 1.4 适用范围

- **MVP**: 数值型 DataTable 修改（技能、Persona、敌人、道具、武器、防具）
- **后续**: 文本修改、批量平衡调整、跨文件依赖追踪、模型/纹理（独立工具链）

---

## 二、目标用户画像

### 2.1 主要用户

**硬核 P3R 玩家 / Mod 爱好者**

| 属性 | 描述 |
|------|------|
| **技术水平** | 会使用命令行/终端，了解 JSON 基本概念，但不了解 UE 资产格式 |
| **游戏知识** | 熟悉 P3R 游戏机制（技能系统、Persona 合成、敌人属性等） |
| **核心诉求** | 快速修改数值验证游戏平衡性想法，创建个性化的难度调整 Mod |
| **痛点** | 现有流程需要手动操作 FModel GUI + 手动编辑 JSON + 手动打包，耗时且易出错 |
| **使用场景** | "我想试试如果把所有技能伤害翻倍会怎样"、"把伊邪那岐的初始技能改成万物流转" |

### 2.2 次要用户

**Mod 社区贡献者 / 数值策划爱好者**

| 属性 | 描述 |
|------|------|
| **技术水平** | 具备一定编程/脚本能力，了解 Git 版本控制 |
| **核心诉求** | 批量修改、版本管理、多 Mod 合并、冲突检测 |
| **使用场景** | 创建完整平衡性重制 Mod、将多个小 Mod 合并为整合包 |

### 2.3 用户故事

```
作为 P3R 玩家，我希望输入"把亚基的伤害改成 999"就能自动生成可用 Mod，
这样我无需学习 DataTable 结构、虚拟路径、PAK 打包等技术细节。

作为 Mod 作者，我希望在修改后看到清晰的差分预览（含 Wiki 名称标注），
这样我能确认我的修改是否正确、是否有遗漏。

作为 Mod 社区成员，我希望当我创建的 Mod 与其他 Mod 冲突时能收到警告，
这样我能避免游戏崩溃或不稳定的情况。
```

---

## 三、核心功能列表及优先级

### 3.1 P0 — 必须实现（MVP，预估 1-2 周）

| ID | 功能 | 描述 | 验收标准 | 状态 |
|------|------|------|------|------|
| **F1** | 数据读取引擎 | CUE4Parse 读取 IoStore DataTable → 导出 JSON | 任意虚拟路径 3 秒内返回完整 JSON | ✅ 已实现 |
| **F2** | ID 参考知识库 | Wiki ↔ 游戏文件精确映射，Amicitia Wiki ID 参考表 + biligame WIKI 中文译名（docs/zh-cn/） | 输入"亚基"可定位到 DatSkillNormalDataAsset Data[10] | ✅ 已实现 |
| **F3** | Zen byte-patch 写回引擎 | 复制 `Extracted/IoStore` Zen 原件，按 010 schema 计算 offset，`Invoke-ZenPatch.ps1` 定长标量 in-place patch | 输出 `.uasset` 大小与原件一致；无 `.uexp`；Agi/Bufu/ExpMod 实测生效 | ✅ 已实现 |
| **F4** | UnrealEssentials 散文件交付 | 自动生成 Reloaded II ModConfig.json，并把 Zen `.uasset` 镜像到 `<Mod>/UnrealEssentials/P3R/Content/...` | `modify-and-repack.ps1` 全自动流程；默认依赖 `p3rpc.essentials` 或 `UnrealEssentials` | ✅ 已实现 |
| **F5** | 自然语言查询 | LLM 理解用户意图 → 匹配 DataTable + 字段 | "把亚基伤害改成999" → 正确识别 table=Skills, ID=10, field=hpn, value=999 | 🔴 需扩展 |
| **F6** | 010 schema 库与安全状态 | `tools/templates-010/` + schema regression metadata 管理 PASS/PARTIAL/FAIL/SKIP 与字段级风险 | PASS + flat scalar 可自动写回；PARTIAL 需复核；FAIL/SKIP/union/nested/变长默认拒绝 | 🟡 已有基础，Sprint 2 guard 扩展 |

**P0 用户流程（Happy Path）:**

```
输入: "把亚基 (Agi) 的伤害从 40 改成 999"

步骤1: 查询定位
  search_data_table("亚基", category="skill")
  → virtualPath: "P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset"
  → rowIndex: 10, fieldPath: "Data[10].hpn", currentValue: 40

步骤2: 差分预览
  diff_changes(changes)
  → "亚基 (Agi, ID:10): 伤害 hpn: 40 → 999"

步骤3: 用户确认 [Y/n]

步骤4: 写回 + 安装
  guard-modify + modify-and-repack("SuperAgi", tableKey="Skills", changes=[...])
  → 生成 SuperAgi/UnrealEssentials/P3R/Content/.../DatSkillNormalDataAsset.uasset

步骤5: 完成
  ✅ "SuperAgi 已生成为 UnrealEssentials Zen 散文件 Mod，通过 Reloaded II 启动游戏即可生效"
```

### 3.2 P1 — 重要（增强体验，预估 2-3 周）

| ID | 功能 | 描述 | 验收标准 |
|------|------|------|------|
| **F7** | 人类可读差分预览 | 修改前后对比，自动标注 Wiki 名称 | 亚基 (Agi, ID:10): hpn 40→999, cost 3→1 |
| **F8** | 备份/快照系统 | 修改前自动备份原始数据，支持一键还原 | `backup create --label "before_skill_mod"` 创建可恢复快照 |
| **F9** | 回滚机制 | 移除 Reloaded II Mod 目录或 UnrealEssentials 产物，恢复原始游戏状态 | `rollback_mod("SuperAgi")` → 删除 loose `.uasset`/Mod 目录 + 原始状态确认 |
| **F10** | Mod 版本管理 | mod.json 元数据 + Git 历史追踪 | 每个 mod 有名称、描述、修改列表、时间戳、Git commit hash |
| **F11** | 冲突检测 | 检测多个 Mod 是否修改同一 DataTable 同一行 | `conflict_check("ModA")` → "与 ModB 冲突: Skills Data[10] 同时被修改" |
| **F12** | 多表 Mod 支持 | 一次修改涉及多个 DataTable | "给伊邪那岐加新技能并提升基础HP" → 同时修改 PersonaGrowth + PlayerMaxHP |

### 3.3 P2 — 增强（完善生态，预估 4+ 周）

| ID | 功能 | 描述 |
|------|------|------|
| **F13** | 语义验证引擎 | 修改后自动校验：数值范围、引用完整性（技能 ID 必须存在）、Persona ID 有效 |
| **F14** | 跨文件依赖追踪 | "修改 Persona A 的技能列表" → 自动提示哪些敌人/遇敌表引用了 A |
| **F15** | 批量平衡调整 | "将所有 BOSS 敌人 HP 翻倍" → 自动遍历 EnemyData 筛选 BOSS → 批量修改 |
| **F16** | Wiki RAG 问答 | "伊邪那岐的初始技能是什么？" → LLM 检索 Wiki MD → 回答 + 数据来源 |
| **F17** | 崩溃日志分析 | 游戏崩溃后，自动解析 UE 日志 → 定位问题 Mod → 建议修复方案 |
| **F18** | 多语言文本修改 | 提取 BMD_* 文本表 → 翻译 → 替换 → 打包 |
| **F19** | Mod 预设模板 | 常见 Mod 类型预置参数：Hard 模式、掉落率翻倍、经验倍率等 |
| **F20** | Mod 社区分享 | 导出 .zip（.pak + mod.json + README），一键分享 |

---

## 四、非功能性需求

### 4.1 性能

| 指标 | 目标 | 说明 |
|------|------|------|
| **DataTable 读取** | < 3 秒 | 单次 CUE4Parse 加载 + JSON 序列化 |
| **JSON 缓存命中** | < 100ms | 489 个文件已在 tools/Output/json/ 预导出 |
| **Mod patch** | < 2 秒 | 复制 Zen 原件 + 定长标量 byte-patch + 大小不变验证 |
| **UnrealEssentials 部署** | < 2 秒 | 生成 ModConfig.json + 镜像虚拟路径 + 写入单 `.uasset` |
| **端到端延迟** | < 15 秒 | 从用户输入到 UnrealEssentials Mod 生成完成 |
| **内存占用** | < 500MB | CUE4Parse 挂载 140K 文件索引在内存中 |

### 4.2 安全性

| 原则 | 实施方式 |
|------|---------|
| **不修改源文件** | `Paks/` 原始容器与 `Extracted/IoStore/` Zen 原件永不修改；patch 总是复制到 mod 工作目录后写入 |
| **操作可撤销** | Git 记录每次修改；mod 产物隔离到独立目录 |
| **先备份后操作** | 修改前自动创建时间点备份到 `tools/Output/.backup/` |
| **冲突主动告警** | 写入前检查 mod 注册表，发现同一行冲突即告警 |
| **操作审计** | 所有修改记录到 `history.json`（action, timestamp, beforeHash, afterHash） |

### 4.3 兼容性

| 维度 | 要求 |
|------|------|
| **UE 版本** | 4.27（pak version 11），与 P3R 严格一致 |
| **IoStore 格式** | CUE4Parse 1.1.1（不可升级，1.2.2 有 Zlib 兼容问题） |
| **传统格式** | UAssetAPI 1.1.0 / TemplateCreator 保留为弃用 fallback；传统 `.uasset+.uexp` 已证实不适合作为 P3R 主写回路径 |
| **操作系统** | Windows 10/11 x64（P3R 仅 Windows） |
| **C# 运行时** | .NET 8（自包含发布，用户无需安装运行时） |
| **AES 密钥** | 0x92BADFE2...（内置，无需用户配置） |

### 4.4 可扩展性

| 维度 | 设计 |
|------|------|
| **新增 DataTable 类型** | 添加/修复 010 `.bt` schema → 解析/校准 header → regression 标记 PASS/PARTIAL/FAIL/SKIP → Config.ps1 注册 TableKey → guard 开放安全字段 |
| **新增工具命令** | P3RDataTools 使用 switch 路由，新增 case 即可 |
| **新增 Claude Code 工具** | 添加 PowerShell 脚本 → CLAUDE.md 注册 → Agent 自动发现 |
| **自定义验证规则** | JSON Schema 或 C# ValidationAttribute，表类型可插拔 |

### 4.5 可用性

| 原则 | 实施 |
|------|------|
| **自然语言优先** | 默认通过 Claude Code 对话交互，无需记忆命令 |
| **降级到脚本** | 高级用户可直接调用 PowerShell 脚本（Claude Code 工具也可独立使用） |
| **进度可见** | 长时间操作（批量修改/打包）显示进度提示 |
| **错误友好** | 错误信息包含：原因、影响、建议修复步骤 |

---

## 五、用户流程图

### 5.1 核心流程：修改技能数值

```
┌─────────────────────────────────────────────────────────────────┐
│                      用户输入                                     │
│            "把亚基的伤害改成 999"                                   │
└──────────────┬──────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────────────┐
│  Step 1: 意图解析 (LLM)                                          │
│  ├─ 实体识别: 亚基 → 技能 Agi                                    │
│  ├─ 操作识别: 修改 → 数值                                        │
│  └─ 参数提取: 伤害=999                                           │
└──────────────┬──────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────────────┐
│  Step 2: 文件定位 (search_data_table)                             │
│  ├─ 查 DATA_MAPPING.md: 技能 → DatSkillNormalDataAsset           │
│  ├─ 查 docs/zh-cn/skills.md: 亚基 → Agi → Skill ID = 10          │
│  └─ 定位: virtualPath + rowIndex + fieldPath + currentValue       │
└──────────────┬──────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────────────┐
│  Step 3: 读取确认 (read_datatable)                                │
│  ├─ 优先从缓存 tools/Output/json/Battle/ 读取                     │
│  └─ 提取目标行: Data[10].hpn = 40 (当前值)                        │
└──────────────┬──────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────────────┐
│  Step 4: 差分预览 (diff_changes)                                  │
│  ├─ 格式化: "亚基 (Agi, ID:10): 伤害 hpn: 40 → 999"             │
│  └─ 展示给用户确认                                                │
└──────────────┬──────────────────────────────────────────────────┘
               ↓
          ┌────┴────┐
          │ 用户确认? │
          └────┬────┘
               │ ✅ 确认
               ↓
┌─────────────────────────────────────────────────────────────────┐
│  Step 5: 安全检查 + Zen byte-patch 写回                         │
│  ├─ a. guard-modify: schema 状态 / field-level 安全 / 值范围 / 冲突 │
│  ├─ b. DryRun: 计算 offset，展示 `Data[10].hpn @ 0x246A: 40→999` │
│  ├─ c. 复制 Extracted/IoStore Zen 原件到 Mod 工作目录              │
│  ├─ d. Invoke-ZenPatch.ps1 写入定长标量字节                       │
│  ├─ e. 验证 output size == original size，且同目录无 `.uexp`       │
│  └─ f. 部署到 UnrealEssentials/P3R/Content/...                    │
└──────────────┬──────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────────────┐
│  Step 6: 完成                                                     │
│  ├─ 输出: Reloaded II/Mods/SuperAgi/UnrealEssentials/P3R/Content/...│
│  ├─ 产物: DatSkillNormalDataAsset.uasset (Zen 单文件，无 .uexp)     │
│  └─ 提示: 通过 Reloaded II 启动游戏验证                             │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 回滚流程

```
用户: rollback_mod("SuperAgi")
         ↓
  ┌──────────────────────┐
  │ 1. 查找 mod 注册表    │
  │    找到 mod.json      │
  └──────┬───────────────┘
         ↓
  ┌──────────────────────┐
  │ 2. 显示 mod 信息     │
  │    "删除 SuperAgi?    │
  │     修改: Skills[10] │
  │     hpn: 40→999"     │
  └──────┬───────────────┘
         ↓
    用户确认? ── 否 ──→ 取消
         │
         ↓ 是
  ┌──────────────────────┐
  │ 3. 移除 UnrealEssentials 产物 │
  │    删除 loose .uasset/Mod目录  │
  └──────┬───────────────┘
         ↓
  ┌──────────────────────┐
  │ 4. 清理 mod 产物     │
  │    删除 changes/日志/备份索引 │
  └──────┬───────────────┘
         ↓
  ┌──────────────────────┐
  │ 5. 验证恢复           │
  │    P3RDataTools read  │
  │    → Data[10].hpn=40  │
  └──────┬───────────────┘
         ↓
  ✅ "SuperAgi 已回滚，原始数据已确认恢复"
```

### 5.3 冲突检测流程

```
用户: conflict_check("HarderBosses")
         ↓
  ┌─────────────────────────────────────┐
  │ 1. 读取 HarderBosses 的 mod.json     │
  │    tables: [DatEnemyDataAsset]       │
  │    rows: [0, 1, 2, 3]               │
  └──────┬──────────────────────────────┘
         ↓
  ┌─────────────────────────────────────┐
  │ 2. 遍历所有已安装 mod 的 mod.json   │
  │    ● DoubleLoot (DatItemCommon)     │
  │    ● EasyMode (DatEnemyData) ⚠️     │
  └──────┬──────────────────────────────┘
         ↓
  ┌─────────────────────────────────────┐
  │ 3. 对比重叠行                        │
  │    EasyMode 也修改了 DatEnemyData    │
  │    重叠: row[1], row[3]  ⚠️         │
  └──────┬──────────────────────────────┘
         ↓
  ⚠️ "冲突检测: HarderBosses 与 EasyMode
      在 DatEnemyData 有 2 行重叠:
      - row[1] (亚巴顿)
      - row[3] (力之百臂巨人)
      后加载的 mod 将覆盖先加载的修改"
```

---

## 六、验收标准

### 6.1 Phase 1 验收 (Zen byte-patch 写回引擎)

| # | 测试项 | 预期结果 | 验证方法 |
|---|--------|---------|---------|
| V1 | IoStore 读取 | `P3RDataTools read "DatSkillNormalDataAsset"` → 返回完整 JSON | CLI 输出验证 |
| V2 | schema 回归 | 010 schema 可解析/校准，PASS/PARTIAL/FAIL/SKIP 状态明确 | `Test-SchemaRegression.ps1` 报告 |
| V3 | 数值修改写回 | 修改 Skills `Data[10].hpn=999` → output `.uasset` 大小与原 Zen 一致，无 `.uexp` | byte diff + 文件大小断言 |
| V4 | DryRun offset | `Data[10].hpn` 计算到 `0x246A`，旧值 40，新值 999 | 自动化断言 |
| V5 | UnrealEssentials 部署 | 文件镜像到 `<Mod>/UnrealEssentials/P3R/Content/...`，ModConfig 支持 `p3r.exe` | 文件存在性 + 配置检查 |
| V6 | 游戏加载 | Agi/Bufu/ExpMod 类 smoke test 游戏内生效 | 手动验证 |

### 6.2 Phase 2 验收 (工具集成)

| # | 测试项 | 预期结果 | 验证方法 |
|---|--------|---------|---------|
| V6 | search_data_table | "亚基" → 返回 {virtualPath, rowIndex:10, fieldPath:"Data[10].hpn", currentValue:40} | 自动化测试 |
| V7 | diff_changes | 修改前后对比输出含 Wiki 名称标注 | 输出格式匹配 |
| V8 | build_mod | 输入 modName + 修改 → 生成 UnrealEssentials Zen 散文件 Mod | 端到端流程 |
| V8b | unsafe guard | FAIL/SKIP/union/nested/变长字段请求 → 拒绝自动写回并说明原因 | 针对性测试 |

### 6.3 Phase 3 验收 (安全系统)

| # | 测试项 | 预期结果 | 验证方法 |
|---|--------|---------|---------|
| V9 | 自动备份 | 修改前自动创建备份文件，`backup.json` 含 snapshotHash | `backup-mod.ps1 -List/-Compare` 非破坏性 CLI 验证 |
| V10 | rollback_mod | 支持回滚预览；真实覆盖需 `-Force` 明确授权 | `rollback-mod.ps1 -Preview`，破坏性路径人工验证 |
| V11 | conflict_check | 两个修改同一表/target 的 Mod → severity=`error/warning/info` 分级报告 | 针对性 CLI 测试，`error` 阻断主流程 |
| V11b | 操作审计 | `mod.json` / `history.json` / `mod_registry.json` 记录 beforeHash/afterHash/userInput/changes/assets | `docs/SPRINT_3_TEST_REPORT.md` 复验 |

### 6.4 Phase 4 验收 (端到端)

| # | 测试项 | 预期结果 | 验证方法 |
|---|--------|---------|---------|
| V12 | 自然语言全流程 | "把亚基伤害改成999" → Agent 自动完成 → UnrealEssentials Zen Mod 生成 | 端到端手动测试 |
| V13 | 多表联合修改 | "给伊邪那岐加新技能并提升HP" → 同时修改 PersonaGrowth + PlayerMaxHP | 端到端手动测试 |
| V14 | 完整回滚 | 安装 Mod → 回滚 → 游戏恢复原始状态 | 回归验证 |

---

## 七、风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| PARTIAL/FAIL/SKIP schema 被误开放 | 中 | 高 | Sprint 2 schema/field guard；默认仅 PASS + flat scalar 自动写回 |
| union / struct-with-union 直接 byte-patch 崩溃 | 中 | 高 | guard 禁止 union 字段；引用 P-010；需要逆向 discriminator 或完整序列化 |
| nested struct array / 变长字段无法表达 | 中 | 中 | target parser 后续扩展；string/TArray/增删行默认 `unsupported` / `requiresManualResearch` |
| P3R 更新导致 headerSize/rowSize 变化 | 低 | 高 | 每次游戏更新后复跑 calibration + regression + golden anchor |
| UnrealEssentials 路径/依赖配置错误 | 中 | 中 | 自动生成 ModConfig；安装检查清单；默认依赖 `p3rpc.essentials` |
| CUE4Parse 版本升级导致兼容性变更 | 低 | 高 | 锁定 1.1.1 版本，记录版本锁定原因 |

---

## 八、项目里程碑

```
Week 1-2:  ████ Phase 1 — Zen byte-patch 写回引擎
             ├─ 010 schema 导入/解析/校准
             ├─ Invoke-ZenPatch.ps1 + DSL + modify-and-repack
             └─ Agi/Bufu/ExpMod 游戏内验证

Week 3-4:  ████ Phase 2 — 工具集成
             ├─ PowerShell 工具脚本
             ├─ Config.ps1 / TableKey / SchemaKey resolver
             ├─ schema/field guard
             ├─ CLAUDE.md 更新
             └─ 工具定义完成

Week 5-6:  ████ Phase 3 — 安全系统 + UX ✅
             ├─ 备份/回滚/冲突检测增强
             ├─ mod.json 元数据 + history.json 审计 + registry v2
             ├─ Git pre-mod backup（脏工作区安全跳过）
             ├─ diff_changes + DryRun offset 预览 + post-patch guard
             └─ 安全协议文档 + Sprint 3 复验报告

Week 7-8:  ████ Phase 4 — 验证 + 发布
             ├─ 端到端测试
             ├─ 010 schema 覆盖扩展
             ├─ 多表 / 批量 Mod 支持
             └─ 用户文档 + 示例
```

---

## 附录 A：术语表

| 术语 | 说明 |
|------|------|
| **IoStore** | UE4 的新型容器格式（.utoc 索引 + .ucas 数据），P3R DataTable 原生来源 |
| **Zen `.uasset`** | 从 IoStore 提取出的单文件资产，首字节通常为 `00 00 00 00`，无 `.uexp`；P3R 当前可工作的散文件替换形态 |
| **010 schema** | 从 010-Editor `.bt` 模板解析出的 rowSize/headerSize/field offset 元数据，用于计算 byte-patch 位置 |
| **Zen byte-patch** | 复制 Zen 原件后对定长标量字段做 in-place 字节写入，要求输出文件大小不变 |
| **传统 UE Package** | UE4 传统格式（.uasset 头部/元数据 + .uexp 批量数据），Magic Number: C1 83 2A 9E；在 P3R DataTable 主路径中已弃用 |
| **DataTable** | UE4 数据表资产，CUE4Parse 导出为 JSON 结构 `{Type, Name, Class, Properties: {Data: [...]}}` |
| **模板法** | 历史路径：用传统格式模板 `.uasset+.uexp` 通过 UAssetAPI/TemplateCreator 写出；P3R 实测 boot-crash，保留备查 |
| **虚拟路径** | P3RDataTools/UnrealEssentials 路径格式：`P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset` |
| **UnrealEssentials 散文件** | Reloaded II Mod 下的 `<Mod>/UnrealEssentials/P3R/Content/...` 路径镜像，当前默认交付方式 |
| **PAK / FEmulator** | 备用交付路径，仅用于 fallback/排查；不再作为 P3R DataTable 主输出 |

## 附录 B：数据目录

| 目录 | 内容 |
|------|------|
| `Paks/` | 原始游戏 IoStore 容器（.utoc + .ucas），只读 |
| `Extracted/IoStore/` | FModel 提取的完整资产（138,936 文件，41.2 GB） |
| `tools/Output/json/` | P3RDataTools 预导出的 489 个 DataTable JSON 快照 |
| `tools/templates-010/` | 010 `.bt` 模板与解析出的 schema，当前写回主路径的 offset 来源 |
| `tools/templates/` | 传统格式模板库（~15-20 个 .uasset+.uexp 对），已弃用，仅保留 fallback/历史研究 |
| `tools/Output/mod/` | Mod 输出目录，每个 Mod 一个子目录，默认生成 UnrealEssentials 散文件结构 |
| `docs/amicitia/` | Amicitia Wiki 参考数据（37 MD + 1 DATA_MAPPING.md） |
