class_name Player
extends Area2D

## 自機（魔法少女）。walk.gif から抜き出した後ろ姿のスプライトで歩き、
## 攻撃 / 特技（御札） / 詠唱 / 疾走 / 神招き の 5 つの技を持つ。
## 神々の恩恵は boons / slots / gods に保持し、Combat や UI から has() / val() で参照される。

signal died
signal leveled_up

const SHEET := "res://image/player_walk.png"
const HFRAMES := 10
const SPR_SCALE := 0.5

## 「ダメージ +X%」型の恩恵（スロット弾のダメージ倍率に使う）
const DMG_BOONS := ["ama_atk", "susa_atk", "uzume_atk", "iza_atk",
	"ama_spc", "susa_spc", "uzume_spc", "inari_spc", "iza_spc", "ama_cast", "susa_cast"]

var stats := {
	"max_hp": 100.0,
	"damage": 11.0,
	"fire_rate": 5.0,
	"bullet_speed": 900.0,
	"speed": 330.0,
	"crit": 0.05,
	"crit_mult": 2.0,
	"xp_mult": 1.0,
	"magnet": 170.0,
	"dash_cd": 2.2,
	"special_cd": 1.5,
	"cast_cd": 5.0,
	"cast_max": 2,
}

# ---- 恩恵 ----
var boons := {}          # id -> {"rar": int, "lv": int}
var slots := {}          # Cfg.Slot -> boon id（PASSIVE 以外）
var gods: Array = []     # [主神, 副神, 副神]

# ---- 状態 ----
var hp := 100.0
var level := 1
var xp := 0.0
var xp_next := 40.0
var pending_levels := 0
var alive := true

var radius := 7.0
var fire_cd := 0.0
var special_cd := 0.0
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
var call_t := 0.0            # 持続型の神招きの残り時間
var call_kind := ""
var call_tick := 0.0
var call_power := 1.0
var _crit_window := 0.0
var _contact_cd := 0.0
var _ghost_t := 0.0
var _miracle_cd := 0.0       # 常世の妙薬
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
	spr.position = Vector2(0, 9)   # 胴体の中心が当たり判定に重なるように
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
	_crit_window = maxf(0.0, _crit_window - delta)
	_miracle_cd = maxf(0.0, _miracle_cd - delta)

	_move(delta)
	_animate(delta)
	_weapons(delta)
	_call_tick(delta)
	_upkeep(delta)
	_contact()
	_graze()
	queue_redraw()


# ---------- 恩恵の参照 ----------

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


func slot_kami(slot: int) -> String:
	var id: String = slots.get(slot, "")
	if id == "":
		return ""
	return String(Kami.boon(id)["kami"])


func kami_color(kami_id: String) -> Color:
	var k := Kami.kami(kami_id)
	return k["color"] if not k.is_empty() else Cfg.C_PBULLET


func on_boons_changed() -> void:
	# 最大 HP
	var base_hp := 100.0 + float(level - 1) * 3.0
	var new_max := base_hp + (val("uzume_p2") if has("uzume_p2") else 0.0)
	var diff := new_max - float(stats["max_hp"])
	stats["max_hp"] = new_max
	if diff > 0.0:
		hp = minf(new_max, hp + diff)
	# 詠唱の弾数
	stats["cast_max"] = 2 + (1 if has("saru_p6") else 0)
	cast_charges = mini(cast_charges + 1, int(stats["cast_max"]))
	# 眷属の狐
	var want := int(round(val("inari_p3"))) if has("inari_p3") else 0
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
	# 鏡の護り
	if has("ama_p3") and shield == 0:
		shield_t = minf(shield_t, 2.0)
	# 空の色を主神に寄せる
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
	return float(stats["speed"]) * (1.0 + val("saru_p1") * 0.01)


func dash_cd_time() -> float:
	return float(stats["dash_cd"]) * (1.0 - val("saru_p3") * 0.01)


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
		position += dash_dir * move_speed() * 3.6 * delta
		_ghost_t -= delta
		if _ghost_t <= 0.0:
			_ghost_t = 0.03
			Fx.ghost(tex, HFRAMES, int(_anim) % HFRAMES, position + spr.position, SPR_SCALE,
					rotation, kami_color(slot_kami(Cfg.Slot.DASH)) if slot_kami(Cfg.Slot.DASH) != "" else Cfg.C_PLAYER, 0.3)
		if slot_kami(Cfg.Slot.DASH) == "ama":
			_reflect_near(40.0)
		if dash_t <= 0.0:
			_on_dash_end()
	else:
		var want_dash := Input.is_key_pressed(KEY_SPACE)
		if tc != null:
			# スマホ：指をすばやく弾くと、その方向へ疾走
			var flick := tc.take_flick()
			if flick != Vector2.ZERO:
				want_dash = true
				dir = flick
		if want_dash and dash_cool <= 0.0 and dir != Vector2.ZERO:
			_start_dash(dir)
		if tc != null and touch_move != Vector2.ZERO:
			# タッチは相対移動：指の移動量ぶんだけ動く（速度上限は疾走と同じ）
			var maxlen := move_speed() * 3.6 * delta
			position += touch_move.limit_length(maxlen)
		else:
			var sp := move_speed() * (0.42 if focus else 1.0)
			position += dir * sp * delta

	var r := Cfg.play_rect()
	position.x = clampf(position.x, r.position.x + 10.0, r.end.x - 10.0)
	position.y = clampf(position.y, r.position.y + 60.0, r.end.y - 30.0)


func _start_dash(dir: Vector2) -> void:
	dash_t = 0.16
	dash_cool = dash_cd_time()
	dash_dir = dir
	var kami := slot_kami(Cfg.Slot.DASH)
	var col := kami_color(kami) if kami != "" else Cfg.C_PLAYER
	Fx.ring(position, col, 6.0, 50.0, 0.25, 3.0)
	Sfx.play("dash", -12.0, randf_range(0.95, 1.1))
	var v := val(slots.get(Cfg.Slot.DASH, ""))
	match kami:
		"susa":
			Fx.ring(position, col, 10.0, 130.0, 0.35, 5.0)
			Sfx.play("hit_storm", -8.0, 0.8)
			for e in _enemies_within(115.0):
				Combat.hit(e, v, e.position, {"tag": "dash", "slot": Cfg.Slot.DASH, "kami": "susa",
						"dir": (e.position - position).normalized(), "kb": 520.0})
		"take":
			var n := 0
			for e in _enemies_within(230.0):
				if n >= 3:
					break
				n += 1
				Combat.hit(e, v, e.position, {"tag": "dash", "slot": Cfg.Slot.DASH, "kami": "take"})
		"tsuki":
			var z := Zone.new()
			z.setup(position, "moon", 42.0, 1.6 * (1.0 + val("tsuki_p3") * 0.01),
					v * (1.0 + val("tsuki_p3") * 0.01), col)
			Game.inst.spawn_deferred(z)
			var z2 := Zone.new()
			z2.setup(position + dir * 50.0, "moon", 42.0, 1.6 * (1.0 + val("tsuki_p3") * 0.01),
					v * (1.0 + val("tsuki_p3") * 0.01), col)
			Game.inst.spawn_deferred(z2)
		"uzume":
			Fx.petals(position, col, 16, 180.0)
			Fx.ring(position, col, 10.0, 130.0, 0.3, 3.0)
			for e in _enemies_within(150.0):
				Combat.apply_weak(e)
			for eb in get_tree().get_nodes_in_group("ebullet"):
				if is_instance_valid(eb) and eb.position.distance_to(position) <= 130.0:
					Fx.petals(eb.position, col, 2, 60.0)
					eb.vanish()
		"inari":
			_crit_window = 1.5
			Fx.burst(position, col, 8, 140.0, 3.0, 0.3, true)
		"suku":
			var z3 := Zone.new()
			z3.setup(position, "fog", 70.0, 2.5, 0.0, col)
			Game.inst.spawn_deferred(z3)
		"iza":
			Fx.ring(position, col, 10.0, 110.0, 0.3, 4.0)
			for e in _enemies_within(110.0):
				Combat.hit(e, v, e.position, {"tag": "dash", "slot": Cfg.Slot.DASH, "kami": "iza"})


func _on_dash_end() -> void:
	var kami := slot_kami(Cfg.Slot.DASH)
	var v := val(slots.get(Cfg.Slot.DASH, ""))
	match kami:
		"ama":
			iframe = maxf(iframe, v)
		"suku":
			iframe = maxf(iframe, 0.1 + v)


func _reflect_near(r: float) -> void:
	for b in get_tree().get_nodes_in_group("ebullet"):
		if not is_instance_valid(b):
			continue
		if b.position.distance_to(position) <= r:
			b.reflect_to_friendly(shot_damage(Cfg.Slot.ATTACK) * 0.8)
			Sfx.play("deflect", -12.0, 1.1, 0.04)


func _enemies_within(r: float) -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.position.distance_to(position) <= r:
			out.append(e)
	return out


# ---------- アニメーション ----------

func _animate(delta: float) -> void:
	# 常に前へ歩いている（背景が流れる）ので止まっていてもゆっくり歩き、動くと速くなる
	var moving := _move_dir.length() > 0.1
	var fps := 10.0 if moving else 5.5
	if focus:
		fps *= 0.7
	_anim += delta * fps
	spr.frame = int(_anim) % HFRAMES
	_lean = lerpf(_lean, _move_dir.x * 0.13, clampf(9.0 * delta, 0.0, 1.0))
	spr.rotation = _lean
	spr.position.y = 9.0 + sin(_anim * PI) * 1.2
	# 無敵中は点滅
	if iframe > 0.0 and dash_t <= 0.0:
		spr.modulate = Color(1, 1, 1, 0.45 + 0.55 * (0.5 + 0.5 * sin(t * 40.0)))
	elif dash_t > 0.0:
		spr.modulate = Color(1.2, 1.1, 1.4, 0.85)
	else:
		spr.modulate = Color(1, 1, 1, 1)


# ---------- 武装 ----------

func shot_damage(slot: int) -> float:
	var d: float = stats["damage"] * (1.0 + float(level - 1) * 0.03)
	var id: String = slots.get(slot, "")
	if id != "" and DMG_BOONS.has(id):
		d *= 1.0 + val(id) * 0.01
	match slot:
		Cfg.Slot.SPECIAL: d *= 0.8
		Cfg.Slot.CAST: d *= 5.0
	return d


func crit_chance(slot: int) -> float:
	var c: float = stats["crit"]
	if slot == Cfg.Slot.ATTACK and has("inari_atk"):
		c += 0.10
	if slot == Cfg.Slot.CAST and has("inari_cast"):
		c += val("inari_cast") * 0.01
	if _crit_window > 0.0 and has("inari_dash"):
		c += val("inari_dash") * 0.01
	return minf(c, 0.95)


func crit_mult() -> float:
	return float(stats["crit_mult"]) + val("inari_p2") * 0.01


func fire_rate_mult() -> float:
	return 1.0 + val("saru_p2") * 0.01


func _weapons(delta: float) -> void:
	fire_cd -= delta
	if fire_cd <= 0.0:
		fire_cd = 1.0 / (float(stats["fire_rate"]) * fire_rate_mult())
		_fire_main()

	special_cd -= delta
	if special_cd <= 0.0:
		special_cd = float(stats["special_cd"]) / fire_rate_mult()
		_fire_special()

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
	return float(stats["cast_cd"]) * (1.0 - val("saru_p6") * 0.01)


func _new_bullet(slot: int) -> Bullet:
	var b := Bullet.new()
	b.slot = slot
	b.kami = slot_kami(slot)
	b.tag = ["attack", "special", "cast", "dash", "call", "passive"][slot]
	b.color = kami_color(b.kami) if b.kami != "" else Cfg.C_PBULLET
	b.crit_chance = crit_chance(slot)
	return b


func bullet_speed() -> float:
	return float(stats["bullet_speed"]) * (1.0 + val("saru_p2") * 0.01)


func _fire_main() -> void:
	var nose := position + Vector2(0, -34.0)
	var kami := slot_kami(Cfg.Slot.ATTACK)
	var dmg := shot_damage(Cfg.Slot.ATTACK)
	var spread := deg_to_rad(randf_range(-2.0, 2.0) * (0.4 if focus else 1.0))
	var col := Cfg.C_PBULLET
	match kami:
		"susa":
			# 3 方向に広がる荒波。1 発ごとのダメージは値（%）で決まる
			var base_d: float = stats["damage"] * (1.0 + float(level - 1) * 0.03)
			var each := base_d * val("susa_atk") * 0.01
			for i in 3:
				var b := _new_bullet(Cfg.Slot.ATTACK)
				b.radius = 6.0
				b.trail_len = 18.0
				b.kb = 260.0
				var a := -PI * 0.5 + (float(i) - 1.0) * deg_to_rad(13.0) + spread
				b.setup(nose + Vector2((float(i) - 1.0) * 10.0, 0), Vector2(cos(a), sin(a)) * bullet_speed(), each, true)
				Game.inst.world.add_child(b)
				col = b.color
		"ama":
			# 貫通する光線
			var b := _new_bullet(Cfg.Slot.ATTACK)
			b.radius = 5.5
			b.trail_len = 46.0
			b.pierce = 2
			b.setup(nose, Vector2(cos(-PI * 0.5 + spread), sin(-PI * 0.5 + spread)) * bullet_speed() * 1.15, dmg, true)
			Game.inst.world.add_child(b)
			col = b.color
		_:
			var b := _new_bullet(Cfg.Slot.ATTACK)
			b.radius = 5.0
			b.trail_len = 22.0
			b.setup(nose, Vector2(cos(-PI * 0.5 + spread), sin(-PI * 0.5 + spread)) * bullet_speed(), dmg, true)
			Game.inst.world.add_child(b)
			col = b.color

	# 稲荷：攻撃のたびに追尾する狐火
	if kami == "inari":
		var target := Combat.nearest_enemy(position, 600.0)
		if target != null:
			spawn_foxfire(nose + Vector2(randf_range(-14, 14), 0), target, dmg * val("inari_atk") * 0.01)
	# 狐の加勢（加護）
	if has("inari_p1") and randf() < val("inari_p1") * 0.01:
		var target2 := Combat.nearest_enemy(position, 520.0)
		if target2 != null:
			spawn_foxfire(nose, target2, dmg * 0.6)

	Fx.cone(nose, Vector2.UP, col, 2, 90.0, 0.4, 2.0, 0.12)
	Sfx.play("shoot", -20.0, randf_range(0.95, 1.1), 0.035)


func _fire_special() -> void:
	var kami := slot_kami(Cfg.Slot.SPECIAL)
	var dmg := shot_damage(Cfg.Slot.SPECIAL)
	var from := position + Vector2(0, -18.0)
	if kami == "susa":
		# 大波：横に広い 1 枚の波
		var w := _new_bullet(Cfg.Slot.SPECIAL)
		w.shape_kind = 4
		w.radius = 78.0
		w.pierce = 999
		w.kb = 620.0
		w.life = 2.5
		w.setup(from + Vector2(0, -20), Vector2(0, -380.0), dmg * 1.2, true)
		Game.inst.world.add_child(w)
		Sfx.play("hit_storm", -14.0, 0.7)
		return

	var n := 2
	for i in n:
		var b := _new_bullet(Cfg.Slot.SPECIAL)
		b.shape_kind = 1
		b.radius = 7.0
		b.homing = 2.6
		b.pierce = 1
		var a := -PI * 0.5 + (float(i) - float(n - 1) * 0.5) * deg_to_rad(28.0)
		match kami:
			"ama":
				b.eraser = true
			"uzume":
				b.eraser = true
				b.radius = 12.0
			"inari":
				b.homing = 6.5
			"tsuki":
				b.zone_kind = "moon"
				b.zone_r = 52.0
				b.zone_life = 2.2 * (1.0 + val("tsuki_p3") * 0.01)
				b.zone_dmg = val("tsuki_spc") * (1.0 + val("tsuki_p3") * 0.01)
			"suku":
				b.zone_kind = "fog"
				b.zone_r = 58.0
				b.zone_life = 2.6
				b.zone_dmg = 0.0
			"iza":
				b.split_on_hit = 4
		b.setup(from + Vector2((float(i) - 0.5) * 24.0, 0), Vector2(cos(a), sin(a)) * 620.0 * (1.0 + val("saru_p2") * 0.01), dmg, true)
		Game.inst.world.add_child(b)
	Sfx.play("clap", -16.0, randf_range(0.95, 1.1), 0.1)


func _try_cast() -> void:
	if cast_charges <= 0:
		return
	cast_charges -= 1
	if cast_cd <= 0.0:
		cast_cd = cast_cd_time()
	var kami := slot_kami(Cfg.Slot.CAST)
	var dmg := shot_damage(Cfg.Slot.CAST)
	var from := position + Vector2(0, -30.0)
	var b := _new_bullet(Cfg.Slot.CAST)
	b.shape_kind = 2
	b.radius = 12.0
	b.pierce = 2
	var speed := 480.0
	match kami:
		"ama":
			b.shape_kind = 5
			b.radius = 44.0
			b.reflect = true
			b.pierce = 999
			b.life = 2.6
			speed = 150.0
		"susa":
			b.shape_kind = 6
			b.radius = 26.0
			b.mode = "vortex"
			b.pierce = 999
			b.kb = 480.0
			b.life = 2.2
			speed = 210.0
		"take":
			b.mode = "cloud"
			b.zone_dmg = val("take_cast")
			speed = 420.0
		"inari":
			b.shape_kind = 3
			b.radius = 9.0
			b.homing = 6.0
			b.pierce = 999
			speed = 560.0
		"suku":
			b.zone_kind = "fog"
			b.zone_r = 85.0
			b.zone_life = val("suku_cast")
			b.zone_dmg = 0.0
		"iza":
			b.zone_kind = "frost"
			b.zone_r = 90.0
			b.zone_life = 3.2
			b.zone_dmg = val("iza_cast")
	b.setup(from, Vector2(0, -speed), dmg, true)
	Game.inst.world.add_child(b)
	Fx.ring(from, b.color, 6.0, 40.0, 0.2, 3.0)
	Sfx.play("cast", -8.0, randf_range(0.95, 1.05))


func spawn_foxfire(from: Vector2, target: Node2D, dmg: float) -> void:
	var b := Bullet.new()
	b.shape_kind = 3
	b.radius = 6.0
	b.homing = 7.0
	b.color = kami_color("inari")
	b.kami = "inari"
	b.slot = Cfg.Slot.PASSIVE
	b.tag = "foxfire"
	b.crit_chance = crit_chance(Cfg.Slot.ATTACK)
	var dir := (target.global_position - from).normalized() if target != null else Vector2.UP
	b.setup(from, dir * 520.0, dmg, true)
	# 当たり判定のシグナル処理中（会心の派生など）からも呼ばれるので遅延追加
	Game.inst.spawn_deferred(b)
	Sfx.play("fox", -18.0, randf_range(0.9, 1.2), 0.05)


# ---------- 神招き ----------

func add_call_gauge(amount: float) -> void:
	if slots.get(Cfg.Slot.CALL, "") == "":
		return
	call_gauge = clampf(call_gauge + amount, 0.0, 1.0)


func _try_call() -> void:
	var id: String = slots.get(Cfg.Slot.CALL, "")
	if id == "" or call_t > 0.0 or call_gauge < 0.25:
		return
	var greater := call_gauge >= 0.999
	call_power = 1.0 if not greater else 1.8
	call_gauge = 0.0 if greater else call_gauge - 0.25
	var kami := slot_kami(Cfg.Slot.CALL)
	var v := val(id) * (1.0 if not greater else 1.3)
	var col := kami_color(kami)
	Sfx.play("flute", -4.0)
	Sfx.play("taiko", -6.0)
	Fx.flash(Cfg.with_a(col, 0.55), 0.35)
	Fx.ring(position, col, 20.0, 400.0, 0.6, 6.0)
	Fx.shake_add(10.0)
	Game.inst.hitstop(0.25, 0.08)
	Game.inst.ui.banner(String(Kami.boon(id)["name"]), Kami.kami(kami)["name"] + ("　大神招き" if greater else ""), col)
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
					Combat.hit(e, v, e.position, {"tag": "call", "kami": "susa", "dir": Vector2.UP, "kb": 700.0})
			Fx.shake_add(18.0)
		"tsuki":
			Game.inst.hitstop(1.0, 0.12)
			for e in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(e):
					e.add_doom(v * (1.0 + val("tsuki_p1") * 0.01), 1.3)
		"uzume":
			for e in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(e):
					e.add_charm(v)
			Fx.petals(position, col, 40, 260.0)
			Sfx.play("charm", -4.0, 0.8)
		"inari":
			var n := 9 if not greater else 15
			for i in n:
				var target := Combat.nearest_enemy(position, 2000.0)
				var b := Bullet.new()
				b.shape_kind = 3
				b.radius = 8.0
				b.homing = 5.5
				b.pierce = 1
				b.color = col
				b.kami = "inari"
				b.slot = Cfg.Slot.CALL
				b.tag = "call"
				b.crit_chance = crit_chance(Cfg.Slot.ATTACK) + 0.3
				var a := -PI * 0.5 + (float(i) - float(n - 1) * 0.5) * 0.28
				b.setup(position + Vector2(0, -20), Vector2(cos(a), sin(a)) * 500.0, v, true)
				if target != null:
					b._target = target
				Game.inst.world.add_child(b)
		"suku":
			for e in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(e):
					Combat.apply_hangover(e, Combat.hangover_max(), Combat.hangover_dps())
			heal(float(stats["max_hp"]) * v * 0.01, true)
			Fx.zone(position, 200.0, col, 0.8)
		"iza":
			for e in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(e):
					e.freeze(v)
			Fx.flash(Cfg.with_a(Color(0.8, 0.95, 1.0), 0.6), 0.4)


func _call_tick(delta: float) -> void:
	if call_t <= 0.0:
		return
	call_t -= delta
	var id: String = slots.get(Cfg.Slot.CALL, "")
	var v := val(id) * (1.0 if call_power <= 1.0 else 1.3)
	var col := kami_color(slot_kami(Cfg.Slot.CALL))
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
	if call_t <= 0.0:
		call_kind = ""


# ---------- 維持処理 ----------

func _upkeep(delta: float) -> void:
	if has("suku_p1"):
		regen_t += delta
		if regen_t >= 1.0:
			regen_t -= 1.0
			if hp < stats["max_hp"]:
				heal(val("suku_p1"), false)

	if has("ama_p3") and shield < 1:
		shield_t -= delta
		if shield_t <= 0.0:
			shield = 1
			shield_t = val("ama_p3")
			Fx.ring(position, Cfg.C_GOLD, 12.0, 40.0, 0.3)
			Sfx.play("suzu", -14.0, 1.0)


func _contact() -> void:
	if _contact_cd > 0.0 or iframe > 0.0:
		return
	for a in get_overlapping_areas():
		if a is Enemy:
			_contact_cd = 0.4
			take_damage(float((a as Enemy).contact_dmg) * (a as Enemy).out_dmg_mult())
			return


## かすり：敵弾が至近距離を通過したら神招きゲージが溜まる（大導き）
func _graze() -> void:
	if not has("saru_leg"):
		return
	for b in get_tree().get_nodes_in_group("ebullet"):
		if not is_instance_valid(b) or _grazed.has(b.get_instance_id()):
			continue
		var d: float = b.position.distance_to(position)
		if d < 30.0 and d > radius + b.radius:
			_grazed[b.get_instance_id()] = true
			add_call_gauge(val("saru_leg") * 0.01)
			Fx.sparks(b.position, Vector2.UP, Color(0.72, 1.0, 0.98), 2, 200.0)
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
				heal(p.value + (val("uzume_p2") if has("uzume_p2") else 0.0), true)
				Sfx.play("heal", -12.0)
			Pickup.Kind.MIKI:
				Sfx.play("miki", -6.0)
				Game.inst.on_miki_picked()
		Fx.burst(p.position, p.color_of(), 5, 110.0, 2.5, 0.28, true)
		p.queue_free()
	elif a is Enemy and _contact_cd <= 0.0 and iframe <= 0.0:
		_contact_cd = 0.4
		take_damage(float((a as Enemy).contact_dmg) * (a as Enemy).out_dmg_mult())


# ---------- HP / XP ----------

func damage_taken_mult() -> float:
	return 1.0 - val("ama_p1") * 0.01


func take_damage(d: float, _crit := false, _at := Vector2.ZERO) -> void:
	if not alive or iframe > 0.0:
		return
	if shield > 0:
		shield -= 1
		shield_t = val("ama_p3") if has("ama_p3") else 99.0
		iframe = 0.7
		Fx.ring(position, Cfg.C_GOLD, 14.0, 90.0, 0.35, 4.0)
		Fx.sparks(position, Vector2.UP, Cfg.C_GOLD, 14, 300.0)
		Fx.shake_add(5.0)
		Sfx.play("deflect", -4.0, 0.8)
		Sfx.play("suzu", -8.0)
		return

	d *= damage_taken_mult()
	hp -= d
	iframe = 1.0 * (1.0 + val("saru_p5") * 0.01)
	add_call_gauge(0.12)
	Fx.shake_add(9.0)
	Fx.flash(Color(1, 0.3, 0.4, 0.25), 0.15)
	Fx.burst(position, Cfg.C_ENEMY, 14, 250.0, 4.0, 0.45)
	Fx.number(position + Vector2(0, -40), "-" + str(int(round(d))), Color(1, 0.45, 0.5), 17.0, true)
	Sfx.play("hurt", -6.0)
	Game.inst.hitstop(0.08, 0.05)
	# 常世の妙薬
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
	xp += amount * float(stats["xp_mult"]) * (1.0 + val("saru_p4") * 0.01)
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		# 1 波でおよそ 1 回、神が現れる程度の緩やかな曲線
		xp_next = 34.0 + float(level) * 18.0 + pow(float(level), 1.5) * 2.0
		pending_levels += 1
		stats["max_hp"] = float(stats["max_hp"]) + 3.0
		hp += 3.0
		leveled_up.emit()


func magnet_range() -> float:
	return float(stats["magnet"]) * (1.0 + val("saru_p4") * 0.01)


func _die() -> void:
	alive = false
	Fx.burst(position, Cfg.C_PLAYER, 40, 420.0, 6.0, 1.0)
	Fx.petals(position, Color(1, 0.8, 0.95), 30, 220.0)
	Fx.ring(position, Color(1, 1, 1), 8.0, 300.0, 0.7)
	Fx.shake_add(22.0)
	Sfx.play("boom", -4.0)
	Sfx.play("gameover", -8.0)
	visible = false
	# 当たり判定のシグナル処理中に呼ばれることがあるので遅延して切る
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	died.emit()


# ---------- 描画（スプライトの下に描く魔法陣など） ----------

func _draw() -> void:
	var main := main_god()
	var col := kami_color(main) if main != "" else Cfg.C_PLAYER

	# 足元の魔法陣
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

	# 鏡の護り
	if shield > 0:
		draw_arc(Vector2(0, -6), 34.0, 0.0, TAU, 40,
				Cfg.with_a(Cfg.C_GOLD, 0.35 + 0.12 * sin(t * 3.0)), 2.0, true)
		draw_arc(Vector2(0, -6), 30.0, t * 2.0, t * 2.0 + 1.2, 12, Color(1, 1, 1, 0.5), 2.0, true)

	# 神招き中の光
	if call_t > 0.0 and call_kind == "sun":
		draw_circle(Vector2(0, -6), 60.0 + 10.0 * sin(t * 12.0), Cfg.with_a(Cfg.C_GOLD, 0.18))

	# 詠唱の印（弾の発生位置）
	var ck := slot_kami(Cfg.Slot.CAST)
	if cast_charges > 0:
		var cc := kami_color(ck) if ck != "" else Cfg.C_PBULLET
		draw_circle(Vector2(0, -34), 3.0 + sin(t * 8.0), Cfg.with_a(cc, 0.6))

	# フォーカス時は当たり判定を表示
	if focus:
		draw_circle(Vector2.ZERO, radius, Color(1, 0.4, 0.5, 0.75))
		draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 24, Color(1, 1, 1, 0.5), 1.0, true)

	# 疾走のクールダウン
	if dash_cool > 0.0:
		var k := 1.0 - dash_cool / maxf(0.01, dash_cd_time())
		draw_arc(Vector2(0, 34), 12.0, -PI * 0.5, -PI * 0.5 + TAU * k, 18, Color(1, 1, 1, 0.3), 2.0, true)
