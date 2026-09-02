class_name Pickup
extends Area2D

## 勾玉（経験値）／御札（回復）／神酒（恩恵の強化）。マグネット範囲に入ると吸い寄せられる。

enum Kind {XP, HEAL, MIKI}

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


func _ready() -> void:
	z_index = Cfg.Z_PICKUP
	collision_layer = Cfg.L_PICKUP
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("pickup")
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 11.0 if kind != Kind.MIKI else 16.0
	cs.shape = c
	add_child(cs)


func _physics_process(delta: float) -> void:
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
		queue_free()
	rotation = sin(_t * 2.2) * 0.35 if kind != Kind.XP else _t * 1.6
	queue_redraw()


func color_of() -> Color:
	match kind:
		Kind.XP: return Cfg.C_XP
		Kind.HEAL: return Cfg.C_HP
		_: return Cfg.C_GOLD


func _draw() -> void:
	var c := color_of()
	var pulse := 1.0 + 0.12 * sin(_t * 7.0)
	draw_circle(Vector2.ZERO, (13.0 if kind != Kind.MIKI else 22.0) * pulse, Cfg.with_a(c, 0.20))
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
			draw_colored_polygon(pts, c)
			draw_circle(Vector2(-r * 0.2, -r * 0.2), r * 0.3, Color(1, 1, 1, 0.85))
		Kind.HEAL:
			# 御札：縦長の紙と朱印
			draw_rect(Rect2(-6, -11, 12, 22), Cfg.C_PAPER)
			draw_rect(Rect2(-6, -11, 12, 22), Cfg.with_a(c, 0.9), false, 1.5)
			draw_rect(Rect2(-3, -7, 6, 9), Color(0.85, 0.2, 0.25, 0.9))
			draw_line(Vector2(0, 4), Vector2(0, 9), Cfg.C_INK, 1.5)
		_:
			# 神酒：瓢箪型の徳利
			draw_circle(Vector2(0, 6), 9.0, Cfg.C_PAPER)
			draw_circle(Vector2(0, -6), 6.5, Cfg.C_PAPER)
			draw_rect(Rect2(-2.5, -15, 5, 5), Cfg.with_a(c, 0.95))
			draw_arc(Vector2(0, 6), 9.0, 0, TAU, 20, Cfg.with_a(c, 0.9), 1.5, true)
			draw_arc(Vector2(0, -6), 6.5, 0, TAU, 16, Cfg.with_a(c, 0.9), 1.5, true)
			draw_rect(Rect2(-4, 2, 8, 8), Color(0.85, 0.2, 0.25, 0.85))
