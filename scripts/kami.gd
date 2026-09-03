class_name Kami
extends RefCounted

## 神々と恩恵のデータベース。
##
## 仕組み（シューティングとして分かりやすい形）：
##   - 神を迎えると、その神の「神器」（自動で発射される武器）がすぐに追加される。
##     主神も副神も神器の威力は同じ。詠唱・神招きだけ主神のもの。神は 3 柱まで（主神 1 + 副神 2）。
##   - 神ごとに「神格」レベルがあり、その神器が与えたダメージで神徳（経験値）が溜まって自動で強くなる。
##     節目のレベルで弾数や大きさが増える（Weapon を参照）。神酒は神格を 1 上げる。
##   - レベルアップで提示される恩恵は、神器の形を変える具体的な強化（幅・本数・射程…）。
##     同じ恩恵は重ねて取れる（maxlv）。数値は base × レアリティ倍率 + 重ねた回数の補正。
##   - 伝説は主神のみ。双神は 2 柱をともに迎えて、それぞれの恩恵を持つと出る。
##   - 詠唱（Z）と神招き（X）は主神の技。

# ---------------------------------------------------------------------------
# 神
# ---------------------------------------------------------------------------
const LIST := [
	{
		"id": "ama", "name": "天照大神", "kana": "アマテラス", "title": "日輪の女神",
		"color": Color(1.0, 0.84, 0.42), "color2": Color(1.0, 0.55, 0.25), "emblem": "sun",
		"role": "遠距離・貫通・安定した高火力",
		"weapon": "日輪光線", "weapon_desc": "正面へ絶えず伸びる光線。触れた敵をすべて貫き、照覧を与える",
		"cast": "八咫鏡", "cast_desc": "大きな光の鏡を前へ浮かべ、敵弾を跳ね返し触れた敵を焼く",
		"call": "天岩戸開き", "call_desc": "光で画面を満たし、無敵のまま全敵を焼く", "call_line": "天岩戸、開け。照らせ！",
		"status": "照覧", "status_desc": "照覧された敵は受けるダメージが 20% 増える（金色の輪郭）",
		"cost": "命の一割を日輪に焼かれ、二度と癒えぬ（最大 HP -10%）", "flavor": "夜更かしができなくなる。日が沈むと眠くてたまらない", "mark": "契約の刻印：光に焼かれた肌",
		"intro": "闇に呑まれるな。わたしの光が、汝の行く道を照らそう。",
		"lines": ["八咫の鏡は、悪しきものの姿を映し返す。", "日輪の下に隠れられるものはない。", "光は、まっすぐにしか進まぬ。"],
	},
	{
		"id": "susa", "name": "須佐之男命", "kana": "スサノオ", "title": "荒ぶる嵐の神",
		"color": Color(0.35, 0.82, 0.95), "color2": Color(0.20, 0.45, 0.85), "emblem": "storm",
		"role": "近距離・超高威力・押し戻し",
		"weapon": "荒波", "weapon_desc": "前方に短い大波を放つ。届く距離は短いが一撃が重く、敵を押し戻す",
		"cast": "渦潮", "cast_desc": "敵を巻き込んで奥へ押し流す渦",
		"call": "天叢雲の一閃", "call_desc": "巨大な剣の一閃で敵弾を消し、前方の全敵を斬る", "call_line": "荒ぶれ、天叢雲！",
		"status": "裂傷", "status_desc": "裂傷の敵は動くほど傷が開いてダメージを受ける（青い裂け目）",
		"cost": "嵐に身を晒し、受ける傷はすべて深くなる（受けるダメージ +8%）", "flavor": "海の幸が食べられなくなる。魚を見るとつい謝ってしまう", "mark": "契約の刻印：塩の匂いが消えない",
		"intro": "小娘、退屈しておったところだ。荒波に乗せて敵を蹴散らせ！",
		"lines": ["押し流せ！　海はすべてを呑み込む。", "近づいてきた奴から、まとめて叩き潰す。", "嵐の前では、雑魚など木の葉にすぎん。"],
	},
	{
		"id": "take", "name": "建御雷神", "kana": "タケミカヅチ", "title": "雷鳴の武神",
		"color": Color(1.0, 0.95, 0.50), "color2": Color(0.70, 0.60, 1.0), "emblem": "thunder",
		"role": "全画面・単発高火力・連鎖",
		"weapon": "神鳴り", "weapon_desc": "一定の間で画面内の敵に雷を落とし、近くの敵へ連鎖する。距離を問わない",
		"cast": "雷雲", "cast_desc": "近い敵 3 体に雷を落とし、前方に長く残る雷雲を作る",
		"call": "布都御魂", "call_desc": "数秒間、画面中の敵に雷が次々と降り注ぐ", "call_line": "布都御魂、降れ！",
		"status": "帯電", "status_desc": "帯電した敵は攻撃するたび自らも雷で焦げる（黄色い火花）",
		"cost": "雷気が指に居座り、詠唱の札が寄りつかぬ（札が落ちる確率 -30%）", "flavor": "雷の日に外へ出ると、必ず髪が逆立つ", "mark": "契約の刻印：指先に残る火花",
		"intro": "雷は理を問わぬ。ただ、当たった者すべてを焼く。",
		"lines": ["一撃が次の一撃を呼ぶ。それが雷だ。", "遠くにいても、雷は届く。", "逃げようとする者ほど、雷はよく落ちる。"],
	},
	{
		"id": "tsuki", "name": "月読命", "kana": "ツクヨミ", "title": "夜を統べる神",
		"color": Color(0.78, 0.72, 1.0), "color2": Color(0.45, 0.40, 0.85), "emblem": "moon",
		"role": "近接周回・時限爆発・範囲",
		"weapon": "月輪", "weapon_desc": "自機の周りを回る三日月の刃。触れた敵に宿命を刻み、少し遅れて範囲爆発",
		"cast": "新月", "cast_desc": "3 体まで貫き、大きな宿命を刻んで広く爆ぜさせる",
		"call": "常世の月", "call_desc": "刻が止まり、画面中の敵すべてに宿命を刻む", "call_line": "常世の月よ、刻を止めよ。",
		"status": "宿命", "status_desc": "刻まれた敵は 1.1 秒後に爆ぜ、周囲も巻き込む（紫の縮む輪）",
		"cost": "月の重みが影に絡み、足が鈍る（移動速度 -6%）", "flavor": "満月の夜は月見団子しか食べられなくなる", "mark": "契約の刻印：瞳に浮かぶ細い月",
		"intro": "……結末はすでに決まっている。ただ、いつ訪れるかだけだ。",
		"lines": ["月が満ちるとき、宿命は成る。", "近づく者は、刃が迎える。", "月輪の刃は音もなく、確実に。"],
	},
	{
		"id": "uzume", "name": "天宇受売命", "kana": "アメノウズメ", "title": "舞と歓喜の女神",
		"color": Color(1.0, 0.58, 0.78), "color2": Color(0.85, 0.30, 0.60), "emblem": "fan",
		"role": "中距離往復・敵弾消し・防御",
		"weapon": "舞扇", "weapon_desc": "投げると手元へ戻る扇。往復で敵を切り、触れた敵弾を花弁に変えて消す",
		"cast": "魅惑の舞", "cast_desc": "貫いた敵を魅了し、仲間を攻撃させる",
		"call": "天鈿女の舞", "call_desc": "画面中の敵を魅了して互いに争わせる", "call_line": "舞え、踊れ、宴の刻！",
		"status": "弱体", "status_desc": "弱体した敵は与えるダメージが 30% 減る（桃色の花弁）",
		"cost": "終わらぬ舞に命を削られる（最大 HP -10%）", "flavor": "音楽が鳴ると勝手に踊り出す。電車で少し恥ずかしい", "mark": "契約の刻印：ほどけない鈴の紐",
		"intro": "あら、可愛い子。さぁ踊りましょう、敵も味方も巻き込んで！",
		"lines": ["わたしの扇は、弾も敵も撫でて消すの。", "魅せてあげる。敵同士が争う様を。", "戦いも宴も、楽しんだ者の勝ちよ。"],
	},
	{
		"id": "inari", "name": "宇迦之御魂神", "kana": "ウカノミタマ", "title": "狐火の稲荷神",
		"color": Color(1.0, 0.62, 0.30), "color2": Color(1.0, 0.35, 0.20), "emblem": "fox",
		"role": "誘導・命中保証・手数",
		"weapon": "狐火", "weapon_desc": "敵を追う狐火を次々に放つ。1 発は軽いが、外れない",
		"cast": "狐火乱舞", "cast_desc": "9 本の狐火を一斉に放ち、狐の印を刻む",
		"call": "九尾の狐火", "call_desc": "敵を追う 9 つの大きな狐火を放つ", "call_line": "九つの尾、火を放て！",
		"status": "狐憑き", "status_desc": "会心が出た敵に狐の印。次の一撃は必ず会心（橙の狐面）",
		"cost": "狐が供物を先に啄み、勾玉が遠のく（勾玉の吸引範囲 -20%）", "flavor": "油揚げが食べられなくなる。稲荷寿司を見ると涙が出る", "mark": "契約の刻印：耳の後ろの狐の毛",
		"intro": "コン。狐火は嘘をつかぬ。狙った獲物は、必ず射抜く。",
		"lines": ["眷属の狐が、汝を援護しよう。", "外れぬ矢は、数を撃てばよい。", "稲穂は実る。汝の一撃もまた。"],
	},
	{
		"id": "suku", "name": "少名毘古那神", "kana": "スクナビコナ", "title": "酒と薬の小神",
		"color": Color(0.62, 1.0, 0.55), "color2": Color(0.30, 0.75, 0.40), "emblem": "gourd",
		"role": "設置・範囲の持続ダメージ・回復",
		"weapon": "酒霧の瓢", "weapon_desc": "敵の群れへ瓢箪を投げ、割れて酒気の霧になる。霧の中の敵は酩酊し続ける",
		"cast": "大霧", "cast_desc": "前方に大きな酒気の霧を残し、自身も少し回復する",
		"call": "神酒の雨", "call_desc": "画面中の敵を最大まで酩酊させ、自らの HP を回復する", "call_line": "神酒よ、雨と降れ。",
		"status": "酩酊", "status_desc": "酩酊は重なるごとに毎秒のダメージが増え、動きも鈍る（緑の泡）",
		"cost": "抜けぬ酔いに手が鈍り、神招きが遠のく（神招きゲージの溜まり -15%）", "flavor": "酒が一滴も飲めなくなる。甘酒でも酔う", "mark": "契約の刻印：ほろ酔いの頬",
		"intro": "やあやあ、一杯どうだい？　敵にはもっと飲ませてやろう。",
		"lines": ["薬も酒も、量が肝心。敵には過ぎるほど。", "霧の中に踏み込んだら、もう酔うしかない。", "傷はわしが癒す。前だけを見ておれ。"],
	},
	{
		"id": "iza", "name": "伊邪那美命", "kana": "イザナミ", "title": "黄泉の大神",
		"color": Color(0.58, 0.82, 1.0), "color2": Color(0.30, 0.35, 0.75), "emblem": "gate",
		"role": "拡散・減速・凍結",
		"weapon": "氷柱", "weapon_desc": "3 方向へ氷柱を撒く。当たった敵は動きも弾も鈍り、冷気が重なると砕ける",
		"cast": "黄泉の凍土", "cast_desc": "前方に広い凍土を置き、そこにいた敵を凍らせて削る",
		"call": "黄泉返し", "call_desc": "画面中の敵を凍結させる", "call_line": "黄泉より返れ。凍てつけ。",
		"status": "冷気", "status_desc": "冷気は重なるほど敵の動きと弾の間隔を鈍らせ、5 段階で砕ける（青白い結晶）",
		"cost": "黄泉の冷えが骨に棲み、受ける傷はすべて深くなる（受けるダメージ +8%）", "flavor": "冷たいものが食べられなくなる。かき氷は永遠の思い出", "mark": "契約の刻印：温まらない指先",
		"intro": "生ける者よ。黄泉の冷たさを、汝の敵に分けてやろう。",
		"lines": ["止まれ。黄泉では何ものも動かぬ。", "凍てついた魂は、触れれば砕ける。", "死は静かに広がる。ひとりから、皆へ。"],
	},
	{
		"id": "saru", "name": "猿田彦大神", "kana": "サルタヒコ", "title": "道開きの神",
		"color": Color(0.72, 1.0, 0.98), "color2": Color(0.35, 0.70, 0.75), "emblem": "road",
		"role": "連射・機動・手数",
		"weapon": "神風の刃", "weapon_desc": "小さな風の刃を高速で連射する。迎えるだけで移動も速くなる",
		"cast": "道開き", "cast_desc": "前方の敵弾を吹き飛ばして大きな風の刃を放ち、しばらく移動と連射が速くなる",
		"call": "大導き", "call_desc": "しばらくの間、敵と敵弾の動きが遅くなる", "call_line": "道は開いた。駆けよ！",
		"status": "", "status_desc": "神威は持たないが、手数と速さで押し切る",
		"cost": "道祖の縛りに足を止められ、疾走が遠のく（疾走の間隔 +10%）", "flavor": "道を尋ねられると断れない。旅人を案内して毎回遅刻する", "mark": "契約の刻印：擦り切れた草鞋",
		"intro": "道は開ける。速く、迷わず、まっすぐに進めばよい。",
		"lines": ["速さは、それだけで力になる。", "迷わぬ者に、道は自ら開く。", "一歩の余裕が、命を救う。"],
	},
]

# ---------------------------------------------------------------------------
# 恩恵（神器の強化）
#   base  : 数値の基準。desc の {v} に value() の結果が入る
#   fmt   : "pct" / "num" / "sec" / "sec_down"(小さいほど良い) / "x"
#   maxlv : 重ねて取れる回数
#   rar   : 伝説・双神は固定
# ---------------------------------------------------------------------------
## 説明文の「威力 N%」は、自機の基礎攻撃 × その神の神格倍率 に対する割合（位や神格で伸びる）
const BOONS := [
	# ===== 天照大神：日輪光線 =====
	{"id": "ama_u1", "kami": "ama", "tier": Cfg.Rar.COMMON, "name": "日輪の広がり", "desc": "光線の幅 +{v}", "base": 40.0, "fmt": "pct", "maxlv": 3},
	{"id": "ama_u2", "kami": "ama", "tier": Cfg.Rar.COMMON, "name": "灼熱の光", "desc": "光線のダメージ +{v}", "base": 30.0, "fmt": "pct", "maxlv": 4},
	{"id": "ama_u6", "kami": "ama", "tier": Cfg.Rar.COMMON, "name": "灼き付く光", "desc": "光線に触れている敵は動きが {v} 遅くなる", "base": 25.0, "fmt": "pct", "maxlv": 3},
	{"id": "ama_u8", "kami": "ama", "tier": Cfg.Rar.COMMON, "name": "日輪の恵み", "desc": "照覧された敵を倒すと {v} の確率で HP 1 回復", "base": 35.0, "fmt": "pct", "maxlv": 3},
	{"id": "ama_u4", "kami": "ama", "tier": Cfg.Rar.RARE, "name": "照覧の眼", "desc": "照覧された敵への全ダメージ +{v}", "base": 25.0, "fmt": "pct", "maxlv": 3},
	{"id": "ama_u7", "kami": "ama", "tier": Cfg.Rar.RARE, "name": "陽炎", "desc": "{v} ごとに光線が閃き、その瞬間に光線に触れている敵弾を蒸発させる", "base": 4.0, "fmt": "sec_down", "maxlv": 3},
	{"id": "ama_u9", "kami": "ama", "tier": Cfg.Rar.RARE, "name": "暁の熱", "desc": "同じ敵に当て続けると光線の威力が上がる（2 秒で最大 +{v}）", "base": 40.0, "fmt": "pct", "maxlv": 3},
	{"id": "ama_u3", "kami": "ama", "tier": Cfg.Rar.EPIC, "name": "三光", "desc": "斜めに伸びる光線 +{v} 本", "base": 1.0, "fmt": "num", "maxlv": 2},
	{"id": "ama_u5", "kami": "ama", "tier": Cfg.Rar.EPIC, "name": "鏡の護り", "desc": "被弾を一度防ぐ光の鏡を纏う。{v} ごとに再生成", "base": 14.0, "fmt": "sec_down", "maxlv": 3},
	{"id": "ama_leg", "kami": "ama", "name": "日食", "rar": Cfg.Rar.LEGENDARY,
		"desc": "{v} ごとに画面全体が光で満たされ、全敵に光線 1 秒分のダメージと照覧", "base": 8.0, "fmt": "sec_down", "maxlv": 2},

	# ===== 須佐之男命：荒波 =====
	{"id": "susa_u1", "kami": "susa", "tier": Cfg.Rar.COMMON, "name": "怒涛", "desc": "大波のダメージ +{v}", "base": 35.0, "fmt": "pct", "maxlv": 4},
	{"id": "susa_u2", "kami": "susa", "tier": Cfg.Rar.COMMON, "name": "大津波", "desc": "大波の大きさ +{v}", "base": 30.0, "fmt": "pct", "maxlv": 3},
	{"id": "susa_u3", "kami": "susa", "tier": Cfg.Rar.COMMON, "name": "遠鳴り", "desc": "大波の届く距離 +{v}", "base": 40.0, "fmt": "pct", "maxlv": 3},
	{"id": "susa_u6", "kami": "susa", "tier": Cfg.Rar.COMMON, "name": "早潮", "desc": "大波の間隔 -{v}", "base": 15.0, "fmt": "pct", "maxlv": 3},
	{"id": "susa_u4", "kami": "susa", "tier": Cfg.Rar.RARE, "name": "裂傷の波", "desc": "押し戻された敵は裂傷を負い、動くたび {v} のダメージ", "base": 4.0, "fmt": "num", "maxlv": 3},
	{"id": "susa_u8", "kami": "susa", "tier": Cfg.Rar.RARE, "name": "重い波", "desc": "押し戻した敵に威力 {v} の追加ダメージ", "base": 150.0, "fmt": "pct", "maxlv": 3},
	{"id": "susa_u5", "kami": "susa", "tier": Cfg.Rar.RARE, "name": "怯み波", "desc": "押し戻された敵は {v} のあいだ動けず撃てない", "base": 0.8, "fmt": "sec", "maxlv": 3},
	{"id": "susa_u7", "kami": "susa", "tier": Cfg.Rar.EPIC, "name": "潮騒", "desc": "大波が触れた敵弾を {v} の確率で消す", "base": 40.0, "fmt": "pct", "maxlv": 3},
	{"id": "susa_u9", "kami": "susa", "tier": Cfg.Rar.EPIC, "name": "怒りの海", "desc": "画面の敵 1 体ごとに大波のダメージ +{v}（10 体まで）", "base": 6.0, "fmt": "pct", "maxlv": 3},
	{"id": "susa_leg", "kami": "susa", "name": "八岐大蛇殺し", "rar": Cfg.Rar.LEGENDARY,
		"desc": "大波が 2 連になり、触れた敵弾を 70% の確率で消す。押し戻した敵に威力 {v} の追加ダメージ", "base": 400.0, "fmt": "pct", "maxlv": 2},

	# ===== 建御雷神：神鳴り =====
	{"id": "take_u1", "kami": "take", "tier": Cfg.Rar.COMMON, "name": "雷帯", "desc": "雷のダメージ +{v}", "base": 30.0, "fmt": "pct", "maxlv": 4},
	{"id": "take_u2", "kami": "take", "tier": Cfg.Rar.COMMON, "name": "早鳴り", "desc": "雷の間隔 -{v}", "base": 18.0, "fmt": "pct", "maxlv": 3},
	{"id": "take_u6", "kami": "take", "tier": Cfg.Rar.COMMON, "name": "天罰", "desc": "大妖（ボス）への雷のダメージ +{v}", "base": 30.0, "fmt": "pct", "maxlv": 3},
	{"id": "take_u8", "kami": "take", "tier": Cfg.Rar.COMMON, "name": "雷の加護", "desc": "雷が命中するたび神招きゲージ +{v}", "base": 1.0, "fmt": "pct", "maxlv": 3},
	{"id": "take_u3", "kami": "take", "tier": Cfg.Rar.RARE, "name": "双雷", "desc": "雷の連鎖 +{v}", "base": 1.0, "fmt": "num", "maxlv": 3},
	{"id": "take_u4", "kami": "take", "tier": Cfg.Rar.RARE, "name": "帯電の呪", "desc": "雷を受けた敵は帯電し、攻撃するたび威力 {v} の雷を受ける", "base": 200.0, "fmt": "pct", "maxlv": 3},
	{"id": "take_u9", "kami": "take", "tier": Cfg.Rar.RARE, "name": "遠雷", "desc": "雷が {v} の確率でもう 1 体にも同時に落ちる", "base": 30.0, "fmt": "pct", "maxlv": 3},
	{"id": "take_u5", "kami": "take", "tier": Cfg.Rar.EPIC, "name": "落雷の広がり", "desc": "雷が落ちた周囲 {v} の敵にも半分のダメージ", "base": 70.0, "fmt": "num", "maxlv": 3},
	{"id": "take_u7", "kami": "take", "tier": Cfg.Rar.EPIC, "name": "雷雲", "desc": "雷が落ちた所に {v} のあいだ雷雲が残り、近くの敵に小さな落雷を続ける", "base": 1.0, "fmt": "sec", "maxlv": 3},
	{"id": "take_leg", "kami": "take", "name": "神鳴りの矛", "rar": Cfg.Rar.LEGENDARY,
		"desc": "雷が命中するたび {v} の確率で別の敵にも雷が落ちる", "base": 35.0, "fmt": "pct", "maxlv": 2},

	# ===== 月読命：月輪 =====
	{"id": "tsuki_u5", "kami": "tsuki", "tier": Cfg.Rar.COMMON, "name": "月光の刃", "desc": "刃のダメージ +{v}", "base": 35.0, "fmt": "pct", "maxlv": 4},
	{"id": "tsuki_u4", "kami": "tsuki", "tier": Cfg.Rar.COMMON, "name": "遠い月", "desc": "刃の軌道半径 +{v}", "base": 25.0, "fmt": "pct", "maxlv": 3},
	{"id": "tsuki_u2", "kami": "tsuki", "tier": Cfg.Rar.COMMON, "name": "月の満ち欠け", "desc": "宿命の爆発ダメージ +{v}", "base": 40.0, "fmt": "pct", "maxlv": 4},
	{"id": "tsuki_u6", "kami": "tsuki", "tier": Cfg.Rar.COMMON, "name": "速い月", "desc": "刃の回る速さ +{v}（当たる間隔も短くなる）", "base": 30.0, "fmt": "pct", "maxlv": 3},
	{"id": "tsuki_u3", "kami": "tsuki", "tier": Cfg.Rar.RARE, "name": "宵闇の加護", "desc": "宿命の爆発範囲 +{v}", "base": 40.0, "fmt": "pct", "maxlv": 3},
	{"id": "tsuki_u9", "kami": "tsuki", "tier": Cfg.Rar.RARE, "name": "月華", "desc": "宿命の爆発が {v} の確率で会心になる", "base": 25.0, "fmt": "pct", "maxlv": 3},
	{"id": "tsuki_u7", "kami": "tsuki", "tier": Cfg.Rar.RARE, "name": "新月の影", "desc": "宿命が爆ぜて敵が倒れると、{v} の確率で近くの敵に宿命が移る", "base": 40.0, "fmt": "pct", "maxlv": 3},
	{"id": "tsuki_u1", "kami": "tsuki", "tier": Cfg.Rar.EPIC, "name": "月輪の刃", "desc": "回る刃 +{v}", "base": 1.0, "fmt": "num", "maxlv": 3},
	{"id": "tsuki_u8", "kami": "tsuki", "tier": Cfg.Rar.EPIC, "name": "月の盾", "desc": "刃が触れた敵弾を {v} の確率で消す", "base": 50.0, "fmt": "pct", "maxlv": 3},
	{"id": "tsuki_leg", "kami": "tsuki", "name": "月読の裁定", "rar": Cfg.Rar.LEGENDARY,
		"desc": "宿命が爆ぜるとき、残り HP {v} 以下の敵（ボス以外）は即座に倒れる", "base": 25.0, "fmt": "pct", "maxlv": 2},

	# ===== 天宇受売命：舞扇 =====
	{"id": "uzume_u2", "kami": "uzume", "tier": Cfg.Rar.COMMON, "name": "大扇", "desc": "扇の大きさとダメージ +{v}", "base": 35.0, "fmt": "pct", "maxlv": 3},
	{"id": "uzume_u6", "kami": "uzume", "tier": Cfg.Rar.COMMON, "name": "遠投", "desc": "扇の飛距離 +{v}", "base": 30.0, "fmt": "pct", "maxlv": 3},
	{"id": "uzume_u7", "kami": "uzume", "tier": Cfg.Rar.COMMON, "name": "早舞", "desc": "扇を投げる間隔 -{v}", "base": 15.0, "fmt": "pct", "maxlv": 3},
	{"id": "uzume_u5", "kami": "uzume", "tier": Cfg.Rar.COMMON, "name": "宴の恵み", "desc": "最大 HP +{v}", "base": 25.0, "fmt": "num", "maxlv": 4},
	{"id": "uzume_u3", "kami": "uzume", "tier": Cfg.Rar.RARE, "name": "艶やかな加護", "desc": "弱体した敵への与ダメージ +{v}", "base": 20.0, "fmt": "pct", "maxlv": 3},
	{"id": "uzume_u4", "kami": "uzume", "tier": Cfg.Rar.RARE, "name": "誘いの舞", "desc": "扇が触れた敵を {v} の確率で 3 秒魅了する", "base": 12.0, "fmt": "pct", "maxlv": 3},
	{"id": "uzume_u8", "kami": "uzume", "tier": Cfg.Rar.RARE, "name": "帰り扇", "desc": "戻ってくる扇のダメージ +{v}", "base": 50.0, "fmt": "pct", "maxlv": 3},
	{"id": "uzume_u1", "kami": "uzume", "tier": Cfg.Rar.EPIC, "name": "二枚扇", "desc": "投げる扇 +{v}", "base": 1.0, "fmt": "num", "maxlv": 2},
	{"id": "uzume_u9", "kami": "uzume", "tier": Cfg.Rar.EPIC, "name": "舞い手の護り", "desc": "扇が手元に戻ると HP {v} 回復（3 秒に 1 度まで）", "base": 1.0, "fmt": "num", "maxlv": 3},
	{"id": "uzume_leg", "kami": "uzume", "name": "八百万の宴", "rar": Cfg.Rar.LEGENDARY,
		"desc": "弱体した敵を倒すと {v} の確率で HP が 6 回復する", "base": 35.0, "fmt": "pct", "maxlv": 2},

	# ===== 宇迦之御魂神（稲荷）：狐火 =====
	{"id": "inari_u2", "kami": "inari", "tier": Cfg.Rar.COMMON, "name": "燃え盛る狐火", "desc": "狐火のダメージ +{v}", "base": 35.0, "fmt": "pct", "maxlv": 4},
	{"id": "inari_u3", "kami": "inari", "tier": Cfg.Rar.COMMON, "name": "狐の眼", "desc": "会心率 +{v}", "base": 12.0, "fmt": "pct", "maxlv": 4},
	{"id": "inari_u6", "kami": "inari", "tier": Cfg.Rar.COMMON, "name": "早い狐", "desc": "狐火の間隔 -{v}", "base": 15.0, "fmt": "pct", "maxlv": 3},
	{"id": "inari_u9", "kami": "inari", "tier": Cfg.Rar.COMMON, "name": "九尾の追い火", "desc": "狐火の速さと誘導 +{v}", "base": 25.0, "fmt": "pct", "maxlv": 3},
	{"id": "inari_u5", "kami": "inari", "tier": Cfg.Rar.RARE, "name": "稲穂の実り", "desc": "会心ダメージ +{v}", "base": 40.0, "fmt": "pct", "maxlv": 3},
	{"id": "inari_u7", "kami": "inari", "tier": Cfg.Rar.RARE, "name": "狐火の連鎖", "desc": "狐火が敵を倒すと {v} の確率で次の敵へ跳ぶ", "base": 40.0, "fmt": "pct", "maxlv": 3},
	{"id": "inari_u8", "kami": "inari", "tier": Cfg.Rar.RARE, "name": "油揚げの供物", "desc": "敵を倒すと {v} の確率で勾玉が余分に落ちる", "base": 30.0, "fmt": "pct", "maxlv": 3},
	{"id": "inari_u1", "kami": "inari", "tier": Cfg.Rar.EPIC, "name": "狐火の群れ", "desc": "一度に放つ狐火 +{v} 本", "base": 1.0, "fmt": "num", "maxlv": 2},
	{"id": "inari_u4", "kami": "inari", "tier": Cfg.Rar.EPIC, "name": "眷属の狐", "desc": "自機の周りを回り狐火を放つ眷属 +{v}", "base": 1.0, "fmt": "num", "maxlv": 2},
	{"id": "inari_leg", "kami": "inari", "name": "白狐の加護", "rar": Cfg.Rar.LEGENDARY,
		"desc": "会心が出るたび、近くの敵へ威力 {v} の狐火が飛ぶ", "base": 250.0, "fmt": "pct", "maxlv": 2},

	# ===== 少名毘古那神：酒霧の瓢 =====
	{"id": "suku_u1", "kami": "suku", "tier": Cfg.Rar.COMMON, "name": "大瓢箪", "desc": "霧の大きさ +{v}", "base": 30.0, "fmt": "pct", "maxlv": 3},
	{"id": "suku_u2", "kami": "suku", "tier": Cfg.Rar.COMMON, "name": "深い霧", "desc": "霧の持続時間 +{v}", "base": 35.0, "fmt": "pct", "maxlv": 3},
	{"id": "suku_u6", "kami": "suku", "tier": Cfg.Rar.COMMON, "name": "早い瓢", "desc": "瓢箪を投げる間隔 -{v}", "base": 15.0, "fmt": "pct", "maxlv": 3},
	{"id": "suku_u8", "kami": "suku", "tier": Cfg.Rar.COMMON, "name": "酔いどれ狩り", "desc": "酩酊した敵への与ダメージ +{v}", "base": 15.0, "fmt": "pct", "maxlv": 3},
	{"id": "suku_u3", "kami": "suku", "tier": Cfg.Rar.RARE, "name": "強い酒", "desc": "酩酊のダメージ +{v}", "base": 35.0, "fmt": "pct", "maxlv": 4},
	{"id": "suku_u5", "kami": "suku", "tier": Cfg.Rar.RARE, "name": "薬師の加護", "desc": "毎秒 HP が {v} 回復する", "base": 1.0, "fmt": "x", "maxlv": 4},
	{"id": "suku_u9", "kami": "suku", "tier": Cfg.Rar.RARE, "name": "百薬の長", "desc": "酩酊した敵を倒すと {v} の確率で酒気の霧が残る", "base": 35.0, "fmt": "pct", "maxlv": 3},
	{"id": "suku_u4", "kami": "suku", "tier": Cfg.Rar.EPIC, "name": "深酔い", "desc": "酩酊の最大段階 +{v}", "base": 2.0, "fmt": "num", "maxlv": 2},
	{"id": "suku_u7", "kami": "suku", "tier": Cfg.Rar.EPIC, "name": "薬酒", "desc": "自機が霧の中にいると毎秒 HP {v} 回復し、被ダメージ -20%", "base": 1.0, "fmt": "num", "maxlv": 3},
	{"id": "suku_leg", "kami": "suku", "name": "常世の妙薬", "rar": Cfg.Rar.LEGENDARY,
		"desc": "HP が 3 割を切ると HP の {v} を即座に回復する（60 秒に 1 度）", "base": 50.0, "fmt": "pct", "maxlv": 2},

	# ===== 伊邪那美命：氷柱 =====
	{"id": "iza_u2", "kami": "iza", "tier": Cfg.Rar.COMMON, "name": "鋭い氷柱", "desc": "氷柱のダメージ +{v}", "base": 30.0, "fmt": "pct", "maxlv": 4},
	{"id": "iza_u6", "kami": "iza", "tier": Cfg.Rar.COMMON, "name": "早い氷", "desc": "氷柱の間隔 -{v}", "base": 15.0, "fmt": "pct", "maxlv": 3},
	{"id": "iza_u7", "kami": "iza", "tier": Cfg.Rar.COMMON, "name": "黄泉の冷気", "desc": "氷柱が与える冷気 +{v} 段階（砕けるのが早くなる）", "base": 1.0, "fmt": "num", "maxlv": 1},
	{"id": "iza_u5", "kami": "iza", "tier": Cfg.Rar.COMMON, "name": "凍土の加護", "desc": "冷気を受けた敵への与ダメージ +{v}", "base": 15.0, "fmt": "pct", "maxlv": 3},
	{"id": "iza_u3", "kami": "iza", "tier": Cfg.Rar.RARE, "name": "氷砕", "desc": "冷気が 5 段階に達して砕けたとき威力 {v} のダメージ", "base": 300.0, "fmt": "pct", "maxlv": 3},
	{"id": "iza_u4", "kami": "iza", "tier": Cfg.Rar.RARE, "name": "凍土", "desc": "砕けた所に {v} のあいだ凍土が残り、中の敵を遅くする", "base": 2.0, "fmt": "sec", "maxlv": 3},
	{"id": "iza_u8", "kami": "iza", "tier": Cfg.Rar.RARE, "name": "氷の棘", "desc": "氷柱が敵を {v} 体貫く", "base": 1.0, "fmt": "num", "maxlv": 2},
	{"id": "iza_u1", "kami": "iza", "tier": Cfg.Rar.EPIC, "name": "氷柱の広がり", "desc": "撒く氷柱 +{v} 方向", "base": 2.0, "fmt": "num", "maxlv": 2},
	{"id": "iza_u9", "kami": "iza", "tier": Cfg.Rar.EPIC, "name": "黄泉の門", "desc": "砕けた敵から氷柱が {v} 本飛び散る", "base": 4.0, "fmt": "num", "maxlv": 2},
	{"id": "iza_leg", "kami": "iza", "name": "黄泉比良坂", "rar": Cfg.Rar.LEGENDARY,
		"desc": "砕けた敵は爆ぜて周囲の敵を凍結させ、威力 {v} のダメージを与える", "base": 600.0, "fmt": "pct", "maxlv": 2},

	# ===== 猿田彦大神：神風の刃 =====
	{"id": "saru_u1", "kami": "saru", "tier": Cfg.Rar.COMMON, "name": "先駈け", "desc": "刃の連射 +{v}", "base": 20.0, "fmt": "pct", "maxlv": 4},
	{"id": "saru_u2", "kami": "saru", "tier": Cfg.Rar.COMMON, "name": "鋭い風", "desc": "刃のダメージ +{v}", "base": 30.0, "fmt": "pct", "maxlv": 4},
	{"id": "saru_u3", "kami": "saru", "tier": Cfg.Rar.COMMON, "name": "道開きの加護", "desc": "移動速度 +{v}", "base": 12.0, "fmt": "pct", "maxlv": 3},
	{"id": "saru_u6", "kami": "saru", "tier": Cfg.Rar.COMMON, "name": "風の道", "desc": "刃が敵を {v} 体貫く", "base": 1.0, "fmt": "num", "maxlv": 2},
	{"id": "saru_u4", "kami": "saru", "tier": Cfg.Rar.RARE, "name": "疾風の御業", "desc": "疾走の間隔 -{v}", "base": 20.0, "fmt": "pct", "maxlv": 3},
	{"id": "saru_u7", "kami": "saru", "tier": Cfg.Rar.RARE, "name": "追い風", "desc": "疾走してから 3 秒は刃のダメージ +{v}", "base": 40.0, "fmt": "pct", "maxlv": 3},
	{"id": "saru_u9", "kami": "saru", "tier": Cfg.Rar.RARE, "name": "小さな身", "desc": "自機の当たり判定 -{v}", "base": 20.0, "fmt": "pct", "maxlv": 3},
	{"id": "saru_u5", "kami": "saru", "tier": Cfg.Rar.EPIC, "name": "神風二列", "desc": "刃の同時発射 +{v} 列", "base": 1.0, "fmt": "num", "maxlv": 1},
	{"id": "saru_u8", "kami": "saru", "tier": Cfg.Rar.EPIC, "name": "疾風の刃", "desc": "疾走すると周囲へ風の刃を {v} 本放つ", "base": 6.0, "fmt": "num", "maxlv": 2},
	{"id": "saru_leg", "kami": "saru", "name": "大導き", "rar": Cfg.Rar.LEGENDARY,
		"desc": "疾走の間隔 -{v}。疾走で触れた敵は怯み、威力 250% のダメージを受ける", "base": 35.0, "fmt": "pct", "maxlv": 2},

	# ===== 双神（2 柱をともに迎え、それぞれの恩恵を 1 つ以上持つと出る） =====
	{"id": "duo_ama_take", "kami": "ama", "kami2": "take", "name": "天鳴", "rar": Cfg.Rar.DUO,
		"desc": "照覧された敵に落ちる雷のダメージ +{v}", "base": 60.0, "fmt": "pct", "maxlv": 2},
	{"id": "duo_susa_iza", "kami": "susa", "kami2": "iza", "name": "凍海", "rar": Cfg.Rar.DUO,
		"desc": "大波が冷気を 2 段階与える。冷気の敵への大波のダメージ +{v}", "base": 60.0, "fmt": "pct", "maxlv": 2},
	{"id": "duo_tsuki_inari", "kami": "tsuki", "kami2": "inari", "name": "月狐", "rar": Cfg.Rar.DUO,
		"desc": "宿命の爆発が必ず会心になる。会心ダメージ +{v}", "base": 30.0, "fmt": "pct", "maxlv": 2},
	{"id": "duo_uzume_suku", "kami": "uzume", "kami2": "suku", "name": "宴と舞", "rar": Cfg.Rar.DUO,
		"desc": "酩酊した敵は弱体も受ける。弱体の敵の与ダメージがさらに -{v}", "base": 20.0, "fmt": "pct", "maxlv": 2},
	{"id": "duo_take_suku", "kami": "take", "kami2": "suku", "name": "雷酔", "rar": Cfg.Rar.DUO,
		"desc": "酩酊した敵に雷が落ちると、酩酊の段階ごとに威力 {v} の追加ダメージ", "base": 100.0, "fmt": "pct", "maxlv": 2},
	{"id": "duo_iza_tsuki", "kami": "iza", "kami2": "tsuki", "name": "黄泉の月", "rar": Cfg.Rar.DUO,
		"desc": "宿命が爆ぜた敵は {v} 凍結する", "base": 1.5, "fmt": "sec", "maxlv": 2},
	{"id": "duo_ama_uzume", "kami": "ama", "kami2": "uzume", "name": "艶光", "rar": Cfg.Rar.DUO,
		"desc": "弱体した敵は照覧も受ける。弱体の敵からの被ダメージ -{v}", "base": 20.0, "fmt": "pct", "maxlv": 2},
	{"id": "duo_susa_take", "kami": "susa", "kami2": "take", "name": "嵐雷", "rar": Cfg.Rar.DUO,
		"desc": "大波に押し戻された敵に威力 {v} の雷が落ちる", "base": 250.0, "fmt": "pct", "maxlv": 2},
	{"id": "duo_inari_saru", "kami": "inari", "kami2": "saru", "name": "風狐", "rar": Cfg.Rar.DUO,
		"desc": "風の刃が命中するたび {v} の確率で狐火が追加で飛ぶ", "base": 25.0, "fmt": "pct", "maxlv": 2},
	{"id": "duo_ama_inari", "kami": "ama", "kami2": "inari", "name": "光狐", "rar": Cfg.Rar.DUO,
		"desc": "狐火が敵を 1 体貫くようになり、照覧された敵への狐火のダメージ +{v}", "base": 40.0, "fmt": "pct", "maxlv": 2},
	{"id": "duo_ama_suku", "kami": "ama", "kami2": "suku", "name": "光霧", "rar": Cfg.Rar.DUO,
		"desc": "酒気の霧の中の敵は照覧も受ける。霧の大きさ +{v}", "base": 20.0, "fmt": "pct", "maxlv": 2},
	{"id": "duo_take_iza", "kami": "take", "kami2": "iza", "name": "雷氷", "rar": Cfg.Rar.DUO,
		"desc": "雷が落ちた敵に冷気を 2 段階与える。凍結した敵への雷のダメージ +{v}", "base": 50.0, "fmt": "pct", "maxlv": 2},
	{"id": "duo_take_uzume", "kami": "take", "kami2": "uzume", "name": "雷舞", "rar": Cfg.Rar.DUO,
		"desc": "扇が敵に触れるたび {v} の確率で雷が落ちる", "base": 25.0, "fmt": "pct", "maxlv": 2},
	{"id": "duo_susa_inari", "kami": "susa", "kami2": "inari", "name": "波狐", "rar": Cfg.Rar.DUO,
		"desc": "大波が敵に触れるたび {v} の確率で狐火が飛ぶ", "base": 35.0, "fmt": "pct", "maxlv": 2},
	{"id": "duo_tsuki_suku", "kami": "tsuki", "kami2": "suku", "name": "月霧", "rar": Cfg.Rar.DUO,
		"desc": "宿命が爆ぜた所に {v} のあいだ酒気の霧が残る", "base": 2.0, "fmt": "sec", "maxlv": 2},
]

# ---------------------------------------------------------------------------
# 禍神（まがつかみ）の取引：力と引き換えに代償を負う。稀に提示され、それぞれ一度だけ結べる
# ---------------------------------------------------------------------------
const CURSES := [
	{"id": "curse_fire", "name": "業火の契り", "gain": "すべての神器の威力 +30%", "loss": "受けるダメージ +25%",
		"desc": "禍つ火を身に宿す。神器は猛るが、身は脆くなる"},
	{"id": "curse_haste", "name": "早熟の契り", "gain": "神徳（神格の伸び）+50%", "loss": "最大 HP -20",
		"desc": "命の一部を捧げて、神々との縁を早める"},
	{"id": "curse_wind", "name": "疾風の契り", "gain": "移動速度 +20%、疾走の間隔 -30%", "loss": "最大 HP -25",
		"desc": "身を軽くするため、命の重みを削ぎ落とす"},
	{"id": "curse_edge", "name": "刃の契り", "gain": "会心率 +15%", "loss": "敵弾の速さ +15%",
		"desc": "研がれた刃は、敵の刃も研ぐ"},
]


static func curse(id: String) -> Dictionary:
	for c in CURSES:
		if c["id"] == id:
			return c
	return {}


## 神格レベルアップに必要な神徳（その段階で必要な量）
static func kami_xp_need(lv: int) -> float:
	return 480.0 * pow(float(lv), 1.6)


## 神格 1 段ごとの神器の伸び。近距離の神器は使いにくい見返りとして伸びが大きい
## （後半になるほど強くなる）。それ以外は 12%
const GROWTH := {"tsuki": 0.18, "uzume": 0.18, "susa": 0.15}


static func growth_of(kami_id: String) -> float:
	return float(GROWTH.get(kami_id, 0.12))


## 神格レベルによる神器の倍率
static func kami_power(lv: int, growth := 0.12) -> float:
	return 1.0 + growth * float(lv - 1)


# ---------------------------------------------------------------------------
# 参照ヘルパ
# ---------------------------------------------------------------------------

static func kami(id: String) -> Dictionary:
	for k in LIST:
		if k["id"] == id:
			return k
	return {}


static func boon(id: String) -> Dictionary:
	for b in BOONS:
		if b["id"] == id:
			return b
	return {}


## その神の能力（伝説・双神を除く）。各神 9 種：凡 4・稀 3・秀 2
static func upgrades_of(kami_id: String) -> Array:
	return BOONS.filter(func(b): return b["kami"] == kami_id and not b.has("kami2") and not b.has("rar"))


static func legendary_of(kami_id: String) -> Dictionary:
	for b in BOONS:
		if b["kami"] == kami_id and b.has("rar") and int(b["rar"]) == Cfg.Rar.LEGENDARY:
			return b
	return {}


## 恩恵の現在値。神の能力（tier 付き）はレア度が設計上の格を表すので倍率はかけず、
## 重ねた回数（lv）で伸びる。伝説・双神も倍率なし。
static func value(b: Dictionary, rar: int, lv: int) -> float:
	var base := float(b["base"])
	var fmt := String(b["fmt"])
	var mult: float = Cfg.RAR_MULT[rar]
	if b.has("tier") or rar == Cfg.Rar.LEGENDARY or rar == Cfg.Rar.DUO:
		mult = 1.0
	if fmt == "num" and base <= 2.0:
		# 「+1 本」のような本数系は、レアリティに関係なく重ねた回数ぶん増える
		return base * float(maxi(lv, 1))
	mult += Cfg.LV_BONUS[clampi(lv - 1, 0, Cfg.LV_BONUS.size() - 1)]
	if fmt == "sec_down":
		return maxf(base * 0.3, base / mult)
	return base * mult


static func fmt_value(b: Dictionary, v: float) -> String:
	match String(b["fmt"]):
		"pct": return ("%.1f%%" % v) if v < 10.0 else ("%d%%" % int(round(v)))
		"num": return str(int(round(v)))
		"sec", "sec_down": return "%.1f秒" % v
		_: return "%.1f" % v


## 説明文に現在値を埋め込む
static func describe(b: Dictionary, rar: int, lv: int) -> String:
	return String(b["desc"]).replace("{v}", fmt_value(b, value(b, rar, lv)))
