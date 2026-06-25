# 用户指南

> 本文档由项目目录与工具链状态重新生成（2026-06-25）。备份位置：tools/Output/.backup/docs-regeneration-20260625-120053/。
>
> 目的：把中文 Mod 需求安全地转换为可预览、可回滚的 P3R DataTable 修改。

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

## 标准流程

1. **定位**：用中文名、英文名或 ID 查询目标。
2. **预览**：先跑 `-DryRun` 或 `diff-changes.ps1`，确认字段、旧值、新值、offset。
3. **安全检查**：真实写回前必须通过 guard；冲突至少要被检查并说明。
4. **写回**：用 Zen byte-patch 生成单文件 `.uasset`。
5. **部署**：默认安装到 Reloaded II Mod 的 `UnrealEssentials/P3R/Content/...` 路径。
6. **验证**：通过 Reloaded II 启动 P3R；必要时手动记录游戏内结果。
7. **回滚**：先 `rollback-mod.ps1 -Preview`，获得授权后再 `-Force`。

## 中文需求示例

```powershell
.\tools\scripts\tools\search-datatable.ps1 -Query '亚基' -Field hpn
.\tools\scripts\tools\diff-changes.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999})
.\tools\scripts\tools\guard-modify.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999})
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999}) -ModName 'AgiMod'
```

## 常见修改入口

| 需求 | 推荐方式 |
|---|---|
| 技能伤害/消耗 | `TableKey Skills` 或 DSL `Set-SkillHpn` / `Set-SkillCost` |
| Persona 等级/能力 | DSL `Set-PersonaLevel` / `Set-PersonaStat` |
| 敌人 HP/SP/能力 | DSL `Set-EnemyHP` / `Set-EnemySP` / `Set-EnemyStat` |
| 难度经验倍率 | `Set-DifficultyParam -Difficulty normal -Field ExpRate -Value ...` |
| 批量调整 | `tools/scripts/tools/batch-modify.ps1` |

## 用户必须确认的事项

- 是否通过 Reloaded II 启动，而不是 Steam/桌面快捷方式。
- Mod 是否在 Reloaded II 中启用。
- 当前游戏难度是否与修改的难度行一致。
- 如果使用 `-Force`、`-SkipGuard`、`-SkipConflictCheck`，必须明确知道风险。

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
