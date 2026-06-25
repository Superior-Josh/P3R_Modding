# P3R Mod 制作避坑指南

> 本文档由项目目录与工具链状态重新生成（2026-06-25）。备份位置：tools/Output/.backup/docs-regeneration-20260625-120053/。
>
> 目的：集中记录项目已确认的事实性陷阱，避免脚本和文档复刻错误。

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

## P-001 DataTable 数组索引通常等于资产 ID

`Data[0]` 常是占位行。Agi/亚基是 Skill ID 10，因此应改 `Data[10]`。

## P-002 空 PAK 不要部署

小于 1 KB 的 PAK 多半只是 header。当前默认不走 PAK；若用 fallback，必须检查大小和 manifest。

## P-003 直接复制 `.pak` 到游戏 `Paks/` 不会生效

P3R Mod 应通过 Reloaded II 加载。默认使用 UnrealEssentials 散文件路径。

## P-004 写示例前先查真实 JSON 字段名

Skill 伤害字段是 `hpn`，消耗是 `cost`，命中示例字段是 `hitratio`；不要凭印象写 `dmg`、`Power`、`SPCost`。

## P-005 默认走 UnrealEssentials 散文件

结构：`<Mod>/UnrealEssentials/P3R/Content/<虚拟路径>`。

## P-006 UE DataTable 字段可能带 GUID 后缀

`DT_*` 表 row 字段名可能是 `ExpRate_10_...`，必须用完整 key 或 schema 的规范化策略。

## P-007 P3R 偏好 Zen 单文件，不推荐传统 `.uasset+.uexp`

P3RDataTools 的传统写回命令保留为 legacy，不作为新 Mod 主路径。

## P-008 ModConfig 默认依赖

项目默认依赖 `p3rpc.essentials`；极简资产替换可仅用 `UnrealEssentials`，但需保持与实际安装一致。

## P-009 `hpn` 是显示伤害平方

用户说“伤害 N 倍”时，`hpn` 应按 N² 换算，而不是线性乘 N。

## P-010 union/复杂 struct 禁止直接 byte-patch

可能导致 `Bad name index` 或资产崩溃；guard 应阻断。

## P-011 难度参数只影响对应难度行

验证经验/倍率类 Mod 时，游戏当前难度必须和 patch 行一致。

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
