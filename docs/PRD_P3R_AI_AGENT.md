# P3R Modding AI Agent — 产品需求文档 (PRD)

> **版本**: v1.0 | **日期**: 2026-06-17 | **状态**: MVP 阶段

---

## 一、项目概述与目标

### 1.1 项目背景

Persona 3 Reload (P3R) 是基于 Unreal Engine 4.27 的 JRPG 重制作品。当前 Mod 制作流程存在严重的技术门槛：

- 游戏资产以 IoStore 格式加密存储（.utoc/.ucas 容器），需要专用工具链（AES 解密、CUE4Parse 读取、FModel GUI 导出）
- 资产写回需手动通过 FModel GUI 导出传统格式模板 → UAssetAPI 修改 → UnrealPak 打包，**自动化程度为零**
  推出后经验证，P3R 不支持传统 PAK 直接覆盖 IoStore DataTable — 需通过 Reloaded II + File Emulation Framework 加载 Mod PAK
- 修改某个数值（如技能伤害）需要知道：游戏机制 → DataTable 文件名 → 虚拟路径 → JSON 结构 → 行索引 → 字段名 → 合法值范围 — 整个链条对普通玩家不可见
- 现有工具分散：CUE4Parse (C#)、UAssetAPI (C#)、UnrealPak (C++)、FModel (GUI)，无统一入口

### 1.2 产品愿景

构建一个**自然语言驱动的 P3R Mod 制作 AI Agent**，让硬核玩家/模组爱好者只需说出想要的效果（如"把阿耆尼的伤害改成 999"），Agent 自动完成：定位文件 → 读取数据 → 展示差分 → 修改写回 → 打包 PAK — **全程无需手动操作**。

### 1.3 核心目标

| 目标 | 衡量指标 |
|------|---------|
| **零门槛 Mod 制作** | 用户无需了解 UE 文件格式、AES 加密、DataTable 结构 |
| **全自动闭环** | 从需求到 .pak 文件，全程无需 GUI 操作 |
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
作为 P3R 玩家，我希望输入"把阿耆尼的伤害改成 999"就能自动生成可用 Mod，
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
| **F2** | ID 参考知识库 | Wiki ↔ 游戏文件精确映射，Amicitia Wiki ID 参考表 | 输入"阿耆尼"可定位到 DatSkillNormalDataAsset row[0] | ✅ 已实现 |
| **F3** | 模板写回引擎 | TemplateCreator 直接二进制序列化：读取 IoStore JSON → 生成传统格式 .uasset+.uexp（Magic=C1832A9E） | 18/18 DataTable 类型验证通过 | ✅ 已实现 |
| **F4** | PAK 打包 + 交付 | UnrealPak 自动打包 mod → 输出 .pak 文件，通过 Reloaded II + File Emulation Framework 加载 | `modify-and-repack.ps1` 全自动流程 | ✅ 已实现 |
| **F5** | 自然语言查询 | LLM 理解用户意图 → 匹配 DataTable + 字段 | "把阿耆尼伤害改成999" → 正确识别 table=Skills, row=0, field=Power, value=999 | 🔴 需扩展 |
| **F6** | 模板库 | 每种 DataTable 类型一个传统格式模板（~15-20 个）| 每类至少 1 个模板，存储于 tools/templates/ | 🔴 一次性手动 |

**P0 用户流程（Happy Path）:**

```
输入: "把阿耆尼 (Agi) 的伤害从 15 改成 999"

步骤1: 查询定位
  search_data_table("阿耆尼", category="skill")
  → virtualPath: "P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset"
  → rowIndex: 0, fieldPath: "Data[0].Power", currentValue: 15

步骤2: 差分预览
  diff_changes(changes)
  → "阿耆尼 (Agi, ID:0): 伤害 Power: 15 → 999"

步骤3: 用户确认 [Y/n]

步骤4: 写回 + 打包
  modify_value + build_mod("SuperAgi", tables=["Skills"])
  → 生成 SuperAgi_P.pak

步骤5: 完成
  ✅ "SuperAgi.pak 已生成，通过 Reloaded II 启动游戏即可生效"
```

### 3.2 P1 — 重要（增强体验，预估 2-3 周）

| ID | 功能 | 描述 | 验收标准 |
|------|------|------|------|
| **F7** | 人类可读差分预览 | 修改前后对比，自动标注 Wiki 名称 | skill_name (ID:0): damage 15→999, sp_cost 4→1 |
| **F8** | 备份/快照系统 | 修改前自动备份原始数据，支持一键还原 | `backup create --label "before_skill_mod"` 创建可恢复快照 |
| **F9** | 回滚机制 | 移除 mod PAK，恢复原始游戏状态 | `rollback_mod("SuperAgi")` → PAK 删除 + 原始状态确认 |
| **F10** | Mod 版本管理 | mod.json 元数据 + Git 历史追踪 | 每个 mod 有名称、描述、修改列表、时间戳、Git commit hash |
| **F11** | 冲突检测 | 检测多个 Mod 是否修改同一 DataTable 同一行 | `conflict_check("ModA")` → "与 ModB 冲突: Skills Data[0] 同时被修改" |
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
| **模板写回** | < 2 秒 | UAssetAPI 加载模板 + 替换行 + .Write() |
| **PAK 打包** | < 5 秒 | UnrealPak 压缩打包单个 DataTable |
| **端到端延迟** | < 15 秒 | 从用户输入到 .pak 生成完成 |
| **内存占用** | < 500MB | CUE4Parse 挂载 140K 文件索引在内存中 |

### 4.2 安全性

| 原则 | 实施方式 |
|------|---------|
| **不修改源文件** | `tools/Output/json/` 为只读快照；Paks/ 原始容器永不修改 |
| **操作可撤销** | Git 记录每次修改；mod 产物隔离到独立目录 |
| **先备份后操作** | 修改前自动创建时间点备份到 `tools/Output/.backup/` |
| **冲突主动告警** | 写入前检查 mod 注册表，发现同一行冲突即告警 |
| **操作审计** | 所有修改记录到 `history.json`（action, timestamp, beforeHash, afterHash） |

### 4.3 兼容性

| 维度 | 要求 |
|------|------|
| **UE 版本** | 4.27（pak version 11），与 P3R 严格一致 |
| **IoStore 格式** | CUE4Parse 1.1.1（不可升级，1.2.2 有 Zlib 兼容问题） |
| **传统格式** | UAssetAPI 1.1.0，EngineVersion = VER_UE4_27 |
| **操作系统** | Windows 10/11 x64（P3R 仅 Windows） |
| **C# 运行时** | .NET 8（自包含发布，用户无需安装运行时） |
| **AES 密钥** | 0x92BADFE2...（内置，无需用户配置） |

### 4.4 可扩展性

| 维度 | 设计 |
|------|------|
| **新增 DataTable 类型** | 添加模板 .uasset+.uexp → Config.ps1 注册虚拟路径 → 立即可用 |
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
│            "把阿耆尼的伤害改成 999"                                 │
└──────────────┬──────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────────────┐
│  Step 1: 意图解析 (LLM)                                          │
│  ├─ 实体识别: 阿耆尼 → 技能 Agi                                  │
│  ├─ 操作识别: 修改 → 数值                                        │
│  └─ 参数提取: 伤害=999                                           │
└──────────────┬──────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────────────┐
│  Step 2: 文件定位 (search_data_table)                             │
│  ├─ 查 DATA_MAPPING.md: 技能 → DatSkillNormalDataAsset           │
│  ├─ 查 Wiki MD: 阿耆尼 → Agi → Skill ID = 0                      │
│  └─ 定位: virtualPath + rowIndex + fieldPath + currentValue       │
└──────────────┬──────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────────────┐
│  Step 3: 读取确认 (read_datatable)                                │
│  ├─ 优先从缓存 tools/Output/json/Battle/ 读取                     │
│  └─ 提取目标行: Data[0].Power = 15 (当前值)                       │
└──────────────┬──────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────────────┐
│  Step 4: 差分预览 (diff_changes)                                  │
│  ├─ 格式化: "阿耆尼 (Agi, ID:0): 伤害 Power: 15 → 999"           │
│  └─ 展示给用户确认                                                │
└──────────────┬──────────────────────────────────────────────────┘
               ↓
          ┌────┴────┐
          │ 用户确认? │
          └────┬────┘
               │ ✅ 确认
               ↓
┌─────────────────────────────────────────────────────────────────┐
│  Step 5: 修改写回 (modify_value + build_mod)                      │
│  ├─ a. 克隆原始 JSON → 修改 Data[0].Power = 999                   │
│  ├─ b. 匹配模板: DatSkillNormalTable → tools/templates/           │
│  ├─ c. UAssetAPI: 加载模板 → 替换行数据 → .Write()                │
│  ├─ d. 生成 manifest.txt                                          │
│  └─ e. UnrealPak: 打包 → SuperAgi_P.pak                           │
└──────────────┬──────────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────────────┐
│  Step 6: 完成                                                     │
│  ├─ 输出: SuperAgi_P.pak (XXX KB)                                 │
│  ├─ 安装: 复制到 ~mods/ 目录                                       │
│  └─ 提示: 启动游戏验证                                             │
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
  │     修改: Skills[0]  │
  │     Power: 15→999"   │
  └──────┬───────────────┘
         ↓
    用户确认? ── 否 ──→ 取消
         │
         ↓ 是
  ┌──────────────────────┐
  │ 3. 移除 PAK 文件      │
  └──────┬───────────────┘
         ↓
  ┌──────────────────────┐
  │ 4. 清理 mod 产物     │
  │    删除 .uasset/.uexp │
  └──────┬───────────────┘
         ↓
  ┌──────────────────────┐
  │ 5. 验证恢复           │
  │    P3RDataTools read  │
  │    → Data[0].Power=15 │
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
      - row[1] (魔人アバドン)
      - row[3] (力のマーヤ)
      后加载的 mod 将覆盖先加载的修改"
```

---

## 六、验收标准

### 6.1 Phase 1 验收 (写回引擎)

| # | 测试项 | 预期结果 | 验证方法 |
|---|--------|---------|---------|
| V1 | 模板往返 | FModel 导出模板 → UAssetAPI 加载 → 不做修改 .Write() → 二进制对比原始一致 | 文件哈希对比 |
| V2 | IoStore 读取 | `P3RDataTools read "DatSkillNormalDataAsset"` → 返回完整 JSON | CLI 输出验证 |
| V3 | 数值修改写回 | 修改 Skills Data[0].Power=999 → .Write() → 再次 UAssetAPI 加载 → 确认值=999 | 自动化断言 |
| V4 | PAK 打包 | .uasset+.uexp → UnrealPak → 生成 _P.pak | 文件存在性 + 大小 > 0 |
| V5 | 游戏加载 | _P.pak 放入 Paks/ → 游戏正常启动 | 手动验证 |

### 6.2 Phase 2 验收 (工具集成)

| # | 测试项 | 预期结果 | 验证方法 |
|---|--------|---------|---------|
| V6 | search_data_table | "阿耆尼" → 返回 {virtualPath, rowIndex:0, fieldPath, currentValue:15} | 自动化测试 |
| V7 | diff_changes | 修改前后对比输出含 Wiki 名称标注 | 输出格式匹配 |
| V8 | build_mod | 输入 modName + 修改 → 生成 .pak | 端到端流程 |

### 6.3 Phase 3 验收 (安全系统)

| # | 测试项 | 预期结果 | 验证方法 |
|---|--------|---------|---------|
| V9 | 自动备份 | 修改前自动创建备份文件 | 文件存在性检查 |
| V10 | rollback_mod | 移除 PAK → 清理产物 → 原始值确认 | 端到端回归验证 |
| V11 | conflict_check | 两个修改同一表的 Mod → 正确报告重叠行 | 针对性测试 |

### 6.4 Phase 4 验收 (端到端)

| # | 测试项 | 预期结果 | 验证方法 |
|---|--------|---------|---------|
| V12 | 自然语言全流程 | "把阿耆尼伤害改成999" → Agent 自动完成 → .pak 生成 | 端到端手动测试 |
| V13 | 多表联合修改 | "给伊邪那岐加新技能并提升HP" → 同时修改 PersonaGrowth + PlayerMaxHP | 端到端手动测试 |
| V14 | 完整回滚 | 安装 Mod → 回滚 → 游戏恢复原始状态 | 回归验证 |

---

## 七、风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| UAssetAPI 写回的 .uasset 游戏不加载 | 中 | 高 | Phase 1 优先做游戏加载测试；若不通过，探索 hex-editing 或 C++ 替代方案 |
| FModel 无法导出某些表类型的传统格式 | 中 | 中 | 手动构造最简模板（逆向工作，一次性成本） |
| 模板 NameMap 与修改后数据不匹配 | 低 | 中 | 只修改数值、不修改字段名；文本表单独处理 |
| CUE4Parse 版本升级导致兼容性变更 | 低 | 高 | 锁定 1.1.1 版本，记录版本锁定原因 |
| 游戏更新导致资产结构变化 | 低 | 中 | 维护虚拟路径映射表，可通过配置更新适配 |

---

## 八、项目里程碑

```
Week 1-2:  ████ Phase 1 — 写回引擎
             ├─ 模板导出（一次性手动）
             ├─ CreateUassetFromJson 实现
             └─ 往返测试 + 游戏加载验证

Week 3-4:  ████ Phase 2 — 工具集成
             ├─ PowerShell 工具脚本
             ├─ Config.ps1 扩展
             ├─ CLAUDE.md 更新
             └─ 工具定义完成

Week 5-6:  ████ Phase 3 — 安全系统 + UX
             ├─ 备份/回滚/冲突检测
             ├─ mod.json 元数据
             ├─ diff_changes 人类可读格式
             └─ 安全协议文档

Week 7-8:  ████ Phase 4 — 验证 + 发布
             ├─ 端到端测试
             ├─ 模板库扩展
             ├─ 多表 Mod 支持
             └─ 用户文档 + 示例
```

---

## 附录 A：术语表

| 术语 | 说明 |
|------|------|
| **IoStore** | UE4 的新型容器格式（.utoc 索引 + .ucas 数据），文件头为零，UAssetAPI 不可直接编辑 |
| **传统 UE Package** | UE4 传统格式（.uasset 头部/元数据 + .uexp 批量数据），Magic Number: C1 83 2A 9E |
| **DataTable** | UE4 数据表资产，CUE4Parse 导出为 JSON 结构 `{Type, Name, Class, Properties: {Data: [...]}}` |
| **模板法** | 用传统格式模板 .uasset+.uexp（一次 FModel 导出），通过 UAssetAPI 替换行数据后写出 |
| **虚拟路径** | P3RDataTools 内部路径格式：`P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset` |
| **PAK** | UE4 资产包容器，`_P` 后缀 = 最高加载优先级 |
| **_P.pak** | Mod 输出格式，放入 Paks/ 目录即可被游戏加载 |

## 附录 B：数据目录

| 目录 | 内容 |
|------|------|
| `Paks/` | 原始游戏 IoStore 容器（.utoc + .ucas），只读 |
| `Extracted/IoStore/` | FModel 提取的完整资产（138,936 文件，41.2 GB） |
| `tools/Output/json/` | P3RDataTools 预导出的 489 个 DataTable JSON 快照 |
| `tools/templates/` | 写回用传统格式模板库（~15-20 个 .uasset+.uexp 对） |
| `tools/Output/mod/` | Mod 输出目录，每个 Mod 一个子目录 |
| `docs/amicitia/` | Amicitia Wiki 参考数据（37 MD + 1 DATA_MAPPING.md） |
