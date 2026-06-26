# UnrealEssentials 与 p3rpc.essentials 能力速查

> **来源**：
> - UnrealEssentials：[github.com/AnimatedSwine37/UnrealEssentials](https://github.com/AnimatedSwine37/UnrealEssentials) `README.md`（2026-06-24 抓取）
> - p3rpc.essentials：[github.com/AnimatedSwine37/p3rpc.essentials](https://github.com/AnimatedSwine37/p3rpc.essentials)（GPL-3.0，C#；上游 README 基本为空，本文档基于源码与 release notes 整理）
>
> **本仓库实际安装版本**：
> - [`tools/Reloaded II/Mods/UnrealEssentials/ModConfig.json`](../tools/Reloaded%20II/Mods/UnrealEssentials/ModConfig.json) `ModVersion: 2.0.0`
> - [`tools/Reloaded II/Mods/p3rpc.essentials/ModConfig.json`](../tools/Reloaded%20II/Mods/p3rpc.essentials/ModConfig.json) `ModVersion: 1.3.0`（上游最新 release，2025-12-10；@rirurin 贡献额外特性）
>
> **作者**：AnimatedSwine37（两个模组同一作者）。
>
> 本文档是 P3R 项目使用这两个模组时的**权威能力清单**。当 [`CLAUDE.md`](../CLAUDE.md) / [`docs/MODDING_PITFALLS.md`](MODDING_PITFALLS.md) 与上游 README 冲突时，以本文档为准，同时把不一致处修回去。

---

## 1. 两者定位与关系

| 模组 | 一句话定位 | 作用对象 |
|---|---|---|
| **UnrealEssentials** | Reloaded II 下的**通用 UE 文件替换中间层**（UE 4.25–4.27 / 5.0–5.7） | 替换 UTOC/PAK 容器内文件、去掉 UTOC/PAK 签名校验、记录被访问文件以便排错 |
| **p3rpc.essentials** | P3R 专用的**运行时原生钩子模组**（sigscan + vtable patching） | 可选体验补丁（去焦点失活/跳开场/快速菜单）；**不替换任何 `.uasset`** |

P3R 是上游官方列名的支持游戏（UE 4.27）；上游额外推荐装 p3rpc.essentials。关系是**依赖**而非封装：`p3rpc.essentials` 依赖 `UnrealEssentials`，间接把整条文件替换链拉齐，并额外附加 2 个运行时 hook（默认关闭，用户主动启用）。

- ❌ p3rpc.essentials **不是**文件加载器、不是 SDK/API（无 `IsLibrary`、无 `HasExports`、无 interface DLL）、不是 UnrealEssentials 的封装。
- ❌ 数值/资产 mod 直接依赖 `UnrealEssentials` 就够了；依赖 `p3rpc.essentials` 反而引入体验补丁选项面板。

---

## 2. UnrealEssentials：支持的输入形态

同时接受两种粒度，放在 `<Mod>/UnrealEssentials/` 下（可建子目录，UnrealEssentials 自排优先级）：

### 2.1 整包（Full Packages）

把整个 `.utoc + .ucas` 对（IoStore）或整个 `.pak` 放进 `<Mod>/UnrealEssentials/` 任意位置即可。**不需要 `_P` 后缀**（上游原文：*"priority will automatically be sorted by Unreal Essentials"*）；带了也不会出错。

> 对 P3R 的意义：以前单独配进 `<Mod>/FEmulator/PAK/` 的 `.pak`，丢进 `<Mod>/UnrealEssentials/` 也成立。但项目两个已验证参考 mod（[`p3rpc.ui.barionskillnames`](../tools/Reloaded%20II/Mods/p3rpc.ui.barionskillnames/) / [`p3r.qol.arkemultiplier`](../tools/Reloaded%20II/Mods/p3r.qol.arkemultiplier/)）都走散文件，故仍以散文件为默认。

### 2.2 散文件（Loose Assets）

把单个资产按**原游戏虚拟路径**镜像到 `<Mod>/UnrealEssentials/` 下。P3R 示例（上游 README 原话）：

```
<Mod>/UnrealEssentials/P3R/Content/Xrd777/Font/<原资产名>.uasset
```

虚拟路径即 FModel 浏览资产树看到的路径，或 P3RDataTools `read` 使用的 `P3R/Content/...` 路径。**这是项目当前默认形态。**

---

## 3. ⚠️ Zen 资产 vs 传统 `.uasset+.uexp`（P3R 必读）

上游 [Adding Loose Assets](https://github.com/AnimatedSwine37/UnrealEssentials#adding-loose-assets) 原文：

> *"Note that if your game uses UTOC files, any `.uasset` files you replace will have to come from a UTOC as the file format is different when they are in PAK files. This means that you will need to export them from Unreal Engine into an IO Store container (`.utoc` + `.ucas`) and then extract them if you want to use them loosely."*

要点：

- P3R 使用 UTOC（IoStore 是主容器），故**散文件替换的 `.uasset` 必须来自 UTOC** —— 即 **Zen 资产**，从 `.ucas` 直接拆出的单文件 cooked 字节，**无伴随 `.uexp`**（exports/bulk data 全内嵌）。
- 上游现状：**Cooked `.uasset+.uexp` → Zen `.uasset` 自动转换是计划中 feature**（README "Planned Features" 列着），1.x / 2.0 均未实现。
- `P3RDataTools.create` 产物属**传统 `.uasset+.uexp`**（首字节 `C1 83 2A 9E`），**已被 P3R 实测证伪**：2026-06-24 后复测确认在 P3R DataTable 覆盖中 boot-crash，详见 [MODDING_PITFALLS.md P-007](MODDING_PITFALLS.md#p-007-unrealessentials-iostore-资产替换偏好-zen-单文件)。早期 Sprint 1 "已工作"判断已被人工验证推翻。

**当前策略**：

- ✅ **默认主路径**：`Extracted/IoStore` Zen 原件 → `Invoke-ZenPatch.ps1` / `modify-and-repack.ps1` byte-patch → `<Mod>/UnrealEssentials/P3R/Content/.../<Asset>.uasset`。
- ✅ 产物保持 Zen 形态：首字节 `00 00 00 00`、**无 `.uexp`**、输出大小与原件一致。
- ⊘ `P3RDataTools.create` / TemplateCreator 传统 `.uasset+.uexp` 仅留作历史/fallback/未来完整序列化研究，不用于新 DataTable Mod。
- 🟡 尚未提取到 `Extracted/IoStore` 的资产，可按上游建议用 `utoc-extractor`（§4）拆 Zen 单文件；项目当前已优先使用现有 `Extracted/IoStore` 原件。

---

## 4. `utoc-extractor` 工具（随 UnrealEssentials 发布）

上游 [Using the UTOC Extractor](https://github.com/AnimatedSwine37/UnrealEssentials#using-the-utoc-extractor)。**项目目前没用上**，但对未来"Zen 资产覆盖"路线关键。

- 把 `.utoc` 拆成 **Zen 散文件** + 元数据，目录布局直接匹配 UnrealEssentials 期望形态（`<root>/Content/...`）。
- 转换元数据存储形式（无 ↔ 每资产 `.uassetmeta` ↔ 整目录 `.utocmeta`）。
- CLI + GUI 双模式；首次运行自动下载 `oo2core_9_win64.dll` 解压 Oodle。

```
utoc-extractor.exe <COMMAND>
  Commands: unpack（拆 Zen 资产）/ convert（切元数据形式）

utoc-extractor.exe unpack [OPTIONS] <INPUT>
  <INPUT>                        目标 .utoc 路径
  --aes-key <AES_KEY>
  -i, --include <PATHS>          只拆指定路径（可多次）；缺省 = 全部
  -m, --metadata <none|table|per-asset>
                                  none / table（每 UE 目录一个 .utocmeta）/ per-asset（每 .uasset 旁一个 .uassetmeta）
  --override-version <UE4_25..UE5_7>
  --root-name <ROOT>              缺省 "Game"；P3R 应 "P3R"（仅 mount point 是 "../../../" 时生效）
  -o, --output <DIR>              缺省 = 与 .utoc 同级新目录

utoc-extractor.exe convert --metadata <TYPE> --version <UE_VERSION> <INPUT>
  <INPUT>  指向 mod 的 UnrealEssentials 文件夹
```

P3R 典型用法（计划路线）：

```powershell
& "<UnrealEssentials 安装目录>\utoc-extractor.exe" unpack `
    "<P3R>\Content\Paks\pakchunk0-WindowsNoEditor.utoc" `
    --include "P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset" `
    --override-version UE4_27 --root-name "P3R" --metadata table `
    -o ".\my-mod\UnrealEssentials"
```

> 注意：**P3RDataTools 还没有"应用 JSON 修改并写回 Zen 字节"的能力**——走这条路需新增写回器，或先用 `utoc-extractor` 拿原始 Zen 字节再用同等能力工具序列化。属未来 Sprint backlog。

---

## 5. 资产元数据：`.uassetmeta` / `.utocmeta`

> *"For UE 4.25 - 4.27, asset metadata is optional ... we recommend that mod authors use the UTOC extractor to generate asset metadata to avoid the issues detailed above."*

- **作用**：补齐 Zen 资产自身丢失的 imports/exports 依赖信息。UnrealEssentials 1.x 会自己推导，但不完美，偶尔触发崩溃/加载错误。
- **两种形式**：`*.uassetmeta`（与 `.uasset` 一一对应、同目录）；`.utocmeta`（整个 mod 一份、放 `<Mod>/UnrealEssentials/` 根，加载性能更好，**发布前推荐转成 `.utocmeta`**）。
- **P3R 是 UE 4.27 → 元数据 optional**；UE 5.0–5.2 强制（没元数据报 *"Asset metadata is required for UE5 versions before 5.3!"*）。

---

## 6. p3rpc.essentials：用户可见配置选项

源自 [`p3rpc.essentials/Config.cs`](https://github.com/AnimatedSwine37/p3rpc.essentials/blob/master/p3rpc.essentials/Config.cs)，可在 Reloaded II UI Configure 面板调整。**5 项默认全 `false`/`None`，用户主动启用才生效。**

| 配置项 | 类别 | 默认 | 行为 |
|---|---|---|---|
| `RenderInBackground` | 顶层 | `false` | 窗口失焦时继续渲染（不暂停） |
| `IntroSkip` | Intro Skip | `None` | 跳到指定开场段：`None`/`OpeningMovie`/`MainMenu`/`LoadMenu` |
| `NetworkSkip` | Intro Skip | `false` | 跳过"是否启用网络功能"提示（**会同时关闭网络功能**） |
| `IntroSkipAstrea` | Intro Skip | `false` | Episode Aigis（Astrea）也跳到主菜单（1.3.0 新增） |
| `FastMenuNavigation` | Intro Skip | `false` | 标题菜单立即接受输入（1.3.0 新增；参考 Metaphor 标题屏） |

> `IntroSkip.LoadMenu` 让游戏跳到 `TS_LoadGame`（最近存档读取菜单），等同"快速继续游戏"。

### 6.1 实现层（仅供调试参考）

- **NoPauseOnFocusLoss**（[`Patches/NoPauseOnFocusLoss.cs`](https://github.com/AnimatedSwine37/p3rpc.essentials/blob/master/p3rpc.essentials/Patches/NoPauseOnFocusLoss.cs)）：sigscan `4C 8B DC 53 55 56 41 54 41 55 41 56`（标签 "SetupWindow"），取 `hWnd` 后 hook `WndProc`；`RenderInBackground=true` 时吞掉 `WM_KILLFOCUS`，短路 `WM_ACTIVATE`/`WM_ACTIVATEAPP` 的失焦情况，游戏认为永远在前台。
- **IntroSkip**（[`Patches/IntroSkip.cs`](https://github.com/AnimatedSwine37/p3rpc.essentials/blob/master/p3rpc.essentials/Patches/IntroSkip.cs)）：sigscan `48 89 5C 24 ?? 48 89 74 24 ?? 57 48 83 EC 30 80 B9 ?? ?? ?? ?? 00 48 8B D9`（标签 "Caution Skip"），hook `UTitleStateBase::UpdateState` 中处理 `TS_Caution` 的虚函数；进入 `Caution` 时枚举 `ATitleActor::StateAlloc`，按需 hook 后续状态 `UpdateState`（`TS_Logo`/`TS_PressWait`/`TS_OP`/`TS_Select`/`TS_OP_Astrea`/`TS_Select_Astrea`）。
- **FastMenuNavigation**：进 `PressWait` 时把 `DT_TitleUI->PleaseWaitFadeInWaitTime` 改成 `1.75f`；进 `Select` 时把所有 `ATitleActorInputEntry.ValCur` 拉到 `ValEnd` 并 `InputControl0/1=true`，让淡入立即完成。

标题状态机枚举（排查崩溃参考）：

```
TS_Caution=0  TS_PhotosensitiveCaution=1  TS_NetworkCheck=2
TS_Logo=3     TS_OP=4                     TS_PressWait=5
TS_Select=6   TS_NewGame=7                TS_LoadGame=8
TS_Config=9   TS_Exit=10                  TS_ComeBackLoad=11
TS_WaitGamerTag=12  TS_ResidentReload=13  TS_OP_Astrea=14
TS_PressWait_Astrea=15  TS_Select_Astrea=16
```

> 这些 hook 针对 P3R 当前版本反编译出的 sig + offset；P3R 大版本更新若重新编译 EXE 可能失效，需等上游更新 sig。

### 6.2 p3rpc.essentials 1.3.0 变更要点（2025-12-10）

来自 [Release notes](https://github.com/AnimatedSwine37/p3rpc.essentials/releases/tag/1.3.0)（@rirurin 贡献）：

- ➕ `IntroSkipAstrea`（跳过 Episode Aigis 开场 OP）
- 🐛 修复 *"从 Ep Aigis 回到本篇时无论 IntroSkip 是否 OpeningMovie 都会播放开场"*
- ➕ `FastMenuNavigation`（标题菜单允许立即输入）

`p3rpc.essentials1.3.0.7z`（约 1 MB）截至抓取日下载量约 44k 次。

---

## 7. 依赖链

`p3rpc.essentials/ModConfig.json` 显式声明 `ModDependencies: ["Reloaded.Memory.SigScan.ReloadedII", "reloaded.sharedlib.hooks", "UnrealEssentials"]`；`UnrealEssentials` 又依赖 `UTOC.Stream.Emulator` → `reloaded.universal.fileemulationframework`：

```
                                       ┌─ Reloaded.Memory.SigScan.ReloadedII
p3rpc.essentials ─► UnrealEssentials ──┼─ reloaded.sharedlib.hooks
                                       └─ UTOC.Stream.Emulator ──► reloaded.universal.fileemulationframework
```

来源：[`UnrealEssentials/ModConfig.json`](../tools/Reloaded%20II/Mods/UnrealEssentials/ModConfig.json) 与 [`p3rpc.essentials/ModConfig.json`](../tools/Reloaded%20II/Mods/p3rpc.essentials/ModConfig.json)。

---

## 8. 我们的 mod 应该依赖谁？

| 你的 mod 是 … | 推荐 `ModDependencies` | 原因 / 参考 |
|---|---|---|
| **★ 项目级默认（2026-06-24 起）：任何 P3R mod** | `["p3rpc.essentials"]` | 项目统一约定（[P-008](MODDING_PITFALLS.md#p-008-modconfigjson-默认依赖统一为-p3rpcessentials)）；间接拉齐整条 UE 链；如 [`p3rpc.ui.barionskillnames`](../tools/Reloaded%20II/Mods/p3rpc.ui.barionskillnames/) |
| 极小化资产 mod（不想给用户看到体验补丁面板） | `["UnrealEssentials"]` | 只拉资产替换链；如 [`p3r.qol.arkemultiplier`](../tools/Reloaded%20II/Mods/p3r.qol.arkemultiplier/) |
| 完全绕过 UnrealEssentials 走 FEmulator/PAK 老路 | `["reloaded.universal.fileemulationframework.pak"]` | ❌ 历史 fallback，P3R 实际没必要（[P-005](MODDING_PITFALLS.md#p-005-mod-默认走-unrealessentials-散文件挂载不是-femulatorpak)） |

两种写法都能让 mod 跑起来——区别只在加载链多带不带 P3R 体验补丁层。新 mod 默认采纳 [`p3r.qol.arkemultiplier`](../tools/Reloaded%20II/Mods/p3r.qol.arkemultiplier/) 的最小化写法。

> `tools/scripts/modify-and-repack.ps1` 从 2026-06-24 起生成的 `ModConfig.json` 默认 `["p3rpc.essentials"]`（脚本 `-ModDependencies` 可覆盖）。

---

## 9. 已知限制（上游 README + 实操总结）

1. **没有 AES key 持久化**——`--aes-key` 命令行传入，每次手动给。P3R AES key 见 [`tools/scripts/Config.ps1`](../tools/scripts/Config.ps1) `$AesKey`。
2. **散文件替换 P3R `.uasset` 必须来自 UTOC**（Zen 单文件格式）——见 §3。
3. **MDR/Sifu/Callisto Protocol 等需先卸 DRM**；P3R 不在此列。
4. **DLL hook 受 EXE 改动影响**——P3R 升级若 EXE 重新签名，需等 UnrealEssentials 更新签名码（一般通过 Inaba EXE Patcher 解锁后无影响）；p3rpc.essentials 的 sigscan 同理，失效时 Reloaded II 日志会出现 "Couldn't find pattern ..."。
5. **同名资产冲突解决策略未文档化**——多 mod 同时替换同一 `.uasset` 时按字典序还是 Reloaded II load order 选取，README 未说明；项目目前避免同名冲突。

### 上游"计划中但未实现"特性

- ✅ 旧版本 UE4 支持（< 4.25）
- ❌ **Cooked `.uasset+.uexp` → Zen `.uasset` 自动转换**——项目最需要的功能；落地前，传统 `.uasset+.uexp` 散文件挂载属"在 4.27 + DataTable 上经验证可工作但严格按 README 不被官方背书"的状态。

---

## 10. 与本项目工具链的交点

| 项目 | 关系 |
|---|---|
| `P3RDataTools.create` / `.uasset+.uexp` 写回 | 无依赖关系；不参与文件替换链，且已被 P-007 证伪 |
| `tools/scripts/modify-and-repack.ps1` | 默认依赖 `["p3rpc.essentials"]`（见 §8）；`-PackPak` 走 §2.1 整包路径（fallback） |
| AI Agent / 中文用户对话 | 用户问"跳开场"/"alt-tab 不暂停"/"标题菜单慢"等**运行时行为**→ 指引配置 `p3rpc.essentials`，而非生成数值 mod |

项目内引用关系：

```
CLAUDE.md / README.md ─► 本文档（能力清单）
docs/MODDING_PITFALLS.md
  ├─ P-005（散文件挂载 vs FEmulator/PAK）  ─► 本文档 §8
  ├─ P-007（Zen vs 传统 .uasset+.uexp）     ─► 本文档 §3
  └─ P-008（默认依赖 p3rpc.essentials）      ─► 本文档 §8
```

---

## 11. 维护约定

- 每次模组升级（看 [`tools/Reloaded II/Mods/`](../tools/Reloaded%20II/Mods/) 下对应 `ModConfig.json` 的 `ModVersion`），把变更对照各自 [UnrealEssentials Releases](https://github.com/AnimatedSwine37/UnrealEssentials/releases) / [p3rpc.essentials Releases](https://github.com/AnimatedSwine37/p3rpc.essentials/releases) 抄到本文档顶部；p3rpc.essentials 跨次大版本（如 1.x → 2.x）时更新 §6.2。
- 任何"上游 README 与实操不一致"→ 在 [`docs/MODDING_PITFALLS.md`](MODDING_PITFALLS.md) 立 `P-NNN`，再在本文档相应小节加一行"项目内例外"。
- 永远以 `tools/Reloaded II/Mods/` 下**真实安装**的 ModConfig + ModVersion 为基准，不要拿 GameBanana / 第三方 wiki 当权威。
