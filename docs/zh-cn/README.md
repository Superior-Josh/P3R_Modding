# P3R 标准中文译名（biligame WIKI）

> **目的**：当中文用户用中文名称（如「亚基」「俄耳甫斯」「魔术之手」）描述需求时，AI Agent 应能识别并映射到 DataTable 中的英文/日文键，从而修改正确的字段。
>
> **来源**：[biligame WIKI · P3R 攻略专区](https://wiki.biligame.com/persona/P3R%E9%A6%96%E9%A1%B5%E6%94%BB%E7%95%A5%E4%B8%93%E5%8C%BA)
>
> **抓取日期**：2026-06-24

## 文档列表

| 文档 | 内容 | 条目数 |
|------|------|-------:|
| [skills.md](skills.md) | 全技能中/日/英三语对照（含 Skill ID） | 368 |
| [personas.md](personas.md) | 全人格面具中/日/英 + Arcana + 初始等级 | 209 |
| [enemies.md](enemies.md) | 全敌人/Shadow 中文名 + Arcana + 等级（合并敌人数据 + 塔尔塔罗斯页面） | 284 |
| [arcana.md](arcana.md) | 22 阿尔卡纳中/日/英 + 大卡效果 | 22 |
| [characters.md](characters.md) | SEES 成员 + Social Link NPC 译名 | 30+ |
| [elements-status.md](elements-status.md) | 属性（火/冰/雷/风等）与异常状态译名 | 20+ |
| [locations-systems.md](locations-systems.md) | 地点（塔尔塔罗斯/桐叶购物中心等）与系统术语（神谕/Shift/合体等） | 30+ |

## 使用约定

### 对 AI Agent 的硬性要求

中文用户提出 Mod 需求时：

1. **识别中文译名 → 找到对应 ID/英文键**
   - 用户说「把亚基伤害改成 999」→ 查 [skills.md](skills.md) → `Agi` → `ID = 10` → 修改 `DatSkillNormalDataAsset.Properties.Data[10].hpn`
   - 用户说「让俄耳甫斯初始等级 50」→ 查 [personas.md](personas.md) → `Orpheus` → 修改 `DatPersonaDataAsset`

2. **回复用户时优先使用标准中文译名 + 校准 hpn 语义**
   - ✅ 正确：「已将**亚基**（火焰，3 MP）`hpn` 提升到 999（约为原版 5x 显示伤害，详见 [MODDING_PITFALLS.md P-009](../MODDING_PITFALLS.md#p-009-skill-表的-hpn-字段是显示伤害的平方要改-n-倍伤害得乘-n²)）」
   - ⚠️ **当用户说"把亚基伤害改成 N 倍"时**，要写回 `hpn = 40 × N²`，不是 `hpn = 40 × N`——Skill 表的 `hpn` 是显示伤害的**平方**
   - ❌ 错误：「已将 Agi 的伤害提升到 999」（除非用户明显使用英文/日文）
   - ❌ 错误：「已将『阿基』的伤害提升到 999」（非标准译名）

3. **歧义时按下列优先级**
   1. 标准中文（biligame WIKI / 本目录）
   2. 英文（Amicitia WIKI / `docs/amicitia/md/`）
   3. 日文片假名（仅当用户用日文输入时）

### 与 Amicitia WIKI 的关系

| | docs/amicitia/ | **docs/zh-cn/**（本目录） |
|---|---|---|
| 语言 | 英文 | 中文 |
| 来源 | Amicitia Wiki | biligame WIKI |
| 用途 | ID / 数据结构权威参考 | **中文用户输入识别** + 标准译名输出 |
| 字段精度 | 完整（含未公开数据） | 名称三语对照 + 关键数值 |

→ **两个目录互补**：英文 ID/数据结构以 Amicitia 为准；中文译名以本目录为准。

## 数据来源页面（biligame WIKI 子页面索引）

抓取的原始 HTML 缓存于 `tools/Output/.data/wiki_zh/`（Git 忽略），解析后的 CSV 与本目录 Markdown 同步。重新抓取/更新流程：

```powershell
# 重新抓取首页 + 子页面 HTML
$dir='tools\Output\.data\wiki_zh'; New-Item -ItemType Directory -Force $dir | Out-Null
$urls = @{
  'skills' = 'https://wiki.biligame.com/persona/P3R/%E6%8A%80%E8%83%BD%E5%88%97%E8%A1%A8'
  'personas' = 'https://wiki.biligame.com/persona/P3R/%E4%BA%BA%E6%A0%BC%E9%9D%A2%E5%85%B7%E5%9B%BE%E9%89%B4'
  'enemies' = 'https://wiki.biligame.com/persona/P3R/%E6%95%8C%E4%BA%BA%E6%95%B0%E6%8D%AE'
  'tartarus' = 'https://wiki.biligame.com/persona/P3R/%E5%A1%94%E5%B0%94%E5%A1%94%E7%BD%97%E6%96%AF'
  'arcana' = 'https://wiki.biligame.com/persona/P3R/%E9%98%BF%E5%B0%94%E5%8D%A1%E7%BA%B3%E5%A4%A7%E5%8D%A1%E6%95%88%E6%9E%9C'
  'status' = 'https://wiki.biligame.com/persona/P3R/%E5%BC%82%E5%B8%B8%E7%8A%B6%E6%80%81%E6%95%88%E6%9E%9C'
}
foreach($k in $urls.Keys){
  (Invoke-WebRequest -Uri $urls[$k] -UseBasicParsing).Content | Out-File "$dir\$k.html" -Encoding utf8
}
```

## 局限与已知缺口

- ⚠ **biligame 部分页面尚未填充内容**：饰品图鉴 / 武器图鉴 / 防具数据 / 失踪者 / 仲魔合体表 / 合成范式 / 异常状态等页面在抓取时为骨架（仅模板，无表格行）。这些条目的中文译名只能在游戏内 L10N 文件中获取（见 `Extracted/IoStore/L10N/zh-Hans/`）或等待 WIKI 补完。
- ⚠ **敌人页缺少英文/日文列**：biligame 敌人页仅有中文。如需英文键，对照 `docs/amicitia/md/Persona_3_Reload_Enemies.md`。
- ⚠ **音频/BGM 缺中文译名表**：biligame 未提供。

## 与游戏内 L10N 数据的关系

游戏内 13 种语言本地化文本位于：

```
Extracted/IoStore/L10N/zh-Hans/   ← 简体中文 (3,723 文件)
Extracted/IoStore/L10N/zh-Hant/   ← 繁体中文
```

biligame WIKI 的译名**与游戏内简中本地化文本基本一致**（biligame 攻略组主要参照游戏内简中文本）。如遇 WIKI ≠ 游戏内不一致，**以游戏内 L10N 为准**（毕竟用户在游戏中看到的就是 L10N 文本）。
