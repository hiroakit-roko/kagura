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
# 固有ギミック
var invuln := false          # 百目鬼：閉眼中は無敵
var eye_t := 0.0             # 百目鬼：開眼/閉眼の切り替え
var eye_open := true
var dash_state := 0          # 荒魂：0 通常 1 狙い 2 突進 3 戻り
var dash_t := 0.0
var dash_dir := Vector2.DOWN
var heads_alive := 8         # 八岐大蛇：残っている首
var _heads_prev := 8

const NAMES := ["荒魂", "百目鬼", "八岐大蛇"]
const TITLES := ["参道を塞ぐ荒ぶる魂", "百の眼で見張る鬼", "八つの首を持つ大蛇"]


func setup_boss(w: int) -> void:
	wave = w
	tier = Cfg.stage_of(w)
	is_final = Cfg.is_final_wave(w) and not Game.inst.endless
	kind = "boss"
	is_boss = true
	boss_name = NAMES[mini(tier - 1, NAMES.size() - 1)]
	max_hp = 1300.0 * (1.0 + float(tier - 1) * 1.0) * (4.2 if is_final else 1.0)
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


func title_text() -> String:
	return TITLES[mini(tier - 1, TITLES.size() - 1)]


## 八岐大蛇：残っている首の位置（体の左右に扇状に並ぶ）
func head_positions() -> Array:
	var out: Array = []
	var n := 8
	for i in n:
		if i >= heads_alive:
			break
		var a := PI + PI * float(i + 1) / float(n + 1)
		out.append(position + Vector2(cos(a) * radius * 2.2, sin(a) * radius * 1.4 - radius * 0.3))
	return out


func _behavior(delta: float) -> void:
	if entering:
		position.y = move_toward(position.y, 175.0, 165.0 * delta)
		if absf(position.y - 175.0) < 1.0:
			entering = false
		return

	var ph := phase()

	# ---- 荒魂：狙いを定めてから突進し、戻る ----
	if tier == 1 and not is_final:
		if dash_state == 1:
			dash_t -= delta
			if dash_t <= 0.0:
				dash_state = 2
				dash_t = 1.6
				var pl := _player()
				# 自機の少し先を狙って、画面の下端まで突き抜ける
				dash_dir = ((pl.position + Vector2(0, 40.0) - position).normalized() if pl != null else Vector2.DOWN)
				if dash_dir.y < 0.35:
					dash_dir = Vector2(dash_dir.x, 0.35).normalized()
				Sfx.play("hit_storm", -4.0, 0.6)
				Fx.shake_add(6.0)
			return
		elif dash_state == 2:
			dash_t -= delta
			position += dash_dir * 900.0 * delta
			Fx.cone(position, -dash_dir, color, 3, 160.0, 0.6, 6.0, 0.3)
			Fx.puff(position, radius * 0.6, radius * 1.6, Cfg.with_a(color, 0.6), 0.2)
			if dash_t <= 0.0 or position.y > Cfg.H - 30.0:
				dash_state = 3
			return
		elif dash_state == 3:
			position.y = move_toward(position.y, 175.0, 260.0 * delta)
			position.x = lerpf(position.x, Cfg.W * 0.5, clampf(2.0 * delta, 0.0, 1.0))
			if absf(position.y - 175.0) < 2.0:
				dash_state = 0
				atk_cd = 1.2
			return

	# ---- 百目鬼：開眼（無防備）と閉眼（無敵・弾幕）を繰り返す ----
	if tier == 2 and not is_final:
		eye_t -= delta
		if eye_t <= 0.0:
			eye_open = not eye_open
			eye_t = 4.5 if eye_open else 2.6
			invuln = not eye_open
			if eye_open:
				Fx.ring(position, Color(1, 1, 1), radius, radius * 3.0, 0.4, 4.0)
				Sfx.play("suzu", -6.0, 0.9)
				Game.inst.ui.banner_small("開眼　いま撃て", Color(1, 0.9, 0.6))
			else:
				Fx.burst(position, color, 14, 200.0, 4.0, 0.4, true)
				Sfx.play("warn", -14.0, 1.4)
				Game.inst.ui.banner_small("閉眼　弾を弾き返す", Color(1, 0.6, 0.6))

	# ---- 八岐大蛇：首が減るたびに短い硬直と怒りの弾幕 ----
	if is_final:
		heads_alive = maxi(1, int(ceil(hp / max_hp * 8.0)))
		if heads_alive < _heads_prev:
			_heads_prev = heads_alive
			Fx.shake_add(10.0)
			Fx.ring(position, Color(1, 1, 1), radius, radius * 4.0, 0.5, 5.0)
			Sfx.play("taiko", -2.0, 0.7)
			Game.inst.hitstop(0.25, 0.1)
			Game.inst.ui.banner_small("首を断った　残り %d" % heads_alive, Color(1, 0.8, 0.6))
			burst_left = 0
			atk_cd = 0.4
			burst_kind = "heads"
			burst_left = 2
			burst_gap = 0.35

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

	atk_cd -= delta * fire_mult()
	if atk_cd <= 0.0:
		_choose_attack(ph)


func _choose_attack(ph: int) -> void:
	var opts: Array
	match ph:
		1: opts = ["radial", "aimed", "radial"] if not is_final else ["radial", "aimed", "spiral"]
		2: opts = ["spiral", "shotgun", "radial", "summon"] if not is_final else ["spiral", "shotgun", "wall", "summon"]
		_: opts = ["spiral2", "shotgun", "summon", "wall", "spiral2"]
	burst_kind = opts[randi() % opts.size()]
	# 荒魂：たまに突進
	if tier == 1 and not is_final and ph >= 2 and randf() < 0.35 and dash_state == 0:
		dash_state = 1
		dash_t = 0.8
		Sfx.play("warn", -10.0, 0.8)
		return
	# 百目鬼：閉眼中は螺旋に寄せる、開眼中は隙の大きい攻撃
	if tier == 2 and not is_final:
		burst_kind = ["spiral", "spiral2", "radial"][randi() % 3] if not eye_open else ["aimed", "shotgun", "summon"][randi() % 3]
	# 八岐大蛇：首から吐く弾幕を混ぜる
	if is_final and randf() < 0.45:
		burst_kind = "heads"
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
		"heads":
			burst_left = 3
			burst_gap = 0.4
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
		"heads":
			# 首ごとに自機へ向けて吐く
			_on_fire()
			var pl := _player()
			for hpos0 in head_positions():
				var hpos: Vector2 = hpos0
				var a: float = ((pl.position - hpos).normalized().angle() if pl != null else PI * 0.5) + randf_range(-0.15, 0.15)
				Game.inst.spawn_ebullet(hpos, Vector2(cos(a), sin(a)) * (spd + 40.0), _bullet_dmg(), 6.0, Cfg.C_EBULLET, 0.0, boss_name + "の吐息")
			Sfx.play("eshot", -10.0, 0.6, 0.05)
		"wall":
			_on_fire()
			var gap := randi_range(1, 6)
			for i in 8:
				if absi(i - gap) <= 1:
					continue
				var x := 45.0 + float(i) * (Cfg.W - 90.0) / 7.0
				Game.inst.spawn_ebullet(Vector2(x, position.y + 40.0),
						Vector2(0, spd * 0.85), _bullet_dmg(), 6.0, Cfg.C_EBULLET, 0.0, boss_name + "の弾幕")
			Sfx.play("eshot", -12.0, 0.7, 0.05)


func take_damage(d: float, crit: bool, at: Vector2, quiet := false) -> void:
	if invuln:
		# 閉眼中：弾を弾く
		if not quiet:
			Fx.sparks(at, Vector2.DOWN, Color(1, 1, 1), 3, 200.0)
			Fx.number(at + Vector2(0, -radius), "無効", Color(1, 1, 1, 0.7), 11.0)
		return
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
	Fx.glow(self, Vector2.ZERO, radius * 2.8, Cfg.with_a(color, 0.45))

	# 回転する外殻（数珠のように連なる珠）
	for ring_i in 2:
		var rr := radius * (1.35 + 0.28 * float(ring_i))
		var dir := 1.0 if ring_i == 0 else -1.0
		var seg := 8 + ring_i * 4
		for i in seg:
			var a0 := t * (0.5 + 0.3 * float(ph)) * dir + TAU * float(i) / float(seg)
			draw_circle(Vector2(cos(a0), sin(a0)) * rr, 5.0 - float(ring_i), Cfg.with_a(c, 0.6))

	# 八岐大蛇：首
	if is_final:
		for hpos0 in head_positions():
			var lp: Vector2 = (hpos0 as Vector2) - position
			var mid := lp * 0.5 + Vector2(0, -20.0 + sin(t * 2.0 + lp.x * 0.02) * 6.0)
			draw_line(Vector2.ZERO, mid, c.darkened(0.3), 10.0, Cfg.AA)
			draw_line(mid, lp, c.darkened(0.3), 8.0, Cfg.AA)
			draw_circle(lp, 14.0, c)
			draw_circle(lp + Vector2(-4, -3), 3.0, Color(1, 0.95, 0.6))
			draw_circle(lp + Vector2(4, -3), 3.0, Color(1, 0.95, 0.6))
			draw_colored_polygon(PackedVector2Array([lp + Vector2(-5, 6), lp + Vector2(5, 6), lp + Vector2(0, 14)]), Color(1, 0.95, 0.85))
	# 百目鬼：閉眼中は鈍い色、開眼中は大きな眼
	if tier == 2 and not is_final:
		if invuln:
			c = c.darkened(0.45)
			draw_arc(Vector2.ZERO, radius * 1.15, 0, TAU, 40, Color(1, 1, 1, 0.35 + 0.15 * sin(t * 10.0)), 3.0, Cfg.AA)
		else:
			draw_circle(Vector2(0, -radius * 0.1), radius * 0.5, Color(1, 1, 0.95))
			draw_circle(Vector2(0, -radius * 0.1), radius * 0.26, Color(0.9, 0.2, 0.3))
			draw_circle(Vector2(0, -radius * 0.1), radius * 0.12, Cfg.C_INK)
	# 荒魂：狙いの線
	if tier == 1 and not is_final and dash_state == 1:
		var pl := _player()
		if pl != null:
			draw_line(Vector2.ZERO, (pl.position - position).normalized() * 1200.0, Color(1, 0.4, 0.5, 0.25 + 0.2 * sin(t * 30.0)), 3.0, Cfg.AA)
	# 本体：鬼の面
	var hex := PackedVector2Array()
	for i in 6:
		var a := TAU * float(i) / 6.0 + PI / 6.0
		hex.append(Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(hex, c.darkened(0.35))
	draw_polyline(hex + PackedVector2Array([hex[0]]), c, 3.0, Cfg.AA)
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
	draw_arc(Vector2(0, radius * 0.3), radius * 0.4, 0.3, PI - 0.3, 12, Cfg.C_INK, 3.0, Cfg.AA)
	for i in ph * 2:
		var x := (float(i) - float(ph * 2 - 1) * 0.5) * radius * 0.16
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 3, radius * 0.45), Vector2(x + 3, radius * 0.45), Vector2(x, radius * 0.7)]),
			Color(1, 0.95, 0.85))

	_draw_status()
