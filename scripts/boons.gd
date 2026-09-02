class_name Boons
extends RefCounted

## 恩恵の抽選・取得（Hades の部屋報酬〜恩恵選択の流れを模したもの）。
##
##   - 神を迎える瞬間はそれ自体が報酬（神器が付く）で、他の選択は続かない
##       ・位 2（最初のレベルアップ）で 3 柱から主神を選ぶ
##       ・位 4 と位 7 で、残る神から 3 柱が現れ副神を迎える（神器の威力は主神と同じ。詠唱・神招きだけ主神のもの）
##   - それ以外のレベルアップは、迎えている神から 1 柱を自分で選ぶ。その神の神格が 1 上がり、能力 3 枚を提示する
##       ・神ごとの能力は 9 種（凡 4・稀 3・秀 2）。1 柱につき 3 つまで選べる
##       ・提示は「空いている枠のぶん新しい能力」＋「残りは選んだ能力の強化」
##         例：1 つ選んでいれば 新規 2 枚＋強化 1 枚、2 つなら 新規 1 枚＋強化 2 枚
##       ・条件を満たせば 伝説（主神のみ）／双神／禍神の取引 が 1 枚混ざる
##   - 神酒（Pom of Power 相当）は神を 1 柱選んで神格を 1 上げる

const MAX_KAMI := 3
## 1 柱の神から選べる能力の数
const MAX_PER_KAMI := 3
## 新しい能力を引くときの格ごとの重み（位が上がると稀・秀が出やすくなる）
const TIER_W := {Cfg.Rar.COMMON: 1.0, Cfg.Rar.RARE: 0.7, Cfg.Rar.EPIC: 0.4}
## i 柱目の神を迎える位（主神・副神①・副神②）
const RECRUIT_LEVELS := [2, 4, 7]


static func kami_ids() -> Array:
	return Kami.LIST.map(func(k): return String(k["id"]))


## 次に神を迎える位。もう枠がなければ -1
static func next_recruit_level(p: Player) -> int:
	if p.gods.size() >= MAX_KAMI:
		return -1
	return int(RECRUIT_LEVELS[p.gods.size()])


## 今のレベルアップで新たな神を迎える番か
static func recruit_due(p: Player) -> bool:
	var need := next_recruit_level(p)
	return need > 0 and p.level >= need


## 神を迎える候補 3 柱（すでに迎えている神は除く）
static func roll_kami_choices(p: Player, n := 3) -> Array:
	var pool := kami_ids().filter(func(id): return p == null or not p.gods.has(id))
	pool.shuffle()
	return pool.slice(0, n)


## 次に現れる神（迎えている神の中から。主神がやや出やすい）
static func pick_kami(p: Player) -> String:
	var candidates: Array = []
	var weights: Array = []
	for id in p.gods:
		var has_pool := not pool_for(p, id).is_empty() or not legendary_for(p, id).is_empty() \
				or not duos_for(p, id).is_empty()
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


## その神の能力のうち選んでいるもの
static func owned_of(p: Player, kami_id: String) -> Array:
	return Kami.upgrades_of(kami_id).filter(func(b): return p.boons.has(b["id"]))


## まだ選んでいない能力（枠が残っているときだけ）
static func new_pool(p: Player, kami_id: String) -> Array:
	if owned_of(p, kami_id).size() >= MAX_PER_KAMI:
		return []
	return Kami.upgrades_of(kami_id).filter(func(b): return not p.boons.has(b["id"]))


## 選んだ能力のうち、まだ重ねられるもの
static func lv_pool(p: Player, kami_id: String) -> Array:
	return owned_of(p, kami_id).filter(func(b): return int(p.boons[b["id"]]["lv"]) < int(b.get("maxlv", 3)))


## その神が今提示できるもの（新規＋強化）
static func pool_for(p: Player, kami_id: String) -> Array:
	return new_pool(p, kami_id) + lv_pool(p, kami_id)


## 格の重みで 1 つ引く（引いたものは cands から除く）
static func _draw_new(p: Player, cands: Array, kami_id: String) -> Dictionary:
	var total := 0.0
	var ws: Array = []
	for b in cands:
		var tier := int(b.get("tier", Cfg.Rar.COMMON))
		var w: float = TIER_W.get(tier, 1.0)
		if tier == Cfg.Rar.RARE:
			w += 0.02 * float(p.level) + (0.1 if kami_id == p.main_god() else 0.0)
		elif tier == Cfg.Rar.EPIC:
			w += 0.03 * float(p.level) + (0.1 if kami_id == p.main_god() else 0.0)
		ws.append(w)
		total += w
	var r := randf() * total
	for i in cands.size():
		r -= float(ws[i])
		if r <= 0.0:
			return cands.pop_at(i)
	return cands.pop_back()


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


## 神 kami_id からの提示。各要素は
##   {"type": "upgrade"|"legendary"|"duo"|"curse", "boon": Dictionary, "rar": int, "kami": String}
##   upgrade の rar はその能力の格（tier）。すでに選んでいる能力なら「強化」として出る。
##   （新たな神は専用画面で迎えるので、ここには混ざらない）
##   min_rar が 凡 より上なら、新しい能力はその格以上のものを優先する（討伐の褒賞）
static func offer(p: Player, kami_id: String, count := 3, min_rar := Cfg.Rar.COMMON) -> Array:
	var out: Array = []
	# 特別な 1 枚（伝説 > 双神 > 禍神の取引）。多くても 1 枚
	var leg := legendary_for(p, kami_id)
	var duos := duos_for(p, kami_id)
	if not leg.is_empty() and randf() < 0.5:
		out.append({"type": "legendary", "boon": leg, "rar": Cfg.Rar.LEGENDARY, "kami": kami_id})
	elif not duos.is_empty() and randf() < 0.6:
		var d: Dictionary = duos[randi() % duos.size()]
		out.append({"type": "duo", "boon": d, "rar": Cfg.Rar.DUO, "kami": String(d["kami"])})
	elif Game.inst.wave >= 4 and randf() < 0.14:
		var avail := Kami.CURSES.filter(func(c): return not p.boons.has(c["id"]))
		if not avail.is_empty():
			var c: Dictionary = avail[randi() % avail.size()]
			out.append({"type": "curse", "boon": c, "rar": Cfg.Rar.HEROIC, "kami": kami_id})

	_fill_from(p, kami_id, out, count, min_rar)
	# まだ足りなければ、他の迎えている神で埋める
	if out.size() < count:
		for id in p.gods:
			if id != kami_id and out.size() < count:
				_fill_from(p, String(id), out, count, min_rar)
	return out.slice(0, count)


## 神 kami_id の「新規」と「強化」で out を埋める
static func _fill_from(p: Player, kami_id: String, out: Array, count: int, min_rar: int) -> void:
	var remaining := count - out.size()
	if remaining <= 0:
		return
	var news := new_pool(p, kami_id)
	if min_rar > Cfg.Rar.COMMON:
		var hi := news.filter(func(b): return int(b.get("tier", 0)) >= min_rar)
		if not hi.is_empty():
			news = hi
	var lvs := lv_pool(p, kami_id)
	lvs.shuffle()
	var free := MAX_PER_KAMI - owned_of(p, kami_id).size()
	# 空き枠のぶん新規、残りは強化。1 つでも選んでいれば強化を最低 1 枚は混ぜる
	var n_lv := clampi(remaining - free, 1 if (not lvs.is_empty() and remaining >= 2) else 0, lvs.size())
	var n_new := mini(mini(free, remaining - n_lv), news.size())
	n_lv = mini(lvs.size(), remaining - n_new)
	for i in n_new:
		var b := _draw_new(p, news, kami_id)
		out.append({"type": "upgrade", "boon": b, "rar": int(b.get("tier", Cfg.Rar.COMMON)), "kami": kami_id})
	for i in n_lv:
		var b: Dictionary = lvs[i]
		out.append({"type": "upgrade", "boon": b, "rar": int(p.boons[b["id"]]["rar"]), "kami": kami_id})


## 恩恵を受け取る
static func take(p: Player, o: Dictionary) -> void:
	match String(o["type"]):
		"recruit":
			p.add_god(String(o["kami"]))
		"curse":
			p.boons[String(o["boon"]["id"])] = {"rar": Cfg.Rar.HEROIC, "lv": 1}
			p.on_boons_changed()
		_:
			var b: Dictionary = o["boon"]
			var id := String(b["id"])
			if p.boons.has(id):
				# 重ねる（強化）
				p.boons[id]["lv"] = int(p.boons[id]["lv"]) + 1
			else:
				p.boons[id] = {"rar": int(b.get("tier", o["rar"])), "lv": 1}
			p.on_boons_changed()


## 神酒：神格を上げられる神
static func miki_targets(p: Player) -> Array:
	return p.gods.filter(func(id): return int(p.kami_lv.get(id, 1)) < 10)


static func miki_apply(p: Player, kami_id: String) -> void:
	if not p.gods.has(kami_id):
		return
	p.kami_xp[kami_id] = 0.0
	p.kami_level_up(kami_id)
