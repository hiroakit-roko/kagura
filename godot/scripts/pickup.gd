class_name Pickup
extends Area2D

## 勾玉（経験値）／団子（HP 回復）／詠唱の札（詠唱の回数が戻る）。神酒（MIKI）は廃止済み。
## マグネット範囲に入ると吸い寄せられる。詠唱の珠は消えず、自機より下に抜けると必ず戻ってくる。

enum Kind {XP, HEAL, MIKI, ORB}

var kind: int = Kind.XP
var value := 3.0
var vel := Vector2.ZERO
var _t := 0.0
var _pulled := false
var life := 14.0


func setup(p: Vector2, k: int, v: float) -> void:
	position = p
	kind = k
	value = v
	vel = Vector2(randf_range(-70, 70), randf_range(-130, -50))
	if k == Kind.MIKI:
		life = 30.0
	if k == Kind.ORB:
		life = 9999.0
		vel = Vector2(randf_range(-40, 40), randf_range(-60, -20))


func _ready() -> void:
	z_index = Cfg.Z_PICKUP
	collision_layer = Cfg.L_PICKUP
	collision_mask = 0
	set_deferred("monitoring", false)   # 衝突シグナル中に生成されても安全に
	set_deferred("monitorable", true)
	add_to_group("pickup")
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 11.0 if kind != Kind.MIKI else 16.0
	cs.shape = c
	add_child(cs)


func _physics_process(delta: float) -> void:
	var _t0 := Time.get_ticks_usec()
	_perf_physics_process(delta)
	Perf.add("pickup", _t0)


func _perf_physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	if life <= 0.0:
		Fx.burst(position, color_of(), 4, 60.0, 2.0, 0.3, true)
		queue_free()
		return

	var pl: Player = null
	if Game.inst != null:
		pl = Game.inst.player
	if pl != null and is_instance_valid(pl):
		var d := position.distance_to(pl.position)
		var range_r: float = pl.magnet_range()
		if kind == Kind.ORB:
			range_r *= 1.6   # 札は広めに吸い寄せる
		# 自機より下に抜けたアイテムは取り逃さないよう必ず吸い寄せる
		if _pulled or d < range_r or position.y > pl.position.y + 40.0:
			_pulled = true
			var dir := (pl.position - position).normalized()
			vel = vel.lerp(dir * (340.0 + (range_r - d) * 1.6), clampf(9.0 * delta, 0.0, 1.0))
	else:
		vel = vel.lerp(Vector2(0, 60.0), clampf(2.0 * delta, 0.0, 1.0))

	if not _pulled:
		vel.y += 190.0 * delta
		vel.x = lerpf(vel.x, 0.0, clampf(2.0 * delta, 0.0, 1.0))
		vel.y = minf(vel.y, 85.0 if kind != Kind.MIKI else 55.0)

	position += vel * delta
	position.x = clampf(position.x, 8.0, Cfg.W - 8.0)
	if position.y > Cfg.H + 30.0:
		if kind == Kind.ORB:
			# 珠は失われない：画面上から戻ってくる
			position = Vector2(clampf(position.x + randf_range(-80, 80), 20.0, Cfg.W - 20.0), -20.0)
			vel = Vector2(0, 60.0)
			_pulled = false
		else:
			queue_free()
	rotation = sin(_t * 2.2) * 0.35 if kind != Kind.XP else _t * 1.6
	if (Engine.get_physics_frames() + (get_instance_id() & 1)) % 2 == 0:
		queue_redraw()


func color_of() -> Color:
	match kind:
		Kind.XP: return Cfg.C_XP
		Kind.HEAL: return Cfg.C_HP
		Kind.ORB:
			var pl := Game.inst.player if Game.inst != null else null
			if pl != null and is_instance_valid(pl) and pl.main_god() != "":
				return pl.kami_color(pl.main_god())
			return Color(0.8, 0.85, 1.0)
		_: return Cfg.C_GOLD


func _draw() -> void:
	if Cfg.SKIP.has("pickup"):
		return
	var _t0 := Time.get_ticks_usec()
	_perf_draw()
	Perf.add("pickup_draw", _t0)


func _perf_draw() -> void:
	var c := color_of()
	var pulse := 1.0 + 0.12 * sin(_t * 7.0)
	Fx.glow(self, Vector2.ZERO, (20.0 if kind != Kind.MIKI else 30.0) * pulse, Cfg.with_a(c, 0.6))
	Pickup.draw_shape(self, kind, c, _t, pulse)


## アイテムの形（案内の絵にも使う）。原点中心に描く
static func draw_shape(ci: CanvasItem, kind: int, c: Color, t: float, pulse := 1.0) -> void:
	match kind:
		Kind.XP:
			# 勾玉：丸い頭と細くなる尾
			var r := 6.5 * pulse
			var pts := PackedVector2Array()
			for i in 14:
				var a := PI * 0.25 + TAU * 0.75 * float(i) / 13.0
				pts.append(Vector2(cos(a), sin(a)) * r)
			pts.append(Vector2(r * 1.7, r * 1.1))
			pts.append(Vector2(r * 1.15, r * 0.2))
			ci.draw_colored_polygon(pts, c)
			ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 0.9), 1.5, Cfg.AA)
			ci.draw_circle(Vector2(-r * 0.2, -r * 0.2), r * 0.3, Color(1, 1, 1, 0.95))
		Kind.ORB:
			# 詠唱の札：主神の色に光る縦長の御札。朱印と墨の一筆
			var fl := sin(t * 4.0) * 0.12
			ci.draw_set_transform(Vector2.ZERO, fl, Vector2.ONE)
			ci.draw_rect(Rect2(-7, -13, 14, 26), Cfg.with_a(c, 0.35))
			ci.draw_rect(Rect2(-6, -12, 12, 24), Cfg.C_PAPER)
			ci.draw_rect(Rect2(-6, -12, 12, 24), Cfg.with_a(c, 0.95), false, 1.5)
			ci.draw_rect(Rect2(-4, -9, 8, 3), Cfg.with_a(c, 0.9))
			ci.draw_line(Vector2(0, -4), Vector2(0, 6), Cfg.C_INK, 2.0)
			ci.draw_line(Vector2(-3, 0), Vector2(3, 0), Cfg.C_INK, 1.5)
			ci.draw_circle(Vector2(0, 9), 2.2, Color(0.85, 0.2, 0.25, 0.95))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		Kind.HEAL:
			# 団子：串に三色（桃・白・緑）
			ci.draw_line(Vector2(0, 12), Vector2(0, -12), Color(0.55, 0.38, 0.2), 2.5)
			ci.draw_circle(Vector2(0, -7), 5.2 * pulse, Color(1.0, 0.62, 0.72))
			ci.draw_circle(Vector2(0, 0), 5.2 * pulse, Color(0.98, 0.96, 0.9))
			ci.draw_circle(Vector2(0, 7), 5.2 * pulse, Color(0.6, 0.85, 0.5))
			for yy in [-7.0, 0.0, 7.0]:
				ci.draw_circle(Vector2(-1.6, yy - 1.6), 1.4, Color(1, 1, 1, 0.8))
		_:
			# 神酒：瓢箪型の徳利
			ci.draw_circle(Vector2(0, 6), 9.0, Cfg.C_PAPER)
			ci.draw_circle(Vector2(0, -6), 6.5, Cfg.C_PAPER)
			ci.draw_rect(Rect2(-2.5, -15, 5, 5), Cfg.with_a(c, 0.95))
			ci.draw_arc(Vector2(0, 6), 9.0, 0, TAU, 20, Cfg.with_a(c, 0.9), 1.5, Cfg.AA)
			ci.draw_arc(Vector2(0, -6), 6.5, 0, TAU, 16, Cfg.with_a(c, 0.9), 1.5, Cfg.AA)
			ci.draw_rect(Rect2(-4, 2, 8, 8), Color(0.85, 0.2, 0.25, 0.85))
