class_name Combat
extends RefCounted

## 命中処理の中枢。ダメージ倍率の計算、神威（状態異常）の付与、
## 連鎖・宿命・砕けなどの派生効果、伝説／双神の発動をここに集約する。
##
## 呼び出し側は Combat.hit(enemy, dmg, at, opts) を呼ぶだけでよい。
##   opts: tag(String) slot(int) kami(String) crit(bool) dir(Vector2) kb(float) quiet(bool)

# 状態異常の持続時間
const EXPOSED_T := 5.0
const RUPTURE_T := 3.0
const JOLT_T := 8.0
const WEAK_T := 4.0


static func _p() -> Player:
	if Game.inst == null:
		return null
	var p := Game.inst.player
	return p if (p != null and is_instance_valid(p) and p.alive) else null


static func _has(id: String) -> bool:
	var p := _p()
	return p != null and p.has(id)


static func _val(id: String) -> float:
	var p := _p()
	return p.val(id) if p != null else 0.0


# ---------------------------------------------------------------------------
# 命中
# ---------------------------------------------------------------------------

static func hit(e: Node2D, dmg: float, at: Vector2, opts: Dictionary = {}) -> float:
	if e == null or not is_instance_valid(e) or not (e is Enemy):
		return 0.0
	var en := e as Enemy
	if en.hp <= 0.0:
		return 0.0
	var p := _p()
	var tag := String(opts.get("tag", "attack"))
	var kami := String(opts.get("kami", ""))
	var crit := bool(opts.get("crit", false))
	var dir: Vector2 = opts.get("dir", Vector2.UP)

	# --- 倍率 ---
	var mult := 1.0
	if en.st["exposed"] > 0.0:
		mult *= 1.0 + 0.20 + _val("ama_p2") * 0.01
	if en.st["weak"] > 0.0 and _has("uzume_p1"):
		mult *= 1.0 + _val("uzume_p1") * 0.01
	if int(en.st["chill"]["stacks"]) > 0 and _has("iza_p3"):
		mult *= 1.0 + _val("iza_p3") * 0.01
	if en.st["frozen"] > 0.0:
		mult *= 1.5
	if tag == "lightning":
		mult *= 1.0 + _val("take_p1") * 0.01
		if en.st["exposed"] > 0.0 and _has("duo_ama_take"):
			mult *= 1.0 + _val("duo_ama_take") * 0.01
	if tag == "knockback" and int(en.st["chill"]["stacks"]) > 0 and _has("duo_susa_iza"):
		mult *= 1.0 + _val("duo_susa_iza") * 0.01

	# --- 会心 ---
	if en.st["marked"] and tag in ["attack", "special", "cast", "foxfire", "deflect"]:
		crit = true
		en.st["marked"] = false
	if not crit and p != null and en.st["weak"] > 0.0 and _has("uzume_p3") \
			and tag in ["attack", "special", "cast"]:
		crit = randf() < _val("uzume_p3") * 0.01
	if not crit and p != null and int(en.st["chill"]["stacks"]) > 0 and _has("duo_iza_inari") \
			and tag in ["attack", "special", "cast"]:
		crit = randf() < _val("duo_iza_inari") * 0.01
	if crit and p != null:
		mult *= p.crit_mult()

	var final := dmg * mult
	var quiet := bool(opts.get("quiet", false))
	en.take_damage(final, crit, at)
	if p != null:
		p.add_call_gauge(final * 0.0006)
		if tag in ["attack", "special", "cast", "dash", "deflect", "foxfire"]:
			_hit_fx(en, at, dir, kami, crit, tag)

	# 倒れていたら以降は不要
	if not is_instance_valid(en) or en.hp <= 0.0:
		return final

	# --- 神威の付与（スロット弾のみ） ---
	if tag in ["attack", "special", "cast", "dash"] and kami != "":
		_apply_status(en, kami, tag, at, dir, opts)

	# --- 会心の派生 ---
	if crit:
		if _has("duo_inari_take"):
			lightning(en, _val("duo_inari_take"), at + Vector2(0, -60), 0)
		if _has("inari_leg") and tag != "foxfire":
			var other := nearest_enemy(en.position, 260.0, en)
			if other != null and p != null:
				p.spawn_foxfire(en.position, other, _val("inari_leg"))

	# --- 押し戻し ---
	var kb := float(opts.get("kb", 0.0))
	if kb > 0.0:
		knockback(en, dir * kb, at)

	return final


static func _hit_fx(en: Enemy, at: Vector2, dir: Vector2, kami: String, crit: bool, tag: String) -> void:
	var col := Color(1, 1, 1)
	var k := Kami.kami(kami)
	if not k.is_empty():
		col = k["color"]
	Fx.sparks(at, -dir, col, 4 if not crit else 8, 380.0)
	match kami:
		"ama":
			Sfx.play("hit_light", -14.0, randf_range(0.95, 1.1), 0.04)
		"take":
			Sfx.play("hit", -12.0, 1.2, 0.03)
		"susa":
			Sfx.play("hit_storm", -16.0, randf_range(0.9, 1.1), 0.05)
		"iza":
			Sfx.play("hit_ice", -14.0, randf_range(0.95, 1.1), 0.05)
		_:
			Sfx.play("hit", -12.0, randf_range(0.9, 1.15), 0.03)
	if crit:
		Sfx.play("hit_heavy", -10.0, randf_range(1.0, 1.2), 0.05)
		Game.inst.hitstop(0.04 if not en.is_boss else 0.06, 0.05)
	elif en.is_boss and tag == "cast":
		Game.inst.hitstop(0.05, 0.1)


static func _apply_status(en: Enemy, kami: String, tag: String, at: Vector2, dir: Vector2, opts: Dictionary) -> void:
	var p := _p()
	if p == null:
		return
	var slot := int(opts.get("slot", Cfg.Slot.ATTACK))
	var boon_id: String = p.slots.get(slot, "")
	var v := p.val(boon_id) if boon_id != "" else 0.0
	var kc: Color = Kami.kami(kami)["color"]
	match kami:
		"ama":
			if en.st["exposed"] <= 0.0:
				Fx.rays(en.position, kc, 6, en.radius * 0.6, 26.0, 0.25)
			en.add_exposed(EXPOSED_T)
		"susa":
			if tag == "cast" or tag == "dash":
				en.add_rupture(RUPTURE_T)
				Fx.slash(en.position, randf() * TAU, en.radius * 1.3, kc, 2.0, 0.18, 6.0)
		"take":
			match slot:
				Cfg.Slot.ATTACK:
					lightning(en, v, at, 1 + int(_val("take_p3")))
				Cfg.Slot.SPECIAL:
					lightning_area(at, v, 90.0)
				Cfg.Slot.DASH:
					lightning(en, v, at + Vector2(0, -80), 0)
					en.add_jolt(JOLT_T)
		"tsuki":
			match slot:
				Cfg.Slot.ATTACK, Cfg.Slot.CAST:
					en.add_doom(v * (1.0 + _val("tsuki_p1") * 0.01))
					Fx.ring(en.position, Color(0.78, 0.72, 1.0), en.radius, en.radius * 2.0, 0.25, 2.0)
		"uzume":
			match slot:
				Cfg.Slot.ATTACK, Cfg.Slot.SPECIAL, Cfg.Slot.DASH:
					if en.st["weak"] <= 0.0:
						Fx.petals(en.position, kc, 5, 90.0)
					apply_weak(en)
				Cfg.Slot.CAST:
					en.add_charm(v)
					Sfx.play("charm", -10.0)
		"inari":
			if slot == Cfg.Slot.SPECIAL:
				if not en.st["marked"]:
					Fx.ring(en.position, kc, en.radius * 0.5, en.radius * 2.2, 0.3, 2.5)
				en.mark()
		"suku":
			match slot:
				Cfg.Slot.ATTACK:
					Fx.burst(at, kc, 3, 90.0, 2.5, 0.35, true)
					apply_hangover(en, 1, v)
				Cfg.Slot.SPECIAL:
					apply_hangover(en, 2, v)
		"iza":
			Fx.sparks(at, Vector2.UP, Color(0.85, 0.95, 1.0), 3, 220.0)
			match slot:
				Cfg.Slot.ATTACK:
					en.add_chill(1)
				Cfg.Slot.SPECIAL:
					en.add_chill(2)
				Cfg.Slot.DASH:
					en.add_chill(2)


# ---------------------------------------------------------------------------
# 状態異常のヘルパ（他クラスからも参照する定数的な値）
# ---------------------------------------------------------------------------

static func weak_amount() -> float:
	var w := 0.30
	if _has("duo_uzume_suku"):
		w += _val("duo_uzume_suku") * 0.01
	if _has("uzume_dash"):
		w += _val("uzume_dash") * 0.01
	if _has("duo_uzume_ama"):
		w += _val("duo_uzume_ama") * 0.01
	return minf(w, 0.8)


static func hangover_max() -> int:
	return 5 + (3 if _has("suku_p2") else 0)


static func hangover_slow() -> float:
	return _val("suku_p3") * 0.01 if _has("suku_p3") else 0.0


static func hangover_dps() -> float:
	var p := _p()
	if p == null:
		return 3.0
	var v := 0.0
	for id in ["suku_atk", "suku_spc"]:
		if p.has(id):
			v = maxf(v, p.val(id))
	if v <= 0.0:
		v = 3.0
	return v * (1.0 + _val("suku_p2") * 0.01)


static func rupture_dmg() -> float:
	var p := _p()
	var base := 3.0 + (float(p.level) * 0.3 if p != null else 0.0)
	return base * (1.0 + _val("susa_p2") * 0.01)


static func apply_weak(en: Enemy) -> void:
	en.add_weak(WEAK_T)
	if _has("duo_uzume_ama"):
		en.add_exposed(EXPOSED_T)


static func apply_hangover(en: Enemy, stacks: int, dps: float) -> void:
	en.add_hangover(stacks, dps * (1.0 + _val("suku_p2") * 0.01))
	if _has("duo_uzume_suku"):
		en.add_weak(WEAK_T)


## 持続ダメージ（裂傷・酩酊・凍土など）：演出は控えめに
static func status_damage(en: Enemy, dmg: float, tag: String) -> void:
	if en == null or not is_instance_valid(en) or en.hp <= 0.0:
		return
	var col := Color(1, 1, 1, 0.8)
	match tag:
		"rupture": col = Color(0.35, 0.82, 0.95)
		"hangover": col = Color(0.62, 1.0, 0.55)
	en.hp -= dmg
	Fx.number(en.position + Vector2(randf_range(-6, 6), -en.radius), str(int(round(dmg))), col, 11.0)
	var p := _p()
	if p != null:
		p.add_call_gauge(dmg * 0.0004)
	if en.hp <= 0.0:
		en.die()


# ---------------------------------------------------------------------------
# 雷
# ---------------------------------------------------------------------------

static func lightning(en: Enemy, dmg: float, from: Vector2, chains: int, used: Dictionary = {}) -> void:
	if en == null or not is_instance_valid(en) or en.hp <= 0.0:
		return
	used[en.get_instance_id()] = true
	Fx.bolt(from, en.position, Color(1.0, 0.97, 0.7))
	Fx.sparks(en.position, Vector2.UP, Color(1.0, 0.97, 0.7), 4, 300.0)
	Sfx.play("hit_thunder", -12.0, randf_range(0.9, 1.2), 0.04)
	var bonus := 0.0
	if _has("duo_take_suku"):
		bonus = _val("duo_take_suku") * float(en.st["hangover"]["stacks"])
	hit(en, dmg + bonus, en.position, {"tag": "lightning", "kami": "take"})
	if not is_instance_valid(en):
		return
	if _has("take_p2"):
		en.add_jolt(JOLT_T)
	if _has("take_leg") and randf() < _val("take_leg") * 0.01:
		var extra := nearest_enemy(en.position, 240.0, en, used)
		if extra != null:
			lightning(extra, dmg, en.position, 0, used)
	if chains > 0:
		var nxt := nearest_enemy(en.position, 200.0, en, used)
		if nxt != null:
			lightning(nxt, dmg * 0.75, en.position, chains - 1, used)


static func lightning_area(at: Vector2, dmg: float, r: float) -> void:
	Fx.bolt(at + Vector2(randf_range(-30, 30), -160), at, Color(1.0, 0.97, 0.7), 0.22)
	Fx.ring(at, Color(1.0, 0.95, 0.6), 6.0, r, 0.25, 3.0)
	Sfx.play("hit_thunder", -10.0, 0.9, 0.05)
	for e in Game.inst.get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		if e.position.distance_to(at) <= r:
			hit(e, dmg, e.position, {"tag": "lightning", "kami": "take"})
			if is_instance_valid(e) and _has("take_p2"):
				e.add_jolt(JOLT_T)


static func jolt_trigger(en: Enemy) -> void:
	var d := _val("take_p2")
	if d <= 0.0:
		d = 15.0
	Fx.bolt(en.position + Vector2(randf_range(-40, 40), -70), en.position, Color(1.0, 0.97, 0.7), 0.14)
	Sfx.play("hit_thunder", -16.0, 1.3, 0.05)
	hit(en, d, en.position, {"tag": "lightning", "kami": "take"})


# ---------------------------------------------------------------------------
# 宿命
# ---------------------------------------------------------------------------

static func doom_trigger(en: Enemy, dmg: float) -> void:
	if en == null or not is_instance_valid(en) or en.hp <= 0.0:
		return
	var col := Color(0.78, 0.72, 1.0)
	Fx.ring(en.position, col, 6.0, en.radius * 3.5, 0.3, 5.0)
	Fx.burst(en.position, col, 10, 220.0, 3.5, 0.4, true)
	Fx.slash(en.position, randf() * TAU, en.radius * 1.6, Color(1, 1, 1), 2.6, 0.2, 7.0)
	Sfx.play("doom", -8.0, randf_range(0.9, 1.1), 0.05)
	Game.inst.hitstop(0.05, 0.05)

	var crit := _has("duo_tsuki_inari")
	var mult := 1.0
	if crit:
		mult *= 1.0 + _val("duo_tsuki_inari") * 0.01
	if en.st["exposed"] > 0.0 and _has("duo_ama_tsuki"):
		mult *= 1.0 + _val("duo_ama_tsuki") * 0.01
	var pos := en.position
	# 裁定：低 HP の敵は即死
	if _has("tsuki_leg") and not en.is_boss and en.hp / en.max_hp <= _val("tsuki_leg") * 0.01:
		Fx.number(pos + Vector2(0, -en.radius - 10), "裁定", Color(1, 0.9, 1), 18.0, true)
		en.take_damage(en.hp + 1.0, true, pos)
	else:
		hit(en, dmg * mult, pos, {"tag": "doom", "kami": "tsuki", "crit": crit})
	if is_instance_valid(en) and en.hp > 0.0:
		if _has("duo_ama_tsuki"):
			en.add_exposed(EXPOSED_T)
		if _has("duo_iza_tsuki"):
			en.freeze(_val("duo_iza_tsuki"))
	# 範囲爆発：周囲の敵にも半分のダメージ（宵闇の加護で範囲が広がる）
	var r := 72.0 * (1.0 + _val("tsuki_p2") * 0.01)
	Fx.ring(pos, col, 10.0, r, 0.35, 6.0)
	Fx.zone(pos, r, col, 0.35)
	for o in Game.inst.get_tree().get_nodes_in_group("enemy"):
		if o == en or not is_instance_valid(o):
			continue
		if o.position.distance_to(pos) <= r:
			hit(o, dmg * 0.5 * mult, o.position, {"tag": "doom", "kami": "tsuki"})


# ---------------------------------------------------------------------------
# 押し戻し・衝突
# ---------------------------------------------------------------------------

static func knockback(en: Enemy, v: Vector2, at: Vector2) -> void:
	en.knockback(v)
	Fx.cone(at, v.normalized(), Color(0.35, 0.82, 0.95), 4, 260.0, 0.5, 3.0, 0.25)
	if _has("duo_susa_take"):
		lightning(en, _val("duo_susa_take"), at + Vector2(0, -70), 0)
	if _has("duo_susa_iza"):
		en.add_chill(1)
	if _has("duo_susa_uzume"):
		en.add_charm(_val("duo_susa_uzume"))
	if _has("susa_leg"):
		hit(en, _val("susa_leg"), en.position, {"tag": "knockback", "kami": "susa"})
		Game.inst.erase_ebullets_near(en.position, 90.0)


static func collide(en: Enemy, other: Enemy) -> void:
	if not _has("susa_p1"):
		return
	var d := _val("susa_p1")
	Fx.ring(en.position, Color(0.35, 0.82, 0.95), 4.0, 40.0, 0.2, 3.0)
	Sfx.play("hit_storm", -12.0, 0.8, 0.05)
	hit(en, d, en.position, {"tag": "knockback", "kami": "susa"})
	if other != null and is_instance_valid(other):
		hit(other, d, other.position, {"tag": "knockback", "kami": "susa"})


# ---------------------------------------------------------------------------
# 冷気の砕け
# ---------------------------------------------------------------------------

static func shatter(en: Enemy) -> void:
	var col := Color(0.8, 0.95, 1.0)
	Fx.burst(en.position, col, 16, 260.0, 4.0, 0.5)
	Fx.ring(en.position, col, 8.0, en.radius * 3.0, 0.3, 4.0)
	Sfx.play("hit_ice", -6.0, 0.7)
	Game.inst.hitstop(0.05, 0.05)
	var d := _val("iza_p1") if _has("iza_p1") else 25.0
	en.freeze(0.8)
	hit(en, d, en.position, {"tag": "shatter", "kami": "iza"})
	if _has("iza_leg"):
		var ld := _val("iza_leg")
		for o in Game.inst.get_tree().get_nodes_in_group("enemy"):
			if o == en or not is_instance_valid(o):
				continue
			if o.position.distance_to(en.position) <= 120.0:
				o.freeze(1.2)
				hit(o, ld, o.position, {"tag": "shatter", "kami": "iza"})


# ---------------------------------------------------------------------------
# 撃破時
# ---------------------------------------------------------------------------

static func on_kill(en: Enemy) -> void:
	var p := _p()
	if p == null:
		return
	# 日食
	if _has("ama_leg") and en.st["exposed"] > 0.0:
		var d := _val("ama_leg")
		Fx.rays(en.position, Color(1.0, 0.9, 0.5), 10, 10.0, 90.0, 0.3)
		for o in Game.inst.get_tree().get_nodes_in_group("enemy"):
			if o == en or not is_instance_valid(o):
				continue
			if o.position.distance_to(en.position) <= 110.0:
				o.add_exposed(EXPOSED_T)
				hit(o, d, o.position, {"tag": "light", "kami": "ama"})
	# 黄泉の穢れ
	if _has("iza_p2"):
		var r := _val("iza_p2")
		Fx.ring(en.position, Color(0.58, 0.82, 1.0), 8.0, r, 0.4, 3.0)
		for o in Game.inst.get_tree().get_nodes_in_group("enemy"):
			if o == en or not is_instance_valid(o):
				continue
			if o.position.distance_to(en.position) <= r:
				o.add_chill(2)
				Fx.sparks(o.position, Vector2.UP, Color(0.85, 0.95, 1.0), 3, 200.0)
	# 八百万の宴
	if _has("uzume_leg") and en.st["weak"] > 0.0 and randf() < _val("uzume_leg") * 0.01:
		p.heal(6.0, true)


# ---------------------------------------------------------------------------
# 検索
# ---------------------------------------------------------------------------

static func nearest_enemy(from: Vector2, max_d: float, exclude: Node2D = null, used: Dictionary = {}) -> Enemy:
	var best: Enemy = null
	var bd := max_d * max_d
	for e in Game.inst.get_tree().get_nodes_in_group("enemy"):
		if e == exclude or not is_instance_valid(e) or used.has(e.get_instance_id()):
			continue
		var d: float = from.distance_squared_to(e.position)
		if d < bd:
			bd = d
			best = e
	return best
