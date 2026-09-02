class_name Zone
extends Node2D

## 一定時間その場に留まって効果を及ぼす領域。
##   moon  : 月読の月輪。触れた敵にダメージ
##   fog   : 少名毘古那の酒気。中の敵を酩酊させる
##   frost : 伊邪那美の凍土。中の敵を遅くし毎秒ダメージ
##   cloud : 建御雷の雷雲。近くの敵に落雷

var kind := "moon"
var r := 60.0
var life := 2.0
var maxlife := 2.0
var dmg := 10.0
var color := Color(1, 1, 1)
var _t := 0.0
var _tick := 0.0
var _rot := 0.0
var vel := Vector2.ZERO


func setup(p: Vector2, k: String, radius: float, sec: float, d: float, col: Color) -> void:
	position = p
	kind = k
	r = radius
	life = sec
	maxlife = sec
	dmg = d
	color = col


func _ready() -> void:
	z_index = Cfg.Z_PBULLET - 1
	add_to_group("zone")


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	position += vel * delta
	vel = vel.lerp(Vector2.ZERO, clampf(2.0 * delta, 0.0, 1.0))
	_rot += delta * (3.0 if kind == "moon" else 0.6)

	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.4 if kind == "moon" else 0.5
		_apply()
	queue_redraw()


func _apply() -> void:
	var inside: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		if e.position.distance_to(position) <= r + e.radius * 0.5:
			inside.append(e)
	match kind:
		"moon":
			for e in inside:
				Combat.hit(e, dmg, e.position, {"tag": "moon", "kami": "tsuki"})
				Fx.slash(e.position, randf() * TAU, 18.0, color, 2.0, 0.15, 5.0)
		"fog":
			for e in inside:
				e.add_hangover(1, Combat.hangover_dps())
		"frost":
			for e in inside:
				e.add_chill(1)
				Combat.hit(e, dmg * 0.5, e.position, {"tag": "zone", "kami": "iza", "quiet": true})
		"cloud":
			# 最も近い敵 1 体（範囲内）に落雷
			var best: Node2D = null
			var bd := r * r
			for e in inside:
				var d: float = position.distance_squared_to(e.position)
				if d < bd:
					bd = d
					best = e
			if best != null:
				Combat.lightning(best, dmg, position + Vector2(randf_range(-20, 20), -30), 0)


func _draw() -> void:
	var a := clampf(life * 2.0, 0.0, 1.0) * clampf(_t * 4.0, 0.0, 1.0)
	match kind:
		"moon":
			# 回転する三日月の刃 3 枚
			for i in 3:
				var ang := _rot + TAU * float(i) / 3.0
				draw_arc(Vector2.ZERO, r * 0.8, ang, ang + 1.4, 16, Cfg.with_a(color, 0.85 * a), 6.0, true)
				draw_arc(Vector2.ZERO, r * 0.8, ang + 0.2, ang + 1.2, 12, Color(1, 1, 1, 0.7 * a), 2.0, true)
			draw_circle(Vector2.ZERO, r, Cfg.with_a(color, 0.08 * a))
			draw_arc(Vector2.ZERO, r, 0, TAU, 40, Cfg.with_a(color, 0.35 * a), 1.5, true)
		"fog":
			for i in 5:
				var off := Vector2(cos(_t * 0.7 + float(i) * 1.3), sin(_t * 0.9 + float(i) * 2.1)) * r * 0.35
				draw_circle(off, r * (0.55 + 0.1 * sin(_t * 2.0 + float(i))), Cfg.with_a(color, 0.10 * a))
			draw_arc(Vector2.ZERO, r, 0, TAU, 40, Cfg.with_a(color, 0.3 * a), 1.5, true)
		"frost":
			draw_circle(Vector2.ZERO, r, Cfg.with_a(color, 0.12 * a))
			for i in 6:
				var ang := _rot + TAU * float(i) / 6.0
				var p1 := Vector2(cos(ang), sin(ang)) * r * 0.9
				draw_line(Vector2.ZERO, p1, Cfg.with_a(Color(1, 1, 1), 0.35 * a), 1.5, true)
				var side := p1 * 0.6
				var n := p1.normalized().orthogonal() * r * 0.15
				draw_line(side, side + n, Cfg.with_a(Color(1, 1, 1), 0.3 * a), 1.0, true)
				draw_line(side, side - n, Cfg.with_a(Color(1, 1, 1), 0.3 * a), 1.0, true)
			draw_arc(Vector2.ZERO, r, 0, TAU, 40, Cfg.with_a(color, 0.5 * a), 2.0, true)
		"cloud":
			for i in 4:
				var off := Vector2((float(i) - 1.5) * 22.0, sin(float(i) * 2.0 + _t * 3.0) * 4.0)
				draw_circle(off, 22.0 + 6.0 * absf(sin(float(i) * 1.7)), Color(0.35, 0.3, 0.5, 0.9 * a))
			var flick: float = 0.4 + 0.6 * float(fmod(_t * 7.0, 1.0) < 0.2)
			draw_circle(Vector2(0, 4), 12.0, Cfg.with_a(color, 0.5 * a * flick))
			draw_arc(Vector2.ZERO, r, 0, TAU, 40, Cfg.with_a(color, 0.15 * a), 1.0, true)
