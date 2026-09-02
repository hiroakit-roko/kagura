class_name Boons
extends RefCounted

## 恩恵の抽選・取得ロジック（Hades の部屋報酬〜恩恵選択の流れを模したもの）。
##
##   - 主神は専用画面で 3 柱から選ぶ（Boons.roll_kami_choices）
##   - レベルアップごとに 1 柱の神が現れ、その神の恩恵 3 つから 1 つ選ぶ（offer）
##   - 3 柱に達するまでは、新しい神が現れることがある。恩恵を受け取るとその神は副神になる
##   - 双神・伝説は条件を満たすと候補に混ざる。伝説は主神のみ
##   - 別の神の恩恵で埋まっているスロットには「交換」として提示され、交換時はレアリティが 1 段上がる
##   - 神酒（Pom of Power）は所持している恩恵のレベルを上げる

const MAX_KAMI := 3
## レアリティの基礎確率（凡 / 稀 / 秀 / 英）
const RAR_WEIGHTS := [56.0, 30.0, 12.0, 2.0]


static func kami_ids() -> Array:
	return Kami.LIST.map(func(k): return String(k["id"]))


## 主神選択の候補 3 柱（猿田彦は加護しか持たないので主神候補から外す）
static func roll_kami_choices(n := 3) -> Array:
	var pool := kami_ids().filter(func(id): return id != "saru")
	pool.shuffle()
	return pool.slice(0, n)


## 次に現れる神を決める
static func pick_kami(p: Player) -> String:
	var owned: Array = p.gods.duplicate()
	var candidates: Array = []
	var weights: Array = []

	if owned.size() < MAX_KAMI:
		# まだ枠がある：新しい神も現れる（新顔をやや優遇して早めに 3 柱揃うようにする）
		for id in kami_ids():
			if owned.has(id):
				continue
			if pool_for(p, id).is_empty():
				continue
			candidates.append(id)
			weights.append(1.6 if id != "saru" else 0.9)
	for id in owned:
		if pool_for(p, id).is_empty():
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


## その神が今提示できる恩恵の候補（未所持で、スロットの条件を満たすもの）
static func pool_for(p: Player, kami_id: String) -> Array:
	var out: Array = []
	for b in Kami.boons_of(kami_id):
		if p.boons.has(b["id"]):
			continue
		if b.has("rar") and int(b["rar"]) == Cfg.Rar.LEGENDARY:
			continue   # 伝説は別枠で判定
		var slot := int(b["slot"])
		if slot != Cfg.Slot.PASSIVE:
			var cur: String = p.slots.get(slot, "")
			if cur != "" and Kami.boon(cur)["kami"] == kami_id:
				continue   # 同じ神の同じスロットは持てない（上書きにならない）
		out.append(b)
	return out


static func legendary_for(p: Player, kami_id: String) -> Dictionary:
	if kami_id != p.main_god():
		return {}
	for b in Kami.BOONS:
		if b["kami"] != kami_id or not b.has("rar") or int(b["rar"]) != Cfg.Rar.LEGENDARY:
			continue
		if p.boons.has(b["id"]):
			continue
		var have := 0
		for r in b["req"]:
			if p.boons.has(r):
				have += 1
		if have >= int(b.get("reqn", 2)):
			return b
	return {}


static func duos_for(p: Player, kami_id: String) -> Array:
	var out: Array = []
	for b in Kami.BOONS:
		if not b.has("kami2") or p.boons.has(b["id"]):
			continue
		if b["kami"] != kami_id and b["kami2"] != kami_id:
			continue
		if not p.gods.has(b["kami"]) or not p.gods.has(b["kami2"]):
			continue
		var ok1 := false
		for r in b["req"]:
			if p.boons.has(r):
				ok1 = true
		var ok2 := false
		for r in b["req2"]:
			if p.boons.has(r):
				ok2 = true
		if ok1 and ok2:
			out.append(b)
	return out


static func roll_rarity(p: Player, kami_id: String, min_rar := Cfg.Rar.COMMON) -> int:
	var w := RAR_WEIGHTS.duplicate()
	var luck := float(p.level) * 0.6
	w[1] += luck
	w[2] += luck * 0.6
	w[3] += luck * 0.15
	if kami_id == p.main_god():
		# 主神の恩恵はやや高レアが出やすい（Keepsake 装備の +10〜20% に相当）
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


## 神 kami_id からの提示。各要素は {"boon", "rar", "exchange", "cur"}
static func offer(p: Player, kami_id: String, count := 3, min_rar := Cfg.Rar.COMMON) -> Array:
	var out: Array = []
	var leg := legendary_for(p, kami_id)
	if not leg.is_empty() and randf() < 0.5:
		out.append({"boon": leg, "rar": Cfg.Rar.LEGENDARY, "exchange": false, "cur": ""})
	var duos := duos_for(p, kami_id)
	if not duos.is_empty() and randf() < 0.6:
		out.append({"boon": duos[randi() % duos.size()], "rar": Cfg.Rar.DUO, "exchange": false, "cur": ""})

	var pool := pool_for(p, kami_id)
	pool.shuffle()
	# 神威スロットの恩恵（攻撃/特技…）を優先的に混ぜ、加護ばかりにならないようにする
	# （shuffle 済みなので、スロット恩恵を前に寄せるだけの安定ソートでよい）
	var slotted_pool := pool.filter(func(b): return int(b["slot"]) != Cfg.Slot.PASSIVE)
	var passive_pool := pool.filter(func(b): return int(b["slot"]) == Cfg.Slot.PASSIVE)
	pool = slotted_pool + passive_pool
	var slotted := 0
	for b in pool:
		if out.size() >= count:
			break
		var is_slot := int(b["slot"]) != Cfg.Slot.PASSIVE
		if is_slot and slotted >= 2 and pool.size() > count:
			continue
		if is_slot:
			slotted += 1
		var slot := int(b["slot"])
		var cur: String = p.slots.get(slot, "") if slot != Cfg.Slot.PASSIVE else ""
		var exchange := cur != ""
		var rar := roll_rarity(p, kami_id, min_rar)
		if exchange:
			rar = mini(rar + 1, Cfg.Rar.HEROIC)
		out.append({"boon": b, "rar": rar, "exchange": exchange, "cur": cur})
	# 残りを埋める（候補が少ないときは加護も追加）
	if out.size() < count:
		for b in pool:
			if out.size() >= count:
				break
			var dup := false
			for o in out:
				if o["boon"]["id"] == b["id"]:
					dup = true
			if dup:
				continue
			var slot2 := int(b["slot"])
			var cur2: String = p.slots.get(slot2, "") if slot2 != Cfg.Slot.PASSIVE else ""
			var rar2 := roll_rarity(p, kami_id, min_rar)
			if cur2 != "":
				rar2 = mini(rar2 + 1, Cfg.Rar.HEROIC)
			out.append({"boon": b, "rar": rar2, "exchange": cur2 != "", "cur": cur2})
	return out.slice(0, count)


## 恩恵を受け取る
static func take(p: Player, o: Dictionary) -> void:
	var b: Dictionary = o["boon"]
	var id := String(b["id"])
	var slot := int(b["slot"])
	var lv := 1
	if slot != Cfg.Slot.PASSIVE:
		var cur: String = p.slots.get(slot, "")
		if cur != "":
			# 交換：レベルは引き継ぐ（Hades と同じ）
			lv = int(p.boons[cur]["lv"])
			p.boons.erase(cur)
		p.slots[slot] = id
	p.boons[id] = {"rar": int(o["rar"]), "lv": lv}
	# 神の登録（主神→副神）
	for key in ["kami", "kami2"]:
		if b.has(key):
			var k := String(b[key])
			if not p.gods.has(k) and p.gods.size() < MAX_KAMI:
				p.gods.append(k)
	p.on_boons_changed()


## 神酒で上げられる恩恵
static func miki_targets(p: Player) -> Array:
	var out: Array = []
	for id in p.boons.keys():
		var b := Kami.boon(id)
		if b.is_empty():
			continue
		var rar := int(p.boons[id]["rar"])
		if rar == Cfg.Rar.LEGENDARY or rar == Cfg.Rar.DUO:
			continue
		if int(p.boons[id]["lv"]) >= int(b.get("maxlv", 5)):
			continue
		out.append(id)
	return out


static func miki_apply(p: Player, id: String) -> void:
	if not p.boons.has(id):
		return
	p.boons[id]["lv"] = int(p.boons[id]["lv"]) + 1
	p.on_boons_changed()
