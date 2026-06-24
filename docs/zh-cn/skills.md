# P3R 标准中文译名 — 技能（Skills）

> 来源：[biligame WIKI · P3R/技能列表](https://wiki.biligame.com/persona/P3R/%E6%8A%80%E8%83%BD%E5%88%97%E8%A1%A8)
> 抓取日期：2026-06-24  | 共 368 条记录
> 与游戏 DataTable 对应：`DatSkillDataAsset.uasset` + `DatSkillNormalDataAsset.uasset`（`Properties.Data[ID]`）

本表用于：**面向中文用户时，技能名称统一使用此处「标准中文译名」（如 Agi → 亚基）。** 写脚本时仍以 `ID`（数组下标）为唯一键，**不要按名字猜测**。

## ID 重要说明

⚠ `DatSkillNormalDataAsset.Properties.Data[]` 的数组下标 == Skill ID == 本表 ID 列。`Data[0]..Data[9]` 多为引擎占位行；首个游戏技能「亚基 / Agi」位于 `Data[10]`。详见 [MODDING_PITFALLS.md#P-001](../MODDING_PITFALLS.md#p-001-datatable-数组索引--资产-id不要默认改-data0)。

## 完整技能译名对照表

| ID | 中文 | 日文 | 英文 | 属性 | SP |
|---:|------|------|------|------|----|
| 10 | 亚基 | アギ | Agi | 火焰 | 3 MP |
| 11 | 亚基拉欧 | アギラオ | Agilao | 火焰 | 6 MP |
| 12 | 亚基达因 | アギダイン | Agidyne | 火焰 | 12 MP |
| 13 | 玛哈拉基 | マハラギ | Maragi | 火焰 | 8 MP |
| 14 | 玛哈拉基翁 | マハラギオン | Maragion | 火焰 | 14 MP |
| 15 | 玛哈拉基达因 | マハラギダイン | Maragidyne | 火焰 | 24 MP |
| 16 | 炼狱 | インフェルノ | Inferno | 火焰 | 40 MP |
| 18 | 魔罗拉基达因 | マララギダイン | Maralagidyne | 火焰 | 24 MP |
| 20 | 布芙 | ブフ | Bufu | 冰冻 | 4 MP |
| 21 | 布芙拉 | ブフーラ | Bufula | 冰冻 | 8 MP |
| 22 | 布芙达因 | ブフダイン | Bufudyne | 冰冻 | 14 MP |
| 23 | 玛哈布芙 | マハブフ | Mabufu | 冰冻 | 10 MP |
| 24 | 玛哈布芙拉 | マハブフーラ | Mabufula | 冰冻 | 16 MP |
| 25 | 玛哈布芙达因 | マハブフダイン | Mabufudyne | 冰冻 | 24 MP |
| 26 | 钻石星尘 | ダイアモンドダスト | Diamond Dust | 冰冻 | 46 MP |
| 30 | 加尔 | ガル | Garu | 疾风 | 3 MP |
| 31 | 加尔拉 | ガルーラ | Garula | 疾风 | 6 MP |
| 32 | 加尔达因 | ガルダイン | Garudyne | 疾风 | 12 MP |
| 33 | 玛哈加尔 | マハガル | Magaru | 疾风 | 8 MP |
| 34 | 玛哈加尔拉 | マハガルーラ | Magarula | 疾风 | 14 MP |
| 35 | 玛哈加尔达因 | マハガルダイン | Magarudyne | 疾风 | 24 MP |
| 36 | 万物流转 | 万物流転 | Panta Rhei | 疾风 | 40 MP |
| 40 | 吉欧 | ジオ | Zio | 电击 | 4 MP |
| 41 | 吉欧加 | ジオンガ | Zionga | 电击 | 8 MP |
| 42 | 吉欧达因 | ジオダイン | Ziodyne | 电击 | 14 MP |
| 43 | 玛哈吉欧 | マハジオ | Mazio | 电击 | 10 MP |
| 44 | 玛哈吉欧加 | マハジオンガ | Mazionga | 电击 | 16 MP |
| 45 | 玛哈吉欧达因 | マハジオダイン | Maziodyne | 电击 | 24 MP |
| 46 | 真理之雷 | 真理の雷 | Thunder Reign | 电击 | 46 MP |
| 50 | 哈玛 | ハマ | Hama | 神圣 | 6 MP |
| 51 | 哈玛翁 | ハマオン | Hamaon | 神圣 | 14 MP |
| 52 | 玛翰玛 | マハンマ | Mahama | 神圣 | 12 MP |
| 53 | 玛翰玛翁 | マハンマオン | Mahamaon | 神圣 | 26 MP |
| 54 | 回转讲道 | 回転説法 | Samsara | 神圣 | 40 MP |
| 56 | 克哈 | コウハ | Kouha | 神圣 | 4 MP |
| 57 | 克加 | コウガ | Kouga | 神圣 | 8 MP |
| 58 | 克加翁 | コウガオン | Kougaon | 神圣 | 15 MP |
| 59 | 玛哈克哈 | マハコウハ | Makouha | 神圣 | 10 MP |
| 60 | 玛哈克加 | マハコウガ | Makouga | 神圣 | 16 MP |
| 61 | 玛哈克加翁 | マハコウガオン | Makougaon | 神圣 | 25 MP |
| 62 | 神之审判 | 神の審判 | Divine Judgment | 神圣 | 38 MP |
| 64 | 姆多 | ムド | Mudo | 暗黑 | 6 MP |
| 65 | 姆多翁 | ムドオン | Mudoon | 暗黑 | 14 MP |
| 66 | 玛哈姆多 | マハムド | Mamudo | 暗黑 | 12 MP |
| 67 | 玛哈姆多翁 | マハムドオン | Mamudoon | 暗黑 | 26 MP |
| 68 | 可以为我而死吗？ | 死んでくれる？ | Die For Me! | 暗黑 | 40 MP |
| 70 | 耶哈 | エイハ | Eiha | 暗黑 | 4 MP |
| 71 | 耶加 | エイガ | Eiga | 暗黑 | 8 MP |
| 72 | 耶加翁 | エイガオン | Eigaon | 暗黑 | 15 MP |
| 73 | 玛哈耶哈 | マハエイハ | Maeiha | 暗黑 | 10 MP |
| 74 | 玛哈耶加 | マハエイガ | Maeiga | 暗黑 | 16 MP |
| 75 | 玛哈耶加翁 | マハエイガオン | Maeigaon | 暗黑 | 25 MP |
| 76 | 恶魔审判 | 悪魔の審判 | Demonic Decree | 暗黑 | 38 MP |
| 78 | 米吉多 | メギド | Megido | 万能 | 20 MP |
| 79 | 米吉多拉 | メギドラ | Megidola | 万能 | 32 MP |
| 80 | 米吉多拉翁 | メギドラオン | Megidolaon | 万能 | 50 MP |
| 81 | 漆黑之蛇 | 漆黒の蛇 | Black Viper | 万能 | 70 MP |
| 82 | 拂晓明星 | 明けの明星 | Morning Star | 万能 | 64 MP |
| 85 | 施毒术 | ポイズマ | Poisma | 剧毒 | 5 MP |
| 86 | 毒雾 | ポイズンミスト | Poison Mist | 剧毒 | 10 MP |
| 87 | 马琳卡琳 | マリンカリン | Marin Karin | 魅惑 | 5 MP |
| 88 | 性感之舞 | セクシーダンス | Sexy Dance | 魅惑 | 10 MP |
| 89 | 欺敌奇招 | ネコダマシ | Bewilder | 动摇 | 5 MP |
| 90 | 闪光噪声 | フラッシュノイズ | Eerie Sound | 动摇 | 10 MP |
| 91 | 普林帕 | プリンパ | Pulinpa | 混乱 | 5 MP |
| 92 | 颠塔拉弗 | テンタラフー | Tentarafoo | 混乱 | 10 MP |
| 93 | 恶魔之触 | デビルタッチ | Evil Touch | 恐惧 | 5 MP |
| 94 | 恶魔微笑 | デビルスマイル | Evil Smile | 恐惧 | 10 MP |
| 95 | 恶毒咒骂 | バリゾーゴン | Provoke | 暴怒 | 5 MP |
| 96 | 终焉预言 | 終末の予言 | Infuriate | 暴怒 | 10 MP |
| 100 | 亡者喟叹 | 亡者の嘆き | Ghastly Wail | 万能 | 28 MP |
| 101 | 污秽吐息 | 淀んだ吐息 | Foul Breath | 万能 | 8 MP |
| 102 | 污秽空气 | 淀んだ空気 | Stagnant Air | 万能 | 12 MP |
| 103 | 吸血 | 吸血 | Life Drain | 万能 | 3 MP |
| 104 | 吸魔 | 吸魔 | Spirit Drain | 万能 | 3 MP |
| 105 | 病毒之息 | ウィルスブレス | Virus Breath | 万能 | 25 MP |
| 110 | 威力斩击 | パワースラッシュ | Power Slash | 斩击 | 7% HP |
| 111 | 死亡终结 | デッドエンド | Fatal End | 斩击 | 10% HP |
| 112 | 五月雨斩 | 五月雨斬り | Tempest Slash | 斩击 | 14% HP |
| 113 | 真空斩 | 真空斬 | Vacuum Slash | 斩击 | 14% HP |
| 114 | 利剑乱舞 | 利剣乱舞 | Blade of Fury | 斩击 | 17% HP |
| 115 | 死亡界限 | デスバウンド | Deathbound | 斩击 | 19% HP |
| 116 | 勇气之击 | ブレイブザッパー | Brave Blade | 斩击 | 20% HP |
| 117 | 空间杀法 | 空間殺法 | Vorpal Blade | 斩击 | 22% HP |
| 118 | 天军之剑 | 天軍の剣 | Heaven's Blade | 斩击 | 18% HP |
| 119 | 月影 | 月影 | Getsu-ei | 斩击 | 13% HP |
| 120 | 残影 | 残影 | Zan-ei | 斩击 | 10% HP |
| 121 | 神经碎断 | ニューロクランチ | Neuro Slash | 斩击 | 16% HP |
| 125 | 突击 | 突撃 | Bash | 打击 | 7% HP |
| 126 | 俯冲突击 | アサルトダイブ | Assault Dive | 打击 | 11% HP |
| 127 | 巨人铁拳 | ギガンフィスト | Gigantic Fist | 打击 | 14% HP |
| 128 | 电光石火 | 電光石火 | Swift Strike | 打击 | 15% HP |
| 129 | 金刚发破 | 金剛発破 | Herculean Strike | 打击 | 17% HP |
| 130 | 灼热波浪 | ヒートウェイブ | Heat Wave | 打击 | 20% HP |
| 131 | 神之手 | ゴッドハンド | God's Hand | 打击 | 25% HP |
| 132 | 虚无艺术 | アカシャアーツ | Akasha Arts | 打击 | 22% HP |
| 133 | 音速拳 | ソニックパンチ | Sonic Punch | 打击 | 9% HP |
| 139 | 单次射击 | シングルショット | Single Shot | 贯穿 | 6% HP |
| 140 | 天使之箭 | エンジェルアロー | Holy Arrow | 贯穿 | 8% HP |
| 141 | 百万射击 | ミリオンシュート | Torrent Shot | 贯穿 | 11% HP |
| 142 | 疯狂突击 | マッドアサルト | Vile Assault | 贯穿 | 15% HP |
| 143 | 箭浴 | アローシャワー | Arrow Rain | 贯穿 | 16% HP |
| 144 | 刹那五月雨击 | 刹那五月雨撃 | Myriad Arrows | 贯穿 | 19% HP |
| 145 | 爆破攻击 | バスタアタック | Cruel Attack | 贯穿 | 13% HP |
| 146 | 纯真突刺 | イノセントタック | Primal Force | 贯穿 | 21% HP |
| 147 | 大劫 | プララヤ | Pralaya | 贯穿 | 23% HP |
| 148 | 毒箭 | ポイズンアロー | Poison Arrow | 贯穿 | 13% HP |
| 155 | 迪亚 | ディア | Dia | 恢复 | 3 MP |
| 156 | 迪亚拉玛 | ディアラマ | Diarama | 恢复 | 8 MP |
| 157 | 迪亚拉翰 | ディアラハン | Diarahan | 恢复 | 20 MP |
| 160 | 梅迪亚 | メディア | Media | 恢复 | 7 MP |
| 161 | 梅迪拉玛 | メディラマ | Mediarama | 恢复 | 16 MP |
| 162 | 梅迪亚拉翰 | メディアラハン | Mediarahan | 恢复 | 44 MP |
| 163 | 救世主之愈 | メシアライザー | Salvation | 恢复 | 60 MP |
| 165 | 利卡姆 | リカーム | Recarm | 恢复 | 12 MP |
| 166 | 萨玛利卡姆 | サマリカーム | Samarecarm | 恢复 | 35 MP |
| 167 | 利卡姆多拉 | リカームドラ | Recarmdra | 恢复 | 5 MP |
| 170 | 帕特拉 | パトラ | Patra | 恢复 | 4 MP |
| 171 | 梅帕特拉 | メパトラ | Me Patra | 恢复 | 10 MP |
| 172 | 拜斯堤 | バイスディ | Baisudi | 恢复 | 4 MP |
| 173 | 玛哈拜斯堤 | マハバイスディ | Mabaisudi | 恢复 | 10 MP |
| 176 | 甘露之雨 | アムリタシャワー | Amrita Shower | 恢复 | 25 MP |
| 177 | 甘露水滴 | アムリタドロップ | Amrita Drop | 恢复 | 14 MP |
| 180 | 塔尔卡加 | タルカジャ | Tarukaja | 辅助 | 8 MP |
| 181 | 拉库卡加 | ラクカジャ | Rakukaja | 辅助 | 8 MP |
| 182 | 斯库卡加 | スクカジャ | Sukukaja | 辅助 | 8 MP |
| 185 | 玛哈塔尔卡加 | マハタルカジャ | Matarukaja | 辅助 | 24 MP |
| 186 | 玛哈拉库卡加 | マハラクカジャ | Marakukaja | 辅助 | 24 MP |
| 187 | 玛哈斯库卡加 | マハスクカジャ | Masukukaja | 辅助 | 24 MP |
| 188 | 灼热奋起 | ヒートライザ | Heat Riser | 辅助 | 36 MP |
| 190 | 塔伦达 | タルンダ | Tarunda | 辅助 | 8 MP |
| 191 | 拉坤达 | ラクンダ | Rakunda | 辅助 | 8 MP |
| 192 | 斯坤达 | スクンダ | Sukunda | 辅助 | 8 MP |
| 195 | 玛哈塔伦达 | マハタルンダ | Matarunda | 辅助 | 24 MP |
| 196 | 玛哈拉坤达 | マハラクンダ | Marakunda | 辅助 | 24 MP |
| 197 | 玛哈斯坤达 | マハスクンダ | Masukunda | 辅助 | 24 MP |
| 198 | 女巫诅咒 | ランダマイザ | Debilitate | 辅助 | 36 MP |
| 200 | 迪卡加 | デカジャ | Dekaja | 辅助 | 10 MP |
| 201 | 迪坤达 | デクンダ | Dekunda | 辅助 | 10 MP |
| 205 | 蓄力 | チャージ | Charge | 辅助 | 30 MP |
| 206 | 专心致志 | コンセントレイト | Concentrate | 辅助 | 30 MP |
| 207 | 鲜血蓄力 | ブラッディチャージ | Bloody Charge | 辅助 | 40% HP |
| 210 | 反叛 | リベリオン | Rebellion | 辅助 | 7 MP |
| 211 | 革命 | レボリューション | Revolution | 辅助 | 14 MP |
| 215 | 提特拉康 | テトラカーン | Tetrakarn | 辅助 | 24 MP |
| 216 | 玛卡拉康 | マカラカーン | Makarakarn | 辅助 | 24 MP |
| 220 | 消除火焰防御 | 火炎ガードキル | Fire Break | 辅助 | 12 MP |
| 221 | 消除冰冻防御 | 氷結ガードキル | Ice Break | 辅助 | 12 MP |
| 222 | 消除疾风防御 | 疾風ガードキル | Wind Break | 辅助 | 12 MP |
| 223 | 消除电击防御 | 電撃ガードキル | Elec Break | 辅助 | 12 MP |
| 230 | 大罪穿甲弹 | 大罪の徹甲弾 | Sinful Shell | 万能 | 66 MP |
| 231 | 崇高圣战 | エル・ジハード | Wild Thunder | 电击 | 48 MP |
| 232 | 真空波 | 真空波 | Vacuum Wave | 疾风 | 44 MP |
| 233 | 大燃烧 | 大炎上 | Blazing Hell | 火焰 | 44 MP |
| 234 | 大冰河时期 | 大氷河期 | Ice Age | 冰冻 | 48 MP |
| 235 | 宇宙火焰 | コズミックフレア | Cosmic Flare | 万能 | 40 MP |
| 236 | 一枪毙命 | ワンショットキル | One-shot Kill | 贯穿 | 17% HP |
| 237 | 反抗之刃 | 反逆の刃 | Rebellion Blade | 万能 | 80 MP |
| 238 | 化装舞会 | マスカレイド | Masquerade | 斩击 | 24% HP |
| 239 | 十文字斩 | 十文字斬り | Cross Slash | 斩击 | 18% HP |
| 240 | 祸津曼荼罗 | マガツマンダラ | Magatsu Mandala | 暗黑 | 38 MP |
| 241 | 辉箭 | 輝矢 | Shining Arrows | 神圣 | 24 MP |
| 245 | 高阶分析 | ハイ・アナライズ | Full Analysis | 特殊 | 35 MP |
| 246 | 逃离路线 | エスケープロード | Escape Route | 特殊 | 24 MP |
| 247 | 干扰 | ジャミング | Jamming | 特殊 | 20 MP |
| 248 | 塔尔塔罗斯侦测 | タルタロスサーチ | Tartarus Search | 特殊 | 50 MP |
| 249 | 希尔芙灵气 | シルフィードオーラ | Sylphid Aura | 特殊 | 24 MP |
| 250 | 冲击噪声 | ショックノイズ | Shock Noise | 特殊 | 30 MP |
| 260 | 华彩乐段 | カデンツァ | Cadenza | 恢复 | 0 0 |
| 261 | 杰克兄弟 | ジャックブラザーズ | Jack Brothers | 万能 | 0 0 |
| 262 | 大王和俺们 | おおさまとおいら | King and I | 冰冻 | 0 0 |
| 263 | 最佳好友 | ベストフレンド | Best Friends | 辅助 | 0 0 |
| 264 | 红莲华斩杀 | 紅蓮華斬殺 | Scarlet Havoc | 斩击 | 0 0 |
| 265 | 诡骗师 | トリックスター | Trickster | 万能 | 0 0 |
| 266 | 哈米吉多顿 | ハルマゲドン | Armageddon | 万能 | 0 0 |
| 700 | 斩击耐性 | 斬撃耐性 | Resist Slash | 被动 |  |
| 701 | 斩击无效 | 斬撃無効 | Null Slash | 被动 |  |
| 702 | 斩击反弹 | 斬撃反射 | Repel Slash | 被动 |  |
| 703 | 斩击吸收 | 斬撃吸収 | Drain Slash | 被动 |  |
| 704 | 打击耐性 | 打撃耐性 | Resist Strike | 被动 |  |
| 705 | 打击无效 | 打撃無効 | Null Strike | 被动 |  |
| 706 | 打击反弹 | 打撃反射 | Repel Strike | 被动 |  |
| 707 | 打击吸收 | 打撃吸収 | Drain Strike | 被动 |  |
| 708 | 贯穿耐性 | 貫通耐性 | Resist Pierce | 被动 |  |
| 709 | 贯穿无效 | 貫通無効 | Null Pierce | 被动 |  |
| 710 | 贯穿反弹 | 貫通反射 | Repel Pierce | 被动 |  |
| 711 | 贯穿吸收 | 貫通吸収 | Drain Pierce | 被动 |  |
| 712 | 火焰耐性 | 火炎耐性 | Resist Fire | 被动 |  |
| 713 | 火焰无效 | 火炎無効 | Null Fire | 被动 |  |
| 714 | 火焰反弹 | 火炎反射 | Repel Fire | 被动 |  |
| 715 | 火焰吸收 | 火炎吸収 | Drain Fire | 被动 |  |
| 716 | 冰冻耐性 | 氷結耐性 | Resist Ice | 被动 |  |
| 717 | 冰冻无效 | 氷結無効 | Null Ice | 被动 |  |
| 718 | 冰冻反弹 | 氷結反射 | Repel Ice | 被动 |  |
| 719 | 冰冻吸收 | 氷結吸収 | Drain Ice | 被动 |  |
| 720 | 疾风耐性 | 疾風耐性 | Resist Wind | 被动 |  |
| 721 | 疾风无效 | 疾風無効 | Null Wind | 被动 |  |
| 722 | 疾风反弹 | 疾風反射 | Repel Wind | 被动 |  |
| 723 | 疾风吸收 | 疾風吸収 | Drain Wind | 被动 |  |
| 724 | 电击耐性 | 電撃耐性 | Resist Elec | 被动 |  |
| 725 | 电击无效 | 電撃無効 | Null Elec | 被动 |  |
| 726 | 电击反弹 | 電撃反射 | Repel Elec | 被动 |  |
| 727 | 电击吸收 | 電撃吸収 | Drain Elec | 被动 |  |
| 728 | 光耐性 | 光耐性 | Resist Light | 被动 |  |
| 729 | 光无效 | 光無効 | Null Light | 被动 |  |
| 730 | 光反弹 | 光反射 | Repel Light | 被动 |  |
| 731 | 光吸收 | 光吸収 | Drain Light | 被动 |  |
| 732 | 暗耐性 | 闇耐性 | Resist Dark | 被动 |  |
| 733 | 暗无效 | 闇無効 | Null Dark | 被动 |  |
| 734 | 暗反弹 | 闇反射 | Repel Dark | 被动 |  |
| 735 | 暗吸收 | 闇吸収 | Drain Dark | 被动 |  |
| 738 | 昏厥耐性 | 気絶耐性 | Resist Dizzy | 被动 |  |
| 739 | 昏厥无效 | 気絶無効 | Null Dizzy | 被动 |  |
| 740 | 毒耐性 | 毒耐性 | Resist Poison | 被动 |  |
| 741 | 毒无效 | 毒無効 | Null Poison | 被动 |  |
| 742 | 魅惑耐性 | 悩殺耐性 | Resist Charm | 被动 |  |
| 743 | 魅惑无效 | 悩殺無効 | Null Charm | 被动 |  |
| 744 | 动摇耐性 | 動揺耐性 | Resist Distress | 被动 |  |
| 745 | 动摇无效 | 動揺無効 | Null Distress | 被动 |  |
| 746 | 混乱耐性 | 混乱耐性 | Resist Confuse | 被动 |  |
| 747 | 混乱无效 | 混乱無効 | Null Confuse | 被动 |  |
| 748 | 恐惧耐性 | 恐怖耐性 | Resist Fear | 被动 |  |
| 749 | 恐惧无效 | 恐怖無効 | Null Fear | 被动 |  |
| 750 | 暴怒耐性 | ヤケクソ耐性 | Resist Rage | 被动 |  |
| 751 | 暴怒无效 | ヤケクソ無効 | Null Rage | 被动 |  |
| 752 | 冻结耐性 | 凍結耐性 | Resist Freeze | 被动 |  |
| 753 | 冻结无效 | 凍結無効 | Null Freeze | 被动 |  |
| 754 | 触电耐性 | 感電耐性 | Resist Shock | 被动 |  |
| 755 | 触电无效 | 感電無効 | Null Shock | 被动 |  |
| 756 | 不动心 | 不動心 | Unshaken Will | 被动 |  |
| 757 | 异常状态耐性 | 状態異常耐性 | Resist Ailments | 被动 |  |
| 759 | 斩击识破 | 斬撃見切り | Dodge Slash | 被动 |  |
| 760 | 真·斩击识破 | 真・斬撃見切り | Evade Slash | 被动 |  |
| 761 | 打击识破 | 打撃見切り | Dodge Strike | 被动 |  |
| 762 | 真·打击识破 | 真・打撃見切り | Evade Strike | 被动 |  |
| 763 | 贯穿识破 | 貫通見切り | Dodge Pierce | 被动 |  |
| 764 | 真·贯穿识破 | 真・貫通見切り | Evade Pierce | 被动 |  |
| 765 | 火焰识破 | 火炎見切り | Dodge Fire | 被动 |  |
| 766 | 真·火焰识破 | 真・火炎見切り | Evade Fire | 被动 |  |
| 767 | 冰冻识破 | 氷結見切り | Dodge Ice | 被动 |  |
| 768 | 真·冰冻识破 | 真・氷結見切り | Evade Ice | 被动 |  |
| 769 | 疾风识破 | 疾風見切り | Dodge Wind | 被动 |  |
| 770 | 真·疾风识破 | 真・疾風見切り | Evade Wind | 被动 |  |
| 771 | 电击识破 | 電撃見切り | Dodge Elec | 被动 |  |
| 772 | 真·电击识破 | 真・電撃見切り | Evade Elec | 被动 |  |
| 773 | 光识破 | 光見切り | Dodge Light | 被动 |  |
| 774 | 真·光识破 | 真・光見切り | Evade Light | 被动 |  |
| 775 | 暗识破 | 闇見切り | Dodge Dark | 被动 |  |
| 776 | 真·暗识破 | 真・闇見切り | Evade Dark | 被动 |  |
| 779 | 反击 | カウンタ | Counter | 被动 |  |
| 780 | 重反击 | ヘビーカウンタ | Counterstrike | 被动 |  |
| 781 | 超反击 | ハイパーカウンタ | High Counter | 被动 |  |
| 784 | 小治愈促进 | 小治癒促進 | Regenerate 1 | 被动 |  |
| 785 | 中治愈促进 | 中治癒促進 | Regenerate 2 | 被动 |  |
| 786 | 大治愈促进 | 大治癒促進 | Regenerate 3 | 被动 |  |
| 788 | 小气功 | 小気功 | Invigorate 1 | 被动 |  |
| 789 | 中气功 | 中気功 | Invigorate 2 | 被动 |  |
| 790 | 大气功 | 大気功 | Invigorate 3 | 被动 |  |
| 792 | 斩击强化 | 斬撃ブースタ | Slash Boost | 被动 |  |
| 793 | 高级斩击强化 | 斬撃ハイブースタ | Slash Amp | 被动 |  |
| 794 | 打击强化 | 打撃ブースタ | Strike Boost | 被动 |  |
| 795 | 高级打击强化 | 打撃ハイブースタ | Strike Amp | 被动 |  |
| 796 | 贯穿强化 | 貫通ブースタ | Pierce Boost | 被动 |  |
| 797 | 高级贯穿强化 | 貫通ハイブースタ | Pierce Amp | 被动 |  |
| 798 | 火焰强化 | 火炎ブースタ | Fire Boost | 被动 |  |
| 799 | 高级火焰强化 | 火炎ハイブースタ | Fire Amp | 被动 |  |
| 800 | 冰冻强化 | 氷結ブースタ | Ice Boost | 被动 |  |
| 801 | 高级冰冻强化 | 氷結ハイブースタ | Ice Amp | 被动 |  |
| 802 | 疾风强化 | 疾風ブースタ | Wind Boost | 被动 |  |
| 803 | 高级疾风强化 | 疾風ハイブースタ | Wind Amp | 被动 |  |
| 804 | 电击强化 | 電撃ブースタ | Elec Boost | 被动 |  |
| 805 | 高级电击强化 | 電撃ハイブースタ | Elec Amp | 被动 |  |
| 806 | 光强化 | 光ブースタ | Light Boost | 被动 |  |
| 807 | 高级光强化 | 光ハイブースタ | Light Amp | 被动 |  |
| 808 | 暗强化 | 闇ブースタ | Dark Boost | 被动 |  |
| 809 | 高级暗强化 | 闇ハイブースタ | Dark Amp | 被动 |  |
| 811 | 昏厥率ＵＰ | 気絶率ＵＰ | Dizzy Boost | 被动 |  |
| 812 | 中毒率ＵＰ | 毒率ＵＰ | Poison Boost | 被动 |  |
| 813 | 魅惑率ＵＰ | 悩殺率ＵＰ | Charm Boost | 被动 |  |
| 814 | 动摇率ＵＰ | 動揺率ＵＰ | Distress Boost | 被动 |  |
| 815 | 混乱率ＵＰ | 混乱率ＵＰ | Confuse Boost | 被动 |  |
| 816 | 恐惧率ＵＰ | 恐怖率ＵＰ | Fear Boost | 被动 |  |
| 817 | 暴怒率ＵＰ | ヤケクソ率ＵＰ | Rage Boost | 被动 |  |
| 818 | 冻结率ＵＰ | 凍結率ＵＰ | Freeze Boost | 被动 |  |
| 819 | 触电率ＵＰ | 感電率ＵＰ | Shock Boost | 被动 |  |
| 820 | 异常状态成功率ＵＰ | 状態異常成功率ＵＰ | Ailment Boost | 被动 |  |
| 821 | 哈玛成功率ＵＰ | ハマ成功率ＵＰ | Hama Boost | 被动 |  |
| 822 | 姆多成功率ＵＰ | ムド成功率ＵＰ | Mudo Boost | 被动 |  |
| 825 | 自动塔尔卡加 | タルカジャオート | Auto Tarukaja | 被动 |  |
| 826 | 自动拉库卡加 | ラクカジャオート | Auto Rakukaja | 被动 |  |
| 827 | 自动斯库卡加 | スクカジャオート | Auto Sukukaja | 被动 |  |
| 828 | 自动玛哈塔尔卡 | マハタルカオート | Auto Mataru | 被动 |  |
| 829 | 自动玛哈拉库卡 | マハラクカオート | Auto Maraku | 被动 |  |
| 830 | 自动玛哈斯库卡 | マハスクカオート | Auto Masuku | 被动 |  |
| 831 | 自动反叛 | リベリオンオート | Auto Rebellion | 被动 |  |
| 833 | 指导 | コーチング | Sharp Student | 被动 |  |
| 834 | 建言 | アドバイス | Apt Pupil | 被动 |  |
| 835 | 坚忍 | 食いしばり | Endure | 被动 |  |
| 836 | 不屈斗志 | 不屈の闘志 | Enduring Soul | 被动 |  |
| 838 | 胜利气息 | 勝利の息吹 | Life Aid | 被动 |  |
| 839 | 胜利咆哮 | 勝利の雄たけび | Victory Cry | 被动 |  |
| 841 | 诸神庇佑 | 神々の加護 | Divine Grace | 被动 |  |
| 842 | 大天使的庇佑 | 大天使の加護 | Angelic Grace | 被动 |  |
| 843 | 大虎 | 大虎 | Raging Tiger | 被动 |  |
| 844 | 明王的庇佑 | 明王の加護 | Vidyaraja's Blessing | 被动 |  |
| 845 | 初级成长 | ローグロウ | Growth 1 | 被动 |  |
| 846 | 中级成长 | ミドルグロウ | Growth 2 | 被动 |  |
| 847 | 高级成长 | ハイグロウ | Growth 3 | 被动 |  |
| 848 | 蚁之舞 | アリ・ダンス | Ali Dance | 被动 |  |
| 849 | 不动如山 | 仁王立ち | Firm Stance | 被动 |  |
| 850 | 光明生还 | 光からの生還 | Survive Light | 被动 |  |
| 851 | 光明大生还 | 光からの大生還 | Endure Light | 被动 |  |
| 852 | 黑暗生还 | 闇からの生還 | Survive Dark | 被动 |  |
| 853 | 黑暗大生还 | 闇からの大生還 | Endure Dark | 被动 |  |
| 854 | 生还把戏 | 生還トリック | Survival Trick | 被动 |  |
| 856 | 武道的资质 | 武道の素養 | Arms Master | 被动 |  |
| 857 | 魔术的资质 | 魔術の素養 | Spell Master | 被动 |  |
| 863 | 万能强化 | 万能ブースタ | Almighty Boost | 被动 |  |
| 864 | 高级万能强化 | 万能ハイブースタ | Almighty Amp | 被动 |  |
| 865 | 魔导才能 | 魔導の才能 | Magic Ability | 被动 |  |
| 866 | 魔导精髓 | 魔導の極意 | Magic Mastery | 被动 |  |
| 869 | 急速恢复 | 急速回復 | Fast Heal | 被动 |  |
| 870 | 瞬间恢复 | 瞬間回復 | Insta-Heal | 被动 |  |
| 871 | 物理耐性 | 物理耐性 | Resist Phys | 被动 |  |
| 872 | 物理无效 | 物理無効 | Null Phys | 被动 |  |
| 875 | 终极斩击强化 | 斬撃メガブースタ | Slash Driver | 被动 |  |
| 876 | 终极打击强化 | 打撃メガブースタ | Strike Driver | 被动 |  |
| 877 | 终极贯穿强化 | 貫通メガブースタ | Pierce Driver | 被动 |  |
| 878 | 终极火焰强化 | 火炎メガブースタ | Fire Driver | 被动 |  |
| 879 | 终极冰冻强化 | 氷結メガブースタ | Ice Driver | 被动 |  |
| 880 | 终极电击强化 | 電撃メガブースタ | Elec Driver | 被动 |  |
| 881 | 终极疾风强化 | 疾風メガブースタ | Wind Driver | 被动 |  |
| 882 | 终极光强化 | 光メガブースタ | Light Driver | 被动 |  |
| 883 | 终极暗强化 | 闇メガブースタ | Dark Driver | 被动 |  |
| 884 | 暴击ＵＰ | クリティカルＵＰ | Crit Rate Boost | 被动 |  |
| 885 | 暴击大ＵＰ | クリティカル大ＵＰ | Crit Rate Amp | 被动 |  |
| 886 | 防炎诀窍 | 防炎の心得 | Anti-Fire Master | 被动 |  |
| 887 | 防冰诀窍 | 防氷の心得 | Anti-Ice Master | 被动 |  |
| 888 | 防雷诀窍 | 防雷の心得 | Anti-Electric Master | 被动 |  |
| 889 | 防风诀窍 | 防風の心得 | Anti-Wind Master | 被动 |  |
| 890 | 灵魂交接 | ソウルシフト | Soul Shift | 被动 |  |
| 891 | 灵魂连锁 | ソウルチェイン | Soul Chain | 被动 |  |
| 892 | 真·灵魂连锁 | 真・ソウルチェイン | Soul Link | 被动 |  |
| 893 | 交接强化 | シフトブースタ | Shift Boost | 被动 |  |
| 894 | 高级交接强化 | シフトハイブースタ | Shift Amp | 被动 |  |
| 895 | 吸引才能 | 吸引の才能 | Drain Ability | 被动 |  |
| 896 | 单体攻击强化 | シングルブースタ | Single-Target Boost | 被动 |  |
| 897 | 全体攻击强化 | マルチブースタ | Multi-Target Boost | 被动 |  |
| 901 | 弱点强化 | ウィークブースタ | Weakness Boost | 被动 |  |
| 902 | 高级弱点强化 | ウィークハイブースタ | Weakness Amp | 被动 |  |
| 903 | 治愈的资质 | 治癒の素養 | Healing Master | 被动 |  |
| 904 | 治愈的极致 | 治癒の極致 | Healing Apex | 被动 |  |
| 905 | 会心强化 | 会心ブースタ | Critical Boost | 被动 |  |
| 906 | 高级会心强化 | 会心ハイブースタ | Critical Amp | 被动 |  |
| 907 | 卡加强化 | カジャブースタ | Buff Boost | 被动 |  |
| 908 | 高级卡加强化 | カジャハイブースタ | Buff Amp | 被动 |  |
| 909 | 异常发破强化 | 異常発破ブースタ | Ailment Burst | 被动 |  |
| 910 | 高级异常发破强化 | 異常発破ハイブースタ | Ailment Surge | 被动 |  |
| 911 | 弱点防护 | ウィークケア | Weakness Buffer | 被动 |  |
| 912 | 高级弱点防护 | ウィークハイケア | Weakness Mitigator | 被动 |  |
| 913 | 物理强化 | 物理ブースタ | Phys Boost | 被动 |  |
| 914 | 高级物理强化 | 物理ハイブースタ | Phys Amp | 被动 |  |
| 915 | 精神恢复 | 精神回復 | Spirit Refresh | 被动 |  |
| 916 | 精神大恢复 | 精神大回復 | Spirit Restore | 被动 |  |
| 917 | 自动斯坤达 | スクンダオート | Auto Sukunda | 被动 |  |
| 918 | 自动玛哈斯坤达 | マハスクンダオート | Auto Masukunda | 被动 |  |
| 919 | 自动强化 | 強化オート | Auto Bolster | 被动 |  |
| 920 | 自动灼热奋起 | ヒートライザオート | Auto Heat Riser | 被动 |  |
