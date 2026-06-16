# P3R Modding AI Agent — 项目开发计划

> **开发方式**: Claude Code 辅助开发（AI 生成代码 → 人工审查/测试 → 迭代）  
> **总预估工时**: 108 小时（含人工验证）  
> **Sprint 周期**: 2 周 / Sprint（约 20-30h 有效编码时间）

---

## Sprint 总览

```
Sprint 0  ██ 基础设施补全 (12h)          ← 前置准备
Sprint 1  ████ 写回引擎 (30h)            ← 核心阻塞点
Sprint 2  ████ 工具链集成 (26h)          ← 端到端闭环
Sprint 3  ████ 安全系统 (24h)            ← 防护层
Sprint 4  ██ 扩展与验证 (16h)            ← 覆盖 + 确认
         ──
         合计: 108h (~5.5 周 全职，或 11 周 半职)
```

---

## Sprint 0: 基础设施补全

> **目标**: 补齐开发环境依赖，完成所有一次性手动准备工作  
> **工期**: 12h | **依赖**: 无 | **可交付物**: 模板库 + 项目初始化脚本

### 任务清单

| ID | 任务 | 描述 | 工时 | 依赖 | Claude Code 做什么 | 人工做什么 |
|----|------|------|------|------|-------------------|-----------|
| **T0.1** | 模板导出 | 用 FModel GUI 为 18 种 DataTable 类型导出传统格式 .uasset+.uexp | 4h | — | 生成导出清单文档 | **操作 FModel GUI**（手工操作，不可 AI 化） |
| **T0.2** | 模板验证 | UAssetAPI 加载每个模板 → 不改动 .Write() → 二进制对比原始 | 2h | T0.1 | 编写模板验证测试脚本 | 审查验证结果，确认 18/18 通过 |
| **T0.3** | 模板目录建立 | 将验证通过的模板存入 `tools/templates/`，建立命名规范 | 0.5h | T0.2 | 生成模板索引 JSON | 确认目录结构 |
| **T0.4** | 项目初始化脚本 | 编写 `setup.ps1`：检查运行时 → 编译 P3RDataTools → 验证容器 → 生成配置文件 | 2h | — | 编写完整 setup.ps1 | 从头测试安装流程 |
| **T0.5** | 开发环境文档 | 编写 `docs/DEVELOPER_GUIDE.md`：环境要求、编译步骤、调试方法 | 1.5h | T0.4 | 生成开发者文档初稿 | 审查并补充游戏特有细节 |
| **T0.6** | Git 工作流配置 | 配置 `.gitignore` 更新、Git LFS（如需）、分支策略 | 0.5h | — | 生成配置建议 | 执行并验证 |
| **T0.7** | Sprint 0 评审 | 确认模板库完整、setup.ps1 可从头安装、文档清晰 | 1.5h | T0.1-T0.6 | — | 逐项检查验收 |

### 交付物

- [ ] `tools/templates/` 目录，含 18 种 .uasset+.uexp 模板 ← **待人工 T0.1 FModel 导出**
- [x] `tools/templates/template_index.json` 模板索引
- [x] `setup.ps1` 项目初始化脚本
- [x] `docs/DEVELOPER_GUIDE.md` 开发指南
- [x] `tools/scripts/verify-templates.ps1` 模板验证脚本
- [ ] 模板往返验证报告（18/18 通过）← **依赖 T0.1**

### 任务依赖图

```
T0.1 (FModel导出)
  │
  └──→ T0.2 (模板验证)
         │
         └──→ T0.3 (存入templates/)
                │
                └──→ T0.7 (Sprint 评审)
                      
T0.4 (setup.ps1) ──→ T0.5 (开发文档) ──→ T0.7
T0.6 (Git配置) ──────────────────────→ T0.7
```

---

## Sprint 1: 写回引擎

> **目标**: 实现模板法写回，打通「修改 JSON → .uasset+.uexp → .pak」全链路  
> **工期**: 30h | **依赖**: Sprint 0 完成 | **可交付物**: 可用的 P3RDataTools create 命令

### 任务清单

| ID | 任务 | 描述 | 工时 | 依赖 | Claude Code 做什么 | 人工做什么 |
|----|------|------|------|------|-------------------|-----------|
| **T1.1** | UAssetAPI 模板加载模块 | 实现 `TemplateLoader.cs`：根据 JSON Type 字段匹配模板、加载 .uasset+.uexp、定位 DataTableExport | 4h | T0.3 | 编写 TemplateLoader 类（~150 行 C#） | 审查代码、验证加载逻辑 |
| **T1.2** | 行数据替换引擎 | 实现 `DataTablePatcher.cs`：遍历 Export → 定位 StructPropertyData → 替换行值 → 调整行数 | 6h | T1.1 | 编写 DataTablePatcher 类（~300 行 C#），处理嵌套结构 | 审查代码、验证替换逻辑 |
| **T1.3** | 输出写回模块 | 实现 `AssetWriter.cs`：调用 UAssetAPI `.Write()` 输出 .uasset+.uexp，处理 manifest 生成 | 3h | T1.2 | 编写 AssetWriter 类（~100 行 C#） | 审查代码 |
| **T1.4** | CLI 集成 | 在 Program.cs 中重写 `CreateUassetFromJson`，接入三个新模块，新增 `create` 命令 | 3h | T1.3 | 重写 Program.cs 相关方法（~150 行） | 审查代码、CLI 测试 |
| **T1.5** | 往返测试脚本 | 编写自动化测试：IoStore read → 修改 JSON → create → UAssetAPI 重新加载 → 断言值一致 | 3h | T1.4 | 编写测试 PowerShell 脚本 + 测试用例数据 | 执行测试、分析失败 |
| **T1.6** | 游戏加载测试（关键） | 对 DatSkillNormalDataAsset 做最小修改 → 打包 _P.pak → 放入 Paks/ → 启动游戏 | 3h | T1.5 | 生成测试用最小修改 JSON | **手动启动游戏、观察运行** |
| **T1.7** | 问题修复与调优 | 根据 T1.5/T1.6 的发现修复 bug：文件头、偏移、行数匹配、StructProperty 嵌套 | 6h | T1.6 | 分析问题根因、生成修复代码 | 验证修复、重新测试 |
| **T1.8** | Sprint 1 评审 | 确认写回引擎对 18 种模板全部可用、游戏加载成功、往返测试通过 | 2h | T1.7 | 生成测试报告 | 逐项验收 |

### 交付物

- [ ] `tools/P3RDataTools/TemplateLoader.cs` 模板加载模块
- [ ] `tools/P3RDataTools/DataTablePatcher.cs` 行数据替换引擎
- [ ] `tools/P3RDataTools/AssetWriter.cs` 输出写回模块
- [ ] `tools/P3RDataTools/Program.cs` 更新（`create` 命令）
- [ ] `tools/scripts/test-roundtrip.ps1` 往返测试脚本
- [ ] 游戏加载测试报告（至少 1 个表验证通过）
- [ ] 往返测试报告（18/18 表类型）

### 任务依赖图

```
T1.1 (模板加载)
  │
  └──→ T1.2 (数据替换) 
         │
         └──→ T1.3 (输出写回)
                │
                └──→ T1.4 (CLI集成)
                       │
                       └──→ T1.5 (往返测试)
                              │
                              └──→ T1.6 (游戏测试) ← ⚠️ 最高风险点
                                     │
                                     └──→ T1.7 (修复调优)
                                            │
                                            └──→ T1.8 (评审)
```

> ⚠️ **风险提示**: T1.6 如果失败，T1.7 可能延长 2-3 倍工时。最坏情况需探索 hex-editing 或 C++ 替代方案。

---

## Sprint 2: 工具链集成

> **目标**: 编写 Claude Code 工具脚本，更新 CLAUDE.md，实现端到端自然语言闭环  
> **工期**: 26h | **依赖**: Sprint 1 完成 | **可交付物**: 全部 8 个工具可用 + 完整 CLAUDE.md

### 任务清单

| ID | 任务 | 描述 | 工时 | 依赖 | Claude Code 做什么 | 人工做什么 |
|----|------|------|------|------|-------------------|-----------|
| **T2.1** | Config.ps1 扩展 | 添加 `$Templates`、`$ModRegistry`、`$BackupDir`、`$ToolsDir` 变量 | 1h | T0.3 | 生成 Config.ps1 新增部分 | 审查并加载测试 |
| **T2.2** | search-datatable.ps1 | 实现：查 DATA_MAPPING.md + Wiki MD → 返回虚拟路径、行索引、字段、当前值 | 4h | — | 编写搜索脚本（~200 行 PS），含中文模糊匹配逻辑 | 测试各种查询（中/日/英名称、拼音、描述） |
| **T2.3** | search-wiki.ps1 | 实现：grep 37 个 Wiki MD → 返回相关条目 + 对应游戏文件路径 | 2h | — | 编写 Wiki 搜索脚本（~100 行 PS），含索引缓存优化 | 测试查询质量 |
| **T2.4** | diff-changes.ps1 | 实现：对比修改前后 JSON → 人类可读输出（含 Wiki 名称标注） | 5h | T2.2 | 编写 diff 脚本（~200 行 PS），含 ID→名称翻译 | 测试各种类型修改的预览效果 |
| **T2.5** | backup-mod.ps1 | 实现：创建时间点备份 → 复制原始 JSON → 写入 backup.json | 2h | T2.1 | 编写备份脚本（~80 行 PS） | 测试备份/恢复 |
| **T2.6** | rollback-mod.ps1 | 实现：查找 mod 注册表 → 展示信息 → 确认 → 移除 PAK → 清理产物 → 验证 | 3h | T2.5 | 编写回滚脚本（~150 行 PS） | 端到端测试回滚 |
| **T2.7** | conflict-check.ps1 | 实现：遍历已安装 mod → 对比 DataTable 行 → 报告重叠 | 3h | T2.1 | 编写冲突检测脚本（~150 行 PS） | 创建冲突场景测试 |
| **T2.8** | modify-and-repack.ps1 重写 | 集成 `create` 命令 → 移除手动步骤 → 添加进度提示 → 错误友好输出 | 3h | T1.7, T2.1 | 重写编排脚本（~200 行 PS） | 全流程测试 |
| **T2.9** | CLAUDE.md 更新 | 添加全部工具定义、工作流规则、安全协议、使用示例 | 2h | T2.2-T2.8 | 生成 CLAUDE.md 新增章节 | 审查并确认 Claude Code 正确加载 |
| **T2.10** | Sprint 2 评审 | 端到端 AI 测试：自然语言输入 → Agent 自动完成 → .pak 生成 | 1h | T2.9 | — | 用 5+ 种不同需求的自然语言做完整测试 |

### 交付物

- [ ] `tools/scripts/Config.ps1` 更新（新增变量）
- [ ] `tools/scripts/tools/search-datatable.ps1`
- [ ] `tools/scripts/tools/search-wiki.ps1`
- [ ] `tools/scripts/tools/diff-changes.ps1`
- [ ] `tools/scripts/tools/backup-mod.ps1`
- [ ] `tools/scripts/tools/rollback-mod.ps1`
- [ ] `tools/scripts/tools/conflict-check.ps1`
- [ ] `tools/scripts/modify-and-repack.ps1` 重写
- [ ] `CLAUDE.md` 更新（含 8 个工具定义 + 安全规则）
- [ ] 端到端测试报告（5+ 自然语言场景）

### 任务依赖图

```
T2.1 (Config扩展)
  │
  ├──→ T2.5 (backup) ──→ T2.6 (rollback)
  │                       │
  ├──→ T2.7 (conflict)    │
  │                       │
  └──→ T2.8 (modify-and-repack重写)
         │                 │
         └──→ ... ────────┴──→ T2.9 (CLAUDE.md) ──→ T2.10 (评审)

T2.2 (search-datatable) ──→ T2.4 (diff-changes)
         │                      │
         └──→ T2.9 ─────────────┘

T2.3 (search-wiki) ──→ T2.9
```

---

## Sprint 3: 安全系统

> **目标**: 实现四层安全架构，保证操作可逆、冲突可检测、历史可审计  
> **工期**: 24h | **依赖**: Sprint 2 完成 | **可交付物**: 完整安全系统

### 任务清单

| ID | 任务 | 描述 | 工时 | 依赖 | Claude Code 做什么 | 人工做什么 |
|----|------|------|------|------|-------------------|-----------|
| **T3.1** | Mod 注册表系统 | 实现 `mod.json` 元数据格式 + 创建/读取/更新/删除 API | 3h | T2.1 | 编写 ModRegistry 模型 + PS 脚本（~200 行） | 审查格式设计、测试 CRUD |
| **T3.2** | history.json 操作审计 | 每次修改自动记录：action、timestamp、beforeHash、afterHash、userInput | 2h | T3.1 | 编写审计记录模块（~100 行 PS） | 验证审计完整性 |
| **T3.3** | Git 集成层 | 修改前自动 commit 原始 JSON → 标记 "auto: pre-mod backup for <modName>" | 3h | T3.1 | 编写 Git 操作脚本（~100 行 PS），处理边缘情况 | 测试各种 Git 状态下的行为 |
| **T3.4** | 备份系统增强 | 增强 T2.5：支持命名备份、列出备份、从备份恢复、版本比较 | 3h | T2.5, T3.1 | 增强 backup-mod.ps1（+150 行 PS） | 测试多版本备份场景 |
| **T3.5** | 回滚系统增强 | 增强 T2.6：支持选择性回滚、回滚预览、回滚后验证 | 3h | T2.6, T3.4 | 增强 rollback-mod.ps1（+100 行 PS） | 测试部分回滚场景 |
| **T3.6** | 冲突检测增强 | 增强 T2.7：冲突严重性分级（错误/警告/信息）、合并建议 | 3h | T2.7, T3.1 | 增强 conflict-check.ps1（+150 行 PS） | 测试复杂冲突场景 |
| **T3.7** | 安全屏障脚本 | 实现 `guard-modify.ps1`：修改前自动检查清单（备份存在、无冲突、值合法） | 2h | T3.2-T3.6 | 编写安全屏障脚本（~100 行 PS） | 集成到 modify-and-repack 流程 |
| **T3.8** | 安全协议文档 | 编写 `docs/SECURITY.md`：安全架构、操作流程、紧急恢复指南 | 2h | T3.7 | 生成安全文档初稿 | 审查并补充细节 |
| **T3.9** | Sprint 3 评审 | 全量安全测试：批量修改、模拟冲突、破坏性回滚、审计链验证 | 3h | T3.8 | 生成测试场景脚本 | 逐项验收 |

### 交付物

- [ ] `tools/Output/mod/<name>/mod.json` 注册表格式
- [ ] `tools/Output/mod/<name>/history.json` 审计日志
- [ ] `tools/scripts/tools/backup-mod.ps1` 增强版
- [ ] `tools/scripts/tools/rollback-mod.ps1` 增强版
- [ ] `tools/scripts/tools/conflict-check.ps1` 增强版
- [ ] `tools/scripts/tools/guard-modify.ps1` 安全屏障
- [ ] `docs/SECURITY.md` 安全协议文档
- [ ] 安全系统测试报告

### 任务依赖图

```
T3.1 (Mod注册表)
  │
  ├──→ T3.2 (审计日志)
  │       │
  ├──→ T3.3 (Git集成)
  │       │
  ├──→ T3.4 (备份增强) ──→ T3.5 (回滚增强)
  │       │                   │
  └──→ T3.6 (冲突增强) ───────┤
          │                   │
          └──→ T3.7 (安全屏障) ←┘
                 │
                 └──→ T3.8 (安全文档) ──→ T3.9 (评审)
```

---

## Sprint 4: 扩展与验证

> **目标**: 扩展覆盖率、端到端验证、用户文档编写  
> **工期**: 16h | **依赖**: Sprint 3 完成 | **可交付物**: 完整产品 + 文档

### 任务清单

| ID | 任务 | 描述 | 工时 | 依赖 | Claude Code 做什么 | 人工做什么 |
|----|------|------|------|------|-------------------|-----------|
| **T4.1** | 多表 Mod 支持 | 修改 modify-and-repack.ps1 支持一次修改多个 DataTable | 3h | T2.8 | 扩展编排脚本（+100 行 PS） | 测试 2-3 表联合修改 |
| **T4.2** | 模板库扩展验证 | 验证全部 18 种模板的读写正确性 | 2h | T1.7 | 生成批量验证脚本 | 审查结果并修复遗漏 |
| **T4.3** | 批量修改支持 | 实现 "将所有 X 的 Y 改为 Z" 模式（筛选 + 批量 modify + 单次打包） | 3h | T4.1 | 编写批量修改脚本（~150 行 PS） | 测试批量操作正确性 |
| **T4.4** | 边界情况测试 | 测试：空行、最大值溢出、负值、无效 ID、文件名冲突、路径空格 | 3h | T4.3 | 生成边界测试用例脚本 | 逐项执行并记录 |
| **T4.5** | 用户文档 | 编写 `docs/USER_GUIDE.md`：安装、首次使用、常见场景、FAQ | 3h | T4.4 | 生成用户文档初稿 | 审查、补充截图和示例 |
| **T4.6** | Sprint 4 评审 | 全量端到端测试 + 文档完整性检查 | 2h | T4.5 | 生成最终测试报告 | 逐项验收 |

### 交付物

- [ ] `tools/scripts/modify-and-repack.ps1` 多表支持版
- [ ] `tools/scripts/tools/batch-modify.ps1` 批量修改脚本
- [ ] 全模板验证报告（18/18 表类型）
- [ ] 边界测试报告
- [ ] `docs/USER_GUIDE.md` 用户指南
- [ ] 端到端最终测试报告

### 任务依赖图

```
T4.1 (多表支持) ──→ T4.3 (批量修改) ──→ T4.4 (边界测试)
                                          │
T4.2 (模板验证) ──────────────────────────┤
                                          │
                                          └──→ T4.5 (用户文档) ──→ T4.6 (评审)
```

---

## 依赖关系总图

```
Sprint 0 ──→ Sprint 1 ──→ Sprint 2 ──→ Sprint 3 ──→ Sprint 4
  │              │            │            │            │
  │              │            │            │            └── 多表/批量/文档
  │              │            │            └── 备份/回滚/冲突/审计
  │              │            └── 8个工具脚本 + CLAUDE.md
  │              └── UAssetAPI写回 + 游戏验证 ← 最关键路径
  └── 模板库 + setup + 开发环境
```

**关键路径**: Sprint 0 T0.1 → Sprint 1 T1.6（游戏加载测试）→ Sprint 1 T1.7（修复）→ 后续 Sprint 才能推进

> ⚠️ **Sprint 1 是最大风险点**: 如果 T1.6 游戏加载测试失败，后续所有 Sprint 都需要等待。建议 Sprint 1 优先处理，尽早暴露风险。

---

## 工时汇总

| Sprint | 名称 | 预估工时 | Claude Code 产出 | 人工 |
|--------|------|---------|-------------------|------|
| Sprint 0 | 基础设施补全 | 12h | 脚本/文档生成 (6h) | FModel 操作 + 审查 (6h) |
| Sprint 1 | 写回引擎 | 30h | C# 代码生成 (16h) | 审查 + 游戏测试 (14h) |
| Sprint 2 | 工具链集成 | 26h | PS 脚本生成 (18h) | 集成测试 + 审查 (8h) |
| Sprint 3 | 安全系统 | 24h | PS 脚本生成 (16h) | 安全场景测试 (8h) |
| Sprint 4 | 扩展与验证 | 16h | 脚本/文档生成 (9h) | 端到端测试 + 审查 (7h) |
| **合计** | | **108h** | **65h (60%)** | **43h (40%)** |

### Claude Code 的角色

| 阶段 | Claude Code 负责 | 不能替代人工 |
|------|-----------------|-------------|
| **编写代码** | 生成 C# 模块、PowerShell 脚本、配置文件 | 架构决策、API 选型 |
| **测试** | 生成测试脚本、测试数据、边界用例 | 游戏加载验证（必须真人启动游戏） |
| **文档** | 生成初稿、格式排版、交叉引用 | 游戏机制描述、截图、FAQ 真实性 |
| **调试** | 分析错误日志、提出修复方案 | 确认修复在真实游戏环境生效 |
| **审查** | 代码质量检查、安全检查清单 | 最终判断是否合格 |

---

## 风险时间缓冲

| 风险 | 概率 | 额外工时 | 触发条件 |
|------|------|---------|---------|
| 游戏不加载传统格式 PAK | 25% | +20h | T1.6 失败 |
| FModel 无法导出某类型 | 20% | +8h | T0.1 部分失败 |
| UAssetAPI 写回数据错位 | 15% | +10h | T1.5 大量失败 |
| 模板 NameMap 不匹配 | 10% | +6h | T1.2 遇到特定类型 |

**建议**: Sprint 1 预留 30% 缓冲（30h + 9h = 39h）

---

## 里程碑日历

```
Week 1 ─ Sprint 0: 基础设施
  Day 1-2  ██ 模板导出 + 验证
  Day 3-4  ██ setup.ps1 + 文档
  Day 5    ██ Sprint 0 评审
  ───────────────────────────
      里程碑 A: 模板库就绪，可开始写回引擎开发

Week 2-3 ─ Sprint 1: 写回引擎
  Day 1-3  ██ 三个 C# 模块（TemplateLoader / Patcher / Writer）
  Day 4-5  ██ CLI 集成 + 往返测试
  Day 6     ██ 游戏加载测试 ← 关键决策点
  Day 7-9  ██ 修复调优
  Day 10   ██ Sprint 1 评审
  ───────────────────────────
      里程碑 B: 写回链路打通，可生成可用 .pak

Week 4-5 ─ Sprint 2: 工具链集成
  Day 1-3  ██ search + diff + wiki 脚本
  Day 4-6  ██ backup + rollback + conflict 脚本
  Day 7-8  ██ modify-and-repack 重写 + CLAUDE.md
  Day 9-10 ██ 端到端 AI 测试 + Sprint 2 评审
  ───────────────────────────
      里程碑 C: 自然语言 → .pak 全流程可用

Week 6-7 ─ Sprint 3: 安全系统
  Day 1-3  ██ 注册表 + 审计 + Git 集成
  Day 4-5  ██ 备份/回滚/冲突增强
  Day 6-7  ██ 安全屏障 + 文档
  Day 8-9  ██ 安全测试 + Sprint 3 评审
  ───────────────────────────
      里程碑 D: 安全系统就绪，操作完全可逆

Week 8 ─ Sprint 4: 验证发布
  Day 1-2  ██ 多表/批量支持
  Day 3-4  ██ 边界测试 + 模板全验证
  Day 5-6  ██ 用户文档 + 最终评审
  ───────────────────────────
      里程碑 E: v1.0 发布就绪
```

---

## 关键文件产出清单

| 文件 | Sprint | 类型 |
|------|--------|------|
| `tools/P3RDataTools/TemplateLoader.cs` | S1 | 新建 |
| `tools/P3RDataTools/DataTablePatcher.cs` | S1 | 新建 |
| `tools/P3RDataTools/AssetWriter.cs` | S1 | 新建 |
| `tools/P3RDataTools/Program.cs` | S1 | 修改 |
| `tools/scripts/Config.ps1` | S2 | 修改 |
| `tools/scripts/tools/search-datatable.ps1` | S2 | 新建 |
| `tools/scripts/tools/search-wiki.ps1` | S2 | 新建 |
| `tools/scripts/tools/diff-changes.ps1` | S2 | 新建 |
| `tools/scripts/tools/backup-mod.ps1` | S2/S3 | 新建 |
| `tools/scripts/tools/rollback-mod.ps1` | S2/S3 | 新建 |
| `tools/scripts/tools/conflict-check.ps1` | S2/S3 | 新建 |
| `tools/scripts/tools/guard-modify.ps1` | S3 | 新建 |
| `tools/scripts/tools/batch-modify.ps1` | S4 | 新建 |
| `tools/scripts/modify-and-repack.ps1` | S2/S4 | 重写 |
| `CLAUDE.md` | S2 | 修改 |
| `tools/templates/` (18 对文件) | S0 | 新建 |
| `tools/templates/template_index.json` | S0 | 新建 |
| `setup.ps1` | S0 | 新建 |
| `docs/DEVELOPER_GUIDE.md` | S0 | 新建 |
| `docs/SECURITY.md` | S3 | 新建 |
| `docs/USER_GUIDE.md` | S4 | 新建 |
