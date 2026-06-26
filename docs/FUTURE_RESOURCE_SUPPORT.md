# 非 DataTable 资源支持路线图（音乐 / 文本 / 模型）

> **状态日期**: 2026-06-26
> **定位**: 本文汇总 P3R **非 DataTable 资源**（文本/本地化、音乐/音频、模型/纹理/动画）的社区可行路线与本仓库的接口定位。当前这些类别在仓库内**均未实现为内置写回**，但本文确认社区已有多条独立于本仓库引擎的可行创作路线。
>
> ⚠️ **不要向用户承诺这些类别"已支持"**。当前唯一已工程化、已人工实测的写回路径是 **Zen 单文件 `.uasset` byte-patch + UnrealEssentials 散文件挂载**，且仅覆盖**定长标量型 DataTable** 字段。

---

## 1. 为什么本仓库引擎做不了：统一技术瓶颈

当前写回引擎（[Invoke-ZenPatch.ps1](../tools/scripts/Invoke-ZenPatch.ps1)）是**就地字节修改**，不重新序列化，硬断言：

```text
output file size == original file size
```

| 能改 | 不能改 |
|---|---|
| `ubyte` / `short` / `int32` / `float` / enum 底层整数 / 固定 offset flat scalar | string、TArray 变长数组、增删 row、改 NameMap/ImportMap/ExportMap、对象引用结构、union 语义结构 |

文本、模型顶点、音频流本质都是**变长 / 二进制结构**。改它们会改变文件总字节数 → 破坏 size-invariant → 后续 offset 全部错位、TOC 指针失效。因此这类需求在本仓库引擎能力之外。详见 [ZEN_BYTE_PATCH_WORKFLOW.md §6.4](ZEN_BYTE_PATCH_WORKFLOW.md#54-string--tarray--变长字段)。

但社区**绕开**了这个问题——不是靠 Zen byte-patch，而是走**独立的完整资产创作管线**：全文以下路线均不依赖本仓库引擎。

---

## 2. 文本 / 本地化

### 现状

文本修改是非 DataTable mod 中社区成熟度最高的方向。本仓库未实现内置支持，但社区已验证**两条独立可行路线**，且 P3R 的文本替换具体实例（`p3rpc.ui.barionskillnames` 替换 L10N 名称表）已在本仓库中确认可运行（见 [MODDING_PITFALLS.md P-005](MODDING_PITFALLS.md#p-005)）。

### 涉及文件

| 类别 | 路径 | 文件举例 |
|---|---|---|
| L10N 名称表 | `P3R/Content/L10N/{lang}/Xrd777/UI/Tables/` | `DatSkillNameDataAsset.uasset` |
| 事件文本 | `P3R/Content/L10N/{lang}/Xrd777/Events/{Cmmu,Main,Extr,Qest}/` | `BMD_Event_Cmmu_221_013_C.uasset` |
| 描述/帮助 | `P3R/Content/Xrd777/Help/` | `BMD_SkillHelp.uasset`、`BMD_PersonaHelp.uasset` |
| 游戏内字典 | `P3R/Content/Xrd777/Dictionary/` | `BMD_Dictionary_001~086.uasset` |
| NPC 对话 | `P3R/Content/Xrd777/Field/Data/DataAsset/Bf/Npc` | 文本在 L10N 对应语言目录 |
| UI 文本 | `P3R/Content/Xrd777/` | `UITextDataAsset.uasset` |
| 本地化元数据 | `P3R/Content/Localization/Game/` | `.locres` 资源文件 |

详见 [P3R_ASSET_ANALYSIS.md §3.3](P3R_ASSET_ANALYSIS.md)。

---

### 可行路线 A：AtlusScriptToolchain CLI + BMD Emulator（推荐，最轻量）

**可行性评估**：⭐ 已验证（P3P/P4G/P5R PC 确认兼容；P3R 工具链支持已在 AtlusScriptToolchain 中实现）

#### 技术原理

P3R 的对话/描述文本存储在 **BMD（Binary Message Data）** 格式中，内嵌在 `.uasset` 内。社区工具 **AtlusScriptToolchain**（TGE 维护，[GitHub](https://github.com/TGEnigma/AtlusScriptToolchain)，2025-03 更新）提供完整反编译/回编译支持。

**文件格式**：BMD 是 Atlus 自定义的消息脚本格式，包含：
- 消息条目（`[msg MSG_ID]`）：唯一标识符
- 对话文本（支持 `[n]` 换行、`[e]` 结束等控制码）
- 标记代码（`[uf 0 5 65278]` 系列）：控制说话人名称、立绘 ID、表情 ID、服装 ID、语音 Cue、红晕/汗滴等覆盖层开关
- 时间戳标记（`[s Wait x]`）：语音与文本同步延时

#### 完整工作流

```text
# 1. 反编译（从 .uasset 提取可编辑 .msg）
AtlusScriptCompiler.exe -In BMD_target.uasset `
  -Decompile -InFormat MessageScriptBinary -Encoding UTF-8 `
  -OutFormat V1RE -Library P3RE

# 产出文件：
#   BMD_target.bmd           — 解封装后的纯 BMD
#   BMD_target.bmd.msg       — 可编辑文本文件（核心产出）
#   BMD_target.bmd.h         — 消息 ID 常量参考（辅助）

# 2. 编辑 .msg
# 纯文本格式，用任意文本编辑器（Notepad++ 等）修改。
# 可以只改对话文本，也可以改说话人/立绘/音频等标记。
# 注意：标记码是八进制数值，不要破坏格式结构。

# 3. 回编译（生成替换用 .uasset）
AtlusScriptCompiler.exe -In BMD_target.bmd.msg `
  -Compile -Encoding UTF-8 -OutFormat V1RE -Library P3RE `
  -UPatch BMD_target.uasset

# 产出：修补后的 .uasset（保持与原文件同结构）
```

**关键参数说明**：

| 参数 | 含义 |
|---|---|
| `-OutFormat V1RE` | V1RE = P3R 使用的 BMD 版本格式（Reload 引擎） |
| `-Library P3RE` | 指定游戏库版本：Persona 3 Reload Engine |
| `-UPatch` | 以原 `.uasset` 为模板生成 uasset 容器，免去从头打包 UE 资产头 |
| `-InFormat MessageScriptBinary` | 输入是二进制消息脚本（非纯文本） |

**图形化替代**：[Atlus Script GUI](https://gamebanana.com/tools/12526)（ShrineFox，2024-12 更新）提供拖放操作，免去记忆 CLI 参数。

#### 部署方式

**方式 1 — 散文件替换（推荐）**：
```text
<Mod>/UnrealEssentials/P3R/Content/.../<target>.uasset
```
替换用回编译产物的 `.uasset` 直接按虚拟路径镜像放置。这是 **barionskillnames 已验证的模式**。

**方式 2 — BMD Emulator 运行时覆盖（更轻量）**：
通过 [FileEmulationFramework BMD Emulator](https://sewer56.dev/FileEmulationFramework/emulators/bmd.html)（v1.0.0，Reloaded II 依赖 `reloaded.universal.fileemulationframework.bmd`）：
- 只需在 Mod 目录新建 `FEmulator/BMD/` 文件夹
- 放入 `.msg` 文件（与目标 BMD 同名，如 `BMD_SkillHelp.msg`）
- **只包含需要改动的消息条目**，消息名保持与原始一致
- Emulator 在运行时 hook BMD 加载，用 `.msg` 中的条目覆盖对应消息
- 测试验证：P3P、P4G、P5R（PC），P3R 理论上兼容（同为 V1RE 格式）

#### 优点与局限

| 优势 | 局限 |
|---|---|
| 无需 UE 编辑器 | 涉及 UE 资产头的字段（非 BMD 部分）不能改 |
| 文本级修改，所见即所得 | BMD 内嵌的标记码需要理解结构 |
| BMD Emulator 方式只需改动的条目 | 替换角色/事件文本需要定位精确的 BMD 文件名 |
| GameBanana 有完整教程 (tuts/17261) | — |

---

### 可行路线 B：L10N 名称表散文件替换（本仓库已验证）

**可行性评估**：⭐ 已验证（`p3rpc.ui.barionskillnames` 本仓库实测可运行）

#### 技术原理

P3R 的 DataTable 名称表（如 `DatSkillNameDataAsset.uasset`）存储在 `L10N/{lang}/` 目录中。与 Zen byte-patch 不同，**整文件替换**这些 L10N 资产不需要 size-invariant——直接用 `utoc-extractor` 或 FModel 提取原件，替换文本内容后整文件放回即可。

#### 工作流

```text
FModel / utoc-extractor 提取原件
  → 用 UE 工具或 hex 编辑替换名称表内的字符串数据
  → 保持文件名和虚拟路径一致
  → 部署到 <Mod>/UnrealEssentials/P3R/Content/L10N/{lang}/...
```

#### 适用范围

| 适用 | 不适用（用路线 A） |
|---|---|
| 名称/标签等固定长度表（`DatSkillName`、`DatItemName`） | 对话/事件文本（BMD 格式） |
| 无需解析 BMD 格式的纯名称数据 | 带标记码和语音同步的复杂文本 |

---

### 可行路线 C：UE 4.27.2 重 cook 工程

**可行性评估**：🟡 理论上完整，但操作成本高

详见 §1.4。在 P3R-Project 中直接用 `BmdAssetPlugin` 编辑 BMD 资产，cook 产出 IoStore 兼容产物。适合需要大规模修改文本（如完整汉化/翻译 Mod）的场景。但在文本修改方向上，**路线 A 和 B 更轻量**，优先度低于前两者。

---

### 可行路线 D：JsonAsAsset + FModel JSON → UE 工程导入

**可行性评估**：🟡 理论上可行（JsonAsAsset v1.4.1 明确支持 DataTable/StringTable 导入），受限 UE4 版本兼容性

#### 技术原理

**[JsonAsAsset](https://github.com/JsonAsAsset/JsonAsAsset)**（MIT 协议，最新版 1.4.1，2025-04 更新）是一个 UE 插件，核心能力：**读取 FModel/CUE4Parse 导出的 JSON properties → 在 UE 编辑器中重建为即用的 `.uasset` 资产**。它充当从"已 cook 打包的二进制资产"到"编辑器可编辑资产"的反序列化桥接。

FModel 对 UE 资产的导出有两种模式：
1. **原始导出（Raw Data）**：直接输出二进制 `.uasset` + `.uexp` + `.ubulk`
2. **属性导出（Save Properties）**：调用 CUE4Parse 反序列化资产，输出人类/机器可读的 **JSON 结构**

JsonAsAsset 吃的是**模式 2 的 JSON**，将其反向重建为 UE 编辑器中的真实资产。

#### 适用文件类型

| 资产类型 | JsonAsAsset 支持 | 对文本/本地化的意义 |
|---|---|---|
| **StringTable** | ✅ 明确支持 | UI 文本以 StringTable 存储 → JSON 编辑 → cook 替换 |
| **DataTable** | ✅ 明确支持 | L10N 名称表（`DatSkillNameDataAsset` 等） |
| **DataAsset** | ✅ 明确支持 | 配置型 DataAsset 可走此路线 |
| **UserDefinedEnum / UserDefinedStruct** | ✅ 明确支持 | 枚举/结构体定义 |

#### 工作流

```text
游戏容器 (.utoc/.ucas/.pak)
  → FModel 浏览并 Save Properties
  → 生成 JSON（每资产一个 .json）
  → JsonAsAsset 导入 UE 工程
  → 在 UE 编辑器中修改/替换文本
  → Cook for Windows
  → 产出 .uasset / .uexp（或 IoStore .utoc/.ucas）
  → UnrealEssentials 散文件挂载
  → 游戏
```

**关键依赖**：JsonAsAsset 重建资产时会执行 UE 反序列化，如果资产引用了自定义 C++ 类（如 `UAppDataAsset` 子类），这些类必须在工程中已定义。P3R-Project（§1.4）的 `Source/xrd777/Public/` 含约 400+ `.h` 头文件正好提供这些类定义——**两者天然互补**。

#### 实操可行性

| 层次 | 评估 | 条件 |
|---|---|---|
| StringTable / 纯 DataTable 文本 | 🟢 理论上完全可行 | FModel JSON 信息完整；不需要额外 C++ 类定义 |
| 需自定义 C++ 类的 DataAsset（如 `DatItemCommonDataAsset`） | 🟡 依赖 P3R-Project 类定义完整性 | stubs 可能缺 `UPROPERTY()` 标记，导入可能失败需手动修补 |
| UE4 编译 | 🔴 当前最大障碍 | 主仓库仅 UE5（标注 "Supports only Unreal Engine 5"）；需从源码自行编译 UE4.27 版本 |

编译步骤：clone [JsonAsAsset/JsonAsAsset](https://github.com/JsonAsAsset/JsonAsAsset/releases) → 放 `P3R-Project/Plugins/` → 右键 .uproject → Generate VS project files → 构建。

#### 优点与局限

| 优势 | 局限 |
|---|---|
| 编辑 JSON 即可，无需学习 BMD 标记码 | 需要 UE 4.27.2 工程 + 编译 JsonAsAsset |
| 可端到端在 UE 编辑器中预览修改 | 部署需 cook，比散文件替换步骤多 |
| 与本仓库 §2A（AtlusScriptToolkit）互补：DataTable 归 JsonAsAsset，BMD 归 AtlusScriptToolkit | 自定义类导入可能因 stubs 不完整而失败 |

---

### 可行路线 E：UnrealLocres + .locres 直接编辑（最轻量文本修改）

**可行性评估**：✅ 已验证（UnrealLocres CLI 工具标准用法，不依赖 UE 工程）

#### 适用场景

P3R 的本地化系统除了 L10N 目录的 DataTable/DataAsset 外，还有 `Localization/Game/` 目录中的 `.locres` 文件（UE 标准本地化二进制格式）。这些文件可以通过 **[UnrealLocres](https://github.com/akintos/UnrealLocres)** 工具直接编辑，**不需要 UE 工程**，工作流是最简单的 CSV 编辑。

#### 工作流

```text
1. FModel 从 Localization/Game/ 导出 .locres 文件
2. UnrealLocres.exe export Game.locres -o Game.csv
   → 转为 CSV，列：key, source, target
3. 在 Excel/文本编辑器中编辑 target 列（文本内容）
4. UnrealLocres.exe import Game.locres Game.csv
   → 回编译为 .locres（产出 .new 文件，重命名覆盖原文件）
5. 部署到 UnrealEssentials 散文件路径
```

#### 优点与局限

| 优势 | 局限 |
|---|---|
| 纯 CSV 编辑，无需理解 UE 或 BMD | 仅限于 `.locres` 覆盖的文本（UI 菜单、系统消息） |
| 不需要 UE 工程 | 不覆盖 BMD 对话文本或 DataTable 名称表 |
| 与 §2A（BMD 文本）、§2D（JsonAsAsset DataTable）互补 | — |

---

## 3. 音乐 / 音频

### 现状

本仓库引擎完全无法触及音频。但社区已建立**两条独立可行路线**：Ryo Framework + Yona（推荐，最易用）和手动 CRI 工具链（进阶）。

P3R 的音频系统是 **CRIWARE ADX2**（非标准 UE 音频格式），BGM 音轨以加密 HCA 格式封装在 AWB 容器中，由 CueSheet（.uasset）索引。

### 涉及文件

| 类别 | 路径 | 说明 |
|---|---|---|
| BGM AWB 容器 | `P3R/Content/Xrd777/CriData/Stream/` | ~118 条 streaming BGM 轨 |
| CueSheet 总表 | `P3R/Content/Xrd777/CriData/CueSheet/` | 51 文件，BGM/SE/语音索引 |
| DLC BGM | `P3R/Content/Xrd777/Sound/Table/` | `DlcBgmAsset.uasset` |
| SE/语音 | 同上，分布多个 AWB | 全局 2,184 .awb |
| BGM 索引 | [amicitia/md/Persona_3_Reload_BGM.md](amicitia/md/Persona_3_Reload_BGM.md) | HCA Name ↔ Cue Name ↔ Track Name 映射 |

---

### 可行路线 A：Ryo Framework + Yona（推荐，社区标准）

**可行性评估**：⭐ 已验证（Ryo Framework 官方文档明示支持 P3R；Yona 有 P3R BGM 模板）

#### 技术原理

**[Ryo Framework](https://ryotune.github.io/guides/audio/audio-replacement-ryo/)**（Reloaded II 插件框架）hook 游戏运行时音频调用：当游戏请求 Cue（通过 CueSheet ID + Cue ID/Name）时，Ryo Framework 拦截请求，用自己的替换文件回应，不修改原始 AWB/ACB 容器。

**[Yona](https://ryotune.github.io/guides/audio/music-replacement-yona/)** 是配套工具，封装了格式转换（WAV → HCA，含加密）、循环点设置、BGM 曲目映射等复杂性：

- **Yona BGM 模板**：针对 P3R 的完整曲目列表（每个 Cue 已命名：BGM_Title、BGM_Tartarus_Explore 等）
- **自动编码**：Yona 调用 VGAudio 将 WAV 转为 P3R 兼容的加密 HCA，用正确密钥编码
- **Build 系统**：将曲目按 ACB 结构组织到 Mod 目录中

#### 完整工作流

```text
# 前提：Reloaded II 已安装并配置 P3R

1. 在 Reloaded II 中安装 Ryo Framework
   Reloaded Downloader → 搜索 "Ryo Framework" → 安装

2. 创建新 Mod
   Reloaded II → 创建 Mod → 命名（如 "BGMMod"）
   → 添加依赖：Ryo Framework

3. 打开 Yona
   Yona → 过滤选择 "Persona 3 Reload" + "BGM"
   → 点击 P3R BGM 模板 → 创建项目
   → 输出文件夹选择 Mod 目录

4. 替换曲目
   曲目列表中选择目标（如 "BGM_Title" 标题曲）
   → 点击 Select File → 选择 WAV 文件（推荐）
   → 设置循环点（Loop Start / Loop End）
   → 对其他曲目重复

5. Build（一键生成）
   Yona → 点击 Build 按钮
   → 自动完成：WAV 编码为加密 HCA、写入 ACB 结构、
     部署到 Mod/Ryo/P3R.exe/ 目录

6. 启动验证
   Reloaded II → Launch P3R
   → 游戏中播放对应 BGM 时触发替换
```

**Mod 目录结构**：
```text
BGMMod/
├── ModConfig.json          # Reloaded II 元数据，含 Ryo Framework 依赖
└── Ryo/
    └── P3R.exe/
        └── bgm.acb/        # BGM CueSheet
            ├── 123456.wav  # Cue ID 方式命名
            ├── bgm_title.cue/  # 或 Cue Name 文件夹（支持随机化）
            │   ├── track1.wav
            │   └── track2.wav
            └── ...
```

**高级用法**：
- **开发者模式**：Ryo Framework 设置中启用，游戏播放音频时 Reloaded Console 显示 ACB 名和 Cue ID，省去手动查找
- **多文件随机化**：Cue 文件夹内放多个文件 → 运行时随机选取
- **自定义编码器**：`Yona/audio/encoders/VGAudio/` 下放 `.ini` 覆盖默认编码参数

#### 优点与局限

| 优势 | 局限 |
|---|---|
| 无需手动处理 AWB/ACB/HCA | 只替换 Cue 播放内容，不修改 CueSheet 元数据 |
| 不修改原始游戏文件 | 不能改音量/循环点等播放参数 |
| Yona 自动完成格式转换和加密 | 替换文件需要是未加密的 WAV/HCA/ADX |
| 支持循环点和随机化 | — |

> **注意**：加密 HCA 的解码和再加密由 Ryo Framework 和 VGAudio 在 Build 时自动处理，用户不需要自行处理 HCA 密钥。BGM 加密密钥（`40351957794689840`）仅在手动解码/试听时使用。

---

### 可行路线 B：手动 CRI 工具链（进阶路线）

**可行性评估**：✅ 社区已验证各工具独立可用，P3R 专有 HCA 密钥已确认

#### 适用场景
- 需要替换非 BGM 类型音频（SE、语音）
- 需要对 ACB/CueSheet 层做精细化修改
- Yona 模板未覆盖的特定场景

#### 技术流程

```text
1. 提取原始文件
   FModel → 导出 Xrd777/CriData/Stream/{target}.awb

2. 提取 ACB（从 .awb 容器中）
   十六进制编辑器打开 .awb → 搜索 "@UTF" 标记
   → 从标记处提取到文件尾 → 另存为 .acb

3. 解码 ACB → 拆出 HCA 文件
   SonicAudioTools → 将 ACB 拆分为独立 HCA 文件

4. （可选）试听原生 HCA
   foobar2000 + vgmstream 插件
   + .hcakey 文件（内容为密钥 40351957794689840 的 big-endian uint64）
   → 可解码播放原生 HCA

5. 制作替换 HCA
   VGAudioCli.exe "input.wav" output.hca --keycode 40351957794689840

6. 重打包 ACB
   AcbEditor → 替换 HCA 文件 → 生成新 ACB

7. 注入回 .uasset
   十六进制编辑器 → 替换 .uasset 中的 ACB 段
   → 保持文件总大小不变
   → 若大小变化，需用 UnrealEssentials 整文件替换
```

#### 优点与局限

| 优势 | 局限 |
|---|---|
| 完全控制音频替换细节 | 操作步骤多，工具链分散 |
| 可替换任意类型音频（BGM/SE/语音） | 需要理解 AWBC/ACB/HCA 容器结构 |
| 不依赖 Yona 模板是否存在 | hex 注入必须保持大小不变否则需换文件 |

---

## 4. 模型 / 纹理 / 动画

### 现状

本仓库引擎完全不支持。但社区有**两条独立可行路线**：(1) 完整的 UE 4.27.2 重 cook 工程（§1.4），适合复杂模型/动画创作；(2) FModel + Blender PSK/PSA 轻量替换，适合简单模型交换和纹理替换。前者在本地已有参考实例 `P3R-Project-master`。

### 涉及文件

| 类别 | 路径 | 说明 |
|---|---|---|
| 角色模型 | `Xrd777/Characters/{Player,Persona,Enemy,NPC,Mob,Weapon,Sub}/` | `.uasset` + `.ubulk`（顶点/纹理数据） |
| Bustup 立绘 | `Xrd777/UI/Bustup/Textures/{CharID}/` | 纹理 `.uasset` |
| Cut-In | `Xrd777/UI/` | `T_UI_CI_<角色>_<编号>.uasset` |
| 服装数据 | `Xrd777/UI/Tables/DatItemCostumeDataAsset.uasset` | ID 表，1–119 为实际服装 |
| 动画 | 嵌入模型 uasset + `McaAssetPlugin` 管理 | AppAnimSequence / AppCharAnimDataAsset 等 |

详见 [P3R_ASSET_ANALYSIS.md §3.5/§3.6](P3R_ASSET_ANALYSIS.md)、[amicitia 各页](amicitia/)。

---

### 可行路线 A：FModel + Blender PSK/PSA（推荐入门，轻量模型替换）

**可行性评估**：✅ 社区标准 UE 模型 modding 流程，Atlus UE4 游戏（SMT V Vengeance）有可复用的详细教程

#### 技术原理

FModel 支持将 UE SkeletalMesh 导出为 **PSK**（模型+骨骼）和 **PSA**（动画）格式——这两种格式是 Epic Games 制定的通用 UE 模型交换格式，Blender PSK 插件可直接导入。

#### 完整工作流

```text
# 第一阶段 — 提取
1. FModel 设置
   - 添加 P3R 游戏目录
   - 输入 AES 密钥（在 Config.ps1 中）
   - 设置 UE 版本为 4.27

2. 导出目标模型
   搜索目标 SkeletalMesh（如 SK_PC0001_C002）
   → 右键 → Export → 选择 PSK 格式
   → 产物：.psk（骨骼网格模型）、.psa（动画）、.png（纹理）

# 第二阶段 — 编辑（Blender）
3. 安装 PSK 插件
   [Befzz/blender3d_import_psk_psa](https://github.com/bwpn/blender3d_import_psk_psa)
   → Blender 设置 → Add-on → 安装导入脚本

4. 导入 PSK
   Blender → File → Import → PSK
   → 模型自动导入，含完整骨骼层次和权重

5. 编辑模型
   - 修改顶点/权重/拓扑
   - 或替换为外部 FBX 导入的模型（需要重新绑定骨骼）

6. 导出 FBX（关键设置）
   ├── Armature 名称：必须为 "Armature"  ← 否则 UE 导入后 T-pose 崩溃
   ├── 缩放：0.01                          ← 否则根骨骼 100 倍大，物理崩塌
   ├── Add Leaf Bones：关闭                ← 否则 UE 骨骼命名冲突
   ├── Forward Axis：-Y                    ← UE 标准
   └── Up Axis：Z

# 第三阶段 — 回封
7. 将 FBX 导入 UE 4.27 工程
   - 导入时 Use T0 As Ref Pose
   - 骨骼选择原版 Skeleton（不能是 UE 自动生成的）
   - PhysicsAsset 复选原版

8. Cook + 部署
   - Cook for Windows (bUseIoStore=True)
   - 产出 .utoc/.ucas → 经 Reloaded II + UnrealEssentials 注入
   - 或用 _P 后缀 + PAK 覆盖
```

#### 关键注意事项

| 问题 | 后果 | 解决 |
|---|---|---|
| Armature 名称不是 "Armature" | UE 导入时自动补额外骨骼 → T-pose | 导出前重命名 |
| 缩放未设 0.01 | 根骨骼 100x 大 → 布料/物理崩溃 | FBX 导出→Transform→Scale: 0.01 |
| Add Leaf Bones 开启 | 多出末端骨骼 → UE 绑定错乱 | 关闭（默认在 FBX 导出→右侧面板） |
| 使用 UE 自动生成的骨骼 | 与原版动画不兼容 → 动画错乱 | 必须复用原版 Skeleton 资产 |
| FBX 骨骼名称不匹配 | UE 导入时骨骼节点重命名 | 与原始 PSK 骨骼命名完全一致 |

**进阶工具**：新版 FModel 支持 `.ueformat` 直接导出/导入格式，配合专用 Blender 插件可绕过 FBX 中转，避免命名/缩放问题。详见 [gamebanana.com/tuts/17620](https://gamebanana.com/tuts/17620)（SMT V Vengeance 详细教程，同为 UE4.27 Atlus 游戏，流程完全可复用）。

---

### 可行路线 B：Bustup / Cut-In 纹理替换（最佳入门点）

**可行性评估**：✅ 标准 UE 纹理替换流程，资产映射已完善

#### 文件命名规则

```text
T_BU_{CharID}_Pose{PoseID}_C{CostumeID}.uasset     # 基础立绘
T_BU_{CharID}_F{ExpressionID}_C900_E{Frame}.uasset  # 表情帧（眼睛）
T_BU_{CharID}_F{ExpressionID}_C900_M{Frame}.uasset  # 表情帧（嘴型）

角色 ID 前缀：
  PC = 主角/可玩角色（PC0001=结城理）
  NC = 次要 NPC
  SC = 子角色/社群角色
```

**Bustup 标签格式**（BMD 文本中控制）：
```
[uf 4 5 {charID} {expressionID} {outfitID} 65535 0 0]
# 最后两个 0：红晕覆盖 / 汗滴覆盖（1 = 开启）
```

#### 工作流

```text
1. 定位目标
   amicitia Bustups 页 → 确定 CharID + PoseID
   或 FModel 浏览 Xrd777/UI/Bustup/Textures/

2. 导出纹理
   FModel → 右键目标 .uasset → Export → PNG
   → 产出去平台压缩的 PNG

3. 编辑
   Photoshop / GIMP 编辑 → 保持原分辨率输出 PNG

4. 回写
   方式 A：UAssetGUI 打开原始 .uasset → 替换纹理数据 → 保存
   方式 B：UE 4.27.2 重 cook 工程导入 → 替换 → cook
   方式 C：FModel 导出时用 .ueformat + 插件直接写入

5. 部署
   <Mod>/UnrealEssentials/P3R/Content/Xrd777/UI/Bustup/Textures/{CharID}/{File}.uasset
```

---

### 可行路线 C：UE 4.27.2 重 cook 工程（完整创作路线）

**可行性评估**：🟡 路径完整（本地实例 `P3R-Project-master`），但操作门槛高

详见 §1.4 的技术分析。需要：

1. **安装 UE 4.27.2**（Epic Games Launcher）
2. **打开 P3R-Project**（已含 ATLUS 专有插件）
3. **导入/编辑资产**（FBX → SkeletalMesh 或纹理替换）
4. **cook 产出 IoStore**（`bUseIoStore=True`）
5. **Reloaded II + UnrealEssentials 注入**

`Content/Xrd777/Characters/Player/PC0001/Models/SK_PC0001_C002.uasset` 是**直接可用的起点样板**——打开工程即可看到完整骨骼层次和材质实例，适合作为第一个练习。

> **与本仓库的分工**：本仓库的 [docs/amicitia/md/](amicitia/) 中的 `Persona_3_Reload_Anim.md` / `EnemyModels.md` / `Outfits.md` / `Bustups.md` 提供"改哪个模型/哪套装扮"的 ID 映射参考，**资产定位层**可完全复用。

---

## 5. 本仓库在未来路线中的定位

各资源类别的工具链都已独立存在、社区已验证。本仓库的核心价值不在于复现这些工具链，而在于：

| 角色 | 具体内容 |
|---|---|
| **资产定位层** | amicitia Markdown 页 + DATA_MAPPING.md → 告诉用户"改哪个文件/哪个 ID" |
| **中文入口** | docs/zh-cn/ → 三语译名解析，对接中文需求 |
| **装载约定** | UnrealEssentials 路径规则 + ModConfig.json → 确保散文件可靠部署 |
| **DataTable 数值** | Zen byte-patch 引擎 → 不改模型纹理，只改数值（技能/Persona/敌人等） |
| **方案路由** | 收到"我想改 BGM"时，能正确指向 Ryo Framework + Yona，而不是说"不支持" |

即：**超出 DataTable 数值的需求，本仓库的路由策略不是"不支持"，而是[指向已验证的社区路线并提供定位层支撑]**。

---

## 6. 优先级建议

| 优先 | 方向 | 推荐路线 | 理由 |
|---:|---|---|---|
| 1 | **文本 / L10N 名称表** | §2A (AtlusScriptToolkit) 或 §2D (JsonAsAsset) | 多条可行路线；对中文玩家价值最高 |
| 2 | **BGM 替换** | §3A (Ryo Framework + Yona) | Yona P3R BGM 模板一键替换；无需技术知识；用户感知强 |
| 3 | **.locres UI 文本** | §2E (UnrealLocres) | 最简单路线，纯 CSV 编辑 |
| 4 | **Bustup / Cut-In 纹理** | §4B | 门槛低，仅需 FModel + 图片编辑软件；视觉反馈直观 |
| 5 | **模型 / 服装 / 动画替换** | §4C (UE recook) 或 §4A (PSK+Blender) | 生态丰富（GameBanana/Nexus Mods 大量 mod），但操作门槛最高 |
| 6 | **事件/对话文本修改** | §2A (BMD Emulator) | 需要精确定位 BMD 文件和理解标记码结构，比名称表复杂 |

---

## 7. 参考文献与在线资源

### 工具链入口

| 资源 | 用途 | 路线 |
|---|---|---|
| [AtlusScriptToolchain (GitHub)](https://github.com/TGEnigma/AtlusScriptToolchain) | BMD/BF 反编译/回编译 CLI | 文本 §2A |
| [Atlus Script GUI (GameBanana)](https://gamebanana.com/tools/12526) | 文本编辑图形前端 | 文本 §2A |
| [BMD Emulator (FileEmulationFramework)](https://sewer56.dev/FileEmulationFramework/emulators/bmd.html) | 运行时 BMD 消息覆盖（Reloaded II） | 文本 §2A |
| [Text Editing in P3R Tutorial (GameBanana)](https://gamebanana.com/tuts/17261) | 文本修改完整教程（含 CLI 命令） | 文本 §2A |
| [Ryo Framework Audio Guide](https://ryotune.github.io/guides/audio/audio-replacement-ryo/) | P3R 音频替换官方文档 | 音频 §3A |
| [Yona Music Replacement Guide](https://ryotune.github.io/guides/audio/music-replacement-yona/) | Yona BGM 模板操作指南 | 音频 §3A |
| [Befzz Blender PSK Addon](https://github.com/bwpn/blender3d_import_psk_psa) | Blender → PSK 导入插件 | 模型 §4A |
| [SMT VV Model Editing Tutorial (GameBanana)](https://gamebanana.com/tuts/17620) | Atlus UE4 模型编辑完整流程（可复用） | 模型 §4A |
| [JsonAsAsset (GitHub)](https://github.com/JsonAsAsset/JsonAsAsset) | FModel JSON → UE 资产导入插件 | 文本 §2D |
| [UnrealLocres (GitHub)](https://github.com/akintos/UnrealLocres) | .locres ↔ CSV 转换工具 | 文本 §2E |
| [ue-localization-tools (GitHub)](https://github.com/efonte/ue-localization-tools) | Python locres 编解码 | 文本 §2E |

### 社区生态

| 资源 | 内容 |
|---|---|
| [GameBanana P3R Mods](https://gamebanana.com/games/20036) | 文本/模型/音频 mod 聚集地 |
| [Nexus Mods P3R](https://www.nexusmods.com/persona3reload) | 音频/模型 mod 实例 |
| [ShrineFox Modding Docs](https://docs.shrinefox.com/flowscript/intro-to-scripting) | BF/BMD/Flowscript 概念体系 |
| [P3R Modding Day One](https://animatedswine37.github.io/posts/p3r-modding-day-one/) | P3R modding 能力综述 |

### 本仓库关联文档

| 文档 | 关系 |
|---|---|
| §1.4 UE 4.27.2 重 cook 工程 | 模型/动画完整创作通道 |
| [AMICITIA Bustups / Outfits / Anim 页](amicitia/) | 资产 ID 映射 |
| [P3R_ASSET_ANALYSIS.md](P3R_ASSET_ANALYSIS.md) | 资产拓扑 |
| [MODDING_PITFALLS.md P-005](MODDING_PITFALLS.md) | L10N 散文件先例 |
| [ESSENTIALS_REFERENCE.md](ESSENTIALS_REFERENCE.md) | 散文件/整包装载规则 |
| [ZEN_BYTE_PATCH_WORKFLOW.md §6](ZEN_BYTE_PATCH_WORKFLOW.md#5-已知限制) | 本仓库引擎边界 |
