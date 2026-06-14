# UE 游戏逆向与 Mod 制作技术方案

> **适用场景**: 仅持有 `Paks/` 目录下的 `.pak` 文件，无源代码、无 SDK，需要逆向分析并制作 Mod。

---

## 目录

1. [UE 打包机制概述](#1-ue-打包机制概述)
2. [工具链清单](#2-工具链清单)
3. [第一阶段：信息收集与版本识别](#3-第一阶段信息收集与版本识别)
4. [第二阶段：PAK 解包](#4-第二阶段pak-解包)
5. [第三阶段：资产格式深入解析](#5-第三阶段资产格式深入解析)
6. [第四阶段：核心资产逆向](#6-第四阶段核心资产逆向)
7. [第五阶段：Mod 制作与修改](#7-第五阶段mod-制作与修改)
8. [第六阶段：打包与加载 Mod](#8-第六阶段打包与加载mod)
9. [进阶：蓝图逆向与逻辑还原](#9-进阶蓝图逆向与逻辑还原)
10. [进阶：C++ 层逆向](#10-进阶c-层逆向)
11. [游戏特定适配策略](#11-游戏特定适配策略)
12. [工具速查表](#12-工具速查表)
13. [常见问题与坑点](#13-常见问题与坑点)

---

## 1. UE 打包机制概述

### 1.1 关键概念

| 概念 | 说明 |
|------|------|
| **`.pak`** | UE 的加密/压缩资产包，本质是自定义格式的归档文件，内部存储文件路径→数据映射 |
| **`.uasset`** | UE 资产序列化文件头，包含资产元数据、导入/导出表、属性数据 |
| **`.uexp`** | UE 资产的导出数据（Export Data），与 `.uasset` 成对出现 |
| **`.ubulk`** | 可选的大块数据文件（纹理、网格体原始数据等） |
| **`.ucas`/`.utoc`** | UE5 IoStore 容器格式（UE5.0+），替代传统的 `.pak` + 内部目录结构 |
| **`Asset Registry`** | UE 的资产注册表，记录所有资产的元信息与依赖关系 |
| **`AssetPackage`** | UE 的包（.uasset + .uexp），是最小的可加载单元 |

### 1.2 PAK 文件内部结构

```
┌──────────────────────────────────┐
│  PAK Header (Magic + Version)    │
├──────────────────────────────────┤
│  PAK Index (File Table)          │  ← 文件路径 → Offset/Size/Hash
│    /Game/Blueprints/BP_Enemy.uasset
│    /Game/Blueprints/BP_Enemy.uexp
│    /Game/Maps/Level1.umap
│    ...                           │
├──────────────────────────────────┤
│  Compressed Data Blocks          │  ← 通常使用 Zlib 或 Oodle 压缩
│    [Block 0] [Block 1] ...       │
├──────────────────────────────────┤
│  PAK Footer (Index Offset, Hash) │
└──────────────────────────────────┘
```

### 1.3 加密机制

- **AES-256 加密**: 许多商业游戏会加密 PAK 文件（如 `FORTNITE`, `PUBG` 等）
- 加密 Key 通常嵌入在游戏的可执行文件中（`Shipping.exe`）
- 部分使用非对称加密（公钥嵌入 EXE、私钥在服务器）—— 这种无法直接解包
- **IoStore (.ucas/.utoc)**: UE5 新容器格式，使用不同的压缩和加密策略

---

## 2. 工具链清单

### 2.1 必装工具

| 工具 | 用途 | 获取 |
|------|------|------|
| **FModel** | PAK/IoStore 解包、资产浏览、JSON 导出 | [github.com/4sval/FModel](https://github.com/4sval/FModel) |
| **UE Viewer (UModel)** | 3D 模型/纹理预览、批量导出 | [gildor.org](https://www.gildor.org/en/projects/umodel) |
| **UnrealPak** | PAK 创建/解包（UE 官方工具） | 随 UE 引擎分发，或从 Epic Games Launcher 获取 |
| **QuickBMS** | 通用游戏归档解包脚本 | [quickbms.com](http://quickbms.com) |
| **UE4SS (UE4 Scripting System)** | 运行时 Lua 注入、Dump 内存 | [github.com/UE4SS-RE/RE-UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) |

### 2.2 进阶工具

| 工具 | 用途 |
|------|------|
| **CUE4Parse** (.NET 库) | 编程解析 .uasset/.uexp，FModel 的底层库 |
| **Asset Editor / UAssetGUI** | 手工编辑 .uasset 中的属性值 |
| **HxD / ImHex / 010 Editor** | 十六进制编辑器，用于分析文件头、定位加密 Key |
| **Ghidra / IDA Pro** | 反汇编游戏 EXE/DLL，分析 PAK 加载逻辑、提取 AES Key |
| **x64dbg** | 动态调试，Hook PAK 解密函数 |
| **UE5 Dumper** | 内存 Dump GNames/GObjects 数组 |
| **ReClass.NET** | 运行时数据结构逆向 |
| **Blender + psk/psa 插件** | 3D 资产编辑与重导入 |
| **Unreal-Localization-Editor** | 本地化文本提取与重打包 |

### 2.3 推荐工具组合

```
基础流程: FModel (浏览+解包) → UAssetGUI (修改属性) → UnrealPak (重新打包)
深入逆向: UE4SS (运行时注入) → Ghidra (EXE分析) → CUE4Parse (编程批处理)
```

---

## 3. 第一阶段：信息收集与版本识别

### 3.1 确定 UE 版本

版本信息藏在多处，按优先级排序：

#### 方法 A: 查看 PAK 文件头 (最可靠)

```bash
# 用十六进制编辑器打开任意 .pak 文件，查看前 8 字节
# Magic: 0x5A6F12E1 (PAK magic number)

# Offset 0x04: Version (int32)
# 常见值:
#  7 = UE 4.14-
#  8 = UE 4.15-4.20
#  9 = UE 4.21 (新增 AES256 支持)
#  10 = UE 4.22-4.24
#  11 = UE 4.25-4.27
#  12 = UE 5.0-5.2 (EPakVersion 引入 FrozenIndex + PathHashIndex)
#  13 = UE 5.3+ (IoStore 增强)
```

#### 方法 B: 查看游戏 EXE 属性

```powershell
# 右键 .exe → 详细信息 → 查看 "File version" 字段
# 或使用 PowerShell:
(Get-Item "Shipping.exe").VersionInfo | fl *
```

#### 方法 C: 内存 Dump 引擎版本字符串

```
使用 UE4SS 启动游戏，在控制台中执行:
  getEngineVersion()
  # 输出类似: "4.27.2-0+++UE4+Release-4.27"
```

#### 方法 D: FModel 自动检测

```
FModel 加载 PAK 时会尝试自动识别 UE 版本并显示在底部状态栏
```

### 3.2 IoStore 检测

如果 `.paks/` 目录下没有 `.pak` 文件，而是有 `.ucas`/`.utoc` 文件：

- 确认游戏使用 UE5.0+ 的 **IoStore** 容器系统
- 需要 FModel 5.0+ 或 UE5 原版 UnrealPak
- IoStore 文件通常**不加密**或使用与 PAK 不同的加密方案

### 3.3 加密检测

```bash
# 用 QuickBMS + 标准 UE4 pak 脚本尝试解包
# 如果返回 "encrypted" 或签名/哈希校验失败 → 文件被加密

# 用 FModel 尝试打开:
# 状态栏显示 "AES KEY REQUIRED" → 需要提取 Key
```

### 3.4 游戏引擎定制程度评估

评估游戏引擎的修改程度，决定逆向难度：

| 定制程度 | 特征 | 影响 |
|---------|------|------|
| **低** | 标准 PAK 格式、未修改 AssetRegistry | 标准工具即可 |
| **中** | 自定义 PAK 版本号、修改属性序列化 | 需要适配 CUE4Parse |
| **高** | 自研打包格式、VM 保护 EXE | 需要深度逆向 |
| **极高** | 服务端校验资产哈希、反作弊系统 | 仅限离线 Mod |

```
检查方法:
1. 对比 PAK Header 与标准版本
2. 尝试用 UModel 打开 → 看兼容性选项列表
3. 在 Ghidra 中搜索 PAK 相关字符串 (".pak", "PakFile", "FPakFile")
```

---

## 4. 第二阶段：PAK 解包

### 4.1 无加密 PAK 的解包

#### 方法 A: FModel (推荐，最方便)

```
步骤:
1. 启动 FModel
2. 设置 → 添加游戏 → 选择 PAK 目录
3. 设置 UE 版本 (5.3 选择 GAME_UE5_3 等)
4. 双击 PAK 文件加载
5. 左侧树形浏览所有资产
6. 右键 → Extract 或 Export Data
```

#### 方法 B: UnrealPak (官方工具)

```powershell
# 解包:
UnrealPak.exe "C:\Game\Paks\pakchunk0.pak" -Extract "C:\Game\Extracted" -ExtractToml

# 查看 PAK 内容列表:
UnrealPak.exe "C:\Game\Paks\pakchunk0.pak" -List

# 测试 PAK 完整性:
UnrealPak.exe "C:\Game\Paks\pakchunk0.pak" -Test
```

#### 方法 C: QuickBMS

```
1. 下载 QuickBMS + unreal_tournament_4.bms 脚本
2. 运行 QuickBMS → 选择脚本 → 选择 PAK → 选择输出目录
3. 适用于非标准/旧版本 UE 游戏
```

### 4.2 加密 PAK 的解包

#### Step 1: 提取 AES Key

**方法 A: 从 EXE 静态提取**

```python
# 使用 Ghidra/IDA 分析 Shipping.exe
# 定位目标函数 (常见模式):

# 模式1: 搜索 AES key 常量字符串
# 搜索 "0x" 开头的 256-bit hex 字符串 (64个十六进制字符)

# 模式2: 定位 FPakPlatformFile::Initialize → DecryptPak
# 该函数通常调用 FAES::DecryptData

# 模式3: Hook PAK 解密 API (需要动态调试)
# 在 x64dbg 中设置断点:
#   - Windows Crypto API: BCryptDecrypt / CryptDecrypt
#   - 自定义 AES 实现: 搜索 AES S-Box (0x63, 0x7c, 0x77, 0x7b...)
```

**方法 B: 使用 AES Key Finder 工具**

```bash
# 使用现成工具:
# 1. AESKeyFinder (Valve games)
# 2. pak-decrypt (GitHub 搜索 "ue4 pak aes finder")
# 3. 部分游戏社区会公开 Key (cs.rin.ru 论坛)
```

**方法 C: 内存 Dump (最可靠但需要游戏能运行)**

```
1. 启动游戏到主菜单
2. 用 Process Hacker / Cheat Engine 附加进程
3. 搜索内存中的 AES Key (游戏初始化 PAK 后 Key 存在内存中)
4. 搜索模式: 32 字节的随机分布数据 (非全零、非全FF、熵值高)
5. 逐个尝试候选 Key

UE4SS 辅助:
  配置 UE4SS 的 UMapInfo 插件，它能自动 dump AES Key
```

#### Step 2: 使用 Key 解包

```powershell
# FModel 中:
# Settings → AES → 填入 Key → 重启加载 PAK

# UnrealPak (某些版本):
UnrealPak.exe "pakchunk0.pak" -Extract "Output" -CryptoKeys="key.json"

# 手动解密 (Python 脚本):
# 见本文 附录 A
```

### 4.3 IoStore (.ucas/.utoc) 解包

```
FModel 5.0+ 直接支持 IoStore:
1. 设置 UE 版本为 GAME_UE5_0 或更高
2. 选择 .utoc 文件加载
3. 浏览并导出

命令行:
UnrealPak.exe "Container.utoc" -Extract "Output" -ExtractToml
```

### 4.4 解包后的目录结构

```
Extracted/
├── Engine/
│   ├── Content/          ← 引擎通用资产
│   └── Plugins/          ← 引擎插件
├── Game/                 ← 游戏内容 (核心)
│   ├── Blueprints/       ← 蓝图
│   ├── Characters/       ← 角色
│   ├── Maps/             ← 关卡
│   ├── Textures/         ← 纹理
│   ├── Audio/            ← 音频
│   ├── UI/               ← UI 资源
│   ├── DataTables/       ← 数据表
│   ├── Data/             ← 数据资产
│   └── Config/           ← 游戏配置
└── AssetRegistry.bin     ← 资产注册表
```

---

## 5. 第三阶段：资产格式深入解析

### 5.1 .uasset 文件结构

```
┌──────────────────────────────────────────────┐
│  FPackageFileSummary (Package Header)         │
│  - Tag (0x9E2A83C1)                         │
│  - FileVersionUE4 / FileVersionUE5           │
│  - PackageFlags                              │
│  - NameCount / NameOffset                    │
│  - ImportCount / ImportOffset                │
│  - ExportCount / ExportOffset                │
│  - GUID                                      │
│  - Generations[]                             │
│  - EngineVersion                             │
│  - CompressionFlags                          │
├──────────────────────────────────────────────┤
│  FNameEntrySerialized[] (Name Table)          │
│  - 资产内部使用的 FName 字符串表              │
├──────────────────────────────────────────────┤
│  FObjectImport[] (Import Table)               │
│  - 外部依赖 (引用的其他包中的对象)             │
├──────────────────────────────────────────────┤
│  FObjectExport[] (Export Table)              │
│  - 包内导出的对象列表                         │
│  - 每个 Export 指向 .uexp 中的序列化数据       │
└──────────────────────────────────────────────┘
```

### 5.2 .uexp 文件结构

```cpp
// .uexp 包含所有 Export 对象的属性数据
// 格式: 连续的 FStructuredArchive 序列化数据

struct FObjectExport {
    int32   SerialSize;       // .uexp 中的数据大小
    int64   SerialOffset;     // .uexp 中的数据偏移
    FPackageIndex ClassIndex; // 对象类型 (指向 Import Table)
    FPackageIndex SuperIndex; // 父类
    FPackageIndex TemplateIndex;
    FName    ObjectName;
    uint32   ObjectFlags;
    // ...
};
```

### 5.3 .ubulk 文件

```
.ubulk = 大块二进制数据
- 纹理的 Pixel Data (BulkData)
- 网格体的 Vertex/Index Buffer
- 音频的 PCM 数据

在 .uasset 中标记为:
  BulkDataSize > 0 && BulkDataType == BULKDATA_OptionalPayload
```

### 5.4 关键资产类型与识别

| 文件扩展名 | 资产类型 | 核心数据 | 逆向优先级 |
|-----------|---------|---------|-----------|
| `.umap` | Map/Level | Actor 列表、光照、NavMesh | ★★★ |
| `.uasset` (Blueprint) | 蓝图 | 变量、函数图、组件层级 | ★★★★★ |
| `.uasset` (DataTable) | 数据表 | 结构化行数据 (CSV-like) | ★★★★★ |
| `.uasset` (DataAsset) | 数据资产 | 自定义属性集合 | ★★★★ |
| `.uasset` (Widget) | UMG UI | 控件树、绑定 | ★★★ |
| `.uasset` (SkeletalMesh) | 骨骼网格 | LOD、材质槽、物理资产 | ★★★ |
| `.uasset` (Texture2D) | 2D 纹理 | 分辨率、格式、Mip 数 | ★★ |
| `.uasset` (Material) | 材质 | Shader 节点图 | ★★★ |
| `.uasset` (AnimBlueprint) | 动画蓝图 | 状态机、混合空间 | ★★★ |
| `.uasset` (SoundWave) | 音频 | 压缩格式、采样率 | ★★ |
| `.uasset` (CurveTable) | 曲线表 | 浮点曲线数据 | ★★★ |

---

## 6. 第四阶段：核心资产逆向

### 6.1 DataTable 数据的提取（最易出成果）

DataTable 是 UE 中最容易修改的资产，通常是 Mod 的主要目标。

#### 方法: FModel → JSON → 修改 → 回编

```
步骤:
1. FModel 中定位 DataTable (.uasset)
2. 右键 → Export Data → 选择 JSON 格式
3. 得到人类可读的行数据:

{
  "Name": "DT_EnemyStats",
  "Class": "DataTable",
  "Rows": {
    "Goblin": {
      "HP": 100,
      "Attack": 15,
      "Speed": 120.0
    },
    ...
  }
}

4. 修改 JSON 中的数值
5. 使用 UAssetGUI 导回 JSON
6. 重新打包为 .pak
```

### 6.2 纹理 MOD（换皮）

```
流程:
1. FModel 浏览 Textures/ 目录
2. 右键 Texture2D → Save Image → PNG/TGA
3. Photoshop/GIMP 编辑纹理
4. 使用 UAssetGUI 替换 BulkData 引用
5. 重新打包

或者使用 UTOC (Unreal Texture Override Creator):
  - 拖入替换纹理
  - 自动创建 Patch .pak
```

### 6.3 模型修改

```
1. 用 UModel 导出为 .psk (静态) 或 .pskx (骨骼)
2. 导入 Blender (需 psk/psa 导入插件)
3. 编辑网格体
4. 导出回 .psk
5. 用 UE 引擎的 SkeletalMesh 工具重导入
6. 替换原始资产重新打包

注意: 模型修改通常需要保持顶点数/骨骼数一致，
     否则需要同时修改骨骼资产和物理资产（复杂度高）
```

### 6.4 属性修改（非 DataTable 资产）

```
场景: 修改某个 Blueprint 的默认属性值 (如移动速度)

工具: UAssetGUI

步骤:
1. FModel 定位目标 Blueprint 资产的 .uasset + .uexp 对
2. 用 UAssetGUI 打开 .uasset
3. 在 Export Data 中找到 ClassDefaultObject (CDO)
4. 定位要修改的属性名 (如 "MaxWalkSpeed")
5. 修改数值
6. 保存 (UAssetGUI 会同时更新 .uasset 和 .uexp)
7. 重新打包

注意:
- 必须同时发布 .uasset + .uexp
- 如果修改涉及 BulkData (纹理/模型)，还需要 .ubulk
```

---

## 7. 第五阶段：Mod 制作与修改

### 7.1 Mod 类型与加载机制

UE 游戏加载 Mod 的三种方式：

#### 方式 A: Loose Files（松散文件）—— 最简单

```
原理: UE 引擎加载资产时先检查磁盘路径，再检查 .pak

操作:
将修改后的 .uasset + .uexp 按原始路径放入:
  <GameRoot>\Content\Game\Blueprints\BP_Enemy.uasset
  <GameRoot>\Content\Game\Blueprints\BP_Enemy.uexp

引擎会优先加载磁盘上的版本而非 PAK 中的版本。

优点: 无需重新打包，方便调试
缺点: 部分游戏禁用了 Loose File 加载 (Shipping 构建)
```

#### 方式 B: Mod PAK 文件 —— 推荐

```
原理: 创建一个新的 .pak 文件，覆盖原始 pak 中的资产

命名规则 (UE 按序加载 PAK):
  pakchunk0-WindowsClient.pak   ← 原始
  pakchunk1-WindowsClient.pak   ← 原始
  _P.pak                         ← Mod (优先加载，因为 P > 数字)

实际命名建议:
  如果你的 Mod 叫 "MyMod":
    MyMod_P.pak    ← _P 后缀确保最高优先级
    或
    zMyMod_P.pak   ← z 开头确保在所有 pak 中排最后加载

PAK Mount Point:
  必须设置正确的 Mount Point 为 "../../../"

打包命令:
  UnrealPak.exe MyMod_P.pak -Create=manifest.txt -compress
```

#### 方式 C: Mod Loader 注入（高级）

```
原理: 通过 DLL 注入或 Proxy DLL 劫持来加载自定义代码

工具:
- UE4SS: 注入 Lua 运行时，可以动态修改内存
- DQXIS: DirectX 劫持实现 UI Overlay
- 自写 Proxy DLL (替换 xinput1_3.dll 或 d3d11.dll)

优点: 可以添加全新功能，不局限于资产修改
缺点: 技术难度高，可能触发反作弊
```

### 7.2 Mod 的 manifest.txt 文件

```text
# UnrealPak 的清单文件格式

"../../../Game/Blueprints/BP_Enemy.uasset" "../../../Game/Blueprints/BP_Enemy.uasset"
"../../../Game/Blueprints/BP_Enemy.uexp" "../../../Game/Blueprints/BP_Enemy.uexp"
"../../../Game/DataTables/DT_EnemyStats.uasset" "../../../Game/DataTables/DT_EnemyStats.uasset"
"../../../Game/DataTables/DT_EnemyStats.uexp" "../../../Game/DataTables/DT_EnemyStats.uexp"

# 左侧: 源文件路径 (你修改后的文件)
# 右侧: 目标路径 (PAK 中的挂载路径)

# 可以有选项:
"../../../Game/Textures/T_Hero_Diffuse.uasset" "../../../Game/Textures/T_Hero_Diffuse.uasset" -compress
```

### 7.3 创建 Mod PAK 的完整流程

```powershell
# 1. 准备修改后的文件，保持原始目录结构
mkdir ModWork\Game\Blueprints
copy Modified\BP_Enemy.uasset ModWork\Game\Blueprints\
copy Modified\BP_Enemy.uexp ModWork\Game\Blueprints\

# 2. 生成 manifest
# (在 ModWork 目录下)
pushd ModWork
Get-ChildItem -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Replace((Get-Location).Path + "\", "")
    $mountPath = "../../../" + $relative
    "`"$relative`" `"$mountPath`""
} > manifest.txt
popd

# 3. 打包 (需要对应版本的 UnrealPak.exe)
UnrealPak.exe "MyMod_P.pak" -Create="ModWork\manifest.txt" -compress

# 4. 安装
Copy-Item "MyMod_P.pak" "C:\Game\Game\Content\Paks\"
```

### 7.4 Mod 优先级与冲突处理

```
UE 加载 PAK 的优先级规则:

1. PakOrder 数值越大 → 优先级越高
2. 文件名字典序 (ASCII) → Z > A > 9 > 0
3. _P 后缀 → 最高优先级

所以常见命名:
  pakchunk0-WindowsClient.pak  (优先级最低)
  pakchunk1-WindowsClient.pak
  ...
  MyMod_P.pak                   (优先级最高)

多个 Mod 冲突时:
  - 最后加载的资产覆盖之前的
  - 可以合并多个 Mod 到一个 PAK
  - 或使用 Mod Manager 工具管理加载顺序
```

---

## 8. 第六阶段：打包与加载 Mod

### 8.1 UnrealPak 完整用法

```powershell
# === 查看 PAK 内容 ===
UnrealPak.exe MyGame.pak -List             # 简单列表
UnrealPak.exe MyGame.pak -List -Verbose    # 详细列表 (含压缩信息)

# === 解包 ===
UnrealPak.exe MyGame.pak -Extract OutputDir
UnrealPak.exe MyGame.pak -Extract OutputDir -ExtractToml    # 导出目录结构 TOML

# === 创建 PAK ===
UnrealPak.exe Output.pak -Create=manifest.txt
UnrealPak.exe Output.pak -Create=manifest.txt -compress            # Zlib 压缩
UnrealPak.exe Output.pak -Create=manifest.txt -compress=Oodle      # Oodle 压缩
UnrealPak.exe Output.pak -Create=manifest.txt -encrypt             # 加密 (需要 Key)
UnrealPak.exe Output.pak -Create=manifest.txt -order=order.txt     # 指定文件顺序

# === 加密 ===
UnrealPak.exe Output.pak -Create=manifest.txt -encrypt -CryptoKeys=keys.json

# === 签名 (部分游戏需要) ===
UnrealPak.exe Output.pak -Create=manifest.txt -sign

# === 测试 PAK ===
UnrealPak.exe Output.pak -Test
```

### 8.2 获取正确版本的 UnrealPak

```
UE 版本与 UnrealPak 必须匹配！版本不匹配会导致打包失败或游戏崩溃。

获取方式:
1. 从 Epic Games Launcher 安装对应版本的 UE 引擎
   路径: UE_4.27\Engine\Binaries\Win64\UnrealPak.exe

2. 从 UE 源码编译 (GitHub UE 仓库)

3. 从游戏本身提取:
   部分游戏会在 /Engine/Binaries/ 中包含 UnrealPak.exe

版本对应表:
  游戏 UE 版本    → 需要的 UnrealPak 版本
  UE 4.27         → 4.27 引擎的 UnrealPak
  UE 5.1          → 5.1 引擎的 UnrealPak
  UE 5.3          → 5.3 引擎的 UnrealPak (推荐此版本)
```

### 8.3 IoStore Mod 打包 (UE5)

```powershell
# UE5 IoStore 使用不同的打包流程

# 方式1: 使用 UE5 Editor 创建 DLC/Mod
# (需要完整的 UE5 引擎 + 项目配置)

# 方式2: 使用 FModel/CUE4Parse 工具
# 目前 IoStore Mod 生态还在发展中

# 方式3: 降级为传统 PAK
# 某些 UE5 游戏同时支持 PAK 和 IoStore，可以创建 _P.pak 覆盖

# 方式4: UnrealPak 5.3+
UnrealPak.exe MyMod -CreateIoStore=manifest.txt
```

### 8.4 Mod 测试与调试

```powershell
# 1. 启动游戏 (带日志)
Game.exe -log -verbose

# 2. 查看日志文件
# %LOCALAPPDATA%\GameName\Saved\Logs\

# 3. 常见错误日志模式:
# "Failed to load /Game/Blueprints/BP_Enemy"  → 资产路径错误或格式不兼容
# "Pak signature check failed"                → 需要签名或关闭签名检查
# "Corrupt pak file"                          → 打包版本不匹配
# "BulkData compressed header mismatch"       → .ubulk 未正确打包
```

---

## 9. 进阶：蓝图逆向与逻辑还原

### 9.1 蓝图序列化结构

```
Blueprint 的 .uexp 中存储:

1. UClass → ClassDefaultObject (CDO) → 默认属性值
2. USCS_Node[] → SimpleConstructionScript → 组件层级
3. UEdGraph[] → EventGraph, FunctionGraphs →
   - Nodes[]: UK2Node_* (函数调用、变量读写、流程控制)
   - Pins[]: 节点间的连接关系
   - 每个 Pin: PinName, PinType, LinkedTo[]
```

### 9.2 蓝图节点类型

| UK2Node 子类 | 含义 | 还原难度 |
|--------------|------|---------|
| `K2Node_CallFunction` | 调用函数 | ★ |
| `K2Node_VariableGet/Set` | 变量读写 | ★ |
| `K2Node_IfThenElse` | 分支 | ★ |
| `K2Node_ExecutionSequence` | 顺序执行 | ★ |
| `K2Node_CallArrayFunction` | 数组操作 | ★★ |
| `K2Node_DynamicCast` | 类型转换 | ★★ |
| `K2Node_MacroInstance` | 宏调用 | ★★★ |
| `K2Node_Tunnel` | 函数入口/出口 | ★★ |
| `K2Node_CustomEvent` | 自定义事件 | ★★ |
| `K2Node_Timeline` | 时间轴 | ★★★ |
| `K2Node_Delegate` | 委托绑定 | ★★★★ |

### 9.3 蓝图逆向工具与方法

#### 方法 A: FModel 的 Blueprint Viewer

```
FModel 内置了蓝图查看器:
- 右键 Blueprint → View Blueprint
- 可以查看变量、函数签名
- 不能完全还原节点图逻辑
```

#### 方法 B: KGEnigma (蓝图可视化还原)

```
KGEnigma: UE4 Blueprint graph reconstruction tool
功能:
- 解析 .uexp 中的 K2Node 数据
- 重建成可读的节点图
- 导出为 Graphviz / 自定义格式

限制:
- 仍在开发中，支持部分节点类型
- 复杂蓝图可能无法完全重建
```

#### 方法 C: CUE4Parse 编程分析

```csharp
// C# 示例: 使用 CUE4Parse 读取蓝图属性
using CUE4Parse;
using CUE4Parse.UE4.Assets.Exports;

var provider = new DefaultFileProvider("GameDir", SearchOption.TopDirectoryOnly);
provider.Initialize();

var blueprint = provider.LoadObject("Game/Blueprints/BP_Enemy");
var exports = blueprint.Exports;

foreach (var export in exports)
{
    Console.WriteLine($"Export: {export.ExportType}");
    // 遍历属性...
}
```

#### 方法 D: UE4SS 运行时 Hook

```lua
-- UE4SS Lua 脚本: Hook 蓝图函数调用
local TargetClass = UObjectBlueprintGeneratedClass.Load("Game/Blueprints/BP_Enemy")

RegisterHook("/Script/Engine.Actor:TakeDamage", function(self, Damage, DamageType, InstigatedBy, DamageCauser)
    print(string.format("%s took %.2f damage", self:GetName(), Damage))
    return self.TakeDamage(self, Damage, DamageType, InstigatedBy, DamageCauser)
end)
```

### 9.4 蓝图逻辑还原策略

```
优先级策略:
1. 先还原 DataTable → 直接拿到数值 (最容易)
2. 读取 CDO 默认属性 → 了解初始状态
3. 分析函数签名 → 理解接口 (参数名 + 类型)
4. 用 UE4SS 运行时观测 → 打印执行流程
5. 最后尝试完全重建节点图 (最复杂，按需)

经验法则: 80% 的游戏逻辑隐藏在 DataTable 和 CDO 属性中，
          只有 20% 需要真正逆向蓝图节点图
```

---

## 10. 进阶：C++ 层逆向

### 10.1 何时需要 C++ 层逆向

```
需要深入 EXE/DLL 的场景:
- 提取 AES PAK 加密 Key
- 禁用 PAK 签名校验 (EditSignatureCheck)
- 修改引擎行为 (渲染、物理、网络)
- 绕过反作弊/反篡改机制
- 分析自定义序列化/压缩算法
- 注入自定义 GameMode/GameInstance
```

### 10.2 EXE/DLL 分析方法

#### Step 1: 识别目标二进制

```
核心文件:
  <GameName>.exe              ← 主启动器 (通常不含游戏逻辑)
  <GameName>-Shipping.exe     ← Shipping 构建 (无调试符号)
  <GameName>-Win64-Shipping.exe ← 常见命名

引擎 DLL:
  UE4-{ModuleName}-Win64-Shipping.dll
  MSVCP140.dll, VCRUNTIME140.dll ← 运行时库

常见游戏逻辑 DLL:
  <GameName>/Binaries/Win64/*.dll
  ./Plugins/*/Binaries/Win64/*.dll
```

#### Step 2: 静态分析 (Ghidra/IDA)

```c
// 关键函数搜索模式 (Ghidra):

// 1. PAK 解密
// 搜索字符串: "DecryptData", "AES256", "PakFile"
// 定位: FPakPlatformFile::Initialize

// 2. 签名校验
// 搜索字符串: "PakSign", "SignatureCheckFailed"
// 定位: FPakFile::CheckSignature
// Patch: 跳过校验 → 修改 JNZ/JE 为 JMP

// 3. 引擎初始化
// 搜索字符串: "GEngine", "GameInstance"
// 定位: UEngine::Init → 可以 Hook 注册自定义模块

// 4. 控制台命令
// 搜索字符串: "Exec", "ConsoleCommand"
// 定位: UPlayer::Exec → 可以添加自定义控制台命令
```

#### Step 3: 动态调试 (x64dbg)

```
Hook 策略:

1. PAK 解密 Hook:
   BP on: Windows Crypto API → BCryptDecrypt
   函数返回时 dump 解密后的数据

2. 文件加载 Hook:
   BP on: CreateFileW → 过滤 ".pak" 字符串
   → 追踪文件句柄 → 定位 PAK 读取位置

3. 内存搜索:
   FModel 导出的资产路径字符串
   → 搜索游戏进程内存
   → 定位资产加载地址

4. Loose Files 绕过:
   Hook FPakPlatformFile::FindFileInPakFiles
   → 强制返回 Not Found → 引擎使用磁盘文件
```

### 10.3 创建内部 Mod (Internal Mod)

```cpp
// 方案: DLL 注入 + 引擎修改

// 1. 创建 Proxy DLL (例如 dinput8.dll)
BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved)
{
    if (fdwReason == DLL_PROCESS_ATTACH)
    {
        DisableThreadLibraryCalls(hinstDLL);
        CreateThread(nullptr, 0, InitMod, nullptr, 0, nullptr);
    }
    return TRUE;
}

// 2. 在 InitMod 中:
//    - 获取 GEngine / GWorld 指针
//    - 遍历 Actor 列表
//    - 修改运行时属性
//    - 注册自定义 Spawner

// 3. GEngine 定位模式 (UE 4.22+):
//    搜索: 48 8B 1D ? ? ? ? 48 8B CB 48 85 DB 74 ? (x64)
//    → mov rbx, [rip + offset]  → GEngine
```

### 10.4 反射系统利用

```cpp
// UE 的 UObject 反射系统可以在运行时获取/修改任何属性

// 利用反射系统的路径:
// 1. 获取 UClass: FindObject<UClass>("Class /Script/Engine.Actor")
// 2. 遍历 UProperty (UObject::GetPropertyByName)
// 3. 读取/写入属性值
// 4. 调用函数: UObject::ProcessEvent(UFunction, Params)

// 无符号情况下利用 Offset 定位:
// - GNames:    UE 4.x: +0x20 from GEngine (x64)
// - GObjects:  UE 4.x: +0x30 from GEngine (x64)
// - UObjectArray: GObjects → FUObjectArray → ObjObjects
```

---

## 11. 游戏特定适配策略

### 11.1 不同引擎版本的特殊处理

```yaml
UE 4.14 及更早:
  - PAK Version ≤ 7
  - 无 AES 加密
  - 资产格式差异大，需要老版本 FModel/UE Viewer

UE 4.15–4.20:
  - PAK Version 8
  - 支持 Oodle 压缩 (UE 4.16+)
  - Asset Registry 格式稳定

UE 4.21–4.24:
  - PAK Version 9 (AES256 支持)
  - 属性序列化格式变化 (FProperty → FPropertyTag)
  - FName 多语言改进

UE 4.25–4.27:
  - PAK Version 10
  - 新增 FEditorObjectVersion
  - Niagara VFX 系统成熟

UE 5.0–5.2:
  - PAK Version 11 (FrozenIndex)
  - 引入 IoStore (.ucas/.utoc)
  - Chaos Physics (替代 PhysX)
  - Lumen / Nanite 资产

UE 5.3+:
  - PAK Version 12+
  - IoStore 增强
  - 虚拟纹理池改进
  - World Partition 系统
```

### 11.2 常见引擎定制模式

```yaml
日本游戏 (SEGA/Atlus/Bandai Namco):
  - 常用 UE 4.18-4.25
  - 可能修改 PAK Magic Number
  - 自定义压缩算法 (非标准 Zlib)
  - 纹理格式: BC7, ASTC (Switch), 自定义

中国游戏:
  - 常用 UE 4.26-4.27
  - 反作弊: TenProtect, ACE, MTP
  - 服务端校验资产哈希
  - 自定义 Shader 格式

韩国游戏:
  - 常用 UE 4.24-4.27
  - 可能使用 IoStore 但回退兼容
  - 多层加密 (PAK XOR + AES)
  - 资产表加密

独立游戏:
  - 多版本混用
  - 较少加密
  - 可能包含调试符号 (更容易逆向)
```

### 11.3 反篡改机制应对

```
1. PAK 签名校验:
   定位: FPakFile::CheckSignature
   绕过: Patch EXE → 跳转替换为 ret 1
   风险: 可能触发完整性检查崩溃

2. 哈希校验:
   定位: 字符串 "GlobalShaderHash", "PakHash"
   绕过: Hook 哈希计算函数 → 返回原始值

3. 反作弊 (EAC/BattlEye/Xigncode):
   策略: 仅做离线 Mod，不碰在线功能
   测试: 断网模式下运行

4. VM/混淆保护:
   识别: Themida, VMProtect 包裹的 EXE
   应对: 用 x64dbg 从内存 dump 解密后的 PE
   风险: 高，建议先尝试非侵入式 Mod (纯资产修改)
```

---

## 12. 工具速查表

### 12.1 按阶段推荐工具

```
┌─────────────────────┬──────────────────────────────────────┐
│ 阶段                │ 推荐工具                             │
├─────────────────────┼──────────────────────────────────────┤
│ PAK 浏览/解包       │ FModel ★★★★★                       │
│ 资产格式解析        │ CUE4Parse (库) / UAssetGUI (手工)    │
│ 3D 模型查看/导出     │ UModel (UE Viewer) ★★★★★           │
│ 纹理查看/导出       │ FModel (内置)                        │
│ 蓝图浏览            │ FModel (内置)                        │
│ 蓝图可视化还原      │ KGEnigma (实验性)                    │
│ DataTable 编辑      │ FModel Export JSON + UAssetGUI       │
│ 属性编辑            │ UAssetGUI ★★★★★                     │
│ PAK 创建/打包       │ UnrealPak (官方) ★★★★★              │
│ PAK 加密            │ UnrealPak 或自写脚本                 │
│ AES Key 提取        │ Ghidra + x64dbg ★★★★★               │
│ 运行时 Hook/注入    │ UE4SS ★★★★★                        │
│ 内存分析            │ Cheat Engine / ReClass.NET           │
│ 二进制逆向          │ Ghidra (静态) + x64dbg (动态)       │
│ 十六进制分析        │ ImHex / 010 Editor                   │
│ 3D 模型编辑         │ Blender + psk/psa 插件              │
│ 纹理编辑            │ Photoshop / GIMP                     │
│ Mod 通用框架        │ UE4SS + Lua 脚本                    │
│ 批量资产处理        │ CUE4Parse 自定义脚本                │
└─────────────────────┴──────────────────────────────────────┘
```

### 12.2 IoStore 专用工具

```
FModel 5.x         ← 主力 (浏览 + 导出)
UnrealPak 5.3+     ← 打包
CUE4Parse 1.2+     ← 库
UE5 Editor         ← 创建 IoStore 容器 (需完整引擎)
```

---

## 13. 常见问题与坑点

### 13.1 资产不匹配导致崩溃

```
症状: 打包 Mod PAK 后游戏崩溃在启动时
原因:
  1. UnrealPak 版本不匹配
  2. .uasset 版本号不兼容 (用较新引擎打开过)
  3. 缺少 .uexp (只打包了 .uasset)
  4. 资产引用路径错误

解决:
  - 使用与游戏完全相同的 UE 版本
  - 确保 .uasset + .uexp 成对发布
  - 检查 Mount Point 路径格式 "../../../Game/..."
  - 用 -verbose 日志定位崩溃资产名
```

### 13.2 Mod 不生效

```
检查清单:
□ PAK 文件名是否以 _P.pak 结尾
□ PAK 是否放在正确的 Paks/ 目录
□ 是否有其他同名资产覆盖了你的 Mod
□ 游戏是否启用了签名校验 (Paksigcheck)
□ 文件系统是否为 NTFS (大小写敏感)

调试方法:
  FModel 加载你的 Mod PAK → 检查内部路径是否正确
  游戏 log 中搜索 "MountPak" → 确认 PAK 被加载
  log 中搜索你的资产路径 → 确认加载来源
```

### 13.3 加密 Key 提取失败

```
备选方案:
1. 搜索 GitHub: "<游戏名> aes key"
2. 搜索 cs.rin.ru 论坛
3. 使用 Process Hacker dump 游戏内存 (游戏运行时)
4. 寻找游戏更新补丁中的未加密文件
5. 如果游戏有 Demo/试玩版 → Demo 版本可能不加密
```

### 13.4 IoStore 兼容性

```
UE5 游戏 (使用 .ucas/.utoc):
  - 确认 FModel 版本 ≥ 5.0
  - 部分 UE5 游戏同时保留 .pak 兼容 → 优先用 PAK 方式
  - IoStore 的 Mod 打包需要使用 UE5 Editor
  - 如果游戏同时加载 PAK 和 IoStore → _P.pak 通常优先
```

---

## 附录 A: Python PAK 解密脚本模板

```python
"""
UE4/UE5 PAK 文件解密工具
依赖: pip install pycryptodome
"""
import struct
import os
from Crypto.Cipher import AES
from Crypto.Util.Padding import unpad

# 标准 UE4/UE5 PAK Magic
PAK_MAGIC = 0x5A6F12E1

def read_pak_header(filepath):
    """读取 PAK 文件头，检测是否加密"""
    with open(filepath, 'rb') as f:
        magic = struct.unpack('<I', f.read(4))[0]
        if magic != PAK_MAGIC:
            raise ValueError(f"非 UE PAK 文件: Magic=0x{magic:08X}")

        version = struct.unpack('<I', f.read(4))[0]
        print(f"PAK Version: {version}")

        # PAK v9+ (UE 4.21+) 有加密标志
        if version >= 9:
            f.seek(0x08)  # Skip magic + version
            index_offset = struct.unpack('<Q', f.read(8))[0]
            index_size = struct.unpack('<Q', f.read(8))[0]
            index_hash = f.read(20)

            bEncrypted = struct.unpack('B', f.read(1))[0]
            print(f"Encrypted: {'Yes' if bEncrypted else 'No'}")

            return {
                'version': version,
                'encrypted': bool(bEncrypted),
                'index_offset': index_offset,
                'index_size': index_size
            }
    return None

def decrypt_pak_data(encrypted_data, aes_key_hex):
    """使用 AES-256 解密 PAK 数据块"""
    key = bytes.fromhex(aes_key_hex)
    cipher = AES.new(key, AES.MODE_ECB)  # UE uses AES-256-ECB
    decrypted = cipher.decrypt(encrypted_data)
    return decrypted

# 使用示例
if __name__ == '__main__':
    PAK_PATH = "pakchunk0-WindowsClient.pak"
    AES_KEY = "0000000000000000000000000000000000000000000000000000000000000000"  # 替换为实际 Key

    info = read_pak_header(PAK_PATH)
    if info and info['encrypted']:
        print(f"需要解密，Key: {AES_KEY}")
        # 解密索引区域...
```

## 附录 B: 推荐学习路径

```
入门 (1-2 周):
  1. 安装 FModel + UModel
  2. 解包游戏 PAK，浏览资产
  3. 导出 DataTable JSON
  4. 修改数值并用 Loose Files 加载测试

进阶 (2-4 周):
  5. 用 UAssetGUI 修改资产属性
  6. 学习 UnrealPak 打包
  7. 制作第一个 .pak Mod
  8. 学习数据表修改、纹理替换

高级 (1-3 月):
  9. 搭建 UE 引擎 (匹配游戏版本)
  10. 学习 CUE4Parse 编程
  11. 提取 AES Key (如果加密)
  12. 运行时注入 (UE4SS)

专家 (3-6 月):
  13. Ghidra/x64dbg 逆向 EXE
  14. 蓝图逻辑完全还原
  15. 编写自定义 Mod 框架
  16. 贡献开源工具
```

## 附录 C: 社区与资源

```
核心工具官网:
  FModel:        https://fmodel.app
  UModel:        https://gildor.org/en/projects/umodel
  UE4SS:         https://github.com/UE4SS-RE/RE-UE4SS
  CUE4Parse:     https://github.com/FabianFG/CUE4Parse
  UAssetGUI:     https://github.com/atenfyr/UAssetGUI

论坛:
  cs.rin.ru       ← 最大游戏逆向社区 (需注册)
  gildor.org      ← UModel 开发者论坛
  zenhax.com      ← QuickBMS / 通用解包
  Nexus Mods      ← Mod 发布平台

参考文档:
  UE 官方源码:    https://github.com/EpicGames/UnrealEngine (需 Epic 账号)
  AgentSvoh 的 PAK 格式分析: https://github.com/panzi/rust-u4pak
  FluffyQuack 的 UE Modding 指南: YouTube 系列

Discord 社区:
  UE Modding     ← 搜索 "UE Modding Discord"
  FModel         ← 搜索 "FModel Discord"
```

---

> **最后提醒**: Mod 制作请遵守游戏 EULA，仅用于个人学习与离线娱乐目的。请勿在联网游戏中使用 Mod，以免被反作弊系统检测导致封号。
