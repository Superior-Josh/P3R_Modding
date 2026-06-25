# 系统架构

> 本文档由项目目录与工具链状态重新生成（2026-06-25）。备份位置：tools/Output/.backup/docs-regeneration-20260625-120053/。
>
> 目的：描述自然语言 Agent 到 P3R Mod 产物的分层架构。

## 当前仓库快照

| 项 | 当前值 |
|---|---:|
| 重生成 Markdown 目标 | 74 |
| tools/Output/json/**/*.json | 490 |
| tools/templates-010/**/*.bt | 48 |
| tools/templates-010/schemas/*_schema.json | 38 |
| tools/scripts PowerShell 模块/脚本 | 17 |
| Amicitia Markdown 参考页 | 37 |
| 中文译名 Markdown 文件 | 8 |

## 分层

```text
用户/Agent
  ↓
需求解析与数据定位（zh-cn + Amicitia + JSON cache）
  ↓
修改计划（changes / target / value）
  ↓
安全层（diff / guard / conflict / backup）
  ↓
Zen byte-patch（schema + offset + endian）
  ↓
Reloaded II Mod（UnrealEssentials loose file）
  ↓
P3R.exe
```

## 文件接口

| 文件 | 角色 |
|---|---|
| `changes.json` / inline `-Changes` | 目标字段与新值 |
| `*_schema.json` | row/header/field offset 与安全元数据 |
| `mod.json` | 单个 Mod 的生成记录 |
| `history.json` | 当前运行审计 |
| `.backup/<ModName>/...` | 回滚快照 |
| `.data/mod_registry.json` | 本地 Mod 冲突/注册表状态 |

## 核心约束

架构不尝试重序列化 UE 资产，而是对已知布局的 Zen 单文件做定长标量 patch。因此它稳定、可审计，但只覆盖 schema 已校准且 guard 放行的字段。

## 必须遵守的项目事实

- 当前唯一推荐写回路径是 **Zen 单文件 `.uasset` byte-patch**，再通过 Reloaded II + UnrealEssentials 散文件挂载。
- `P3RDataTools create/modify/quick/create-template` 仍存在，但属于传统 `.uasset+.uexp` 路径；新 Mod 不应把它们当主写回方案。
- `Data[N]` 的 N 通常就是游戏资产 ID；不要默认修改 `Data[0]`。
- Skill 表 `hpn` 是显示伤害的平方语义；把伤害改为 N 倍时应按 N² 换算。
- 自动写回仅面向 guard 放行的定长标量字段；string、TArray、union、nested struct array、变长字段默认拒绝自动 patch。
- `Paks/`、`Extracted/`、`tools/Reloaded II/`、`tools/UnrealPakTool/`、`tools/Output/.data/` 是本地/生成/忽略目录，不应提交原版游戏资产或个人配置。

## 关键入口

| 用途 | 文件/命令 |
|---|---|
| 主流程 | `tools/scripts/modify-and-repack.ps1` |
| Zen 字节写回 | `tools/scripts/Invoke-ZenPatch.ps1` |
| DSL helper | `tools/scripts/dsl/P3RModDSL.psm1` |
| 数据定位 | `tools/scripts/tools/search-datatable.ps1`、`search-wiki.ps1` |
| 预览与安全 | `diff-changes.ps1`、`guard-modify.ps1`、`conflict-check.ps1` |
| 备份/回滚 | `backup-mod.ps1`、`rollback-mod.ps1` |
| schema 链 | `Parse-BtTemplate.ps1`、`Calibrate-SchemaHeaders.ps1`、`Test-SchemaRegression.ps1` |
