# P3R Modding AI Agent

> 本文档由项目目录与工具链状态重新生成（2026-06-25）。
>
> 目的：作为仓库总入口，说明当前可用的 P3R DataTable Mod 制作路径。

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

这是一个面向 **Persona 3 Reload (P3R)** 的 Mod 制作与逆向工程工作区。当前工程重点不是通用 UE 编辑器，而是把中文/自然语言需求落到 P3R DataTable 的安全、可回滚字节修改上。

## 当前能力状态

✅ 已工程化：

- 从 IoStore/Extracted Zen `.uasset` 获取原始 DataTable 资产。
- 用 010-Editor 模板生成/校准 schema。
- 用 `Invoke-ZenPatch.ps1` 对定长标量字段做 little-endian byte patch。
- 用 `modify-and-repack.ps1` 编排 diff、guard、conflict、backup、install。
- 默认部署到 `<Mod>/UnrealEssentials/P3R/Content/...`，由 Reloaded II 启动游戏加载。

⚠️ 边界：

- 文本、本地化、模型、纹理、动画、音频重打包不是当前自动写回能力。
- 传统 `.uasset+.uexp` 产物不作为新 Mod 推荐路径。
- 真实游戏内验证仍需要用户通过 Reloaded II 手动启动 P3R。

## 快速开始

```powershell
copy .env.example .env
notepad .env
.\setup.ps1
```

一分钟 DryRun：

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999}) `
  -ModName 'AgiMod' -DryRun
```

真实生成并安装：

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999}) `
  -ModName 'AgiMod'
```

`Data[10]` 是亚基 / Agi 的 Skill ID；不要改 `Data[0]`。

## 推荐阅读路径

1. 新用户：`docs/USER_GUIDE.md` → `docs/MODDING_PITFALLS.md` → `docs/ZEN_BYTE_PATCH_WORKFLOW.md`
2. 开发者：`docs/DEVELOPER_GUIDE.md` → `docs/SYSTEM_ARCHITECTURE.md` → `tools/templates-010/schemas/README.md`
3. 数据定位：`docs/zh-cn/README.md` → `docs/amicitia/README.md` → `docs/amicitia/DATA_MAPPING.md`
4. 安全与回滚：`docs/SECURITY.md` → `docs/MANUAL_TEST_TODO.md`

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
