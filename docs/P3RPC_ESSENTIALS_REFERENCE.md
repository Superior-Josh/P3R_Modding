# Persona 3 Reload Essentials (p3rpc.essentials) 能力速查

> **来源**：
> - GameBanana 页面：[gamebanana.com/mods/494020](https://gamebanana.com/mods/494020)（页面在沙箱内不可直接抓取）
> - GitHub 源码：[github.com/AnimatedSwine37/p3rpc.essentials](https://github.com/AnimatedSwine37/p3rpc.essentials)（GPL-3.0，C#）
> - 上游 README **基本为空**（截至 2026-06-24，只有标题），本文档基于源码与 release notes 整理
> - 上游最新 release：**1.3.0**（2025-12-10）
>
> **本仓库实际安装版本**：[`tools/Reloaded II/Mods/p3rpc.essentials/ModConfig.json`](../tools/Reloaded%20II/Mods/p3rpc.essentials/ModConfig.json) `ModVersion: 1.3.0` —— 与上游同步。
>
> **作者**：AnimatedSwine37（同 UnrealEssentials 作者），1.3.0 由 @rirurin 贡献额外特性。
>
> 本文档目标：让 AI Agent 和 mod 作者**清楚地知道 `p3rpc.essentials` 提供什么、什么时候依赖它、什么时候应该用 `UnrealEssentials` 替代**。

---

## 1. 它是什么

> 仓库 description（GitHub API 抓取）：*"A Reloaded mod that adds base support for P3R modding."*
>
> 本仓库 `ModConfig.json`：*"Provides base modding support for P3R and miscellaneous fixes."*

**一句话定位**：`p3rpc.essentials` 是 P3R 专用的 **运行时原生钩子（native runtime hooks）模组**，不替换任何 `.uasset` —— 它通过 sigscan + vtable patching 修改 P3R EXE 的运行时行为，主要提供：

1. **可选的体验补丁**（去焦点失活/跳过开场/快速菜单导航）
2. **作为其他 P3R mod 的"meta-dependency"**——拉它会把 `UnrealEssentials + UTOC.Stream.Emulator + FileEmulationFramework + SigScan + SharedLibHooks` 整条链都拉齐

它**不是**：

- ❌ 不是文件加载器（不会替换 `.uasset` / `.pak`）
- ❌ 不是 SDK / API（没有暴露给其他 mod 调用的 export 接口）
- ❌ 不是 `UnrealEssentials` 的封装——而是 **依赖 `UnrealEssentials`**（见 [§4 依赖链](#4-依赖链)）

---

## 2. 用户可见特性（运行时配置选项）

源自 [`p3rpc.essentials/Config.cs`](https://github.com/AnimatedSwine37/p3rpc.essentials/blob/master/p3rpc.essentials/Config.cs)。所有选项可在 Reloaded II UI 里 Configure 面板调整：

| 配置项 | 类别 | 默认值 | 行为 |
|---|---|---|---|
| `RenderInBackground` | 顶层 | `false` | 窗口失焦时游戏继续运行渲染（不暂停） |
| `IntroSkip` | Intro Skip | `None` | 跳到指定开场段：`None`/`OpeningMovie`/`MainMenu`/`LoadMenu` |
| `NetworkSkip` | Intro Skip | `false` | 跳过"是否启用网络功能"提示（**会同时关闭网络功能**） |
| `IntroSkipAstrea` | Intro Skip | `false` | Episode Aigis（Astrea）也跳到主菜单 |
| `FastMenuNavigation` | Intro Skip | `false` | 标题菜单立即接受输入（参考 Metaphor 标题屏行为） |

> 关于 `IntroSkip.LoadMenu`：源码里它会让游戏跳到 `TS_LoadGame`（最近存档读取菜单），等同于"快速继续游戏"。

### 2.1 实现层（仅供调试参考）

- **NoPauseOnFocusLoss**（[`Patches/NoPauseOnFocusLoss.cs`](https://github.com/AnimatedSwine37/p3rpc.essentials/blob/master/p3rpc.essentials/Patches/NoPauseOnFocusLoss.cs)）
  - sigscan：`4C 8B DC 53 55 56 41 54 41 55 41 56`（标签 "SetupWindow"）
  - 在 `SetupWindow` 取到 `hWnd` 后，hook 它的 `WndProc`；当 `RenderInBackground=true` 时吞掉 `WM_KILLFOCUS`，并把 `WM_ACTIVATE` / `WM_ACTIVATEAPP` 的 `wParam=0`（失焦）情况短路返回，游戏认为永远在前台。

- **IntroSkip**（[`Patches/IntroSkip.cs`](https://github.com/AnimatedSwine37/p3rpc.essentials/blob/master/p3rpc.essentials/Patches/IntroSkip.cs)）
  - sigscan：`48 89 5C 24 ?? 48 89 74 24 ?? 57 48 83 EC 30 80 B9 ?? ?? ?? ?? 00 48 8B D9`（标签 "Caution Skip"），命中即 hook `UTitleStateBase::UpdateState` 中处理 `TS_Caution` 的虚函数
  - 进入 `Caution` 时枚举 `ATitleActor::StateAlloc`（一张状态表），按需 hook 后续状态的 `UpdateState`：`TS_Logo`/`TS_PressWait`/`TS_OP`/`TS_Select`/`TS_OP_Astrea`/`TS_Select_Astrea`
  - 状态机枚举（用 mod 时排查崩溃可参考）：

    ```
    TS_Caution = 0       TS_PhotosensitiveCaution = 1   TS_NetworkCheck = 2
    TS_Logo = 3          TS_OP = 4                      TS_PressWait = 5
    TS_Select = 6        TS_NewGame = 7                 TS_LoadGame = 8
    TS_Config = 9        TS_Exit = 10                   TS_ComeBackLoad = 11
    TS_WaitGamerTag = 12 TS_ResidentReload = 13         TS_OP_Astrea = 14
    TS_PressWait_Astrea = 15  TS_Select_Astrea = 16
    ```

  - `FastMenuNavigation` 实现：进 `PressWait` 时把 `DT_TitleUI->PleaseWaitFadeInWaitTime` 改成 `1.75f`，进 `Select` 时把所有 `ATitleActorInputEntry.ValCur` 拉到 `ValEnd` 并把 `InputControl0/1=true`，让淡入立即完成。

  - 这两段 hook 都是 **针对 P3R 当前版本反编译出的 sig + offset**，P3R 大版本更新如果重新编译 EXE 可能失效——届时需要等 `p3rpc.essentials` 上游更新 sig。

---

## 3. 它**不**做的事（项目里需要警惕的误解）

| 误解 | 实情 |
|---|---|
| ❌ "p3rpc.essentials 封装了 UnrealEssentials" | ✅ 它**依赖** UnrealEssentials（间接拉进来），没有重打包它 |
| ❌ "依赖 p3rpc.essentials 等同依赖 UnrealEssentials" | ✅ 依赖图是包含关系（拉 p3rpc.essentials 会带上 UE），但 p3rpc.essentials 多附加 2 个运行时 hook，**默认是关的**，用户必须主动在 UI 里勾选 |
| ❌ "它是 P3R 的 SDK / 提供给其他 mod 的 API" | ✅ 它没有 `IsLibrary: true`、没有 `HasExports`、没有 interface DLL；纯 end-user mod |
| ❌ "我们的 AgiMod 之类数值 mod 必须依赖它" | ✅ 数值 mod 直接依赖 `UnrealEssentials` 就够了，依赖 `p3rpc.essentials` 反而引入了用户不想要的体验补丁选项面板 |
| ❌ "依赖它就会自动跳过开场" | ✅ 5 个选项默认全是 `false`/`None`，用户主动启用才生效 |

---

## 4. 依赖链

`p3rpc.essentials/ModConfig.json` 显式声明：

```json
"ModDependencies": [
  "Reloaded.Memory.SigScan.ReloadedII",
  "reloaded.sharedlib.hooks",
  "UnrealEssentials"
]
```

`UnrealEssentials` 又依赖 `UTOC.Stream.Emulator` → `reloaded.universal.fileemulationframework`。整条链：

```
p3rpc.essentials ──► UnrealEssentials ──► UTOC.Stream.Emulator ──► reloaded.universal.fileemulationframework
                ──► Reloaded.Memory.SigScan.ReloadedII
                ──► reloaded.sharedlib.hooks
```

参考：[`docs/UNREAL_ESSENTIALS_REFERENCE.md` §6](UNREAL_ESSENTIALS_REFERENCE.md#6-依赖关系实际在本仓库里看到的依赖链)。

---

## 5. 我们的 mod 应该依赖谁？

| 你的 mod 是 … | 推荐 `ModDependencies` | 原因 |
|---|---|---|
| **★ 项目级默认（2026-06-24 起）：任何 P3R mod**（数值/资产/体验补丁/运行时 hook） | `["p3rpc.essentials"]` | 项目统一约定；与参考 mod [`p3rpc.ui.barionskillnames`](../tools/Reloaded%20II/Mods/p3rpc.ui.barionskillnames/) 一致；间接拉齐整条 UnrealEssentials 链；为后续添加运行时补丁留余地 |
| 极小化资产 mod（不想给用户看到任何 P3R 体验补丁选项面板） | `["UnrealEssentials"]` | 只拉资产替换链；如 [`p3r.qol.arkemultiplier`](../tools/Reloaded%20II/Mods/p3r.qol.arkemultiplier/) |
| 你的 mod 跟某个使用 `p3rpc.essentials` 的官方/社区 mod 共享逻辑/补丁层 | `["p3rpc.essentials"]` | 让加载顺序一致 |
| 完全绕过 UnrealEssentials 走 FEmulator/PAK 老路 | `["reloaded.universal.fileemulationframework.pak"]` | 历史 fallback，详见 [P-005](MODDING_PITFALLS.md#p-005-mod-默认走-unrealessentials-散文件挂载不是-femulatorpak) |

**项目内两个已验证可运行的参考 mod 的依赖示例**：

| Mod | 依赖 | 说明 |
|---|---|---|
| [`p3r.qol.arkemultiplier`](../tools/Reloaded%20II/Mods/p3r.qol.arkemultiplier/) | `["UnrealEssentials"]` | 改难度倍率 DataTable —— 纯资产替换 → 最小依赖 |
| [`p3rpc.ui.barionskillnames`](../tools/Reloaded%20II/Mods/p3rpc.ui.barionskillnames/) | `["p3rpc.essentials"]` | 改技能名 L10N —— 作者选择跟随 essentials 生态 |

**两种写法都能让 mod 跑起来**——区别只在加载链多带不带 P3R 体验补丁层。新 mod 默认采纳 [`p3r.qol.arkemultiplier`](../tools/Reloaded%20II/Mods/p3r.qol.arkemultiplier/) 的最小化写法。

---

## 6. 安装

不需要项目自己装。Reloaded II 首次为 P3R 启动时会自动从 GitHub Releases / GameBanana 拉取 `p3rpc.essentials`、`UnrealEssentials`、`UTOC.Stream.Emulator` 等依赖。如果用户禁用了自动依赖下载，可手动从 [Releases](https://github.com/AnimatedSwine37/p3rpc.essentials/releases) 下载 `p3rpc.essentials<version>.7z` 解压到 `Mods/p3rpc.essentials/` 下。

升级时直接覆盖。配置存在 `Mods/p3rpc.essentials/Config/Config.json`（首次启用时自动生成）。

---

## 7. 1.3.0 变更要点（2025-12-10）

来自 [Release notes](https://github.com/AnimatedSwine37/p3rpc.essentials/releases/tag/1.3.0)（由 @rirurin 贡献）：

- ➕ 新增 `IntroSkipAstrea`（跳过 Episode Aigis 的开场 OP）
- 🐛 修复 *"从 Ep Aigis 回到本篇时无论 IntroSkip 是不是 OpeningMovie 都会播放开场"* 的 bug
- ➕ 新增 `FastMenuNavigation`（标题菜单允许立即输入）

`p3rpc.essentials1.3.0.7z`（约 1 MB）截至抓取日下载量约 44k 次。

---

## 8. 与本项目工具链的交点

| 项目 | 关系 |
|---|---|
| `P3RDataTools.create` / `.uasset+.uexp` 写回流程 | 无依赖关系。`p3rpc.essentials` 不参与文件替换链。 |
| `tools/scripts/modify-and-repack.ps1` | **从 2026-06-24 起，生成的 `ModConfig.json` 默认依赖 `["p3rpc.essentials"]`**（脚本顶部 `-ModDependencies` 参数可覆盖）。统一约定的依据见 [`docs/MODDING_PITFALLS.md` P-008](MODDING_PITFALLS.md#p-008-modconfigjson-默认依赖统一为-p3rpcessentials)。 |
| AI Agent prompt / 中文用户对话 | 当用户问"跳开场"/"alt-tab 不暂停"/"标题菜单很慢"这类**运行时行为问题**时，告诉用户去 Reloaded II 配置 `p3rpc.essentials`，而**不是**生成数值 mod。 |
| `docs/UNREAL_ESSENTIALS_REFERENCE.md` | 是它的依赖目标——任何"P3R 的资产替换是怎么工作的"问题都要参考那篇，不是本篇。 |

---

## 9. 维护约定

- 每次 `tools/Reloaded II/Mods/p3rpc.essentials/ModConfig.json` 的 `ModVersion` 跨次大版本变化（如 1.x → 2.x），重抓上游 release notes 并把变更要点追加到 [§7](#7-130-变更要点2025-12-10)。
- 如果 P3R EXE 大版本升级、`p3rpc.essentials` 的 sigscan 失效，可在 Reloaded II 日志面板看到 "Couldn't find pattern ..." 之类报错——记进 [`docs/MODDING_PITFALLS.md`](MODDING_PITFALLS.md) 立 P-NNN。
- 永远以 **`tools/Reloaded II/Mods/p3rpc.essentials/ModConfig.json` 实际安装版本**为基准。

---

## 10. 链接

- GameBanana：https://gamebanana.com/mods/494020
- GitHub 仓库：https://github.com/AnimatedSwine37/p3rpc.essentials
- Releases：https://github.com/AnimatedSwine37/p3rpc.essentials/releases
- License：GPL-3.0
