class_name Relics
extends RefCounted

## 神宝（ボス撃破の褒賞）。3 つから 1 つ選ぶ。持っているだけで効く常時効果で、重複しない。

const LIST := [
	{"id": "r_heal_wave", "name": "癒しの御守", "mark": "癒", "desc": "波を越えるごとに HP 8% 回復"},
	{"id": "r_hp", "name": "命の勾玉", "mark": "命", "desc": "最大 HP +30"},
	{"id": "r_xp", "name": "学びの巻物", "mark": "学", "desc": "勾玉の経験値 +20%"},
	{"id": "r_magnet", "name": "呼び寄せの鈴", "mark": "鈴", "desc": "勾玉を引き寄せる範囲 +40%"},
	{"id": "r_dash", "name": "風の草鞋", "mark": "風", "desc": "疾走の間隔 -25%"},
	{"id": "r_orb", "name": "三つ目の珠", "mark": "珠", "desc": "詠唱の珠 +1"},
	{"id": "r_iframe", "name": "厄除けの札", "mark": "厄", "desc": "被弾後の無敵時間 +40%"},
	{"id": "r_dmg", "name": "破魔の矢", "mark": "破", "desc": "基礎攻撃 +10%"},
	{"id": "r_crit", "name": "鷹の目", "mark": "鷹", "desc": "会心率 +8%"},
	{"id": "r_gauge", "name": "神楽鈴", "mark": "楽", "desc": "神招きの溜まり +25%"},
	{"id": "r_heal_drop", "name": "薬袋", "mark": "薬", "desc": "回復の御札が落ちる確率 2 倍"},
	{"id": "r_revive", "name": "身代わり人形", "mark": "代", "desc": "一度だけ致命傷を防ぎ、HP 半分で立ち上がる"},
	{"id": "r_score", "name": "賽銭箱", "mark": "賽", "desc": "功徳 +20%"},
	{"id": "r_speed", "name": "韋駄天の足", "mark": "速", "desc": "移動速度 +10%"},
	{"id": "r_fam_dmg", "name": "使い魔の首輪", "mark": "魔", "desc": "使い魔の威力 +60%"},
	{"id": "r_fam_rate", "name": "使い魔の鈴", "mark": "連", "desc": "使い魔の連射 +40%"},
	{"id": "r_fam_twin", "name": "使い魔の分身", "mark": "双", "desc": "使い魔がもう 1 匹付いてくる"},
]


static func get_relic(id: String) -> Dictionary:
	for r in LIST:
		if r["id"] == id:
			return r
	return {}


## まだ持っていない神宝から 3 つ
static func offer(p: Player, n := 3) -> Array:
	var pool := LIST.filter(func(r): return not p.relics.has(r["id"]))
	pool.shuffle()
	return pool.slice(0, n)
