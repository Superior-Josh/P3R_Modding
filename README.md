# P3R Modding AI Agent

> **自然语言驱动的 Persona 3 Reload Mod 制作工作流** — 用一句话描述想要的修改，AI Agent 全自动完成定位 → 读取 → 修改 → 打包 → 部署。

[![Status](https://img.shields.io/badge/status-MVP-blue.svg)](docs/DEVELOPMENT_PLAN.md)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%2B-lightgrey.svg)](#)
[![UE Version](https://img.shields.io/badge/UE-4.27-orange.svg)](#)
[![.NET](https://img.shields.io/badge/.NET-8.0-512BD4.svg)](https://dotnet.microsoft.com/download/dotnet/8.0)

---

## 这是什么

Persona 3 Reload (P3R) 是基于 UE 4.27 的 JRPG。它的资产以加密 IoStore 格式（`.utoc`/`.ucas`）存储，传统 Mod 制作链路（FModel GUI → UAssetGUI → UnrealPak）门槛极高、自动化为零。

本项目提供一条 **端到端的程序化 Mod 制作管线**，让 AI Agent（或 Power User）只需一条自然语言指令：

> *"把亚基（Agi）的伤害改成 999"*

就能自动完成：

```
定位 DataTable → 解析 010 schema → 复制 IoStore Zen 原件 → 字节级 patch → 部署到 Reloaded II
```

并通过 **Reloaded II + UnrealEssentials** 加载进游戏（P3R 不支持原生散装 PAK 加载）。

---

## 特性

- 🤖 **自然语言驱动** — Claude Code 作为编排层，理解需求 → 调用工具链
- 🔓 **IoStore 直读** — 基于 CUE4Parse 1.1.1，内置 AES Key，无需手动 FModel 导出
- 🧬 **Zen byte-patch 写回** — 基于 010-Editor schema 就地修改 Zen `.uasset`，P3R 实测可运行
- 📦 **全自动部署** — `schema → patch → UnrealEssentials loose-file install` 一条命令完成
- 📚 **489 个 DataTable JSON 缓存** — 战斗/UI/社群/教程/字典全量快照，秒级查询
- 🛡️ **可逆/可回滚** — 备份/差分/冲突检测脚本（Sprint 2 起）
- 📖 **Wiki 知识库内嵌** — 37 份 Amicitia Wiki Markdown + 精确 ID 映射表
- ⚠️ **避坑指南** — [docs/MODDING_PITFALLS.md](docs/MODDING_PITFALLS.md) 收录已踩坑及修复

---

## 快速开始

### 前置要求

| 组件 | 版本 | 说明 |
|---|---|---|
| Windows | 10 / 11 | |
| PowerShell | 5.1+ | Windows 内置 |
| [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) | 8.0.x | 编译 P3RDataTools |
| Persona 3 Reload | 任意版本 | Steam / Game Pass，需要解密用游戏资产 |
| [Reloaded II](https://github.com/Reloaded-Project/Reloaded-II/releases) | 最新 | Mod 加载器（PAK 模拟） |
| [Claude Code](https://claude.ai/code) | 最新 | AI Agent (可选，命令行也能用) |

### 安装

```powershell
# 1. 克隆
git clone <repo-url> P3R_Modding
cd P3R_Modding

# 2. 配置游戏路径（首次）
copy .env.example .env
notepad .env       # 填入 P3R_PAKS_DIR (P3R 安装目录的 Content/Paks)

# 3. 一键初始化（约 2 分钟，首次需要编译 P3RDataTools）
.\setup.ps1
```

`setup.ps1` 会：检查 .NET → 创建输出目录 → 编译 CLI 工具 → 验证游戏 Paks → 报告 JSON 缓存/模板库状态。

### 安装 Reloaded II（一次性）

1. 从 [Reloaded II Releases](https://github.com/Reloaded-Project/Reloaded-II/releases) 下载并解压到任意目录
2. 运行 `Reloaded-II.exe`，添加 `P3R.exe` 为应用程序
3. 首次启动会自动安装 **P3R Essentials** + **Inaba EXE Patcher**（解锁 Mod 支持）
4. 之后启动游戏必须通过 Reloaded II，**不能 Steam 快捷方式直接启动**

---

## 一分钟实战：做一个 Mod

下面这条命令把 **亚基（火属性单体弱攻击）的 `hpn` 从 40 改成 999**，全程自动：

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999}) `
  -ModName "AgiMod"
```

输出：
```
[1/4] Schema resolved: p3re_skillNormal
[2/4] Preparing changes... Data[10].hpn = 999
[3/4] Executing Zen byte-patch... PATCHED Data[10].hpn 40 -> 999
[4/4] PAK: skipped (default = UnrealEssentials loose files)
[5/5] Installing to Reloaded II...
```

通过 Reloaded II 启动 P3R，亚基现在约为原版 5 倍显示伤害（`hpn` 是显示伤害平方，详见 P-009）。Sprint 1.5 已用 AgiMod / BufuMod / 100× ExpMod 人工实测通过。

> ⚠ **第一次写 Mod 脚本前务必读 [docs/MODDING_PITFALLS.md](docs/MODDING_PITFALLS.md)**。`Data[0]` **不是** 第一个真实技能，而是引擎占位行；改错下标会让 PAK 看似生效实则毫无变化。

---

## 工具链一览

```
┌──────────────────────────────────────────────────────────────────┐
│ 用户/AI Agent: "把 Agi 伤害改成 999"                              │
└────────────────────────────┬─────────────────────────────────────┘
                             ↓
┌──────────────────────────────────────────────────────────────────┐
│ Claude Code (编排层)                                              │
│  • 查 docs/amicitia/DATA_MAPPING.md → 定位 DataTable             │
│  • 查 docs/amicitia/md/*.md → 解析 Skill ID (Wiki)              │
│  • 调用 modify-and-repack.ps1                                    │
└────────────────────────────┬─────────────────────────────────────┘
                             ↓
┌──────────────────────────────────────────────────────────────────┐
│ tools/scripts/modify-and-repack.ps1 (流程编排)                    │
│  ┌──────────┐   ┌──────────────┐   ┌────────────┐   ┌──────────┐ │
│  │Schema/BT │ → │Invoke-ZenPatch│ → │Zen .uasset │ → │UEssentials│ │
│  │  resolve │   │ byte writeback│   │loose file  │   │ install  │ │
│  └──────────┘   └──────────────┘   └────────────┘   └──────────┘ │
│   (010 schema)        (offset + LE scalar write)                 │
└────────────────────────────┬─────────────────────────────────────┘
                             ↓
┌──────────────────────────────────────────────────────────────────┐
│ Reloaded II/Mods/<Name>/UnrealEssentials/P3R/Content/...          │
│         + ModConfig.json (默认依赖 p3rpc.essentials)              │
└────────────────────────────┬─────────────────────────────────────┘
                             ↓
┌──────────────────────────────────────────────────────────────────┐
│ Reloaded II + File Emulation Framework + Inaba EXE Patcher       │
│  → 启动 P3R.exe，Mod 注入                                         │
└──────────────────────────────────────────────────────────────────┘
```

### P3RDataTools CLI

`tools/P3RDataTools/`（.NET 8 + CUE4Parse 1.1.1）提供 5 个核心子命令：

| 命令 | 用途 |
|---|---|
| `read <vpath> <out.json>` | 从 IoStore 解密读取 DataTable → JSON |
| `batch <filter> <dir>` | 按虚拟路径前缀批量导出 |
| `create-template <vpath> <dir>` | ~~生成传统格式模板~~（已弃用主路径，保留备查） |
| `create <json> <dir>` | ~~JSON → .uasset+.uexp+manifest~~（P3R 实测崩溃，别用于新 Mod） |
| `modify <vpath> <json> <dir>` | ~~读 IoStore + 应用修改 → 传统格式输出~~（已弃用） |
| `quick <vpath> <path> <val> <dir>` | ~~单字段快速修改 → 传统格式输出~~（已弃用） |

虚拟路径示例：`P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset`

---

## 项目结构

```
P3R_Modding/
├── CLAUDE.md                    ← AI Agent 工作指南（每次会话加载）
├── README.md                    ← 本文件
├── setup.ps1                    ← 项目初始化
├── .env / .env.example          ← 本地环境变量
│
├── docs/
│   ├── PRD_P3R_AI_AGENT.md      ← 产品需求与验收标准
│   ├── SYSTEM_ARCHITECTURE.md   ← 分层架构与接口设计
│   ├── DEVELOPMENT_PLAN.md      ← Sprint 计划
│   ├── P3R_ASSET_ANALYSIS.md    ← 资产结构分析
│   ├── DEVELOPER_GUIDE.md       ← 开发环境与工作流
│   ├── MODDING_PITFALLS.md      ← ⚠ 避坑指南（写脚本前必读）
│   └── amicitia/
│       ├── DATA_MAPPING.md      ← Wiki ↔ DataTable 精确映射
│       └── md/                  ← 37 份 Wiki Markdown 参考
│
├── tools/
│   ├── P3RDataTools/            ← C# CLI 主工具
│   ├── scripts/
│   │   ├── Config.ps1           ← 共享配置（路径/AES Key/表别名）
│   │   ├── Invoke-ZenPatch.ps1  ← Zen byte-patch 写回引擎
│   │   ├── dsl/P3RModDSL.psm1   ← Mod DSL helper
│   │   └── modify-and-repack.ps1 ← 全流程编排（Zen 默认）
│   ├── templates-010/            ← 010-Editor schema + 38 个 JSON schema
│   ├── templates/                ← 传统格式模板库（已弃用主路径）
│   ├── Output/
│   │   ├── json/                ← 489 个 DataTable JSON 快照（已跟踪）
│   │   ├── mod/                 ← Mod 产物（Git 忽略）
│   │   ├── .backup/             ← 备份（Git 忽略）
│   │   └── Logs/                ← 运行日志（Git 忽略）
│   ├── Reloaded II/             ← Mod 加载器（Git 忽略，体积大）
│   └── UnrealPakTool/           ← UE 4.27 PAK 打包工具
│
├── Paks/                        ← 游戏原始 IoStore（20 GB，未跟踪）
└── Extracted/                   ← 解密提取的资产（48 GB，未跟踪）
```

---

## 文档地图

| 想了解 | 看这里 |
|---|---|
| **第一次上手** | 本文档 → [DEVELOPER_GUIDE.md](docs/DEVELOPER_GUIDE.md) |
| **写 Mod 脚本前的避坑清单** | ⚠ [MODDING_PITFALLS.md](docs/MODDING_PITFALLS.md) |
| **找某个 DataTable 在哪** | [docs/amicitia/DATA_MAPPING.md](docs/amicitia/DATA_MAPPING.md) |
| **查 Skill / Persona / Item 的 ID** | [docs/amicitia/md/](docs/amicitia/md/) |
| **产品需求 / 用户画像 / 验收标准** | [PRD_P3R_AI_AGENT.md](docs/PRD_P3R_AI_AGENT.md) |
| **架构 / 模块设计 / 接口** | [SYSTEM_ARCHITECTURE.md](docs/SYSTEM_ARCHITECTURE.md) |
| **Zen 写回工作流 / DSL / target 语法** | [ZEN_BYTE_PATCH_WORKFLOW.md](docs/ZEN_BYTE_PATCH_WORKFLOW.md) |
| **Sprint 1.5 剩余限制 / 后续待办** | [SPRINT_1_5_TODO.md](docs/SPRINT_1_5_TODO.md) |
| **Sprint 分解 / 里程碑** | [DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md) |
| **资产格式深度分析** | [P3R_ASSET_ANALYSIS.md](docs/P3R_ASSET_ANALYSIS.md) |
| **AI Agent 工作指南** | [CLAUDE.md](CLAUDE.md) |

---

## 可修改的内容范围

| 类别 | 可修改 | 状态 |
|---|---|---|
| 技能数值（伤害/SP 消耗/命中/暴击） | ✅ | MVP |
| Persona 属性/相性/技能习得 | ✅ | MVP |
| 敌人属性/相性/AI 参数 | ✅ | MVP |
| 道具/武器/防具/饰品数值 | ✅ | MVP |
| 商店商品/价格 | ✅ | MVP |
| 玩家升级表/HP·SP 上限 | ✅ | MVP |
| 遇敌表 | ✅ | MVP |
| 文本/本地化（BMD） | 🚧 | Sprint 后期 |
| BGM / 音频流 | ❌ | 当前写回不可靠（cue 元数据可读，AWB 流需外部工具）|
| 模型 / 纹理 / 动画 | ❌ | 独立工具链（FModel 仅可导出） |

---

## 关键约束 & 注意事项

- **UE 4.27** — UnrealPak 和 CUE4Parse 都必须匹配 4.27（PAK version 11）
- **CUE4Parse 锁定 1.1.1** — 1.2.2 的 Zlib-ng.NET 在 P3R 上初始化失败
- **Xrd777 > Astrea** — 同名资产以 Xrd777 容器为准
- **IoStore 只读** — 无法直接覆盖原 utoc/ucas，必须通过 Reloaded II 以传统 PAK 形式注入
- **`Dat*DataAsset` 数组下标 == 资产 ID** — `Data[0]` 通常是引擎占位行，**不是**任何游戏内技能/Persona/道具（[详情](docs/MODDING_PITFALLS.md#p-001-datatable-数组索引--资产-id不要默认改-data0)）
- **Mod PAK 不加密** — UnrealPak 不需要 `-encrypt` 参数
- **不能直接拷 .pak 进游戏 Paks/** — 必须走 Reloaded II + File Emulation Framework

---

## 故障排查

| 症状 | 排查方向 |
|---|---|
| Mod 完全无效果 | 是否通过 Reloaded II 启动游戏？PAK 大小 > 1 KB？改的下标是否对应正确 ID（[P-001](docs/MODDING_PITFALLS.md#p-001-datatable-数组索引--资产-id不要默认改-data0)）？|
| `AgiMod_P.pak` 只有 0.4 KB | UnrealPak 找不到源文件 — 检查 manifest.txt 路径与 .uasset/.uexp 是否成对（[P-002](docs/MODDING_PITFALLS.md#p-002-占位空-pak-不要部署到-reloaded-ii)）|
| 启动崩溃 | UnrealPak 版本是否 4.27？.uasset 和 .uexp 是否都打包了？manifest mount point 是否 `../../../P3R/Content/...`？|
| `setup.ps1` 报缺工具 | 重跑 setup.ps1；或手动 `dotnet publish tools/P3RDataTools -c Release --self-contained -r win-x64 -o publish` |
| AES Key 失败 | 检查 [`tools/scripts/Config.ps1`](tools/scripts/Config.ps1) 中的 `$AesKey`；游戏更新后可能变化 |

更多排查见 [CLAUDE.md "常见问题排查" 章节](CLAUDE.md) 与 [MODDING_PITFALLS.md](docs/MODDING_PITFALLS.md)。

---

## 贡献

踩到新坑请按 [MODDING_PITFALLS.md 末尾的模板](docs/MODDING_PITFALLS.md#模板添加新条目) 追加一节 `P-NNN` 条目，避免他人重蹈覆辙。

---

## 相关项目与致谢

- [CUE4Parse](https://github.com/FabianFG/CUE4Parse) — UE 资产读取库
- [UAssetAPI](https://github.com/atenfyr/UAssetAPI) — UE 资产读写库
- [Reloaded II](https://github.com/Reloaded-Project/Reloaded-II) — Mod 加载器
- [File Emulation Framework](https://github.com/Sewer56/FileEmulationFramework) — 传统 PAK 模拟层
- [Amicitia Wiki](https://amicitia.miraheze.org/) — Persona 系列资产文档
- [FModel](https://github.com/4sval/FModel) — UE 资产浏览器

---

## License

本项目仅用于学习与个人 Mod 制作目的。Persona 3 Reload 的版权归 ATLUS / SEGA 所有。Mod 制作请遵循游戏厂商相关条款；不得用于商业用途、不得分发原版游戏资产。
