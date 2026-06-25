# 开发计划

> 本文档由项目目录与工具链状态重新生成（2026-06-25）。备份位置：tools/Output/.backup/docs-regeneration-20260625-120053/。
>
> 目的：用当前项目状态重整 Sprint 路线与剩余工作。

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

## 已完成基线

- Sprint 1.5：Zen byte-patch 主路径工程化。
- Sprint 2/3：diff、guard、backup、rollback、conflict、registry/history 接入主 pipeline。
- Sprint 4：schema coverage 与批量/边界测试文档已出现，仍需按真实输出持续校正。

## 当前优先级

1. 修复/完善 PARTIAL schema 的人工复核元数据。
2. 提升 `schema-coverage-report.ps1` 输出质量，避免 PowerShell 对象未展开。
3. 为更多常用 DataTable 添加 PASS + guard allowlist。
4. 将 C# CLI 的路径配置从硬编码迁移到配置/环境变量。
5. 补充真实游戏内人工验证记录。

## 长期方向

- 更完整的中文自然语言解析。
- 更安全的批量 Mod 组合与冲突解释。
- 文本/本地化、音频、UI 等非 DataTable 领域的研究，但不得在未验证前写成已支持。

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
