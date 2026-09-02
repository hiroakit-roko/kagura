class_name Boons
extends RefCounted

## 恩恵の抽選・取得（Hades の部屋報酬〜恩恵選択の流れを模したもの）。
##
##   - 主神は専用画面で 3 柱から選ぶ（roll_kami_choices）。選んだ瞬間に神器が付く
##   - レベルアップごとに、迎えている神のうち 1 柱が現れて 3 枚を提示する
##       ・その神の神器の強化（重ねて取れる）
##       ・まだ枠があれば「新たな神を迎える」カード（副神になり、神器が半分の威力で付く）
##       ・条件を満たせば 伝説（主神のみ）／双神
##   - 神酒（Pom of Power 相当）は神を 1 柱選んで神格を 1 上げる

const MAX_KAMI := 3
## レアリティの基礎確率（凡 / 稀 / 秀 / 英）
const RAR_WEIGHTS := [56.0, 30.0, 12.0, 2.0]


static func kami_ids() -> Array:
	return Kami.LIST.map(func(k): return String(k["id"]))


## 主神選択の候補 3 柱
static func roll_kami_choices(n := 3) -> Array:
	var pool := kami_ids()
	pool.shuffle()
	return pool.slice(0, n)


## 次に現れる神（迎えている神の中から。主神がやや出やすい）
static func pick_kami(p: Player) -> String:
	var candidates: Array = []
	var weights: Array = []
	for id in p.gods:
		var has_pool := not pool_for(p, id).is_empty() or not legendary_for(p, id).is_empty() \
				or not duos_for(p, id).is_empty() or p.gods.size() < MAX_KAMI
		if not has_pool:
			continue
		candidates.append(id)
		weights.append(1.5 if id == p.main_god() else 1.0)
	if candidates.is_empty():
		return ""
	var total := 0.0
	for w in weights:
		total += float(w)
	var r := randf() * total
	for i in candidates.size():
		r -= float(weights[i])
		if r <= 0.0:
			return candidates[i]
	return candidates.back()


## その神が今提示できる強化（上限に達していないもの）
static func pool_for(p: Player, kami_id: String) -> Array:
	var out: Array = []
	for b in Kami.upgrades_of(kami_id):
		var lv := int(p.boons[b["id"]]["lv"]) if p.boons.has(b["id"]) else 0
		if lv < int(b.get("maxlv", 3)):
			out.append(b)
	return out


static func legendary_for(p: Player, kami_id: String) -> Dictionary:
	if kami_id != p.main_god():
		return {}
	var b := Kami.legendary_of(kami_id)
	if b.is_empty() or p.boons.has(b["id"]):
		return {}
	# その神の強化を 2 つ以上持っていると出る
	var have := 0
	for u in Kami.upgrades_of(kami_id):
		if p.boons.has(u["id"]):
			have += 1
	return b if have >= 2 else {}


static func duos_for(p: Player, kami_id: String) -> Array:
	var out: Array = []
	for b in Kami.BOONS:
		if not b.has("kami2") or p.boons.has(b["id"]):
			continue
		if b["kami"] != kami_id and b["kami2"] != kami_id:
			continue
		if not p.gods.has(b["kami"]) or not p.gods.has(b["kami2"]):
			continue
		if _upgrade_count(p, String(b["kami"])) >= 1 and _upgrade_count(p, String(b["kami2"])) >= 1:
			out.append(b)
	return out


static func _upgrade_count(p: Player, kami_id: String) -> int:
	var n := 0
	for u in Kami.upgrades_of(kami_id):
		if p.boons.has(u["id"]):
			n += 1
	return n


static func roll_rarity(p: Player, kami_id: String, min_rar := Cfg.Rar.COMMON) -> int:
	var w := RAR_WEIGHTS.duplicate()
	var luck := float(p.level) * 0.6
	w[1] += luck
	w[2] += luck * 0.6
	w[3] += luck * 0.15
	if kami_id == p.main_god():
		w[1] += 10.0
		w[2] += 5.0
	var total := 0.0
	for x in w:
		total += float(x)
	var r := randf() * total
	var rar := 0
	for i in w.size():
		r -= float(w[i])
		if r <= 0.0:
			rar = i
			break
	return maxi(rar, min_rar)


## 神 kami_id からの提示。各要素は
##   {"type": "upgrade"|"legendary"|"duo"|"recruit", "boon": Dictionary, "rar": int, "kami": String}
static func offer(p: Player, kami_id: String, count := 3, min_rar := Cfg.Rar.COMMON) -> Array:
	var out: Array = []
	var leg := legendary_for(p, kami_id)
	if not leg.is_empty() and randf() < 0.5:
		out.append({"type": "legendary", "boon": leg, "rar": Cfg.Rar.LEGENDARY, "kami": kami_id})
	var duos := duos_for(p, kami_id)
	if not duos.is_empty() and randf() < 0.6:
		var d: Dictionary = duos[randi() % duos.size()]
		out.append({"type": "duo", "boon": d, "rar": Cfg.Rar.DUO, "kami": String(d["kami"])})

	# 新たな神を迎えるカード（枠があるとき。2 柱目までは出やすい）
	if p.gods.size() < MAX_KAMI:
		var chance := 0.75 if p.gods.size() == 1 else 0.55
		if randf() < chance:
			var others := kami_ids().filter(func(id): return not p.gods.has(id))
			if not others.is_empty():
				var nk: String = others[randi() % others.size()]
				out.append({"type": "recruit", "boon": {}, "rar": Cfg.Rar.RARE, "kami": nk})

	var pool := pool_for(p, kami_id)
	pool.shuffle()
	for b in pool:
		if out.size() >= count:
			break
		out.append({"type": "upgrade", "boon": b, "rar": roll_rarity(p, kami_id, min_rar), "kami": kami_id})
	# まだ足りなければ、他の迎えている神の強化で埋める
	if out.size() < count:
		for id in p.gods:
			if id == kami_id:
				continue
			for b in pool_for(p, id):
				if out.size() >= count:
					break
				out.append({"type": "upgrade", "boon": b, "rar": roll_rarity(p, id, min_rar), "kami": id})
	return out.slice(0, count)


## 恩恵を受け取る
static func take(p: Player, o: Dictionary) -> void:
	match String(o["type"]):
		"recruit":
			p.add_god(String(o["kami"]))
		_:
			var b: Dictionary = o["boon"]
			var id := String(b["id"])
			if p.boons.has(id):
				# 重ねる：レアリティは高い方を残す
				p.boons[id]["lv"] = int(p.boons[id]["lv"]) + 1
				p.boons[id]["rar"] = maxi(int(p.boons[id]["rar"]), int(o["rar"]))
			else:
				p.boons[id] = {"rar": int(o["rar"]), "lv": 1}
			p.on_boons_changed()


## 神酒：神格を上げられる神
static func miki_targets(p: Player) -> Array:
	return p.gods.filter(func(id): return int(p.kami_lv.get(id, 1)) < 10)


static func miki_apply(p: Player, kami_id: String) -> void:
	if not p.gods.has(kami_id):
		return
	p.kami_xp[kami_id] = 0.0
	p.kami_level_up(kami_id)
