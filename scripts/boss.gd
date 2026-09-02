class_name Boss
extends Enemy

## 5ウェーブごとに出現する大妖。HPで3フェーズに変化する。

var boss_name := "荒魂"
var entering := true
var atk_cd := 1.6
var burst_left := 0
var burst_t := 0.0
var burst_kind := ""
var burst_gap := 0.12
var spiral_a := 0.0
var hover_x := 0.0
var tier := 1
var is_final := false

const NAMES := ["荒魂", "百目鬼", "八岐大蛇"]


func setup_boss(w: int) -> void:
	wave = w
	tier = Cfg.stage_of(w)
	is_final = Cfg.is_final_wave(w)
	kind = "boss"
	is_boss = true
	boss_name = NAMES[mini(tier - 1, NAMES.size() - 1)]
	max_hp = 1300.0 * (1.0 + float(tier - 1) * 1.0) * (1.6 if is_final else 1.0)
	hp = max_hp
	radius = 56.0 if not is_final else 70.0
	speed = 70.0
	contact_dmg = 30.0
	score = 500 * tier
	xp = 60.0 + 20.0 * float(tier)
	color = Cfg.C_BOSS
	position = Vector2(Cfg.W * 0.5, -110.0)
	hover_x = Cfg.W * 0.5


func _ready() -> void:
	super()
	add_to_group("boss")


func phase() -> int:
	var r := hp / max_hp
	if r > 0.66:
		return 1
	elif r > 0.33:
		return 2
	return 3


func _behavior(delta: float) -> void:
	if entering:
		position.y = move_toward(position.y, 175.0, 165.0 * delta)
		if absf(position.y - 175.0) < 1.0:
			entering = false
		return

	var ph := phase()
	# ふわふわ移動
	hover_x = Cfg.W * 0.5 + sin(t * (0.45 + 0.16 * float(ph))) * (Cfg.W * 0.30)
	position.x = lerpf(position.x, hover_x, clampf(2.2 * delta, 0.0, 1.0))
	position.y = 175.0 + sin(t * 0.9) * 18.0

	if burst_left > 0:
		burst_t -= delta
		if burst_t <= 0.0:
			burst_t = burst_gap
			burst_left -= 1
			_do_burst_shot(ph)
		return

	atk_cd -= delta
	if atk_cd <= 0.0:
		_choose_attack(ph)


func _choose_attack(ph: int) -> void:
	var opts: Array
	match ph:
		1: opts = ["radial", "aimed", "radial"] if not is_final else ["radial", "aimed", "spiral"]
		2: opts = ["spiral", "shotgun", "radial", "summon"] if not is_final else ["spiral", "shotgun", "wall", "summon"]
		_: opts = ["spiral2", "shotgun", "summon", "wall", "spiral2"]
	burst_kind = opts[randi() % opts.size()]
	spiral_a = randf() * TAU
	match burst_kind:
		"radial":
			burst_left = 3
			burst_gap = 0.24
			atk_cd = 1.9 - 0.15 * float(ph)
		"aimed":
			burst_left = 4
			burst_gap = 0.16
			atk_cd = 1.7
		"shotgun":
			burst_left = 3
			burst_gap = 0.30
			atk_cd = 1.6
		"spiral":
			burst_left = 26
			burst_gap = 0.055
			atk_cd = 1.7
		"spiral2":
			burst_left = 36
			burst_gap = 0.048
			atk_cd = 1.4
		"summon":
			burst_left = 1
			burst_gap = 0.1
			atk_cd = 2.6
		"wall":
			burst_left = 2
			burst_gap = 0.5
			atk_cd = 1.6
	burst_t = 0.0


func _bullet_dmg() -> float:
	return (10.0 + float(wave) * 0.7) * out_dmg_mult()


func _do_burst_shot(ph: int) -> void:
	var spd := 200.0 + 14.0 * float(ph) + float(tier) * 14.0 + (30.0 if is_final else 0.0)
	match burst_kind:
		"radial":
			_shoot_radial(12 + ph * 3, spd, randf() * TAU)
			Fx.ring(position, color, radius * 0.6, radius * 1.7, 0.25)
		"aimed":
			_shoot_aimed(3, 12.0, spd + 60.0)
		"shotgun":
			_shoot_aimed(7 + ph, 9.0, spd + 30.0)
			Fx.shake_add(2.0)
		"spiral", "spiral2":
			_on_fire()
			var arms := 2 if burst_kind == "spiral" else 3
			for a in arms:
				var ang := spiral_a + TAU * float(a) / float(arms)
				_spawn(Vector2(cos(ang), sin(ang)) * spd)
			spiral_a += 0.42 if burst_kind == "spiral" else -0.36
			Sfx.play("eshot", -20.0, 1.2, 0.06)
		"summon":
			var n := 2 + ph
			for i in n:
				var m := Enemy.new()
				m.setup("mini", wave)
				m.position = position + Vector2(randf_range(-70, 70), randf_range(20, 60))
				Game.inst.spawn_deferred(m)
			Sfx.play("warn", -18.0, 1.6)
		"wall":
			_on_fire()
			var gap := randi_range(1, 6)
			for i in 8:
				if absi(i - gap) <= 1:
					continue
				var x := 45.0 + float(i) * (Cfg.W - 90.0) / 7.0
				Game.inst.spawn_ebullet(Vector2(x, position.y + 40.0),
						Vector2(0, spd * 0.85), _bullet_dmg(), 6.0)
			Sfx.play("eshot", -12.0, 0.7, 0.05)


func take_damage(d: float, crit: bool, at: Vector2, quiet := false) -> void:
	var before := phase()
	super(d, crit, at, quiet)
	if hp > 0.0 and phase() != before:
		Fx.ring(position, Color(1, 1, 1), radius, radius * 5.0, 0.5)
		Fx.shake_add(9.0)
		Sfx.play("taiko", -4.0, 0.8)
		Sfx.play("warn", -10.0, 1.0)
		Game.inst.hitstop(0.2, 0.1)
		burst_left = 0
		atk_cd = 0.7


func die() -> void:
	if not is_inside_tree():
		return
	Sfx.play("boom", -2.0)
	Sfx.play("taiko", 0.0, 0.6)
	for i in 8:
		var off := Vector2(randf_range(-50, 50), randf_range(-50, 50))
		Fx.burst(position + off, color if i % 2 == 0 else Color(1, 0.85, 0.4), 18, 380.0, 7.0, 0.9)
	Fx.ring(position, Color(1, 1, 1), 10.0, 420.0, 0.8)
	Fx.flash(Color(1, 1, 1, 0.5), 0.3)
	Fx.shake_add(24.0)
	Game.inst.on_boss_killed(self)
	queue_free()


func _draw() -> void:
	var c := color
	if flash > 0.0:
		c = c.lerp(Color(1, 1, 1), flash * 0.8)
	if st["frozen"] > 0.0:
		c = c.lerp(Color(0.75, 0.92, 1.0), 0.6)
	var ph := phase()
	var glow := color
	glow.a = 0.16
	draw_circle(Vector2.ZERO, radius * 2.1, glow)

	# 回転する外殻（数珠のように連なる珠）
	for ring_i in 2:
		var rr := radius * (1.35 + 0.28 * float(ring_i))
		var dir := 1.0 if ring_i == 0 else -1.0
		var seg := 8 + ring_i * 4
		for i in seg:
			var a0 := t * (0.5 + 0.3 * float(ph)) * dir + TAU * float(i) / float(seg)
			draw_circle(Vector2(cos(a0), sin(a0)) * rr, 5.0 - float(ring_i), Cfg.with_a(c, 0.6))

	# 本体：鬼の面
	var hex := PackedVector2Array()
	for i in 6:
		var a := TAU * float(i) / 6.0 + PI / 6.0
		hex.append(Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(hex, c.darkened(0.35))
	draw_polyline(hex + PackedVector2Array([hex[0]]), c, 3.0, true)
	# 角
	for sgn in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(sgn * radius * 0.35, -radius * 0.7), Vector2(sgn * radius * 0.55, -radius * 1.35),
			Vector2(sgn * radius * 0.7, -radius * 0.6)]), Color(1, 0.95, 0.85))
	# 目
	var pulse := 0.75 + 0.25 * sin(t * (4.0 + 2.0 * float(ph)))
	for sgn in [-1.0, 1.0]:
		var ep := Vector2(sgn * radius * 0.32, -radius * 0.1)
		draw_circle(ep, radius * 0.2 * pulse, Color(1, 0.95, 0.7, 0.95))
		draw_circle(ep, radius * 0.09, Cfg.C_INK)
	# 口（フェーズで牙が増える）
	draw_arc(Vector2(0, radius * 0.3), radius * 0.4, 0.3, PI - 0.3, 12, Cfg.C_INK, 3.0, true)
	for i in ph * 2:
		var x := (float(i) - float(ph * 2 - 1) * 0.5) * radius * 0.16
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 3, radius * 0.45), Vector2(x + 3, radius * 0.45), Vector2(x, radius * 0.7)]),
			Color(1, 0.95, 0.85))

	_draw_status()
