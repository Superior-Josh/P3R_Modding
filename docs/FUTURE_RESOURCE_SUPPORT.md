# P3R Mod 技术实现路线

> 本文档综合社区已验证的 Mod 制作经验与项目已工程化的写回方案，形成按资源类型分类的完整修改指南。
>
> 核心原则：**按资源类型选择工具链，而不是试图用一个引擎覆盖所有类型**。项目当前以 DataTable 数值修改（byte-patch）为已工程化的核心，其余类型通过本文档路由到社区已验证的独立工具链。

---

## 第一部分：技术路线分析

### 约束前提——为什么路线会分化

P3R 的底层技术事实决定了能改什么、不能改什么。所有路线选择的底层逻辑如下。

#### 约束 1：P3R 是纯 IoStore 游戏

所有游戏资产以 **Zen 格式**（`FZenPackageSummary` 头，首 4 字节 `00 00 00 00`）打包在 `.utoc/.ucas` 容器中。UnrealEssentials 散文件替换要求替换文件**也必须是 Zen 格式**。

传统 `.uasset+.uexp`（首 4 字节 `C1 83 2A 9E`）直接部署为散文件会导致 P3R 崩溃——因为 UTOC.Stream.Emulator 为 mod 文件生成 IoStore-shape 的 TOC 指针，游戏从头到尾以为自己在反序列化 Zen 格式，但文件首字节是传统 magic → 字节布局不匹配 → 越界/cast 错误 → 进程崩溃。链条上没有任何环节做格式自动转换。

详见 [MODDING_PITFALLS.md P-007](MODDING_PITFALLS.md#p-007)。

#### 约束 2：项目写回引擎是 size-invariant byte-patch

当前写回引擎（`Invoke-ZenPatch.ps1`）的硬断言：`output file size == original file size`。

| 能改 | 不能改 |
|---|---|
| `ubyte/uint16/int32/float` 等定长标量 | string、TArray（变长 → 文件大小改变） |
| 已知 offset 的 flat struct 字段 | union（含 discriminator，改值不改类型标签 → `Bad name index` 崩溃） |
| 不改变序列化布局 | 增删 row、改 NameMap/ImportMap/ExportMap |

详见 [ZEN_BYTE_PATCH_WORKFLOW.md §5](ZEN_BYTE_PATCH_WORKFLOW.md#5-已知限制)。

这就是为什么 DataTable 数值可以走 byte-patch，但名字表（FText 变长字符串）、文本（BMD 变长消息）、模型（SkeletalMesh 复杂序列化）、音乐（CRIWARE ADX2 非 UE 格式）不行——后几类都超出 byte-patch 的能力边界。

---

### 路线 A：DataTable 数值修改（项目已工程化 ✅）

**技术判断**：数据表可以直接用 010 Editor 修改。

**为什么可行**：P3R 的 DataTable 继承自 `FTableRowBase`，Zen 文件中无 property tag，字节布局完全由行结构决定：

```
headerSize + (rowIndex × rowSize) + fieldOffsetInRow = 精确 byte offset
```

010 Editor 模板已知 `rowSize`（如技能表 769 字节、Persona 表 402 字节）经 `Calibrate-SchemaHeaders.ps1` 校准的 `headerSize`，schema JSON 又知道每个 field 在行内的偏移 → 可以算出任意定长标量字段的绝对字节位置。修改 2/4/8 个字节不影响总文件大小。

**可行性评估：✅ 已工程化、已实测、已验证回归（19 PASS）**

**边界**：
- 含 union 的 struct（如 PersonaGrowth `SkillEventStruct`）→ P-010 确认崩溃
- 变长字段 → 不支持
- 无 010 模板或 PARTIAL schema → guard 要求人工复核偏移

---

### 路线 B：名字表（NameTable）修改（UE 路径 🟡）

**技术判断**：图片、模型、**名字表需要在 UE 里改**；推荐使用 **jsonasasset** 插件。

**为什么不能 byte-patch**：

```
名字表（DatSkillNameDataAsset 等）存储的是 FText 格式的本地化字符串：
  FText 序列化包含字符串长度（变长）、字符串数据（变长）、命名空间/键（变长）。
  直接 byte-patch 会破坏长度前缀 → UE 反序列化读错偏移 → 崩溃或乱码。
  UE 是唯一能正确重序列化 FText 的工具链。
```

**为什么 jsonasasset 是正确选择**：

```
jsonasasset 的工作流：
  FModel 导出 JSON（含 FText 的字符串值）
    → jsonasasset 在 P3R Project 中反序列化为可编辑资产
    → UE 修改 → Cook → 产出游戏可用的 Cooked Asset

jsonasasset 输出的 .uasset 是 Editor Asset 格式（magic=C1 83 2A 9E），
这不是 bug——UE 编辑器当然输出 Editor 格式。正确使用方式是"在 UE 中修改后 Cook"，
而不是直接用输出替换游戏文件。
```

**可行性评估：🟡 路线正确但工具链门槛高**

| 优势 | 障碍 |
|---|---|
| 符合 UE 资产修改标准流程 | jsonasasset 标注 "Supports only Unreal Engine 5" |
| 在 P3R Project 中有约 400+ C++ 头文件支撑 | 需从源码编译 UE4.27 兼容版本 |
| 理论上可处理任意 FText/StringTable | 须经 Cook 步骤，不能直接替换 |
| 社区的 L10N 散文件替换（barionskillnames）已验证 | 但那是整文件替换非 DataTable 文本 |

---

### 路线 C：文本 / AI 脚本修改（社区已验证 ✅）

**技术判断**：文本和 AI 脚本可以用文本编辑器修改，不需要进 UE 还原。

**为什么可行**：

```
P3R 的对话/描述文本存储在 BMD（Binary Message Data）格式中。
社区工具 AtlusScriptToolchain 反编译 BMD → 纯文本 .msg 文件
→ 任意文本编辑器修改 → 回编译为 .uasset → 散文件挂载或 BMD Emulator 运行时覆盖。
BMD 是纯消息容器，不涉及 UE 序列化格式 → 不需要 UE 工程。
AI 脚本（Flowscript/BF）同样有社区反编译器，反编译后是类脚本语言的标记文本。
```

**可行性评估：✅ 社区已验证、工具链成熟**。工具链完全在 UE 之外，不受 IoStore 格式约束。

---

### 路线 D：音乐 / 音效替换（社区标准 ✅）

**技术判断**：音乐有 Ryo Framework 可以直接替换。目前没有 P3R 用的公开 CriWare 版本，所以没办法在 UE 里改音乐音效。

**为什么不能在 UE 里改**：

```
P3R 的音频系统是 CRIWARE ADX2，不是 Unreal Engine 的音频系统。
音乐存储在 AWB/ACB 容器中，而非 UE 标准音频格式。
CriWare 的 UE 集成插件没有 P3R 可用的公开版本。
```

**为什么 Ryo Framework 可行**：

```
Ryo Framework 是 Reloaded II 插件，hook 游戏运行时的 CRIWARE 音频调用。
当游戏请求某个 Cue（音效 ID）时，Ryo 拦截请求，用自己的 WAV/HCA 文件替代。
不需要修改原始 ACB/AWB 容器，不需要 UE。
Yona 封装了 WAV→加密 HCA 的转换，提供 P3R BGM 模板，一键 Build。
```

**可行性评估：✅ 社区标准、Yona 有 P3R 模板、操作简单**。这是所有非 DataTable 路线中门槛最低的一条。

---

### 路线 E：图片 / 模型 / 蓝图修改（需 UE ✅）

**技术判断**：图片、模型需要在 UE 里改。技能特效数据、Persona 数据都是蓝图做的，所以也需要在 UE 里去做。

**为什么只能在 UE 里改**：

```
模型（SkeletalMesh）：顶点数据、骨骼权重、材质引用——全是 UE 序列化格式，
  没有 byte-patch 的余地。FModel 导出 PSK → Blender 编辑 → FBX → UE 导入 → Cook。

蓝图（Blueprint）：技能蓝图（BP_BtlSk0118 等）由 UE Blueprint 字节码编译。
  可以导出 JSON 让 AI 辅助理解逻辑，但修改后必须在 P3R Project 中重新编译 Cook。
  "导出 JSON 发给 AI，它会教你怎么还原"——这里的"还原"是指在 P3R Project 中
  手动重建同逻辑的蓝图，不是改二进制。
```

**可行性评估：✅ 路线完整，门槛较高**。P3R-Project-master 已本地部署（UE 4.27.2 + ATLUS 插件），具备完整创作管线。

---

## 第二部分：实现工作流

### 2.1 DataTable 数值修改

#### 推荐路径（项目已工程化）

**Zen 单文件 `.uasset` byte-patch + UnrealEssentials 散文件挂载**

- 工具：010 Editor + 项目 `.bt` 模板 / `modify-and-repack.ps1`
- 流程：`Extracted/IoStore` Zen 原件 → 010 schema 算偏移 → 字节级 patch → `<Mod>/UnrealEssentials/P3R/Content/...`
- 项目入口：`modify-and-repack.ps1 -TableKey Skills -Changes @(...) -ModName 'MyMod'`
- DSL 速查：`Set-SkillHpn -SkillId 10 -DamageMultiplier 5.0`

> ⚠️ 传统 `.uasset + .uexp` 写回路径已弃用，P3R 实测不可靠（P-007）。

#### 支持的表

详见 CLAUDE.md §8 TableKey 索引（Skills、Personas、Enemies、Items、Difficulty 等约 20+ 张表）。

#### 安全流程

```
① DryRun / diff-changes.ps1 预览
② guard-modify.ps1 安全检查（schema regression、field type、值域）
③ conflict-check.ps1 冲突检查
④ modify-and-repack.ps1 真实写回（自动备份 + 生成 + 安装）
⑤ 游戏内验证
⑥ rollback-mod.ps1 回滚（如需）
```

---

### 2.2 文本 / AI 脚本修改

#### 可行路线 A：AtlusScriptToolchain CLI + BMD Emulator（推荐，最轻量）

**可行性评估**：✅ 已验证（P3P/P4G/P5R PC 确认兼容；P3R 工具链支持已在 AtlusScriptToolchain 中实现）

**原理**：P3R 的对话/描述文本存储在 **BMD（Binary Message Data）** 格式中，社区工具 **AtlusScriptToolchain**（TGE 维护，[GitHub](https://github.com/TGEnigma/AtlusScriptToolchain)）提供完整反编译/回编译支持。

**完整工作流**：

```bash
# 反编译（从 .uasset 提取可编辑 .msg）
AtlusScriptCompiler.exe -In BMD_target.uasset `
  -Decompile -InFormat MessageScriptBinary -Encoding UTF-8 `
  -OutFormat V1RE -Library P3RE

# 编辑 .msg（纯文本格式，任意文本编辑器）

# 回编译（生成替换用 .uasset）
AtlusScriptCompiler.exe -In BMD_target.bmd.msg `
  -Compile -Encoding UTF-8 -OutFormat V1RE -Library P3RE `
  -UPatch BMD_target.uasset
```

| 参数 | 含义 |
|---|---|
| `-OutFormat V1RE` | P3R 使用的 BMD 版本（Reload 引擎） |
| `-Library P3RE` | 指定游戏库：Persona 3 Reload Engine |
| `-UPatch` | 以原 `.uasset` 为模板生成 uasset 容器 |

**图形化替代**：[Atlus Script GUI](https://gamebanana.com/tools/12526)（ShrineFox）提供拖放操作。

**部署方式**：

| 方式 | 说明 |
|---|---|
| **散文件替换** | 回编译产物 `.uasset` → `<Mod>/UnrealEssentials/P3R/Content/...`（barionskillnames 已验证模式） |
| **BMD Emulator 运行时覆盖** | `.msg` 放 `<Mod>/FEmulator/BMD/`，只包含需改动的消息条目，无需替换文件 |

#### 可行路线 B：UnrealLocres + .locres 直接编辑（最轻量）

适用于 `Localization/Game/` 目录中的 `.locres` 文件（UE 标准本地化二进制）：

```bash
UnrealLocres.exe export Game.locres -o Game.csv   # 转为 CSV
# 编辑 target 列
UnrealLocres.exe import Game.locres Game.csv       # 回编译
```

**可行性评估**：✅ 已验证，纯 CSV 编辑，不需要 UE 工程。

#### 可行路线 C：UE + jsonasasset 导入（用于 DataTable 类文本）

**可行性评估**：🟡 理论上可行，受限 UE4 版本兼容性（见 §2.4 名字表修改分析）

---

### 2.3 音乐 / 音效替换

#### 可行路线 A：Ryo Framework + Yona（推荐，社区标准）

**可行性评估**：✅ 已验证（Ryo Framework 官方文档明示支持 P3R；Yona 有 P3R BGM 模板）

**工作流**：

```text
1. Reloaded II 安装 Ryo Framework
2. 创建 Mod → 添加依赖 Ryo Framework
3. 打开 Yona → 选择 "Persona 3 Reload" + "BGM"
4. 选择曲目 → 选择 WAV → 设置循环点
5. Build → 自动编码为加密 HCA + 部署到 Mod/Ryo/P3R.exe/
6. Reloaded II 启动 → 游戏中播放对应 BGM 时触发替换
```

**Mod 目录结构**：
```
<Mod>/
├── ModConfig.json          # 依赖 Ryo Framework
└── Ryo/P3R.exe/
    └── bgm.acb/
        ├── 123456.wav              # Cue ID 方式命名
        └── bgm_title.cue/          # Cue Name 文件夹（支持随机化）
```

**密钥**（仅手动解码时用）：`40351957794689840`

#### 可行路线 B：手动 CRI 工具链（进阶）

适用于 SE/语音替换或 Yona 模板未覆盖的场景：`FModel 提取 AWB → SonicAudioTools 拆 ACB → VGAudio 编码 HCA → AcbEditor 重打包 → hex 注入 .uasset`。

操作步骤多，不做默认推荐。

---

### 2.4 名字表（DatSkillNameDataAsset 等）修改

#### 推荐的 UE 路径

**jsonasasset** + **P3R Project**（UE 4.27.2）是名字表修改的正确路线：

1. 从 **FModel** 导出目标资产的 JSON（Save Properties）
2. 在 **P3R Project**（https://github.com/rirurin/P3R-Project ）中使用 jsonasasset 插件导入
3. 在 UE 编辑器中编辑 FText 文本
4. **Cook for Windows**（产出 Cooked Asset）
5. 以 UnrealEssentials 散文件挂载

> ⚠️ 注意事项：
> - jsonasasset 必须在 P3R Project 中使用，不能自建 UE 工程
> - 输出是 Editor Asset → 必须 Cook 后才能用于游戏
> - 如遇 UE 崩溃，删除 `Intermediate/Saved/Binaries` 让引擎重编译
> - jsonasasset 官方标注 "Supports only Unreal Engine 5"，UE4.27 版本需自行编译

#### 替代变通方案（UE 路径暂时受阻时）

> ⚠️ 此方案未被官方验证或推荐，仅供参考。

1. IoStore 重打包为 **PAK**，提取完整 `.uasset + .uexp`（传统格式）
2. **UAssetGUI** 打开并编辑（有 name table 可视界面）
3. **010 Editor** 对照二进制变化，将修改手动复制到原版 Zen 单文件的对应偏移

本质是借用 UAssetGUI 的可视能力 + 010 的字节级写入能力的组合拳。

---

### 2.5 图片 / 模型 / 蓝图修改

#### 可行路线 A：FModel + Blender PSK/PSA（推荐入门，轻量模型替换）

**可行性评估**：✅ 社区标准 UE 模型 modding 流程

**完整工作流**：

```text
1. FModel 导出目标 SkeletalMesh 为 PSK 格式
2. Blender 安装 PSK 插件（Befzz/blender3d_import_psk_psa）
3. 导入 PSK → 编辑顶点/权重/拓扑
4. 导出 FBX（关键设置：Armature 名="Armature"、Scale=0.01、Add Leaf Bones=关闭）
5. UE 4.27.2 导入 FBX → 复用原版 Skeleton → Cook for Windows (bUseIoStore=True)
6. Reloaded II + UnrealEssentials 注入
```

#### 可行路线 B：Bustup / Cut-In 纹理替换（最佳入门点）

```text
FModel 导出纹理 PNG → Photoshop/GIMP 编辑 → UAssetGUI 替换纹理数据 → 部署到 UnrealEssentials
```

**可行性评估**：✅ 标准 UE 纹理替换流程，资产映射已完善。

#### 可行路线 C：UE 4.27.2 重 Cook 工程（完整创作路线）

**P3R-Project-master**（本地 `C:\Users\91698\Downloads\P3R-Project-master`）是 UE 4.27.2 工程，含 ATLUS 专有插件，支持完整的 SK 模型/蓝图/动画编辑。

**蓝图（技能特效、Persona 数据）**：
- 技能特效、Persona 数据等是蓝图（Blueprint）实现
- `BP_BtlSk0118.uasset` 等蓝图文件可以**导出 JSON**，发给 AI 辅助还原
- 必须在 **P3R Project** 内操作，不能自建 UE 工程

---

## 第三部分：速查与工具

### 3.1 路线选择树

```
我要改什么？
├─ 数值类（技能伤害/SP/敌人属性/难度系数）
│   → 路线 A：Zen byte-patch ✅（项目已工程化）
│
├─ 文本类
│  ├─ 对话/事件文本（BMD 格式）
│  │   → 路线 C：AtlusScriptToolchain ✅
│  ├─ UI 文本（.locres）
│  │   → 路线 C：UnrealLocres ✅
│  └─ 名字表（FText，如 DatSkillNameDataAsset）
│      → 路线 B：UE + jsonasasset 🟡
│         └─ 备选：二进制 diff 移植
│
├─ 音乐/音效
│   → 路线 D：Ryo Framework + Yona ✅
│
├─ 图片/纹理
│   → 路线 E：P3R Project UE Cook ✅
│
├─ 模型/动画
│   → 路线 E：FModel PSK → Blender → UE Cook ✅
│
└─ 技能特效/蓝图
    → 路线 E：P3R Project 还原蓝图 ✅（JSON 导出 → AI 辅助还原）
```

✅ = 稳定可行  🟡 = 路线正确但工具链有门槛  ❌ = 当前不可行

### 3.2 工作流速查表

| 需求 | 工作流 | 难度 |
|---|---|---|
| 改技能数值、SP 消耗、伤害等 | `modify-and-repack.ps1` -Changes → 散文件安装 | ★☆☆ |
| 改敌人属性、掉落、经验 | 同上，换 TableKey | ★☆☆ |
| 改文本内容（BMD） | AtlusScriptToolchain 反编译 → 编辑 .msg → 回编译 | ★★☆ |
| 改 UI 文本（.locres） | UnrealLocres export CSV → 编辑 → import | ★☆☆ |
| 改技能名字 | **推荐：P3R Project + jsonasasset（UE 路径）**；备选：二进制 diff 移植 | ★★★ |
| 替换音乐 | Ryo Framework + Yona（一键 Build） | ★★☆ |
| 改 Bustup / Cut-In 纹理 | FModel 导出 PNG → 编辑 → UAssetGUI 替换 | ★★☆ |
| 改技能特效、Persona 蓝图 | P3R Project + Niagara | ★★★ |
| 改模型、贴图 | P3R Project 重 Cook | ★★★★ |
| 自建新技能动画 | P3R Project 还原蓝图 + Niagara | ★★★★ |

### 3.3 避坑总结

1. **传统 `.uasset + .uexp` 写回路径已弃用**——P3R 实测不可靠，Zen byte-patch 是唯一可工作的写回路径（P-007）。
2. **名字表不要在 010 里直接凭印象改**——名字表需要在 UE 里改，走 jsonasasset 导入流程。
3. **jsonasasset 只在 P3R Project 中使用**——不能自建 UE 工程。遇到 UE 崩溃先尝试删除 Intermediate/Saved/Binaries 重编译。
4. **jsonasasset 输出 Editor Asset → 必须 Cook 后才能用于游戏**——不能直接替换 Cooked Asset。
5. **P3R 目前没有公开的 CriWare 版本**——音乐音效无法在 UE 内编辑，走 Ryo Framework。
6. **蓝图 JSON 导出 → AI 辅助还原是可行的**——但必须在 P3R Project 内操作（"还原"指重建同逻辑蓝图，不是改二进制）。
7. **含 union 的 struct 不能直接 byte-patch**——必崩 `Bad name index`（P-010）。
8. **难度参数只影响对应难度行**——确认当前游戏难度再验证（P-011）。
9. **文本编辑器改 AI 脚本**——需先反编译为中间格式（AtlusScriptToolchain），然后才能文本编辑。

### 3.4 参考文献与工具链入口

| 资源类型 | 工具 | 入口 |
|---|---|---|
| DataTable | modify-and-repack.ps1 / Invoke-ZenPatch.ps1 | 项目已工程化 |
| 文本 (BMD) | AtlusScriptToolchain | [GitHub](https://github.com/TGEnigma/AtlusScriptToolchain) |
| 文本 (GUI) | Atlus Script GUI | [GameBanana](https://gamebanana.com/tools/12526) |
| 文本 (BMD Emulator) | FileEmulationFramework BMD | [官方文档](https://sewer56.dev/FileEmulationFramework/emulators/bmd.html) |
| 名称表 | JsonAsAsset | [GitHub](https://github.com/JsonAsAsset/JsonAsAsset) |
| 名称表 (UAssetGUI) | UAssetGUI | 备选方案 |
| 音乐 | Ryo Framework + Yona | [音频替换指南](https://ryotune.github.io/guides/audio/audio-replacement-ryo/) |
| 音乐 (Yona) | Yona BGM 模板 | [音乐替换指南](https://ryotune.github.io/guides/audio/music-replacement-yona/) |
| 模型 (PSK) | Blender PSK Addon | [Befzz/blender3d_import_psk_psa](https://github.com/bwpn/blender3d_import_psk_psa) |
| 模型 (教程) | SMT VV 模型编辑教程（可复用） | [GameBanana tuts/17620](https://gamebanana.com/tuts/17620) |
| 本地化 (.locres) | UnrealLocres | [GitHub](https://github.com/akintos/UnrealLocres) |

### 3.5 本仓库在路线图中的定位

| 角色 | 具体内容 |
|---|---|
| **DataTable 数值修改引擎** | Zen byte-patch（已工程化、已实测回归） |
| **资产定位层** | amicitia Markdown 页 + DATA_MAPPING.md → 告诉用户"改哪个文件/哪个 ID" |
| **中文入口** | docs/zh-cn/ → 三语译名解析，对接中文需求 |
| **装载约定** | UnrealEssentials 路径规则 + ModConfig.json → 确保散文件可靠部署 |
| **方案路由** | 超出 DataTable 数值的需求，路由到社区已验证的独立工具链 |

---

> **更新说明**：本文档 2026-06-27 重构。将原来的"未来支持路线"整合为完整的技术实现路线，按资源类型分类。DataTable 数值修改为项目已工程化的核心能力；其余类型通过本文档路由到社区已验证的独立工具链。
