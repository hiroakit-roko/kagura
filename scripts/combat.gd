class_name Combat
extends RefCounted

## 命中処理の中枢。ダメージ倍率、神威（状態異常）の付与、連鎖・宿命・砕けなどの派生、
## 伝説／双神の発動、神徳（神格の経験値）の加算をここに集約する。
##
## Combat.hit(enemy, dmg, at, opts)
##   opts: tag(String) kami(String) crit(bool) dir(Vector2) kb(float) quiet(bool) doom(float) charm_chance(float)

const EXPOSED_T := 5.0
const RUPTURE_T := 3.0
const JOLT_T := 8.0
const WEAK_T := 4.0

const STATUS_COLOR := {
	"exposed": Color(1.0, 0.84, 0.42), "rupture": Color(0.35, 0.82, 0.95), "jolted": Color(1.0, 0.95, 0.5),
	"doom": Color(0.78, 0.72, 1.0), "weak": Color(1.0, 0.58, 0.78), "charm": Color(1.0, 0.45, 0.7),
	"marked": Color(1.0, 0.62, 0.3), "hangover": Color(0.62, 1.0, 0.55), "chill": Color(0.58, 0.82, 1.0),
	"frozen": Color(0.8, 0.95, 1.0), "frost": Color(0.58, 0.82, 1.0),
}


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


## 「威力 N%」：自機の基礎攻撃 × 神格倍率 × N/100（固定値だと後半に埃をかぶるので割合にする）
static func scaled(id: String, kami: String) -> float:
	var p := _p()
	if p == null:
		return 0.0
	return p.base_damage() * p.kami_power(kami) * _val(id) * 0.01


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
		mult *= 1.20 + _val("ama_u4") * 0.01
	if en.st["weak"] > 0.0 and _has("uzume_u3"):
		mult *= 1.0 + _val("uzume_u3") * 0.01
	if int(en.st["chill"]["stacks"]) > 0 and _has("iza_u5"):
		mult *= 1.0 + _val("iza_u5") * 0.01
	if en.st["frozen"] > 0.0:
		mult *= 1.5
	if tag == "lightning" and en.st["exposed"] > 0.0 and _has("duo_ama_take"):
		mult *= 1.0 + _val("duo_ama_take") * 0.01
	if tag == "wave" and int(en.st["chill"]["stacks"]) > 0 and _has("duo_susa_iza"):
		mult *= 1.0 + _val("duo_susa_iza") * 0.01
	if tag == "foxfire" and en.st["exposed"] > 0.0 and _has("duo_ama_inari"):
		mult *= 1.0 + _val("duo_ama_inari") * 0.01
	if tag == "lightning" and en.st["frozen"] > 0.0 and _has("duo_take_iza"):
		mult *= 1.0 + _val("duo_take_iza") * 0.01
	if tag == "lightning" and en.is_boss and _has("take_u6"):
		mult *= 1.0 + _val("take_u6") * 0.01
	if int(en.st["hangover"]["stacks"]) > 0 and _has("suku_u8"):
		mult *= 1.0 + _val("suku_u8") * 0.01

	# --- 会心 ---
	if en.st["marked"] and tag != "doom":
		crit = true
		en.st["marked"] = false
	if crit and p != null:
		mult *= p.crit_mult()

	var final := dmg * mult
	var quiet := bool(opts.get("quiet", false))
	en.last_tag = tag
	en.take_damage(final, crit, at, quiet)
	if p != null:
		p.add_call_gauge(final * 0.0006)
		if tag == "lightning" and _has("take_u8"):
			p.add_call_gauge(_val("take_u8") * 0.01)
		if kami != "":
			p.add_kami_xp(kami, final)
		if not quiet:
			_hit_fx(en, at, dir, kami, crit, tag)
		elif crit:
			Fx.sparks(at, -dir, Cfg.C_CRIT, 4, 300.0)

	if not is_instance_valid(en) or en.hp <= 0.0:
		return final

	if kami != "":
		_apply_status(en, kami, tag, at, dir, opts)

	if crit and p != null:
		if _has("inari_leg") and tag != "foxfire":
			var other := nearest_enemy(en.position, 260.0, en)
			if other != null:
				p.spawn_foxfire(en.position, other, scaled("inari_leg", "inari"), "foxfire")

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
		"ama": Sfx.play("hit_light", -14.0, randf_range(0.95, 1.1), 0.04)
		"susa": Sfx.play("hit_storm", -16.0, randf_range(0.9, 1.1), 0.05)
		"iza": Sfx.play("hit_ice", -14.0, randf_range(0.95, 1.1), 0.05)
		"take": pass
		_: Sfx.play("hit", -12.0, randf_range(0.9, 1.15), 0.03)
	if crit:
		Sfx.play("hit_heavy", -10.0, randf_range(1.0, 1.2), 0.05)
		Game.inst.hitstop(0.04 if not en.is_boss else 0.06, 0.05)
	elif en.is_boss and tag in ["cast", "wave", "call"]:
		Game.inst.hitstop(0.05, 0.1)


## 神器ごとの神威
static func _apply_status(en: Enemy, kami: String, tag: String, at: Vector2, _dir: Vector2, opts: Dictionary) -> void:
	var p := _p()
	if p == null:
		return
	var kc: Color = Kami.kami(kami)["color"]
	match kami:
		"ama":
			if en.st["exposed"] <= 0.0:
				Fx.rays(en.position, kc, 6, en.radius * 0.6, 26.0, 0.25)
			en.add_exposed(EXPOSED_T + (_val("ama_u6") if _has("ama_u6") else 0.0))
		"susa":
			if tag in ["wave", "cast", "call"]:
				if _has("susa_u4"):
					en.add_rupture(RUPTURE_T)
					Fx.slash(en.position, randf() * TAU, en.radius * 1.3, kc, 2.0, 0.18, 6.0)
				if _has("duo_susa_iza"):
					en.add_chill(2)
				if _has("duo_susa_inari") and randf() < _val("duo_susa_inari") * 0.01:
					var other := nearest_enemy(en.position, 300.0)
					p.spawn_foxfire(en.position, other if other != null else en, p.base_damage() * 0.7, "foxfire")
		"tsuki":
			var doom := float(opts.get("doom", 0.0))
			if doom > 0.0:
				en.add_doom(doom)
				Fx.ring(en.position, kc, en.radius, en.radius * 2.0, 0.25, 2.0)
		"uzume":
			if tag in ["fan", "cast", "call"]:
				if en.st["weak"] <= 0.0:
					Fx.petals(en.position, kc, 5, 90.0)
				apply_weak(en)
				var cc := float(opts.get("charm_chance", 0.0))
				if cc > 0.0 and randf() < cc:
					en.add_charm(5.0 if tag == "cast" else 3.0)
					Sfx.play("charm", -10.0)
				if tag == "fan" and _has("duo_take_uzume") and randf() < _val("duo_take_uzume") * 0.01:
					lightning(en, p.base_damage() * 2.0 * p.kami_power("take"), at + Vector2(0, -80), 0)
		"inari":
			# 狐憑き：詠唱（主神のみ）か、狐火の会心で印が付く（副神でも神威が働く）
			if tag == "cast" or (tag == "foxfire" and bool(opts.get("crit", false))):
				if not en.st["marked"]:
					Fx.ring(en.position, kc, en.radius * 0.5, en.radius * 2.2, 0.3, 2.5)
				en.mark()
		"iza":
			if tag in ["shard", "cast"]:
				Fx.sparks(at, Vector2.UP, Color(0.85, 0.95, 1.0), 3, 220.0)
				en.add_chill(1 + (int(round(_val("iza_u7"))) if _has("iza_u7") else 0))
		"saru":
			if tag == "wind" and _has("duo_inari_saru") and randf() < _val("duo_inari_saru") * 0.01:
				var other := nearest_enemy(en.position, 300.0)
				if other != null:
					p.spawn_foxfire(en.position, other, p.base_damage() * 0.6, "foxfire")


# ---------------------------------------------------------------------------
# 状態異常のヘルパ
# ---------------------------------------------------------------------------

static func weak_amount() -> float:
	var w := 0.30
	if _has("duo_uzume_suku"):
		w += _val("duo_uzume_suku") * 0.01
	if _has("duo_ama_uzume"):
		w += _val("duo_ama_uzume") * 0.01
	return minf(w, 0.8)


static func hangover_max() -> int:
	return 5 + (int(round(_val("suku_u4"))) if _has("suku_u4") else 0)


static func hangover_slow() -> float:
	return 0.12


static func hangover_dps() -> float:
	var p := _p()
	var base := 3.0
	if p != null and p.gods.has("suku"):
		base = p.base_damage() * 0.35 * p.kami_power("suku")
	return base * (1.0 + _val("suku_u3") * 0.01)


static func rupture_dmg() -> float:
	var p := _p()
	var base := _val("susa_u4") if _has("susa_u4") else 3.0
	if p != null and p.gods.has("susa"):
		base *= p.kami_power("susa")
	return base


static func apply_weak(en: Enemy) -> void:
	en.add_weak(WEAK_T)
	if _has("duo_ama_uzume"):
		en.add_exposed(EXPOSED_T)


static func apply_hangover(en: Enemy, stacks: int, dps: float) -> void:
	en.add_hangover(stacks, dps)
	if _has("duo_uzume_suku"):
		en.add_weak(WEAK_T)


## 持続ダメージ（裂傷・酩酊・凍土など）：演出は控えめに、神徳は入る
static func status_damage(en: Enemy, dmg: float, tag: String) -> void:
	if en == null or not is_instance_valid(en) or en.hp <= 0.0:
		return
	var col: Color = STATUS_COLOR.get(tag, Color(1, 1, 1, 0.8))
	var kami: String = {"rupture": "susa", "hangover": "suku", "frost": "iza"}.get(tag, "")
	en.hp -= dmg
	en.flash = maxf(en.flash, 0.3)
	Fx.number(en.position + Vector2(randf_range(-6, 6), -en.radius), str(int(round(dmg))), col, 11.0)
	var p := _p()
	if p != null:
		p.add_call_gauge(dmg * 0.0004)
		if kami != "":
			p.add_kami_xp(kami, dmg)
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
	Fx.sparks(en.position, Vector2.UP, Color(1.0, 0.97, 0.7), 5, 300.0)
	Fx.ring(en.position, Color(1.0, 0.97, 0.7), 4.0, en.radius * 2.0, 0.2, 3.0)
	Sfx.play("hit_thunder", -12.0, randf_range(0.9, 1.2), 0.04)
	var bonus := 0.0
	if _has("duo_take_suku"):
		bonus = scaled("duo_take_suku", "take") * float(en.st["hangover"]["stacks"])
	var p := _p()
	var crit := p != null and randf() < p.crit_chance()
	hit(en, dmg + bonus, en.position, {"tag": "lightning", "kami": "take", "crit": crit})
	if not is_instance_valid(en):
		return
	if _has("take_u4"):
		en.add_jolt(JOLT_T)
	if _has("duo_take_iza"):
		en.add_chill(2)
	if _has("take_u5"):
		var r := _val("take_u5")
		for o in Game.inst.get_tree().get_nodes_in_group("enemy"):
			if o == en or not is_instance_valid(o) or used.has(o.get_instance_id()):
				continue
			if o.position.distance_to(en.position) <= r:
				hit(o, dmg * 0.5, o.position, {"tag": "lightning", "kami": "take", "quiet": true})
	if _has("take_leg") and randf() < _val("take_leg") * 0.01:
		var extra := nearest_enemy(en.position, 240.0, en, used)
		if extra != null:
			lightning(extra, dmg, en.position, 0, used)
	if chains > 0:
		var nxt := nearest_enemy(en.position, 220.0, en, used)
		if nxt != null:
			lightning(nxt, dmg * 0.75, en.position, chains - 1, used)


static func jolt_trigger(en: Enemy) -> void:
	var d := scaled("take_u4", "take")
	if d <= 0.0:
		d = 15.0
	Fx.bolt(en.position + Vector2(randf_range(-40, 40), -70), en.position, Color(1.0, 0.97, 0.7), 0.14)
	Sfx.play("hit_thunder", -16.0, 1.3, 0.05)
	hit(en, d, en.position, {"tag": "lightning", "kami": "take"})


# ---------------------------------------------------------------------------
# 宿命（時限爆発）
# ---------------------------------------------------------------------------

static func doom_trigger(en: Enemy, dmg: float) -> void:
	if en == null or not is_instance_valid(en) or en.hp <= 0.0:
		return
	var col := Color(0.78, 0.72, 1.0)
	var pos := en.position
	var r := 72.0 * (1.0 + _val("tsuki_u3") * 0.01)
	Fx.ring(pos, col, 6.0, r, 0.35, 6.0)
	Fx.ring(pos, Color(1, 1, 1), 4.0, r * 0.6, 0.25, 3.0)
	Fx.zone(pos, r, col, 0.35)
	Fx.burst(pos, col, 14, 260.0, 3.5, 0.45, true)
	Fx.slash(pos, randf() * TAU, en.radius * 1.6, Color(1, 1, 1), 2.6, 0.2, 7.0)
	Sfx.play("doom", -8.0, randf_range(0.9, 1.1), 0.05)
	Game.inst.hitstop(0.05, 0.05)

	var crit := _has("duo_tsuki_inari") or (_has("tsuki_u9") and randf() < _val("tsuki_u9") * 0.01)
	if _has("tsuki_leg") and not en.is_boss and en.hp / en.max_hp <= _val("tsuki_leg") * 0.01:
		Fx.number(pos + Vector2(0, -en.radius - 10), "裁定", Color(1, 0.9, 1), 18.0, true)
		en.take_damage(en.hp + 1.0, true, pos)
	else:
		hit(en, dmg, pos, {"tag": "doom", "kami": "tsuki", "crit": crit})
	# 新月の影：爆ぜて倒れたら、近くの敵に宿命が移る
	if (not is_instance_valid(en) or en.hp <= 0.0) and _has("tsuki_u7") and randf() < _val("tsuki_u7") * 0.01:
		var nxt := nearest_enemy(pos, 170.0, en)
		if nxt != null:
			nxt.add_doom(dmg * 0.7, 1.1)
			Fx.bolt(pos, nxt.position, col, 0.12)
			Fx.ring(nxt.position, col, nxt.radius, nxt.radius * 2.0, 0.25, 2.0)
	if is_instance_valid(en) and en.hp > 0.0 and _has("duo_iza_tsuki"):
		en.freeze(_val("duo_iza_tsuki"))
	if _has("duo_tsuki_suku"):
		var z := Zone.new()
		z.setup(pos, "fog", r * 0.9, _val("duo_tsuki_suku"), 0.0, Color(0.62, 1.0, 0.55))
		Game.inst.spawn_deferred(z)
	for o in Game.inst.get_tree().get_nodes_in_group("enemy"):
		if o == en or not is_instance_valid(o):
			continue
		if o.position.distance_to(pos) <= r:
			hit(o, dmg * 0.5, o.position, {"tag": "doom", "kami": "tsuki", "crit": crit})


# ---------------------------------------------------------------------------
# 押し戻し・衝突
# ---------------------------------------------------------------------------

static func knockback(en: Enemy, v: Vector2, at: Vector2) -> void:
	en.knockback(v)
	Fx.cone(at, v.normalized(), Color(0.35, 0.82, 0.95), 4, 260.0, 0.5, 3.0, 0.25)
	if _has("duo_susa_take"):
		lightning(en, scaled("duo_susa_take", "take"), at + Vector2(0, -70), 0)
	if _has("susa_leg"):
		hit(en, scaled("susa_leg", "susa"), en.position, {"tag": "wave", "kami": "susa", "quiet": true})


static func collide(en: Enemy, other: Enemy) -> void:
	if not _has("susa_u5"):
		return
	var d := scaled("susa_u5", "susa")
	Fx.ring(en.position, Color(0.35, 0.82, 0.95), 4.0, 40.0, 0.2, 3.0)
	Sfx.play("hit_storm", -12.0, 0.8, 0.05)
	hit(en, d, en.position, {"tag": "collide", "kami": "susa"})
	if other != null and is_instance_valid(other):
		hit(other, d, other.position, {"tag": "collide", "kami": "susa"})


# ---------------------------------------------------------------------------
# 冷気の砕け
# ---------------------------------------------------------------------------

static func shatter(en: Enemy) -> void:
	var col := Color(0.8, 0.95, 1.0)
	Fx.burst(en.position, col, 16, 260.0, 4.0, 0.5)
	Fx.ring(en.position, col, 8.0, en.radius * 3.0, 0.3, 4.0)
	Fx.rays(en.position, col, 8, 4.0, 40.0, 0.25)
	Sfx.play("hit_ice", -6.0, 0.7)
	Game.inst.hitstop(0.05, 0.05)
	var p := _p()
	var d := scaled("iza_u3", "iza") if _has("iza_u3") else (p.base_damage() * 2.0 * p.kami_power("iza") if p != null else 25.0)
	en.freeze(0.8)
	hit(en, d, en.position, {"tag": "shatter", "kami": "iza"})
	if _has("iza_u4"):
		var z := Zone.new()
		z.setup(en.position, "frost", 60.0, _val("iza_u4"), (p.base_damage() * 0.3 if p != null else 3.0), Color(0.58, 0.82, 1.0))
		Game.inst.spawn_deferred(z)
	# 黄泉の門：砕けた所から氷柱が飛び散る
	if _has("iza_u9") and p != null:
		var n := int(round(_val("iza_u9")))
		var sd := p.base_damage() * 0.7 * p.kami_power("iza")
		for i in n:
			var b := Bullet.new()
			b.shape_kind = 10
			b.radius = 5.0
			b.kami = "iza"
			b.tag = "shard"
			b.color = Color(0.85, 0.95, 1.0)
			b.life = 0.7
			b.crit_chance = p.crit_chance()
			var a := TAU * float(i) / float(n) + randf_range(-0.1, 0.1)
			b.setup(en.position + Vector2(cos(a), sin(a)) * 12.0, Vector2(cos(a), sin(a)) * 520.0, sd, true)
			Game.inst.spawn_deferred(b)
	if _has("iza_leg"):
		var ld := scaled("iza_leg", "iza")
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
	if _has("uzume_leg") and en.st["weak"] > 0.0 and randf() < _val("uzume_leg") * 0.01:
		p.heal(6.0, true)
	# 日輪の恵み：照覧された敵を倒すと回復
	if _has("ama_u8") and en.st["exposed"] > 0.0 and randf() < _val("ama_u8") * 0.01:
		p.heal(1.0, false)
		Fx.sparks(en.position, Vector2.UP, Color(1.0, 0.84, 0.42), 3, 160.0)
	# 狐火の連鎖：狐火で倒すと次の敵へ跳ぶ
	if _has("inari_u7") and en.last_tag == "foxfire" and randf() < _val("inari_u7") * 0.01:
		var other := nearest_enemy(en.position, 320.0, en)
		if other != null:
			p.spawn_foxfire(en.position, other, p.base_damage() * 0.75 * p.kami_power("inari"), "foxfire")
	# 百薬の長：酩酊した敵を倒すと霧が残る
	if _has("suku_u9") and int(en.st["hangover"]["stacks"]) > 0 and randf() < _val("suku_u9") * 0.01:
		var z := Zone.new()
		z.setup(en.position, "fog", 52.0, 2.2, 0.0, Color(0.62, 1.0, 0.55))
		Game.inst.spawn_deferred(z)


## 自機弾が敵弾を消したとき（潮騒）
static func on_erase(b: Bullet) -> void:
	var p := _p()
	if p == null:
		return
	if b.kami == "susa" and _has("susa_u7"):
		p.add_call_gauge(_val("susa_u7") * 0.01)
		Fx.sparks(b.position, Vector2.UP, Color(0.35, 0.82, 0.95), 2, 160.0)


## 扇が手元に戻ったとき（舞い手の護り）
static func on_fan_return(_b: Bullet) -> void:
	var p := _p()
	if p == null:
		return
	if _has("uzume_u9") and p.hp < float(p.stats["max_hp"]) and p.fan_heal_cd <= 0.0:
		p.fan_heal_cd = 3.0
		p.heal(_val("uzume_u9"), false)
		Fx.petals(p.position, Color(1.0, 0.58, 0.78), 3, 60.0)


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
