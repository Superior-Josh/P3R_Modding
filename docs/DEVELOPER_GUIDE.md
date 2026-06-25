# 开发者指南

> 本文档由项目目录与工具链状态重新生成（2026-06-25）。备份位置：tools/Output/.backup/docs-regeneration-20260625-120053/。
>
> 目的：说明当前工具链、脚本职责、schema 生成与扩展方式。

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

## 环境

- Windows 10/11 + PowerShell 5.1+
- .NET 8 SDK
- P3R 本地游戏资产（`Paks/` 或 `.env` 指向的路径）
- Reloaded II 与 UnrealEssentials/p3rpc.essentials

## 目录职责

| 目录 | 说明 |
|---|---|
| `tools/P3RDataTools/` | C# CLI，负责读取 IoStore/DataTable JSON；传统写回命令保留但不推荐新 Mod 使用 |
| `tools/scripts/` | PowerShell 主工具链与 DSL |
| `tools/templates-010/` | 010 模板、schema 与回归报告 |
| `tools/Output/json/` | DataTable JSON 缓存 |
| `tools/Output/mod/` | 生成 Mod 输出（忽略） |
| `tools/Output/.backup/` | 备份与回滚数据（忽略） |
| `docs/amicitia/` | 英文 Wiki/ID/资产映射参考 |
| `docs/zh-cn/` | 中文标准译名参考 |

## 构建

```powershell
.\setup.ps1
# 或手动
 dotnet publish .\tools\P3RDataTools\P3RDataTools.csproj -c Release --self-contained -r win-x64 -o .\tools\P3RDataTools\publish
```

注意：PowerShell 配置与 `.env` 负责项目路径；C# CLI 代码中仍有本机路径遗留，跨机器使用前应验证。

## 新增表支持

1. 确认虚拟路径与 JSON cache。
2. 添加/修复 010 `.bt` 模板。
3. 用 `Parse-BtTemplate.ps1` 生成 schema。
4. 用 `Calibrate-SchemaHeaders.ps1` 校准 `headerSize`。
5. 用 `Test-SchemaRegression.ps1` 对比 CUE4Parse JSON。
6. 在 `Config.ps1` 添加 TableKey/SchemaKey 映射。
7. 只把 PASS + flat scalar 或显式 safeWithNormalization 字段接入 guard 自动放行。

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
