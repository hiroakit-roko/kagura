class_name Player
extends Area2D

## 自機（魔法少女）。walk.gif から抜き出した後ろ姿のスプライトで歩く。
##   - 基本の弾（巫矢）は常に自動で撃つ
##   - 迎えた神ごとに Weapon（神器）が付く。主神は 100%、副神は 50%
##   - 神ごとに神格レベル（kami_lv）があり、神器のダメージで神徳（kami_xp）が溜まる
##   - Z：詠唱（主神の技、2 発まで）  X：神招き（主神の技、ゲージ 1/4 以上）  Space：疾走（無敵）

signal died
signal leveled_up

const SHEET := "res://image/player_walk.png"
const HFRAMES := 10
const SPR_SCALE := 0.5

var stats := {
	"max_hp": 100.0,
	"damage": 10.0,
	"fire_rate": 5.0,
	"bullet_speed": 900.0,
	"speed": 330.0,
	"crit": 0.05,
	"crit_mult": 2.0,
	"xp_mult": 1.0,
	"magnet": 170.0,
	"dash_cd": 2.2,
	"cast_cd": 5.0,
	"cast_max": 2,
}

# ---- 神と恩恵 ----
var boons := {}          # id -> {"rar": int, "lv": int}
var gods: Array = []     # [主神, 副神, 副神]
var kami_lv := {}        # 神 id -> 神格レベル
var kami_xp := {}        # 神 id -> 神徳（現在の段階での蓄積）
var weapons := {}        # 神 id -> Weapon
var familiar_id := ""    # 使い魔
var familiar: Familiar
var kami_dmg := {}       # 神 id -> 与えたダメージの累計（貢献度の表示用）
var last_hit_by := ""    # 最後に受けた攻撃の相手（死因の表示用）
var grazes := 0

# ---- 状態 ----
var hp := 100.0
var level := 1
var xp := 0.0
var xp_next := 50.0
var pending_levels := 0
var alive := true

var radius := 7.0
var fire_cd := 0.0
var cast_charges := 2
var cast_cd := 0.0
var iframe := 0.0
var shield := 0
var shield_t := 0.0
var regen_t := 0.0
var dash_t := 0.0
var dash_cool := 0.0
var dash_dir := Vector2.UP
var focus := false
var t := 0.0
var call_gauge := 0.0
var call_t := 0.0
var call_kind := ""
var call_tick := 0.0
var call_power := 1.0
var haste_t := 0.0           # 道開き：移動と連射が速くなる時間
var dash_mult := 1.0         # 疾走の距離倍率（神の強化で伸ばす余地）
var _dash_ready_ping := true
var _contact_cd := 0.0
var _ghost_t := 0.0
var _miracle_cd := 0.0
var _grazed := {}
var _drones: Array = []
var _anim := 0.0
var _lean := 0.0
var _move_dir := Vector2.ZERO
var spr: Sprite2D
var tex: Texture2D


func _ready() -> void:
	z_index = Cfg.Z_PLAYER
	collision_layer = Cfg.L_PLAYER
	collision_mask = Cfg.L_ENEMY | Cfg.L_PICKUP
	monitoring = true
	monitorable = true
	add_to_group("player")
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c
	add_child(cs)
	area_entered.connect(_on_area)
	hp = stats["max_hp"]
	cast_charges = int(stats["cast_max"])

	tex = load(SHEET)
	spr = Sprite2D.new()
	spr.texture = tex
	spr.hframes = HFRAMES
	spr.scale = Vector2(SPR_SCALE, SPR_SCALE)
	spr.position = Vector2(0, 9)
	spr.z_index = 1
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(spr)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	t += delta
	iframe = maxf(0.0, iframe - delta)
	dash_cool = maxf(0.0, dash_cool - delta)
	_contact_cd = maxf(0.0, _contact_cd - delta)
	_miracle_cd = maxf(0.0, _miracle_cd - delta)
	haste_t = maxf(0.0, haste_t - delta)

	# 疾走が使えるようになった瞬間を知らせる
	if dash_cool <= 0.0 and not _dash_ready_ping:
		_dash_ready_ping = true
		Fx.ring(position + Vector2(0, 30), Color(1, 1, 1), 6.0, 30.0, 0.25, 2.0)
		Sfx.play("suzu", -24.0, 1.8)

	_move(delta)
	_animate(delta)
	_weapons(delta)
	_call_tick(delta)
	_upkeep(delta)
	_contact()
	_graze()
	queue_redraw()


# ---------- 神・恩恵の参照 ----------

func has(id: String) -> bool:
	return boons.has(id)


func val(id: String) -> float:
	if not boons.has(id):
		return 0.0
	var b := Kami.boon(id)
	if b.is_empty():
		return 0.0
	return Kami.value(b, int(boons[id]["rar"]), int(boons[id]["lv"]))


func main_god() -> String:
	return String(gods[0]) if gods.size() > 0 else ""


func is_main(kami_id: String) -> bool:
	return main_god() == kami_id


func kami_color(kami_id: String) -> Color:
	var k := Kami.kami(kami_id)
	return k["color"] if not k.is_empty() else Cfg.C_PBULLET


## 神器の威力倍率：主神 1.0 / 副神 0.5 × 神格レベル
func kami_power(kami_id: String) -> float:
	var lv: int = kami_lv.get(kami_id, 1)
	return (1.0 if is_main(kami_id) else 0.5) * Kami.kami_power(lv)


## 基本のダメージ（位で少しずつ伸びる）
func base_damage() -> float:
	return float(stats["damage"]) * (1.0 + float(level - 1) * 0.03)


## 使い魔を連れる
func set_familiar(id: String) -> void:
	familiar_id = id
	if familiar != null and is_instance_valid(familiar):
		familiar.queue_free()
	familiar = Familiar.new()
	familiar.setup(id, self)
	Game.inst.world.add_child.call_deferred(familiar)


## 神を迎える：神器がすぐに付く
func add_god(kami_id: String) -> void:
	if gods.has(kami_id) or gods.size() >= Boons.MAX_KAMI:
		return
	gods.append(kami_id)
	kami_lv[kami_id] = 1
	kami_xp[kami_id] = 0.0
	var w := Weapon.new()
	w.setup(kami_id, self)
	weapons[kami_id] = w
	Game.inst.world.add_child.call_deferred(w)
	var k := Kami.kami(kami_id)
	Fx.ring(position, k["color"], 10.0, 160.0, 0.6, 5.0)
	Fx.rays(position, k["color"], 14, 20.0, 160.0, 0.5)
	on_boons_changed()


## 神徳：神器が与えたダメージで神格が上がる
func add_kami_xp(kami_id: String, amount: float) -> void:
	if not kami_lv.has(kami_id):
		return
	var lv: int = kami_lv[kami_id]
	if lv >= 10:
		return
	kami_xp[kami_id] = float(kami_xp[kami_id]) + amount
	kami_dmg[kami_id] = float(kami_dmg.get(kami_id, 0.0)) + amount
	var need := Kami.kami_xp_need(lv)
	if float(kami_xp[kami_id]) >= need:
		kami_xp[kami_id] = float(kami_xp[kami_id]) - need
		kami_level_up(kami_id)


func kami_level_up(kami_id: String) -> void:
	kami_lv[kami_id] = int(kami_lv.get(kami_id, 1)) + 1
	var k := Kami.kami(kami_id)
	var lv: int = kami_lv[kami_id]
	Sfx.play("suzu", -8.0, 1.1)
	Fx.ring(position, k["color"], 20.0, 140.0, 0.5, 4.0)
	Fx.petals(position, k["color"], 14, 200.0)
	var note := "神器の威力 +12%"
	if lv % 3 == 0 or lv % 4 == 0 or lv % 5 == 0:
		note = "神器の威力 +12%。節目：弾数や大きさが増えた"
	Game.inst.ui.banner(String(k["name"]) + "　神格 %d" % lv, String(k["weapon"]) + "　" + note, k["color"])
	on_boons_changed()


## 契約の代償：迎えた神ごとの軽いペナルティ
func cost_mult(kind: String) -> float:
	var m := 1.0
	match kind:
		"hp":
			if gods.has("ama"): m *= 0.9
			if gods.has("uzume"): m *= 0.9
		"taken":
			if gods.has("susa"): m *= 1.08
			if gods.has("iza"): m *= 1.08
		"cast_cd":
			if gods.has("take"): m *= 1.15
		"speed":
			if gods.has("tsuki"): m *= 0.94
		"magnet":
			if gods.has("inari"): m *= 0.8
		"gauge":
			if gods.has("suku"): m *= 0.85
		"dash_cd":
			if gods.has("saru"): m *= 1.1
	return m


func on_boons_changed() -> void:
	var base_hp := (100.0 + float(level - 1) * 3.0) * cost_mult("hp")
	var new_max := base_hp + (val("uzume_u5") if has("uzume_u5") else 0.0)
	var diff := new_max - float(stats["max_hp"])
	stats["max_hp"] = new_max
	if diff > 0.0:
		hp = minf(new_max, hp + diff)
	hp = minf(hp, new_max)
	stats["cast_max"] = 2 + (1 if has("saru_u5") else 0)
	cast_charges = mini(cast_charges + 1, int(stats["cast_max"]))
	# 眷属の狐
	var want := int(round(val("inari_u4"))) if has("inari_u4") else 0
	if want != _drones.size():
		for d in _drones:
			if is_instance_valid(d):
				d.queue_free()
		_drones.clear()
		for i in want:
			var d := Drone.new()
			d.index = i
			d.total = want
			d.owner_ship = self
			add_child(d)
			_drones.append(d)
	if has("ama_u5") and shield == 0:
		shield_t = minf(shield_t, 2.0)
	if Game.inst != null and Game.inst.stars != null and gods.size() > 0:
		Game.inst.stars.tint = kami_color(main_god()).darkened(0.35)


# ---------- 移動 ----------

func _input_dir() -> Vector2:
	var d := Vector2.ZERO
	d.x = float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) \
		- float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	d.y = float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) \
		- float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	return d.normalized()


func move_speed() -> float:
	var m := 1.0 + val("saru_u3") * 0.01
	if gods.has("saru"):
		m += 0.10
	if familiar_id == "karasu":
		m += 0.06
	if haste_t > 0.0:
		m += 0.35
	return float(stats["speed"]) * m * cost_mult("speed")


func dash_cd_time() -> float:
	return float(stats["dash_cd"]) * (1.0 - val("saru_u4") * 0.01) * cost_mult("dash_cd")


func _touch() -> Touch:
	return Touch.inst if (Touch.inst != null and Touch.inst.active) else null


func _move(delta: float) -> void:
	focus = Input.is_key_pressed(KEY_SHIFT)
	var dir := _input_dir()
	var tc := _touch()
	var touch_move := Vector2.ZERO
	if tc != null:
		touch_move = tc.consume_move()
		if dir == Vector2.ZERO and touch_move.length() > 0.01:
			dir = touch_move.normalized()
	_move_dir = dir

	if dash_t > 0.0:
		dash_t -= delta
		iframe = maxf(iframe, 0.05)
		position += dash_dir * move_speed() * 2.6 * dash_mult * delta
		_ghost_t -= delta
		if _ghost_t <= 0.0:
			_ghost_t = 0.025
			var gc := kami_color(main_god()) if main_god() != "" else Cfg.C_PLAYER
			Fx.ghost(tex, HFRAMES, int(_anim) % HFRAMES, position + spr.position, SPR_SCALE, rotation, gc, 0.35)
			Fx.sparks(position, -dash_dir, Color(1, 1, 1), 2, 220.0)
		if dash_t <= 0.0:
			iframe = maxf(iframe, 0.18)
	else:
		var want_dash := Input.is_key_pressed(KEY_SPACE)
		if tc != null:
			var flick := tc.take_flick()
			if flick != Vector2.ZERO:
				want_dash = true
				dir = flick
		if want_dash and dash_cool <= 0.0 and dir != Vector2.ZERO:
			_start_dash(dir)
		if tc != null and touch_move != Vector2.ZERO:
			var maxlen := move_speed() * 3.6 * delta
			position += touch_move.limit_length(maxlen)
		else:
			var sp := move_speed() * (0.42 if focus else 1.0)
			position += dir * sp * delta

	var r := Cfg.play_rect()
	position.x = clampf(position.x, r.position.x + 10.0, r.end.x - 10.0)
	position.y = clampf(position.y, r.position.y + 60.0, r.end.y - 30.0)


## 疾走：短い無敵。音・残像・光の輪でしっかり分かるようにする
func _start_dash(dir: Vector2) -> void:
	dash_t = 0.18
	dash_cool = dash_cd_time()
	_dash_ready_ping = false
	dash_dir = dir
	var col := kami_color(main_god()) if main_god() != "" else Cfg.C_PLAYER
	Fx.ring(position, Color(1, 1, 1), 8.0, 70.0, 0.25, 4.0)
	Fx.ring(position, col, 6.0, 110.0, 0.35, 3.0)
	Fx.slash(position, dir.angle(), 30.0, Color(1, 1, 1), 1.6, 0.18, 6.0)
	Fx.burst(position, col, 10, 200.0, 3.0, 0.3, true)
	Fx.number(position + Vector2(0, -50), "無敵", Color(1, 1, 1, 0.9), 13.0)
	Sfx.play("dash", -4.0, randf_range(0.95, 1.1))
	Sfx.play("suzu", -18.0, 1.5)
	Game.inst.hitstop(0.03, 0.3)


func _enemies_within(r: float) -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.position.distance_to(position) <= r:
			out.append(e)
	return out


# ---------- アニメーション ----------

func _animate(delta: float) -> void:
	var moving := _move_dir.length() > 0.1
	var fps := 10.0 if moving else 5.5
	if focus:
		fps *= 0.7
	_anim += delta * fps
	spr.frame = int(_anim) % HFRAMES
	_lean = lerpf(_lean, _move_dir.x * 0.13, clampf(9.0 * delta, 0.0, 1.0))
	spr.rotation = _lean
	spr.position.y = 9.0 + sin(_anim * PI) * 1.2
	if dash_t > 0.0:
		spr.modulate = Color(1.6, 1.5, 1.9, 0.9)
	elif iframe > 0.0:
		spr.modulate = Color(1.2, 1.2, 1.4, 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 40.0)))
	else:
		spr.modulate = Color(1, 1, 1, 1)


# ---------- 武装 ----------

func crit_chance() -> float:
	var c: float = stats["crit"] + val("inari_u3") * 0.01
	return minf(c, 0.95)


func crit_mult() -> float:
	return float(stats["crit_mult"]) + val("inari_u5") * 0.01 + val("duo_tsuki_inari") * 0.01


func fire_rate_mult() -> float:
	return 1.0 + (0.4 if haste_t > 0.0 else 0.0)


func bullet_speed() -> float:
	return float(stats["bullet_speed"])


func _weapons(delta: float) -> void:
	fire_cd -= delta
	if fire_cd <= 0.0:
		fire_cd = 1.0 / (float(stats["fire_rate"]) * fire_rate_mult())
		_fire_main()

	if cast_charges < int(stats["cast_max"]):
		cast_cd -= delta
		if cast_cd <= 0.0:
			cast_charges += 1
			cast_cd = cast_cd_time()
			Sfx.play("suzu", -22.0, 1.4)
	var tc := _touch()
	if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_J) or (tc != null and tc.take("cast")):
		_try_cast()
	if Input.is_key_pressed(KEY_X) or Input.is_key_pressed(KEY_K) or (tc != null and tc.take("call")):
		_try_call()


func cast_cd_time() -> float:
	return float(stats["cast_cd"]) * (1.0 - val("saru_u5") * 0.01) * cost_mult("cast_cd")


## 基本の弾：巫矢
func _fire_main() -> void:
	var nose := position + Vector2(0, -34.0)
	var col := kami_color(main_god()).lerp(Color(1, 1, 1), 0.4) if main_god() != "" else Cfg.C_PBULLET
	var spread := deg_to_rad(randf_range(-2.0, 2.0) * (0.4 if focus else 1.0))
	var b := Bullet.new()
	b.radius = 4.5
	b.trail_len = 20.0
	b.color = col
	b.kami = ""
	b.tag = "attack"
	b.crit_chance = crit_chance()
	b.setup(nose, Vector2(cos(-PI * 0.5 + spread), sin(-PI * 0.5 + spread)) * bullet_speed(), base_damage(), true)
	Game.inst.world.add_child(b)
	Fx.cone(nose, Vector2.UP, col, 2, 90.0, 0.4, 2.0, 0.12)
	Sfx.play("shoot", -22.0, randf_range(0.95, 1.1), 0.035)


func spawn_foxfire(from: Vector2, target: Node2D, dmg: float, tag := "foxfire") -> void:
	var b := Bullet.new()
	b.shape_kind = 3
	b.radius = 6.0
	b.homing = 7.0
	b.color = kami_color("inari")
	b.kami = "inari"
	b.tag = tag
	b.crit_chance = crit_chance()
	var dir := (target.global_position - from).normalized() if target != null else Vector2.UP.rotated(randf_range(-0.6, 0.6))
	b.setup(from, dir * 520.0, dmg, true)
	Game.inst.spawn_deferred(b)
	Sfx.play("fox", -20.0, randf_range(0.9, 1.2), 0.06)


# ---------- 詠唱（主神の技） ----------

func _try_cast() -> void:
	if cast_charges <= 0 or main_god() == "":
		return
	cast_charges -= 1
	if cast_cd <= 0.0:
		cast_cd = cast_cd_time()
	var kami := main_god()
	var col := kami_color(kami)
	var dmg := base_damage() * 5.0 * Kami.kami_power(int(kami_lv.get(kami, 1)))
	var from := position + Vector2(0, -30.0)
	var k := Kami.kami(kami)
	Fx.ring(from, col, 6.0, 60.0, 0.25, 3.0)
	Sfx.play("cast", -8.0, randf_range(0.95, 1.05))
	Game.inst.ui.banner_small(String(k["cast"]), col)
	match kami:
		"ama":
			var b := _cast_bullet(kami, 5, 44.0)
			b.reflect = true
			b.pierce = 999
			b.life = 2.6
			b.setup(from, Vector2(0, -150.0), dmg, true)
			Game.inst.world.add_child(b)
		"susa":
			var b := _cast_bullet(kami, 6, 26.0)
			b.mode = "vortex"
			b.pierce = 999
			b.kb = 480.0
			b.life = 2.2
			b.setup(from, Vector2(0, -210.0), dmg, true)
			Game.inst.world.add_child(b)
		"take":
			var b := _cast_bullet(kami, 2, 12.0)
			b.mode = "cloud"
			b.zone_dmg = dmg * 0.4
			b.setup(from, Vector2(0, -420.0), dmg, true)
			Game.inst.world.add_child(b)
		"tsuki":
			var b := _cast_bullet(kami, 2, 14.0)
			b.pierce = 1
			b.doom = dmg * 1.6
			b.setup(from, Vector2(0, -480.0), dmg * 0.5, true)
			Game.inst.world.add_child(b)
		"uzume":
			var b := _cast_bullet(kami, 2, 13.0)
			b.charm_chance = 1.0
			b.pierce = 2
			b.setup(from, Vector2(0, -480.0), dmg * 0.6, true)
			Game.inst.world.add_child(b)
		"inari":
			var target := Combat.nearest_enemy(position, 900.0)
			for i in 6:
				spawn_foxfire(from + Vector2((float(i) - 2.5) * 12.0, 0), target, dmg * 0.35, "cast")
		"suku":
			var b := _cast_bullet(kami, 9, 12.0)
			b.zone_kind = "fog"
			b.zone_r = 110.0 * (1.0 + val("suku_u1") * 0.01)
			b.zone_life = 4.5 * (1.0 + val("suku_u2") * 0.01)
			b.life = 0.55
			b.setup(from, Vector2(0, -520.0), dmg * 0.5, true)
			Game.inst.world.add_child(b)
		"iza":
			var b := _cast_bullet(kami, 2, 12.0)
			b.zone_kind = "frost"
			b.zone_r = 100.0
			b.zone_life = 3.5
			b.zone_dmg = dmg * 0.35
			b.life = 0.6
			b.setup(from, Vector2(0, -520.0), dmg * 0.5, true)
			Game.inst.world.add_child(b)
		"saru":
			haste_t = 4.0
			Fx.slash(from, -PI * 0.5, 160.0, col, 2.4, 0.3, 14.0)
			for eb in get_tree().get_nodes_in_group("ebullet"):
				if is_instance_valid(eb) and eb.position.y < position.y and absf(eb.position.x - position.x) < 160.0:
					eb.vanish()
			Sfx.play("dash", -6.0, 0.8)


func _cast_bullet(kami: String, shape: int, radius: float) -> Bullet:
	var b := Bullet.new()
	b.shape_kind = shape
	b.radius = radius
	b.kami = kami
	b.tag = "cast"
	b.color = kami_color(kami)
	b.crit_chance = crit_chance()
	return b


# ---------- 神招き（主神の技） ----------

func add_call_gauge(amount: float) -> void:
	if main_god() == "":
		return
	call_gauge = clampf(call_gauge + amount * cost_mult("gauge"), 0.0, 1.0)


func _try_call() -> void:
	var kami := main_god()
	if kami == "" or call_t > 0.0 or call_gauge < 0.25:
		return
	var greater := call_gauge >= 0.999
	call_power = 1.0 if not greater else 1.8
	call_gauge = 0.0 if greater else call_gauge - 0.25
	var v := base_damage() * 4.0 * Kami.kami_power(int(kami_lv.get(kami, 1))) * (1.0 if not greater else 1.4)
	var col := kami_color(kami)
	var k := Kami.kami(kami)
	Sfx.play("flute", -4.0)
	Sfx.play("taiko", -6.0)
	Music.duck(1.6)
	Fx.flash(Cfg.with_a(col, 0.55), 0.35)
	Fx.ring(position, col, 20.0, 400.0, 0.6, 6.0)
	Fx.shake_add(10.0)
	Game.inst.hitstop(0.25, 0.08)
	Game.inst.ui.banner(String(k["call"]), String(k["name"]) + ("　大神招き" if greater else ""), col)
	match kami:
		"ama":
			call_kind = "sun"
			call_t = 2.4 * call_power
			call_tick = 0.0
		"take":
			call_kind = "storm"
			call_t = 2.2 * call_power
			call_tick = 0.0
		"susa":
			Fx.slash(Vector2(Cfg.W * 0.5, position.y - 200.0), -PI * 0.5, 420.0, col, 2.8, 0.4, 26.0)
			Fx.slash(Vector2(Cfg.W * 0.5, position.y - 220.0), -PI * 0.5, 300.0, Color(1, 1, 1), 2.6, 0.3, 10.0)
			Game.inst.erase_all_ebullets()
			for e in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(e) and e.position.y < position.y:
					Combat.hit(e, v * 3.0, e.position, {"tag": "call", "kami": "susa", "dir": Vector2.UP, "kb": 700.0})
			Fx.shake_add(18.0)
		"tsuki":
			Game.inst.hitstop(1.0, 0.12)
			for e in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(e):
					e.add_doom(v * 3.0 * (1.0 + val("tsuki_u2") * 0.01), 1.3)
		"uzume":
			for e in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(e):
					e.add_charm(4.0 * call_power)
			Fx.petals(position, col, 40, 260.0)
			Sfx.play("charm", -4.0, 0.8)
		"inari":
			var n := 9 if not greater else 15
			for i in n:
				var target := Combat.nearest_enemy(position, 2000.0)
				var b := Bullet.new()
				b.shape_kind = 3
				b.radius = 9.0
				b.homing = 5.5
				b.pierce = 1
				b.color = col
				b.kami = "inari"
				b.tag = "call"
				b.crit_chance = crit_chance() + 0.3
				var a := -PI * 0.5 + (float(i) - float(n - 1) * 0.5) * 0.28
				b.setup(position + Vector2(0, -20), Vector2(cos(a), sin(a)) * 500.0, v * 1.5, true)
				if target != null:
					b._target = target
				Game.inst.world.add_child(b)
		"suku":
			for e in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(e):
					Combat.apply_hangover(e, Combat.hangover_max(), Combat.hangover_dps())
			heal(float(stats["max_hp"]) * 0.3 * call_power, true)
			Fx.zone(position, 200.0, col, 0.8)
		"iza":
			for e in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(e):
					e.freeze(3.0 * call_power)
			Fx.flash(Cfg.with_a(Color(0.8, 0.95, 1.0), 0.6), 0.4)
		"saru":
			call_kind = "slow"
			call_t = 3.0 * call_power
			Game.enemy_slow = 0.35
			Game.enemy_bullet_slow = 0.6


func _call_tick(delta: float) -> void:
	if call_t <= 0.0:
		return
	call_t -= delta
	var kami := main_god()
	var v := base_damage() * 4.0 * Kami.kami_power(int(kami_lv.get(kami, 1))) * (1.0 if call_power <= 1.0 else 1.4)
	var col := kami_color(kami)
	call_tick -= delta
	match call_kind:
		"sun":
			iframe = maxf(iframe, 0.1)
			if call_tick <= 0.0:
				call_tick = 0.25
				Fx.rays(position, col, 16, 40.0, 700.0, 0.3)
				for e in get_tree().get_nodes_in_group("enemy"):
					if is_instance_valid(e):
						e.add_exposed(Combat.EXPOSED_T)
						Combat.hit(e, v * 0.25, e.position, {"tag": "light", "kami": "ama"})
		"storm":
			if call_tick <= 0.0:
				call_tick = 0.11
				var es := get_tree().get_nodes_in_group("enemy")
				if not es.is_empty():
					var e = es[randi() % es.size()]
					if is_instance_valid(e):
						Combat.lightning(e, v, Vector2(e.position.x + randf_range(-60, 60), -20), 0)
				Fx.shake_add(1.5)
		"slow":
			if call_tick <= 0.0:
				call_tick = 0.2
				Fx.ring(position, col, 40.0, 60.0, 0.3, 1.5)
	if call_t <= 0.0:
		if call_kind == "slow":
			Game.enemy_slow = 1.0
			Game.enemy_bullet_slow = 0.0
		call_kind = ""


# ---------- 維持処理 ----------

func _upkeep(delta: float) -> void:
	if has("suku_u5"):
		regen_t += delta
		if regen_t >= 1.0:
			regen_t -= 1.0
			if hp < stats["max_hp"]:
				heal(val("suku_u5"), false)

	if has("ama_u5") and shield < 1:
		shield_t -= delta
		if shield_t <= 0.0:
			shield = 1
			shield_t = val("ama_u5")
			Fx.ring(position, Cfg.C_GOLD, 12.0, 40.0, 0.3)
			Sfx.play("suzu", -14.0, 1.0)


func _contact() -> void:
	if _contact_cd > 0.0 or iframe > 0.0:
		return
	for a in get_overlapping_areas():
		if a is Enemy:
			_contact_cd = 0.4
			take_damage(float((a as Enemy).contact_dmg) * (a as Enemy).out_dmg_mult(), false, Vector2.ZERO, (a as Enemy).display_name() + "の体当たり")
			return


## かすり（グレイズ）：敵弾のすれすれを抜けると神招きゲージが少し溜まり、功徳にも加算される
func _graze() -> void:
	for b in get_tree().get_nodes_in_group("ebullet"):
		if not is_instance_valid(b) or _grazed.has(b.get_instance_id()):
			continue
		var d: float = b.position.distance_to(position)
		if d < 30.0 and d > radius + b.radius:
			_grazed[b.get_instance_id()] = true
			grazes += 1
			add_call_gauge(0.004 + val("saru_leg") * 0.01)
			Fx.sparks(b.position, Vector2.UP, Color(1, 1, 1), 2, 200.0)
			Fx.number(position + Vector2(0, -40), "かすり", Color(1, 1, 1, 0.6), 9.0)
	if _grazed.size() > 400:
		_grazed.clear()


func _on_area(a: Area2D) -> void:
	if a is Pickup:
		var p := a as Pickup
		match p.kind:
			Pickup.Kind.XP:
				add_xp(p.value)
				Sfx.play("pickup", -22.0, randf_range(1.0, 1.25), 0.02)
			Pickup.Kind.HEAL:
				heal(p.value, true)
				Sfx.play("heal", -12.0)
			Pickup.Kind.MIKI:
				Sfx.play("miki", -6.0)
				Game.inst.on_miki_picked()
		Fx.burst(p.position, p.color_of(), 5, 110.0, 2.5, 0.28, true)
		p.queue_free()
	elif a is Enemy and _contact_cd <= 0.0 and iframe <= 0.0:
		_contact_cd = 0.4
		take_damage(float((a as Enemy).contact_dmg) * (a as Enemy).out_dmg_mult(), false, Vector2.ZERO, (a as Enemy).display_name() + "の体当たり")


# ---------- HP / XP ----------

func take_damage(d: float, _crit := false, _at := Vector2.ZERO, source := "") -> void:
	if not alive or iframe > 0.0:
		return
	if source != "":
		last_hit_by = source
	d *= cost_mult("taken")
	if shield > 0:
		shield -= 1
		shield_t = val("ama_u5") if has("ama_u5") else 99.0
		iframe = 0.7
		Fx.ring(position, Cfg.C_GOLD, 14.0, 90.0, 0.35, 4.0)
		Fx.sparks(position, Vector2.UP, Cfg.C_GOLD, 14, 300.0)
		Fx.shake_add(5.0)
		Sfx.play("deflect", -4.0, 0.8)
		Sfx.play("suzu", -8.0)
		return

	hp -= d
	iframe = 1.0 * (1.25 if familiar_id == "shiki" else 1.0)
	add_call_gauge(0.12)
	Fx.shake_add(9.0)
	Fx.flash(Color(1, 0.3, 0.4, 0.25), 0.15)
	Fx.burst(position, Cfg.C_ENEMY, 14, 250.0, 4.0, 0.45)
	Fx.number(position + Vector2(0, -40), "-" + str(int(round(d))), Color(1, 0.45, 0.5), 17.0, true)
	Sfx.play("hurt", -6.0)
	Game.inst.hitstop(0.08, 0.05)
	if hp > 0.0 and has("suku_leg") and _miracle_cd <= 0.0 and hp / float(stats["max_hp"]) <= 0.3:
		_miracle_cd = 60.0
		heal(float(stats["max_hp"]) * val("suku_leg") * 0.01, true)
		Fx.ring(position, Color(0.62, 1.0, 0.55), 10.0, 160.0, 0.5, 5.0)
		Sfx.play("heal", -2.0, 0.8)
	if hp <= 0.0:
		hp = 0.0
		_die()


func heal(amount: float, show := true) -> void:
	var before := hp
	hp = minf(stats["max_hp"], hp + amount)
	if show and hp > before:
		Fx.number(position + Vector2(0, -44), "+" + str(int(round(hp - before))), Cfg.C_HP, 16.0)


func add_xp(amount: float) -> void:
	xp += amount * float(stats["xp_mult"])
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = 36.0 + float(level) * 20.0 + pow(float(level), 1.5) * 2.5
		pending_levels += 1
		stats["max_hp"] = float(stats["max_hp"]) + 3.0
		hp += 3.0
		leveled_up.emit()


func magnet_range() -> float:
	return float(stats["magnet"]) * (1.35 if familiar_id == "neko" else 1.0) * cost_mult("magnet")


func _die() -> void:
	alive = false
	Fx.burst(position, Cfg.C_PLAYER, 40, 420.0, 6.0, 1.0)
	Fx.petals(position, Color(1, 0.8, 0.95), 30, 220.0)
	Fx.ring(position, Color(1, 1, 1), 8.0, 300.0, 0.7)
	Fx.shake_add(22.0)
	Sfx.play("boom", -4.0)
	Sfx.play("gameover", -8.0)
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	for w in weapons.values():
		if is_instance_valid(w):
			w.queue_free()
	died.emit()


# ---------- 描画（スプライトの下に描く魔法陣など） ----------

func _draw() -> void:
	var main := main_god()
	var col := kami_color(main) if main != "" else Cfg.C_PLAYER

	var mr := 26.0 + 2.0 * sin(t * 3.0)
	var ma := 0.35 if main != "" else 0.18
	draw_set_transform(Vector2(0, 34), 0.0, Vector2(1.0, 0.42))
	draw_arc(Vector2.ZERO, mr, 0, TAU, 40, Cfg.with_a(col, ma), 2.0, true)
	draw_arc(Vector2.ZERO, mr * 0.72, 0, TAU, 32, Cfg.with_a(col, ma * 0.7), 1.0, true)
	for i in 6:
		var a := t * 1.2 + TAU * float(i) / 6.0
		draw_line(Vector2(cos(a), sin(a)) * mr * 0.72, Vector2(cos(a + TAU / 3.0), sin(a + TAU / 3.0)) * mr * 0.72,
				Cfg.with_a(col, ma * 0.5), 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if iframe > 0.0:
		var k := 0.5 + 0.5 * sin(t * 24.0)
		draw_arc(Vector2(0, -4), 30.0 + 3.0 * k, 0, TAU, 40, Color(1, 1, 1, 0.35 + 0.3 * k), 2.0, true)
		for i in 4:
			var a := t * 6.0 + TAU * float(i) / 4.0
			draw_circle(Vector2(cos(a), sin(a)) * (30.0 + 3.0 * k) + Vector2(0, -4), 2.5, Color(1, 1, 1, 0.8))

	if shield > 0:
		draw_arc(Vector2(0, -6), 34.0, 0.0, TAU, 40,
				Cfg.with_a(Cfg.C_GOLD, 0.35 + 0.12 * sin(t * 3.0)), 2.0, true)
		draw_arc(Vector2(0, -6), 30.0, t * 2.0, t * 2.0 + 1.2, 12, Color(1, 1, 1, 0.5), 2.0, true)

	if haste_t > 0.0:
		for i in 3:
			var y := fmod(t * 300.0 + float(i) * 25.0, 70.0)
			draw_line(Vector2(-14, 20 + y), Vector2(-14, 32 + y), Color(0.72, 1.0, 0.98, 0.5), 1.5)
			draw_line(Vector2(14, 20 + y), Vector2(14, 32 + y), Color(0.72, 1.0, 0.98, 0.5), 1.5)

	if call_t > 0.0 and call_kind == "sun":
		draw_circle(Vector2(0, -6), 60.0 + 10.0 * sin(t * 12.0), Cfg.with_a(Cfg.C_GOLD, 0.18))

	if main != "" and cast_charges > 0:
		draw_circle(Vector2(0, -34), 3.0 + sin(t * 8.0), Cfg.with_a(col, 0.6))

	if focus:
		draw_circle(Vector2.ZERO, radius, Color(1, 0.4, 0.5, 0.75))
		draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 24, Color(1, 1, 1, 0.5), 1.0, true)

	# 疾走のクールダウン：足元の輪が満ちると使える
	if dash_cool > 0.0:
		var k2 := 1.0 - dash_cool / maxf(0.01, dash_cd_time())
		draw_arc(Vector2(0, 34), 16.0, 0, TAU, 24, Color(0, 0, 0, 0.45), 4.0, true)
		draw_arc(Vector2(0, 34), 16.0, -PI * 0.5, -PI * 0.5 + TAU * k2, 24, Color(1, 1, 1, 0.75), 3.0, true)
		var f: Font = Game.inst.ui.font_bold
		draw_string(f, Vector2(-20, 58), "%.1f" % dash_cool, HORIZONTAL_ALIGNMENT_CENTER, 40, 10, Color(1, 1, 1, 0.8))
