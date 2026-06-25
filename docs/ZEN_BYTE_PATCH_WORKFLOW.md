# Zen Byte-Patch 写回工作流

> 本文档由项目目录与工具链状态重新生成（2026-06-25）。备份位置：tools/Output/.backup/docs-regeneration-20260625-120053/。
>
> 目的：记录当前 P3R 唯一推荐的写回链路。

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

## 输入

- 从 IoStore/Extracted 获得的 Zen 单文件 `.uasset`。
- 已校准的 schema JSON：`tableShape`、`headerSize`、`rowSize`、字段 offset/type。
- changes：例如 `Data[10].hpn = 999`。

## Offset 公式

| tableShape | 公式 |
|---|---|
| `indexed_rows` | `headerSize + rowIndex * rowSize + field.offset` |
| `named_rows` | `headerSize + row.offset + field.offset` |
| `single_record` | `headerSize + field.offset` |
| `single_record_array` | `headerSize + repIndex * repeatStride + field.offset` |

## 安全断言

- 输出文件大小必须与源 Zen `.uasset` 一致。
- 不生成 `.uexp`。
- 不 patch string/TArray/union/nested struct array。
- DryRun 应能显示目标 offset、旧值、新值。
- 安装路径必须完整镜像虚拟路径：`UnrealEssentials/P3R/Content/.../<asset>.uasset`。

## 示例

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999}) `
  -ModName 'AgiMod' -DryRun
```

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
