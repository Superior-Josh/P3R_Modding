# P3R Modding AI Agent 用户指南

> **版本**: Sprint 4 初稿（2026-06-25）  
> **当前状态**: Zen byte-patch 数值类 Mod 主路径可用；真实游戏验证仍需用户通过 Reloaded II 人工执行。  
> **安全原则**: 默认先 DryRun / diff / guard / conflict；真实覆盖和回滚必须先 Preview 并获得明确授权。

## 1. 适用范围

本工具链用于制作 Persona 3 Reload 的 DataTable 数值类 Mod，默认输出为 UnrealEssentials 散文件：

```text
<ModName>/UnrealEssentials/P3R/Content/.../<Asset>.uasset
```

当前已验证主路径：

- 技能数值，例如亚基 / 布芙的 `hpn`
- Persona 基础数值，例如等级
- 难度参数，例如 Normal `ExpRate`
- 其它 `regressionStatus=pass` 且 flat scalar 的字段

不自动支持：

- 文本 / 本地化字符串
- `TArray` / string / 变长字段
- union / nested struct array
- `regressionStatus=fail/skip/partial` 且未人工复核字段
- 传统 `.uasset+.uexp` 写回路径

## 2. 基本流程

### 2.1 预览单表修改

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999}) `
  -ModName AgiMod `
  -DryRun
```

该命令只执行 diff / guard / conflict / Zen dry-run，不安装 Mod。

### 2.2 只生成工作产物，不安装

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999}) `
  -ModName AgiMod `
  -NoInstall
```

产物位于：

```text
tools/Output/mod/AgiMod/
```

### 2.3 安装到 Reloaded II

确认 DryRun / NoInstall 输出无误后，去掉 `-NoInstall`：

```powershell
.\tools\scripts\modify-and-repack.ps1 -TableKey Skills `
  -Changes @(@{target='Data[10].hpn'; value=999}) `
  -ModName AgiMod
```

安装后需要：

1. 打开 Reloaded II
2. 启用目标 Mod
3. 通过 Reloaded-II.exe 启动 P3R
4. 在游戏内观察效果

## 3. 中文需求注意事项

用户使用中文名时，应先定位标准译名与 ID：

```powershell
.\tools\scripts\tools\search-datatable.ps1 -Query "亚基" -Field hpn
```

注意：技能表的 `hpn` 是显示伤害的平方。若需求是“把亚基伤害改成 N 倍”，应写入：

```text
新 hpn = 原 hpn × N²
```

例如亚基原 `hpn=40`，5 倍显示伤害应写 `40 × 25 = 1000`；PoC 中 `999` 约等于 5 倍。

## 4. 多表 Mod

Sprint 4 起支持 `-MultiChangesJson`：

```json
{
  "tables": [
    {
      "tableKey": "Skills",
      "changes": [
        { "target": "Data[10].hpn", "value": 999 }
      ]
    },
    {
      "tableKey": "Difficulty",
      "changes": [
        { "target": "Rows.normal.ExpRate", "value": 2.0 }
      ]
    }
  ]
}
```

调用：

```powershell
.\tools\scripts\modify-and-repack.ps1 `
  -MultiChangesJson .\multi-changes.json `
  -ModName MyMultiMod `
  -NoInstall
```

建议先 `-DryRun -NoInstall`，人工确认后再安装。

## 5. 批量修改

`batch-modify.ps1` 可把筛选结果转成批量 changes，再交给主 pipeline。

### 5.1 按 ID 批量修改

```powershell
.\tools\scripts\tools\batch-modify.ps1 -TableKey Skills `
  -Field hpn -Value 41 `
  -Ids 118,119 `
  -ModName BatchSkillMod `
  -PreviewOnly
```

### 5.2 按字段条件筛选

```powershell
.\tools\scripts\tools\batch-modify.ps1 -TableKey Skills `
  -Field cost -Value 1 `
  -WhereField costtype -WhereOperator eq -WhereValue 2 `
  -ModName LowCostSkills `
  -DryRun -NoInstall
```

支持的 `WhereOperator`：`eq`、`ne`、`gt`、`ge`、`lt`、`le`、`match`。

## 6. Schema 覆盖报告

生成安全覆盖报告：

```powershell
.\tools\scripts\tools\schema-coverage-report.ps1
```

输出：

- `docs/SCHEMA_COVERAGE_REPORT.md`
- `tools/templates-010/schemas/schema-safety-coverage.json`

只有 allowlist 中的 flat scalar 字段适合自动写回；denylist / PARTIAL 字段应先人工复核。

## 7. 备份、冲突与回滚

### 7.1 冲突检测

```powershell
.\tools\scripts\tools\conflict-check.ps1 -All
```

`error` 会阻断，`warning/info` 可继续但需要说明。

### 7.2 备份

```powershell
.\tools\scripts\tools\backup-mod.ps1 -ModName AgiMod -Description "before tweak"
.\tools\scripts\tools\backup-mod.ps1 -ModName AgiMod -List
```

### 7.3 回滚预览

```powershell
.\tools\scripts\tools\rollback-mod.ps1 -ModName AgiMod -Preview
```

真实回滚必须确认后才使用：

```powershell
.\tools\scripts\tools\rollback-mod.ps1 -ModName AgiMod -Force
```

## 8. 常见失败与处理

| 症状 | 可能原因 | 处理 |
|---|---|---|
| guard 拒绝 | schema fail/skip/partial 或字段需人工复核 | 查看 `docs/SCHEMA_COVERAGE_REPORT.md` |
| conflict 阻断 | 其它 Mod 修改同一字段且值不同 | 选择一个 Mod 负责该字段，或明确 `-Force` |
| Mod 不生效 | 未通过 Reloaded II 启动、路径错误、Mod 未启用 | 检查 `UnrealEssentials/P3R/Content/...` 镜像路径 |
| 游戏崩溃 | 改到不安全字段或用了传统 `.uasset+.uexp` | 禁用 Mod，回滚，检查 guard 与 P-007/P-010 |

## 9. 人工测试暂缓清单

当前暂缓的人工测试见：

- [`docs/MANUAL_TEST_TODO.md`](MANUAL_TEST_TODO.md)（含 Sprint 3/4 暂缓项与 C 节边界/negative 测试矩阵）

在执行真实游戏验证或破坏性回滚前，应先阅读对应条目并确认授权。
