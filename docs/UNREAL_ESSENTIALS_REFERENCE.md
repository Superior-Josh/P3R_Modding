# UnrealEssentials 能力速查（上游 README 提炼）

> **来源**：[github.com/AnimatedSwine37/UnrealEssentials](https://github.com/AnimatedSwine37/UnrealEssentials) `README.md`（2026-06-24 抓取）
> **本仓库实际安装版本**：[`tools/Reloaded II/Mods/UnrealEssentials/ModConfig.json`](../tools/Reloaded%20II/Mods/UnrealEssentials/ModConfig.json) 标注 `ModVersion: 2.0.0`
> **本仓库实际安装的 P3R 适配层**：[`tools/Reloaded II/Mods/p3rpc.essentials/ModConfig.json`](../tools/Reloaded%20II/Mods/p3rpc.essentials/ModConfig.json) `ModVersion: 1.3.0`
>
> 本文档是 P3R 项目使用 UnrealEssentials 时的**权威能力清单**。当 [`CLAUDE.md`](../CLAUDE.md) / [`docs/MODDING_PITFALLS.md`](MODDING_PITFALLS.md) 中的描述与上游 README 冲突时，以本文档为准；同时把不一致的地方修回去。

---

## 1. UnrealEssentials 是什么

> *"A mod for Reloaded-II that makes it easy for other mods to replace files in Unreal Engine games."*

它是 Reloaded II 模组管理器下的一个**通用 UE 文件替换中间层**，作用对象是 UE 4.25–4.27 与 UE 5.0–5.7 的游戏。在我们的项目里它是 **P3R Mod 加载链的核心**，覆盖三件事：

1. **替换 UTOC / PAK 容器内的文件**（IoStore 与传统 PAK 都行）
2. **去掉游戏对 UTOC/PAK 的签名校验**——这是 mod 资产能被注入的前提
3. **记录被访问的文件**，便于排错（在 Reloaded II 的日志面板里查看）

P3R 是上游官方列名的支持游戏（UE 4.27）；上游还**额外推荐**装 [Persona 3 Reload Essentials (p3rpc.essentials)](https://gamebanana.com/mods/494020)——它是依赖 UnrealEssentials 之上的 P3R 专用运行时补丁层（去焦点暂停 / 跳开场 / 快速菜单），**不替换 .uasset**。详见 [`docs/P3RPC_ESSENTIALS_REFERENCE.md`](P3RPC_ESSENTIALS_REFERENCE.md)。

---

## 2. 支持的输入形态（重点）

UnrealEssentials 同时接受**两种粒度**的输入：

### 2.1 整包（Full Packages）

把整个 `.utoc + .ucas` 对（IoStore 容器）或整个 `.pak` 文件**放在 `<Mod>/UnrealEssentials/` 下的任意位置**（可以建子目录）即可——UnrealEssentials 自己排优先级。

- **不需要 `_P` 后缀**（上游原文：*"You do not need to suffix the file names with `_P` ... priority will automatically be sorted by Unreal Essentials"*）；带了也不会出错。
- 来源举例：Scarlet Nexus 社区 mod 走整包路径。
- **对我们 P3R 的意义**：以前我们把 PAK 路径单独配进 `<Mod>/FEmulator/PAK/`；其实把同一个 `.pak` 丢进 `<Mod>/UnrealEssentials/` 也成立。不过项目里两个**已验证可运行**的参考 mod（[`p3rpc.ui.barionskillnames`](../tools/Reloaded%20II/Mods/p3rpc.ui.barionskillnames/) / [`p3r.qol.arkemultiplier`](../tools/Reloaded%20II/Mods/p3r.qol.arkemultiplier/)）都走**散文件**形态，所以我们仍以散文件为默认。

### 2.2 散文件（Loose Assets）

把单个资产文件按**原游戏的虚拟路径**（一般以 `<GameName>/Content/...` 开头）镜像到 `<Mod>/UnrealEssentials/` 下。

P3R 的例子（上游 README 截图原话）：

```
<Mod>/UnrealEssentials/P3R/Content/Xrd777/Font/<原资产名>.uasset
```

这正是项目当前默认走的形态。`<虚拟路径>` 通常用 FModel 浏览 P3R 资产树时看到的路径，或我们 P3RDataTools `read` 命令使用的 `P3R/Content/...` 路径。

---

## 3. ⚠️ Zen 资产 vs 传统 `.uasset+.uexp`（P3R 必读）

上游 README 在 [Adding Loose Assets](https://github.com/AnimatedSwine37/UnrealEssentials#adding-loose-assets) 一节里有一段对 P3R 这类 IoStore 游戏**极其关键**的话（原文）：

> *"Note that if your game uses UTOC files, any `.uasset` files you replace will have to come from a UTOC as the file format is different when they are in PAK files. This means that you will need to export them from Unreal Engine into an IO Store container (`.utoc` + `.ucas`) and then extract them if you want to use them loosely."*

翻译要点：

- **P3R 使用 UTOC**（IoStore 是它的主容器，见 [CLAUDE.md "资产格式"](../CLAUDE.md)），所以**散文件替换的 `.uasset` 必须来自 UTOC**——也就是所谓 **Zen 资产**，从 `.ucas` 直接拆出来的单文件 cooked 字节，**没有伴随的 `.uexp`**（exports / bulk data 全部内嵌在一个 `.uasset` 里）。
- 上游对此的现状是：**Cooked `.uasset+.uexp` → Zen `.uasset` 的自动转换是计划中的 feature**（在上游 README "Planned Features" 里列着），1.x / 2.0 都还没实现。

### 那我们项目当前的 `P3RDataTools.create` 产物属于哪种？

短答：**传统 `.uasset+.uexp` 格式**（首字节 `C1 83 2A 9E`）。

> 已实测：[`tools/Reloaded II/Mods/AgiMod/.../DatSkillNormalDataAsset.uasset`](../tools/Reloaded%20II/Mods/AgiMod/UnrealEssentials/P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset) 首 4 字节为 `C1 83 2A 9E`，配套一个 492 KB 的 `.uexp`。

上游 README 严格按字面读，**理论上不应该工作**——但项目内 AgiMod / `p3r.qol.arkemultiplier`（同样是 `.uasset+.uexp` 形态）都已在 P3R 上跑通过。两种解释：

1. UnrealEssentials 2.0 + UE 4.27 对 DataTable 类资产容忍传统 `.uasset+.uexp` 替换 Zen 资产；
2. 上游 README 的严格警告主要针对**不在 4.25–4.27 里的**资产 / 不在 4.27 里**带依赖元数据**的资产，对 DataTable 这种 self-contained 行表类有例外。

**结论（我们当前的策略）**：

- ✅ **优先维持现状**：`P3RDataTools.create` → 传统 `.uasset+.uexp` 散文件挂载（已工作）。
- 🟡 **新表如果遇到注入不生效**（[Mod 不生效自查清单](../CLAUDE.md#mod-不生效)走完仍失败），按上游建议**改走 Zen 单文件**：用 `utoc-extractor`（见下文 §4）从 IoStore 里把目标资产以 Zen 格式拆出来，**直接覆盖**部署（无 `.uexp`）。
- 🟡 同时考虑生成 **`.uassetmeta`** / **`.utocmeta`** 元数据（见下文 §5），UE 4.27 是 *optional but recommended*，能避免运行时根据残缺依赖信息错误重建 imports/exports。

---

## 4. `utoc-extractor` 工具（随 UnrealEssentials 一起发布）

上游 README 有专门一节 [Using the UTOC Extractor](https://github.com/AnimatedSwine37/UnrealEssentials#using-the-utoc-extractor) 讲它，**这是项目里目前没用上的能力**，但对未来"Zen 资产覆盖"路线非常关键。

### 4.1 主要功能

- 把 `.utoc` 里的资产拆成 **Zen 散文件** + 元数据，目录布局直接匹配 UnrealEssentials 期望的形态（`<root>/Content/...`）。
- 在已有元数据格式之间转换（无元数据 ↔ 每资产 `.uassetmeta` ↔ 整目录 `.utocmeta`），便于公开发布前压缩 mod 加载时间。
- CLI + GUI 双模式（双击运行 = GUI，命令行带参数 = CLI）。
- 首次运行会自动下载 `oo2core_9_win64.dll` 解压 Oodle 块。

### 4.2 CLI 参考

```
utoc-extractor.exe <COMMAND>

Commands:
  unpack     从 IO Store 容器拆 Zen 资产
  convert    切换元数据存储形式
```

#### unpack

```
utoc-extractor.exe unpack [OPTIONS] <INPUT>

Arguments:
  <INPUT>  目标 .utoc 路径

Options:
  --aes-key <AES_KEY>
  -i, --include <PATHS>           只拆指定路径（可多次）；缺省 = 全部
  -m, --metadata <none|table|per-asset>
                                  none      = 不写元数据
                                  table     = 每个 UnrealEssentials 目录一个 .utocmeta
                                  per-asset = 每个 .uasset 旁边一个 .uassetmeta
  --override-version <UE4_25..UE5_7>
  --root-name <ROOT>              缺省 "Game"；P3R 应该用 "P3R"
                                  （仅当 UTOC 的 mount point 是 "../../../" 时生效）
  -o, --output <DIR>              缺省 = 与 .utoc 同级新目录
```

#### convert

```
utoc-extractor.exe convert --metadata <TYPE> --version <UE_VERSION> <INPUT>
  <INPUT>  指向 mod 的 UnrealEssentials 文件夹
```

### 4.3 P3R 典型用法（计划路线）

```powershell
# 拆 P3R 主 IoStore 容器里的某个 DataTable，生成带 .utocmeta 的 Zen 资产
& "<UnrealEssentials 安装目录>\utoc-extractor.exe" unpack `
    "<P3R>\Content\Paks\pakchunk0-WindowsNoEditor.utoc" `
    --include "P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset" `
    --override-version UE4_27 `
    --root-name "P3R" `
    --metadata table `
    -o ".\my-mod\UnrealEssentials"
```

> 注意：**P3RDataTools 还没有"应用 JSON 修改并写回 Zen 字节"的能力**——如果走这条路，需要新增写回器或先用 `utoc-extractor` 拿原始 Zen 字节，再用同等能力的工具序列化修改。这是未来 Sprint 的 backlog 项。

---

## 5. 资产元数据：`.uassetmeta` / `.utocmeta`

> *"For UE 4.25 - 4.27, asset metadata is optional to maintain backwards compatibility with 1.x. However, we recommend that mod authors use the UTOC extractor to generate asset metadata to avoid the issues detailed above."*

- **作用**：补齐 Zen 资产**自身丢失的 imports/exports 依赖信息**。UnrealEssentials 1.x 会自己推导，但**不完美**，偶尔触发崩溃 / 加载错误。
- **两种存储形式**：
  - `*.uassetmeta`：与 `*.uasset` 一一对应，放同目录。
  - `.utocmeta`：整个 mod 一份，放 `<Mod>/UnrealEssentials/` 根。后者加载时性能更好，**发布前推荐转成 `.utocmeta`**。
- **P3R 是 UE 4.27 → 元数据 optional**；UE 5.0–5.2 则**强制**，没元数据直接报 *"Asset metadata is required for UE5 versions before 5.3!"*。

---

## 6. 依赖关系（实际在本仓库里看到的依赖链）

```
                                       ┌─ Reloaded.Memory.SigScan.ReloadedII
p3rpc.essentials ─► UnrealEssentials ──┼─ reloaded.sharedlib.hooks
                                       └─ UTOC.Stream.Emulator ──► reloaded.universal.fileemulationframework
```

来源：
- [`tools/Reloaded II/Mods/UnrealEssentials/ModConfig.json`](../tools/Reloaded%20II/Mods/UnrealEssentials/ModConfig.json#L80-L86)
- [`tools/Reloaded II/Mods/p3rpc.essentials/ModConfig.json`](../tools/Reloaded%20II/Mods/p3rpc.essentials/ModConfig.json#L79-L84)

**给我们写的 mod 一句话**：

| `ModDependencies` 写什么 | 适用场景 |
|---|---|
| `["p3rpc.essentials"]` | ★ **项目级默认**（2026-06-24 起，见 [`docs/MODDING_PITFALLS.md` P-008](MODDING_PITFALLS.md#p-008-modconfigjson-默认依赖统一为-p3rpcessentials)）；间接拉齐 UnrealEssentials；如 [`p3rpc.ui.barionskillnames`](../tools/Reloaded%20II/Mods/p3rpc.ui.barionskillnames/) |
| `["UnrealEssentials"]` | 极小化、不引入 P3R 体验补丁面板；如 [`p3r.qol.arkemultiplier`](../tools/Reloaded%20II/Mods/p3r.qol.arkemultiplier/) |
| `["reloaded.universal.fileemulationframework.pak"]` | ❌ 仅当**完全绕过 UnrealEssentials**走 FEmulator/PAK 路径时；P3R 实际没必要 |

---

## 7. 上游列出的"计划中但未实现"特性

> 来源：上游 README "Planned Features" 节

- ✅ 旧版本 UE4 支持（< 4.25）
- ❌ **Cooked `.uasset+.uexp` → Zen `.uasset` 自动转换**——这是项目最需要的功能；它落地之前，我们的传统 `.uasset+.uexp` 散文件挂载属于"在 4.27 + DataTable 资产上经验证可工作但严格按 README 不被官方背书"的状态。

---

## 8. 已知限制（上游 README + 实操总结）

1. **没有 AES key 持久化机制**——`--aes-key` 命令行传入，每次手动给。P3R 的 AES key 见 [`tools/scripts/Config.ps1`](../tools/scripts/Config.ps1) 里 `$AesKey`。
2. **散文件替换 P3R `.uasset` 必须来自 UTOC**（即 Zen 单文件格式）——见 §3。
3. **MDR/Sifu/Callisto Protocol 等需要先卸 DRM**；P3R 不在此列。
4. **DLL hook 受 EXE 改动影响**——P3R 升级新版本时若 EXE 重新签名，需要等 UnrealEssentials 更新对应签名码（一般通过 Inaba EXE Patcher 解锁后无影响）。
5. **同名资产冲突解决策略未文档化**——多个 mod 同时替换同一 `.uasset` 时，UnrealEssentials 按字典序还是按 Reloaded II load order 选取，README 未说明；项目里目前避免同名冲突。

---

## 9. 项目内引用关系

```
CLAUDE.md
 └─ "资产格式" / "Mod 安装" / "ModConfig.json 模板"  ─► 本文档（能力清单）
                                                    ─► docs/MODDING_PITFALLS.md  P-005 / P-007（具体踩坑）

docs/MODDING_PITFALLS.md
 └─ P-005（已立）                                   ─► 本文档 §6（依赖关系）
 └─ P-007（新增）                                   ─► 本文档 §3（Zen vs 传统）

docs/DEVELOPER_GUIDE.md
 └─ "Mod 安装指南"                                  ─► 本文档（散文件路径示例）

tools/scripts/modify-and-repack.ps1
 └─ -PackPak 选项的注释                              ─► 本文档 §2.1（整包路径在 UnrealEssentials 下也可行）
```

---

## 10. 维护约定

- 每次 UnrealEssentials 升级（看 [`tools/Reloaded II/Mods/UnrealEssentials/ModConfig.json`](../tools/Reloaded%20II/Mods/UnrealEssentials/ModConfig.json) 的 `ModVersion`），把变更对照 [Releases](https://github.com/AnimatedSwine37/UnrealEssentials/releases) 抄到本文档顶部。
- 任何"上游 README 与我们的实操不一致"的发现 → 在 [`docs/MODDING_PITFALLS.md`](MODDING_PITFALLS.md) 立 `P-NNN`，然后在本文档相应小节加一行"项目内例外"。
- 永远以 `tools/Reloaded II/Mods/` 下**真实安装**的 ModConfig + ModVersion 为基准，不要拿 GameBanana / 第三方 wiki 描述当权威。
