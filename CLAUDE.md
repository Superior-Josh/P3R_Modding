# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此仓库中工作时提供指导。

## 项目概述

这是一个 **Persona 3 Reload (P3R) 逆向工程与 Mod 制作工作区**，而非传统的软件项目。包含解包后的游戏资产文件以及用于提取、分析和重新打包虚幻引擎（Unreal Engine）游戏资产的工具链。本仓库没有构建系统、包管理器或测试套件。

### 项目目标

对 P3R（女神异闻录 3 Reload）进行 Mod 制作，包括但不限于以下内容的修改：

- **数值**：角色属性、技能数值、经验曲线、掉落率等 DataTable 数据
- **敌人 AI**：敌方行为树、战斗逻辑、技能使用策略
- **文本**：对话文本、UI 文字、技能描述、本地化内容
- **音乐/音频**：BGM 替换、音效修改、语音包
- **模型**：角色模型、武器模型、场景道具的网格体与材质
- **粒子特效**：技能特效、环境粒子、UI 动效
- **事件/剧情**：事件脚本、过场动画、任务触发条件

权威参考文档为 `docs/UE_MODDING_GUIDE.md`——一份详尽的中文指南，覆盖了从资产提取到重新打包的完整 Mod 制作流程。

## 资产存储格式

游戏以**两种并行的容器格式**存储资产（UE4/UE5 混合）：

| 格式 | 文件 | 说明 |
|--------|-------|-------------|
| **传统 PAK** | `.pak` | UE4 时代归档格式，AES-256 加密，Zlib/Oodle 压缩 |
| **IoStore** | `.ucas` + `.utoc` | UE5 时代容器格式；`.utoc` = 目录索引，`.ucas` = 原始数据 |

两种格式共存于 `Paks/` 目录下。PAK 文件使用 **AES-256 加密**并启用了索引签名。解密密钥位于 `tools/UnrealPakTool/Crypto.json`。

## 工具链

### FModel (`tools/FModel.exe`)
用于浏览和导出 UE 资产的 GUI 应用程序。同时支持 `.pak` 和 IoStore（`.ucas/.utoc`）。常用于：
- 浏览资产树结构
- 将 DataTable 导出为 JSON
- 提取纹理为 PNG
- 导出大块二进制数据（BulkData）

### UnrealPak (`tools/UnrealPakTool/UnrealPak.exe`)
UE 4.27 命令行 PAK 操作工具。配套 DLL（Core、CoreUObject、PakFile 等）必须与 exe 放在同一目录。

**常用命令：**

```powershell
# 查看 PAK 内容列表
UnrealPak.exe "..\..\Paks\pakchunk0-WindowsNoEditor.pak" -List

# 测试 PAK 完整性
UnrealPak.exe "..\..\Paks\pakchunk0-WindowsNoEditor.pak" -Test

# 带解密提取
UnrealPak.exe "..\..\Paks\pakchunk0-WindowsNoEditor.pak" -Extract "OutputDir" -cryptokeys=Crypto.json

# 创建 Mod PAK
UnrealPak.exe "MyMod_P.pak" -Create="manifest.txt" -compress

# 使用 Oodle 压缩创建
UnrealPak.exe "MyMod_P.pak" -Create="manifest.txt" -compress=Oodle
```

**便捷批处理脚本**（在 `tools/UnrealPakTool/` 目录下运行）：
- `UnrealPakExtract.bat` — 不带解密提取所有 `.pak` 文件
- `UnrealPakExtractCrypto.bat` — 使用 `Crypto.json` 带 AES 解密提取所有 `.pak` 文件

## Mod 制作流程

### 1. 资产提取
使用 FModel（GUI）或 UnrealPak（CLI）配合 `Crypto.json` 中的 AES 密钥提取资产。FModel 可自动检测 UE 版本；使用命令行时，本游戏的 PAK 版本为 **UE 4.27**（pak version 11）。

### 2. 资产修改
- **DataTable** → 通过 FModel 导出为 JSON → 编辑数值 → 通过 UAssetGUI 导回
- **纹理** → 通过 FModel 导出为 PNG → 编辑 → 通过 UAssetGUI 替换 BulkData 引用
- **蓝图属性** → 在 UAssetGUI 中打开 `.uasset` + `.uexp` 对 → 修改 ClassDefaultObject 属性
- 资产由 `.uasset`（文件头/元数据）+ `.uexp`（导出数据）+ 可选的 `.ubulk`（大块二进制数据）组成——修改时，如果原始资产包含这三者，则 Mod PAK 中也必须全部包含。

### 3. 创建清单文件
`manifest.txt` 将源文件映射到 PAK 挂载路径：

```
"Game/Blueprints/BP_Enemy.uasset" "../../../Game/Blueprints/BP_Enemy.uasset"
"Game/Blueprints/BP_Enemy.uexp" "../../../Game/Blueprints/BP_Enemy.uexp"
```

### 4. 重新打包
使用 `UnrealPak.exe Output_P.pak -Create=manifest.txt -compress`

### 5. Mod 加载优先级
UE 按 ASCII 字典序加载 PAK 文件。`_P` 后缀具有最高优先级：
- `pakchunk0-WindowsNoEditor.pak`（优先级最低）
- `MyMod_P.pak`（优先级最高——覆盖所有原始文件）

将 Mod PAK 放置在游戏的 `Content\Paks\` 目录下。

## AES 密钥

位于 `tools/UnrealPakTool/Crypto.json`：
```
Key: krrf4pIbN2Bp096FQWltIwuga15DIAhN00om0RfS/+4=
```
这是一个 Base64 编码的 256 位密钥。游戏启用了索引签名、索引加密、ini 加密和 uasset 加密，但未启用全量资产加密。

## 关键约束

- UnrealPak 版本**必须匹配**游戏的 UE 版本（4.27）。版本不匹配会导致打包失败或游戏崩溃。
- 带 `_P` 后缀的 Mod PAK 优先级高于数字编号的分片（`pakchunk0`、`pakchunk1` 等）。
- 本仓库不是 git 仓库——没有版本控制。
- 所有文档均为中文；`UE_MODDING_GUIDE.md` 是操作流程的唯一权威参考。
