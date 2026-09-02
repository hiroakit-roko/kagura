class_name Kami
extends RefCounted

## 神々と恩恵のデータベース。
##
## Hades の Boon システムを日本神話に置き換えたもの：
##   - 各神は「神威（状態異常）」をひとつ持ち、攻撃 / 特技 / 詠唱 / 疾走 / 神招き の各スロットに
##     ひとつずつ恩恵を持つ（スロットは神ごとに排他。別の神の恩恵で上書き＝交換できる）。
##   - さらに常時発動の加護（PASSIVE）を複数持つ。
##   - 伝説（LEGENDARY）は主神のみ。その神の恩恵を 2 つ以上持っていると出現する。
##   - 双神（DUO）は 2 柱の特定の恩恵を揃えると出現する。
##   - 神酒（Hades の Pom of Power）で恩恵のレベルを上げると効果量が伸びる。
##
## 数値は base × レアリティ倍率 + レベル補正で決まる（value() を参照）。

# ---------------------------------------------------------------------------
# 神
# ---------------------------------------------------------------------------
const LIST := [
	{
		"id": "ama", "name": "天照大神", "kana": "アマテラス", "title": "日輪の女神",
		"color": Color(1.0, 0.84, 0.42), "color2": Color(1.0, 0.55, 0.25),
		"domain": "光と鏡", "status": "照覧",
		"status_desc": "照覧を受けた敵は受けるダメージが増える",
		"emblem": "sun",
		"intro": "闇に呑まれるな。わたしの光が、汝の行く道を照らそう。",
		"lines": [
			"八咫の鏡は、悪しきものの姿を映し返す。",
			"日輪の下に隠れられるものはない。",
			"汝の弾に、わたしの光を宿そう。",
		],
	},
	{
		"id": "susa", "name": "須佐之男命", "kana": "スサノオ", "title": "荒ぶる嵐の神",
		"color": Color(0.35, 0.82, 0.95), "color2": Color(0.20, 0.45, 0.85),
		"domain": "嵐と海", "status": "裂傷",
		"status_desc": "裂傷を受けた敵は動くほどダメージを受ける",
		"emblem": "storm",
		"intro": "小娘、退屈しておったところだ。荒波に乗せて敵を蹴散らせ！",
		"lines": [
			"押し流せ！　海はすべてを呑み込む。",
			"天叢雲の剣を、貸してやろう。",
			"嵐の前では、雑魚など木の葉にすぎん。",
		],
	},
	{
		"id": "take", "name": "建御雷神", "kana": "タケミカヅチ", "title": "雷鳴の武神",
		"color": Color(1.0, 0.95, 0.50), "color2": Color(0.70, 0.60, 1.0),
		"domain": "雷と剣", "status": "帯電",
		"status_desc": "帯電した敵は攻撃するたび雷のダメージを受ける",
		"emblem": "thunder",
		"intro": "雷は理を問わぬ。ただ、当たった者すべてを焼く。",
		"lines": [
			"一撃が次の一撃を呼ぶ。それが雷だ。",
			"布都御魂の刃は、天を裂く。",
			"逃げようとする者ほど、雷はよく落ちる。",
		],
	},
	{
		"id": "tsuki", "name": "月読命", "kana": "ツクヨミ", "title": "夜を統べる神",
		"color": Color(0.78, 0.72, 1.0), "color2": Color(0.45, 0.40, 0.85),
		"domain": "月と宿命", "status": "宿命",
		"status_desc": "宿命を刻まれた敵は、少し遅れて大きなダメージを受ける",
		"emblem": "moon",
		"intro": "……結末はすでに決まっている。ただ、いつ訪れるかだけだ。",
		"lines": [
			"月が満ちるとき、宿命は成る。",
			"急がなくてよい。刻はわたしが数える。",
			"月輪の刃は音もなく、確実に。",
		],
	},
	{
		"id": "uzume", "name": "天宇受売命", "kana": "アメノウズメ", "title": "舞と歓喜の女神",
		"color": Color(1.0, 0.58, 0.78), "color2": Color(0.85, 0.30, 0.60),
		"domain": "舞と魅惑", "status": "弱体",
		"status_desc": "弱体した敵は与えるダメージが減る",
		"emblem": "fan",
		"intro": "あら、可愛い子。さぁ踊りましょう、敵も味方も巻き込んで！",
		"lines": [
			"わたしの舞を見た者は、剣を取り落とす。",
			"魅せてあげる。敵同士が争う様を。",
			"戦いも宴も、楽しんだ者の勝ちよ。",
		],
	},
	{
		"id": "inari", "name": "宇迦之御魂神", "kana": "ウカノミタマ", "title": "狐火の稲荷神",
		"color": Color(1.0, 0.62, 0.30), "color2": Color(1.0, 0.35, 0.20),
		"domain": "狐火と豊穣", "status": "狐憑き",
		"status_desc": "狐憑きの敵への次の一撃は必ず会心になる",
		"emblem": "fox",
		"intro": "コン。狐火は嘘をつかぬ。急所を、確かに射抜くのみ。",
		"lines": [
			"眷属の狐が、汝を援護しよう。",
			"ひと矢で仕留めよ。それが狩りの礼儀。",
			"稲穂は実る。汝の一撃もまた。",
		],
	},
	{
		"id": "suku", "name": "少名毘古那神", "kana": "スクナビコナ", "title": "酒と薬の小神",
		"color": Color(0.62, 1.0, 0.55), "color2": Color(0.30, 0.75, 0.40),
		"domain": "神酒と医薬", "status": "酩酊",
		"status_desc": "酩酊は重なるほど毎秒ダメージが増える",
		"emblem": "gourd",
		"intro": "やあやあ、一杯どうだい？　敵にはもっと飲ませてやろう。",
		"lines": [
			"薬も酒も、量が肝心。敵には過ぎるほど。",
			"傷はわしが癒す。前だけを見ておれ。",
			"酔うた敵は、まっすぐ歩けぬぞ。",
		],
	},
	{
		"id": "iza", "name": "伊邪那美命", "kana": "イザナミ", "title": "黄泉の大神",
		"color": Color(0.58, 0.82, 1.0), "color2": Color(0.30, 0.35, 0.75),
		"domain": "黄泉と冷気", "status": "冷気",
		"status_desc": "冷気は重なるほど敵を遅くし、限界に達すると砕ける",
		"emblem": "gate",
		"intro": "生ける者よ。黄泉の冷たさを、汝の敵に分けてやろう。",
		"lines": [
			"止まれ。黄泉では何ものも動かぬ。",
			"凍てついた魂は、触れれば砕ける。",
			"死は静かに広がる。ひとりから、皆へ。",
		],
	},
	{
		"id": "saru", "name": "猿田彦大神", "kana": "サルタヒコ", "title": "道開きの神",
		"color": Color(0.72, 1.0, 0.98), "color2": Color(0.35, 0.70, 0.75),
		"domain": "導きと俊足", "status": "",
		"status_desc": "神威は持たないが、身のこなしを高める加護を多く授ける",
		"emblem": "road",
		"intro": "道は開ける。速く、迷わず、まっすぐに進めばよい。",
		"lines": [
			"速さは、それだけで力になる。",
			"迷わぬ者に、道は自ら開く。",
			"一歩の余裕が、命を救う。",
		],
	},
]

# ---------------------------------------------------------------------------
# 恩恵
#   slot   : Cfg.Slot
#   base   : 数値の基準。desc の {v} に value() の結果が入る
#   fmt    : "pct"(％) / "num"(整数) / "sec"(秒) / "x"(そのまま小数)
#   maxrar : 通常抽選で出る最大レアリティ（伝説・双神は固定）
#   maxlv  : 神酒で上げられる上限
#   req    : 伝説・双神の出現条件（恩恵 id の配列。双神は各神から 1 つずつ）
# ---------------------------------------------------------------------------
const BOONS := [
	# ===== 天照大神 =====
	{"id": "ama_atk", "kami": "ama", "slot": Cfg.Slot.ATTACK, "name": "日輪の矢",
		"desc": "攻撃が敵に照覧を与え、攻撃のダメージ +{v}", "base": 30.0, "fmt": "pct", "maxlv": 5},
	{"id": "ama_spc", "kami": "ama", "slot": Cfg.Slot.SPECIAL, "name": "八咫の御札",
		"desc": "御札が触れた敵弾を消し飛ばし、照覧を与える。特技のダメージ +{v}", "base": 40.0, "fmt": "pct", "maxlv": 5},
	{"id": "ama_cast", "kami": "ama", "slot": Cfg.Slot.CAST, "name": "鏡の詠唱",
		"desc": "詠唱弾が光の鏡となり、触れた敵弾を跳ね返す。詠唱のダメージ +{v}", "base": 50.0, "fmt": "pct", "maxlv": 5},
	{"id": "ama_dash", "kami": "ama", "slot": Cfg.Slot.DASH, "name": "御光の疾走",
		"desc": "疾走中に触れた敵弾を跳ね返し、疾走後 {v} のあいだ無敵が続く", "base": 0.5, "fmt": "sec", "maxlv": 4},
	{"id": "ama_call", "kami": "ama", "slot": Cfg.Slot.CALL, "name": "天岩戸開き",
		"desc": "神招き：光で画面を満たし、無敵になりながら全敵に毎秒 {v} のダメージと照覧", "base": 45.0, "fmt": "num", "maxlv": 5},
	{"id": "ama_p1", "kami": "ama", "slot": Cfg.Slot.PASSIVE, "name": "日出ずる守り",
		"desc": "受けるダメージ -{v}", "base": 10.0, "fmt": "pct", "maxlv": 4},
	{"id": "ama_p2", "kami": "ama", "slot": Cfg.Slot.PASSIVE, "name": "照覧の眼",
		"desc": "照覧を受けた敵への与ダメージ +{v}", "base": 20.0, "fmt": "pct", "maxlv": 5},
	{"id": "ama_p3", "kami": "ama", "slot": Cfg.Slot.PASSIVE, "name": "鏡の護り",
		"desc": "被弾を一度だけ防ぐ光の鏡を纏う。{v} ごとに再生成", "base": 14.0, "fmt": "sec_down", "maxlv": 4},
	{"id": "ama_leg", "kami": "ama", "slot": Cfg.Slot.PASSIVE, "name": "日食", "rar": Cfg.Rar.LEGENDARY,
		"desc": "照覧を受けた敵は倒れるとき光を放ち、周囲の敵に {v} のダメージと照覧を与える",
		"base": 60.0, "fmt": "num", "maxlv": 3, "req": ["ama_atk", "ama_spc", "ama_cast", "ama_p2"], "reqn": 2},

	# ===== 須佐之男命 =====
	{"id": "susa_atk", "kami": "susa", "slot": Cfg.Slot.ATTACK, "name": "荒波の矢",
		"desc": "攻撃が敵を押し戻し、攻撃のダメージ +{v}", "base": 30.0, "fmt": "pct", "maxlv": 5},
	{"id": "susa_spc", "kami": "susa", "slot": Cfg.Slot.SPECIAL, "name": "大波の御札",
		"desc": "御札が横に広い大波となって敵を大きく押し戻す。特技のダメージ +{v}", "base": 50.0, "fmt": "pct", "maxlv": 5},
	{"id": "susa_cast", "kami": "susa", "slot": Cfg.Slot.CAST, "name": "渦の詠唱",
		"desc": "詠唱弾が渦となって敵を巻き込み奥へ押し流し、裂傷を与える。詠唱のダメージ +{v}", "base": 40.0, "fmt": "pct", "maxlv": 5},
	{"id": "susa_dash", "kami": "susa", "slot": Cfg.Slot.DASH, "name": "嵐の疾走",
		"desc": "疾走時に周囲の敵を吹き飛ばし、{v} のダメージと裂傷を与える", "base": 25.0, "fmt": "num", "maxlv": 5},
	{"id": "susa_call", "kami": "susa", "slot": Cfg.Slot.CALL, "name": "天叢雲の一閃",
		"desc": "神招き：巨大な剣の一閃で敵弾を消し去り、前方の全敵に {v} のダメージ", "base": 140.0, "fmt": "num", "maxlv": 5},
	{"id": "susa_p1", "kami": "susa", "slot": Cfg.Slot.PASSIVE, "name": "荒れ狂う海",
		"desc": "押し戻された敵が画面端や他の敵にぶつかると {v} のダメージ", "base": 30.0, "fmt": "num", "maxlv": 5},
	{"id": "susa_p2", "kami": "susa", "slot": Cfg.Slot.PASSIVE, "name": "潮騒の加護",
		"desc": "裂傷のダメージ +{v}", "base": 50.0, "fmt": "pct", "maxlv": 5},
	{"id": "susa_p3", "kami": "susa", "slot": Cfg.Slot.PASSIVE, "name": "海神の恵み",
		"desc": "敵が落とす勾玉の量 +{v}", "base": 30.0, "fmt": "pct", "maxlv": 4},
	{"id": "susa_leg", "kami": "susa", "slot": Cfg.Slot.PASSIVE, "name": "八岐大蛇殺し", "rar": Cfg.Rar.LEGENDARY,
		"desc": "押し戻した敵に {v} の追加ダメージを与え、その敵の弾をすべて消し去る",
		"base": 70.0, "fmt": "num", "maxlv": 3, "req": ["susa_atk", "susa_spc", "susa_dash", "susa_p1"], "reqn": 2},

	# ===== 建御雷神 =====
	{"id": "take_atk", "kami": "take", "slot": Cfg.Slot.ATTACK, "name": "雷の矢",
		"desc": "攻撃が命中すると近くの敵へ雷が連鎖し {v} のダメージ", "base": 12.0, "fmt": "num", "maxlv": 5},
	{"id": "take_spc", "kami": "take", "slot": Cfg.Slot.SPECIAL, "name": "雷符",
		"desc": "御札が命中した地点に落雷し、周囲に {v} のダメージ", "base": 22.0, "fmt": "num", "maxlv": 5},
	{"id": "take_cast", "kami": "take", "slot": Cfg.Slot.CAST, "name": "雷雲の詠唱",
		"desc": "詠唱弾が留まる雷雲となり、周囲の敵へ毎秒 {v} の落雷を降らせる", "base": 30.0, "fmt": "num", "maxlv": 5},
	{"id": "take_dash", "kami": "take", "slot": Cfg.Slot.DASH, "name": "雷光の疾走",
		"desc": "疾走時に周囲の敵へ落雷し {v} のダメージと帯電を与える", "base": 18.0, "fmt": "num", "maxlv": 5},
	{"id": "take_call", "kami": "take", "slot": Cfg.Slot.CALL, "name": "布都御魂",
		"desc": "神招き：数秒間、画面中の敵に 1 発 {v} の雷が次々と降り注ぐ", "base": 28.0, "fmt": "num", "maxlv": 5},
	{"id": "take_p1", "kami": "take", "slot": Cfg.Slot.PASSIVE, "name": "雷帯の加護",
		"desc": "すべての雷のダメージ +{v}", "base": 30.0, "fmt": "pct", "maxlv": 5},
	{"id": "take_p2", "kami": "take", "slot": Cfg.Slot.PASSIVE, "name": "帯電の呪",
		"desc": "雷が命中した敵は帯電し、攻撃するたび {v} のダメージを受ける", "base": 30.0, "fmt": "num", "maxlv": 5},
	{"id": "take_p3", "kami": "take", "slot": Cfg.Slot.PASSIVE, "name": "双雷",
		"desc": "雷の連鎖回数 +{v}", "base": 1.0, "fmt": "num", "maxlv": 3},
	{"id": "take_leg", "kami": "take", "slot": Cfg.Slot.PASSIVE, "name": "神鳴りの矛", "rar": Cfg.Rar.LEGENDARY,
		"desc": "雷が敵に命中するたび {v} の確率で、別の敵にも雷が落ちる",
		"base": 25.0, "fmt": "pct", "maxlv": 3, "req": ["take_atk", "take_spc", "take_cast", "take_dash", "take_p1"], "reqn": 2},

	# ===== 月読命 =====
	{"id": "tsuki_atk", "kami": "tsuki", "slot": Cfg.Slot.ATTACK, "name": "宿命の矢",
		"desc": "攻撃が敵に宿命を刻み、少し遅れて {v} のダメージ", "base": 40.0, "fmt": "num", "maxlv": 5},
	{"id": "tsuki_spc", "kami": "tsuki", "slot": Cfg.Slot.SPECIAL, "name": "月輪の御札",
		"desc": "御札が命中した地点に回転する月輪を残し、触れた敵に {v} のダメージを与え続ける", "base": 12.0, "fmt": "num", "maxlv": 5},
	{"id": "tsuki_cast", "kami": "tsuki", "slot": Cfg.Slot.CAST, "name": "新月の詠唱",
		"desc": "詠唱弾が命中した敵に強い宿命を刻み、遅れて {v} のダメージ", "base": 120.0, "fmt": "num", "maxlv": 5},
	{"id": "tsuki_dash", "kami": "tsuki", "slot": Cfg.Slot.DASH, "name": "月影の疾走",
		"desc": "疾走の軌跡に月輪を残し、触れた敵に {v} のダメージ", "base": 20.0, "fmt": "num", "maxlv": 5},
	{"id": "tsuki_call", "kami": "tsuki", "slot": Cfg.Slot.CALL, "name": "常世の月",
		"desc": "神招き：刻が止まり、画面中の敵すべてに {v} の宿命を刻む", "base": 160.0, "fmt": "num", "maxlv": 5},
	{"id": "tsuki_p1", "kami": "tsuki", "slot": Cfg.Slot.PASSIVE, "name": "月の満ち欠け",
		"desc": "宿命のダメージ +{v}", "base": 40.0, "fmt": "pct", "maxlv": 5},
	{"id": "tsuki_p2", "kami": "tsuki", "slot": Cfg.Slot.PASSIVE, "name": "宵闇の加護",
		"desc": "宿命が成るとき、周囲 {v} の敵にも半分のダメージ", "base": 90.0, "fmt": "num", "maxlv": 4},
	{"id": "tsuki_p3", "kami": "tsuki", "slot": Cfg.Slot.PASSIVE, "name": "月光の刃",
		"desc": "月輪のダメージと持続時間 +{v}", "base": 50.0, "fmt": "pct", "maxlv": 5},
	{"id": "tsuki_leg", "kami": "tsuki", "slot": Cfg.Slot.PASSIVE, "name": "月読の裁定", "rar": Cfg.Rar.LEGENDARY,
		"desc": "宿命が成るとき、残り HP が {v} 以下の敵（ボス以外）は即座に倒れる",
		"base": 20.0, "fmt": "pct", "maxlv": 3, "req": ["tsuki_atk", "tsuki_cast", "tsuki_p1", "tsuki_p2"], "reqn": 2},

	# ===== 天宇受売命 =====
	{"id": "uzume_atk", "kami": "uzume", "slot": Cfg.Slot.ATTACK, "name": "艶舞の矢",
		"desc": "攻撃が敵を弱体させ、攻撃のダメージ +{v}", "base": 45.0, "fmt": "pct", "maxlv": 5},
	{"id": "uzume_spc", "kami": "uzume", "slot": Cfg.Slot.SPECIAL, "name": "舞扇の御札",
		"desc": "御札が敵を弱体させ、特技のダメージ +{v}", "base": 60.0, "fmt": "pct", "maxlv": 5},
	{"id": "uzume_cast", "kami": "uzume", "slot": Cfg.Slot.CAST, "name": "魅惑の詠唱",
		"desc": "詠唱弾が命中した敵を {v} 魅了する。魅了された敵は仲間を攻撃する", "base": 4.0, "fmt": "sec", "maxlv": 5},
	{"id": "uzume_dash", "kami": "uzume", "slot": Cfg.Slot.DASH, "name": "舞の疾走",
		"desc": "疾走時に近くの敵を弱体させる。弱体した敵から受けるダメージ -{v}", "base": 20.0, "fmt": "pct", "maxlv": 4},
	{"id": "uzume_call", "kami": "uzume", "slot": Cfg.Slot.CALL, "name": "天鈿女の舞",
		"desc": "神招き：舞によって画面中の敵を {v} 魅了し、互いに争わせる", "base": 4.0, "fmt": "sec", "maxlv": 5},
	{"id": "uzume_p1", "kami": "uzume", "slot": Cfg.Slot.PASSIVE, "name": "艶やかな加護",
		"desc": "弱体した敵への与ダメージ +{v}", "base": 15.0, "fmt": "pct", "maxlv": 5},
	{"id": "uzume_p2", "kami": "uzume", "slot": Cfg.Slot.PASSIVE, "name": "宴の恵み",
		"desc": "最大 HP +{v}。御札での回復量も同じだけ増える", "base": 25.0, "fmt": "num", "maxlv": 5},
	{"id": "uzume_p3", "kami": "uzume", "slot": Cfg.Slot.PASSIVE, "name": "恍惚の一撃",
		"desc": "弱体した敵への会心率 +{v}", "base": 15.0, "fmt": "pct", "maxlv": 5},
	{"id": "uzume_leg", "kami": "uzume", "slot": Cfg.Slot.PASSIVE, "name": "八百万の宴", "rar": Cfg.Rar.LEGENDARY,
		"desc": "弱体した敵を倒すと {v} の確率で HP が 6 回復する",
		"base": 30.0, "fmt": "pct", "maxlv": 3, "req": ["uzume_atk", "uzume_spc", "uzume_p1", "uzume_p3"], "reqn": 2},

	# ===== 宇迦之御魂神（稲荷） =====
	{"id": "inari_atk", "kami": "inari", "slot": Cfg.Slot.ATTACK, "name": "狐火の矢",
		"desc": "攻撃の会心率 +{v}", "base": 15.0, "fmt": "pct", "maxlv": 5},
	{"id": "inari_spc", "kami": "inari", "slot": Cfg.Slot.SPECIAL, "name": "狐面の御札",
		"desc": "御札が命中した敵に狐憑きを与え、次の一撃を必ず会心にする。特技のダメージ +{v}", "base": 30.0, "fmt": "pct", "maxlv": 5},
	{"id": "inari_cast", "kami": "inari", "slot": Cfg.Slot.CAST, "name": "稲荷の詠唱",
		"desc": "詠唱弾が敵を追う狐火となり貫通する。詠唱の会心率 +{v}", "base": 30.0, "fmt": "pct", "maxlv": 5},
	{"id": "inari_dash", "kami": "inari", "slot": Cfg.Slot.DASH, "name": "狐の疾走",
		"desc": "疾走後 1.5 秒のあいだ会心率 +{v}", "base": 30.0, "fmt": "pct", "maxlv": 5},
	{"id": "inari_call", "kami": "inari", "slot": Cfg.Slot.CALL, "name": "九尾の狐火",
		"desc": "神招き：敵を追う 9 つの狐火を放ち、それぞれ {v} のダメージ", "base": 60.0, "fmt": "num", "maxlv": 5},
	{"id": "inari_p1", "kami": "inari", "slot": Cfg.Slot.PASSIVE, "name": "狐の加勢",
		"desc": "攻撃時 {v} の確率で、敵を追う狐火が追加で放たれる", "base": 30.0, "fmt": "pct", "maxlv": 5},
	{"id": "inari_p2", "kami": "inari", "slot": Cfg.Slot.PASSIVE, "name": "稲穂の実り",
		"desc": "会心ダメージ +{v}", "base": 50.0, "fmt": "pct", "maxlv": 5},
	{"id": "inari_p3", "kami": "inari", "slot": Cfg.Slot.PASSIVE, "name": "眷属の狐",
		"desc": "自機の周りを回り自動で狐火を放つ眷属 +{v}", "base": 1.0, "fmt": "num", "maxlv": 3},
	{"id": "inari_leg", "kami": "inari", "slot": Cfg.Slot.PASSIVE, "name": "白狐の加護", "rar": Cfg.Rar.LEGENDARY,
		"desc": "会心が出るたび、近くの敵へ {v} のダメージの狐火が飛ぶ",
		"base": 35.0, "fmt": "num", "maxlv": 3, "req": ["inari_atk", "inari_spc", "inari_cast", "inari_p2"], "reqn": 2},

	# ===== 少名毘古那神 =====
	{"id": "suku_atk", "kami": "suku", "slot": Cfg.Slot.ATTACK, "name": "酔いの矢",
		"desc": "攻撃が敵を酩酊させ、重なるごとに毎秒 {v} のダメージ", "base": 4.0, "fmt": "num", "maxlv": 5},
	{"id": "suku_spc", "kami": "suku", "slot": Cfg.Slot.SPECIAL, "name": "酒盃の御札",
		"desc": "御札が敵を 2 段階酩酊させ、重なるごとに毎秒 {v} のダメージ", "base": 5.0, "fmt": "num", "maxlv": 5},
	{"id": "suku_cast", "kami": "suku", "slot": Cfg.Slot.CAST, "name": "宴の詠唱",
		"desc": "詠唱弾が酒気の霧を残し、中の敵を酩酊させ続ける。霧の持続 {v}", "base": 4.0, "fmt": "sec", "maxlv": 5},
	{"id": "suku_dash", "kami": "suku", "slot": Cfg.Slot.DASH, "name": "千鳥足",
		"desc": "疾走の後に酒気の霧を残す。疾走の無敵時間 +{v}", "base": 0.2, "fmt": "sec", "maxlv": 4},
	{"id": "suku_call", "kami": "suku", "slot": Cfg.Slot.CALL, "name": "神酒の雨",
		"desc": "神招き：画面中の敵を最大まで酩酊させ、自機の HP を {v} 回復する", "base": 30.0, "fmt": "pct", "maxlv": 5},
	{"id": "suku_p1", "kami": "suku", "slot": Cfg.Slot.PASSIVE, "name": "薬師の加護",
		"desc": "毎秒 HP が {v} 回復する", "base": 1.0, "fmt": "x", "maxlv": 5},
	{"id": "suku_p2", "kami": "suku", "slot": Cfg.Slot.PASSIVE, "name": "強い酒",
		"desc": "酩酊の最大段階 +3、酩酊のダメージ +{v}", "base": 30.0, "fmt": "pct", "maxlv": 5},
	{"id": "suku_p3", "kami": "suku", "slot": Cfg.Slot.PASSIVE, "name": "宴会芸",
		"desc": "酩酊した敵の移動速度と与ダメージ -{v}", "base": 15.0, "fmt": "pct", "maxlv": 4},
	{"id": "suku_leg", "kami": "suku", "slot": Cfg.Slot.PASSIVE, "name": "常世の妙薬", "rar": Cfg.Rar.LEGENDARY,
		"desc": "HP が 3 割を切ると HP の {v} を即座に回復する（60 秒に 1 度）",
		"base": 50.0, "fmt": "pct", "maxlv": 3, "req": ["suku_atk", "suku_spc", "suku_cast", "suku_p1", "suku_p2"], "reqn": 2},

	# ===== 伊邪那美命 =====
	{"id": "iza_atk", "kami": "iza", "slot": Cfg.Slot.ATTACK, "name": "黄泉の矢",
		"desc": "攻撃が敵に冷気を与え、攻撃のダメージ +{v}", "base": 20.0, "fmt": "pct", "maxlv": 5},
	{"id": "iza_spc", "kami": "iza", "slot": Cfg.Slot.SPECIAL, "name": "氷柱の御札",
		"desc": "御札が敵に 3 段階の冷気を与え、特技のダメージ +{v}", "base": 40.0, "fmt": "pct", "maxlv": 5},
	{"id": "iza_cast", "kami": "iza", "slot": Cfg.Slot.CAST, "name": "黄泉の詠唱",
		"desc": "詠唱弾が凍土を残し、中の敵を遅くしながら毎秒 {v} のダメージ", "base": 22.0, "fmt": "num", "maxlv": 5},
	{"id": "iza_dash", "kami": "iza", "slot": Cfg.Slot.DASH, "name": "黄泉路の疾走",
		"desc": "疾走時に周囲の敵へ冷気と {v} のダメージ", "base": 22.0, "fmt": "num", "maxlv": 5},
	{"id": "iza_call", "kami": "iza", "slot": Cfg.Slot.CALL, "name": "黄泉返し",
		"desc": "神招き：画面中の敵を {v} 凍結させる。凍結中の敵は受けるダメージ +50%", "base": 3.0, "fmt": "sec", "maxlv": 5},
	{"id": "iza_p1", "kami": "iza", "slot": Cfg.Slot.PASSIVE, "name": "氷砕の加護",
		"desc": "冷気が限界に達した敵は砕け、{v} のダメージを受ける", "base": 60.0, "fmt": "num", "maxlv": 5},
	{"id": "iza_p2", "kami": "iza", "slot": Cfg.Slot.PASSIVE, "name": "黄泉の穢れ",
		"desc": "敵が倒れるとき、周囲 {v} の敵に冷気が広がる", "base": 100.0, "fmt": "num", "maxlv": 4},
	{"id": "iza_p3", "kami": "iza", "slot": Cfg.Slot.PASSIVE, "name": "凍土の加護",
		"desc": "冷気を受けた敵への与ダメージ +{v}", "base": 15.0, "fmt": "pct", "maxlv": 5},
	{"id": "iza_leg", "kami": "iza", "slot": Cfg.Slot.PASSIVE, "name": "黄泉比良坂", "rar": Cfg.Rar.LEGENDARY,
		"desc": "砕けた敵は爆ぜて周囲の敵を凍結させ、{v} のダメージを与える",
		"base": 80.0, "fmt": "num", "maxlv": 3, "req": ["iza_atk", "iza_spc", "iza_cast", "iza_p1"], "reqn": 2},

	# ===== 猿田彦大神（加護のみ） =====
	{"id": "saru_p1", "kami": "saru", "slot": Cfg.Slot.PASSIVE, "name": "道開きの加護",
		"desc": "移動速度 +{v}", "base": 15.0, "fmt": "pct", "maxlv": 4},
	{"id": "saru_p2", "kami": "saru", "slot": Cfg.Slot.PASSIVE, "name": "先駈けの加護",
		"desc": "攻撃と特技の発射速度 +{v}", "base": 15.0, "fmt": "pct", "maxlv": 5},
	{"id": "saru_p3", "kami": "saru", "slot": Cfg.Slot.PASSIVE, "name": "疾風の御業",
		"desc": "疾走の間隔 -{v}", "base": 20.0, "fmt": "pct", "maxlv": 4},
	{"id": "saru_p4", "kami": "saru", "slot": Cfg.Slot.PASSIVE, "name": "導きの加護",
		"desc": "勾玉を引き寄せる範囲と、得られる経験値 +{v}", "base": 30.0, "fmt": "pct", "maxlv": 4},
	{"id": "saru_p5", "kami": "saru", "slot": Cfg.Slot.PASSIVE, "name": "余裕の一歩",
		"desc": "被弾後の無敵時間 +{v}", "base": 30.0, "fmt": "pct", "maxlv": 3},
	{"id": "saru_p6", "kami": "saru", "slot": Cfg.Slot.PASSIVE, "name": "神足",
		"desc": "詠唱の再充填 -{v}。詠唱の弾数 +1", "base": 25.0, "fmt": "pct", "maxlv": 4},
	{"id": "saru_leg", "kami": "saru", "slot": Cfg.Slot.PASSIVE, "name": "大導き", "rar": Cfg.Rar.LEGENDARY,
		"desc": "敵弾のすれすれを抜ける（かすり）たび、神招きのゲージが {v} 溜まる",
		"base": 4.0, "fmt": "pct", "maxlv": 3, "req": ["saru_p1", "saru_p2", "saru_p3", "saru_p4", "saru_p5", "saru_p6"], "reqn": 2},

	# ===== 双神（2 柱の恩恵を揃えると出現） =====
	{"id": "duo_ama_take", "kami": "ama", "kami2": "take", "slot": Cfg.Slot.PASSIVE, "name": "天鳴", "rar": Cfg.Rar.DUO,
		"desc": "照覧を受けた敵に雷が命中すると、雷のダメージ +{v}", "base": 60.0, "fmt": "pct", "maxlv": 2,
		"req": ["ama_atk", "ama_spc", "ama_cast"], "req2": ["take_atk", "take_spc", "take_cast", "take_dash"]},
	{"id": "duo_ama_tsuki", "kami": "ama", "kami2": "tsuki", "slot": Cfg.Slot.PASSIVE, "name": "日月の裁", "rar": Cfg.Rar.DUO,
		"desc": "宿命が成った敵は照覧を受ける。照覧を受けた敵への宿命ダメージ +{v}", "base": 50.0, "fmt": "pct", "maxlv": 2,
		"req": ["ama_atk", "ama_spc", "ama_p2"], "req2": ["tsuki_atk", "tsuki_cast", "tsuki_call"]},
	{"id": "duo_susa_take", "kami": "susa", "kami2": "take", "slot": Cfg.Slot.PASSIVE, "name": "嵐雷", "rar": Cfg.Rar.DUO,
		"desc": "押し戻された敵に {v} の雷が落ちる", "base": 30.0, "fmt": "num", "maxlv": 2,
		"req": ["susa_atk", "susa_spc", "susa_dash"], "req2": ["take_atk", "take_spc", "take_p1"]},
	{"id": "duo_susa_iza", "kami": "susa", "kami2": "iza", "slot": Cfg.Slot.PASSIVE, "name": "凍海", "rar": Cfg.Rar.DUO,
		"desc": "押し戻しが冷気を与える。冷気を受けた敵への押し戻しダメージ +{v}", "base": 100.0, "fmt": "pct", "maxlv": 2,
		"req": ["susa_atk", "susa_spc", "susa_p1"], "req2": ["iza_atk", "iza_spc", "iza_p1"]},
	{"id": "duo_tsuki_inari", "kami": "tsuki", "kami2": "inari", "slot": Cfg.Slot.PASSIVE, "name": "月狐", "rar": Cfg.Rar.DUO,
		"desc": "宿命のダメージが必ず会心になる。宿命の会心ダメージ +{v}", "base": 30.0, "fmt": "pct", "maxlv": 2,
		"req": ["tsuki_atk", "tsuki_cast", "tsuki_p1"], "req2": ["inari_atk", "inari_spc", "inari_p2"]},
	{"id": "duo_uzume_suku", "kami": "uzume", "kami2": "suku", "slot": Cfg.Slot.PASSIVE, "name": "宴と舞", "rar": Cfg.Rar.DUO,
		"desc": "酩酊した敵は弱体も受ける。弱体した敵の与ダメージがさらに -{v}", "base": 20.0, "fmt": "pct", "maxlv": 2,
		"req": ["uzume_atk", "uzume_spc", "uzume_p1"], "req2": ["suku_atk", "suku_spc", "suku_cast"]},
	{"id": "duo_take_suku", "kami": "take", "kami2": "suku", "slot": Cfg.Slot.PASSIVE, "name": "雷酔", "rar": Cfg.Rar.DUO,
		"desc": "酩酊した敵に雷が命中すると、酩酊の段階ごとに {v} の追加ダメージ", "base": 10.0, "fmt": "num", "maxlv": 2,
		"req": ["take_atk", "take_spc", "take_cast"], "req2": ["suku_atk", "suku_spc", "suku_cast"]},
	{"id": "duo_iza_tsuki", "kami": "iza", "kami2": "tsuki", "slot": Cfg.Slot.PASSIVE, "name": "黄泉の月", "rar": Cfg.Rar.DUO,
		"desc": "宿命が成った敵は {v} 凍結する", "base": 1.5, "fmt": "sec", "maxlv": 2,
		"req": ["iza_atk", "iza_spc", "iza_p1"], "req2": ["tsuki_atk", "tsuki_cast", "tsuki_call"]},
	{"id": "duo_inari_take", "kami": "inari", "kami2": "take", "slot": Cfg.Slot.PASSIVE, "name": "狐雷", "rar": Cfg.Rar.DUO,
		"desc": "会心が出るたび、その敵に {v} の雷が落ちる", "base": 25.0, "fmt": "num", "maxlv": 2,
		"req": ["inari_atk", "inari_spc", "inari_p2"], "req2": ["take_atk", "take_spc", "take_p1"]},
	{"id": "duo_uzume_ama", "kami": "uzume", "kami2": "ama", "slot": Cfg.Slot.PASSIVE, "name": "艶光", "rar": Cfg.Rar.DUO,
		"desc": "弱体した敵は照覧も受ける。弱体した敵からの被ダメージ -{v}", "base": 20.0, "fmt": "pct", "maxlv": 2,
		"req": ["uzume_atk", "uzume_spc", "uzume_dash"], "req2": ["ama_atk", "ama_spc", "ama_p2"]},
	{"id": "duo_susa_uzume", "kami": "susa", "kami2": "uzume", "slot": Cfg.Slot.PASSIVE, "name": "波と舞", "rar": Cfg.Rar.DUO,
		"desc": "押し戻された敵は {v} のあいだ魅了される", "base": 2.0, "fmt": "sec", "maxlv": 2,
		"req": ["susa_atk", "susa_spc", "susa_dash"], "req2": ["uzume_atk", "uzume_spc", "uzume_cast"]},
	{"id": "duo_iza_inari", "kami": "iza", "kami2": "inari", "slot": Cfg.Slot.PASSIVE, "name": "凍狐", "rar": Cfg.Rar.DUO,
		"desc": "冷気を受けた敵への会心率 +{v}", "base": 25.0, "fmt": "pct", "maxlv": 2,
		"req": ["iza_atk", "iza_spc", "iza_cast"], "req2": ["inari_atk", "inari_spc", "inari_p1"]},
]


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


static func boons_of(kami_id: String) -> Array:
	return BOONS.filter(func(b): return b["kami"] == kami_id and not b.has("kami2"))


static func rarity_of(b: Dictionary, rolled: int) -> int:
	if b.has("rar"):
		return int(b["rar"])
	return rolled


## 恩恵の現在値。レアリティで倍率がかかり、神酒のレベルで伸びる。
static func value(b: Dictionary, rar: int, lv: int) -> float:
	var base := float(b["base"])
	var mult: float = Cfg.RAR_MULT[rar]
	if rar == Cfg.Rar.LEGENDARY or rar == Cfg.Rar.DUO:
		mult = 1.0
	# 神酒のレベル補正（逓減）
	mult += Cfg.LV_BONUS[clampi(lv - 1, 0, Cfg.LV_BONUS.size() - 1)]
	var fmt := String(b["fmt"])
	if fmt == "sec_down":
		return maxf(base * 0.3, base / mult)   # 「再生成の秒数」など、小さいほど良い値
	return base * mult


static func fmt_value(b: Dictionary, v: float) -> String:
	match String(b["fmt"]):
		"pct": return "%d%%" % int(round(v))
		"num": return str(int(round(v)))
		"sec", "sec_down": return "%.1f秒" % v
		_: return "%.1f" % v


## 説明文に現在値を埋め込む
static func describe(b: Dictionary, rar: int, lv: int) -> String:
	return String(b["desc"]).replace("{v}", fmt_value(b, value(b, rar, lv)))
