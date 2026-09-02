class_name Starfield
extends Node2D

## 夜空の背景。星・月・流れる雲・舞い散る花弁の多層パララックス。
## tint を主神の色に寄せることで、選んだ神ごとに空の色味が少し変わる。

var _stars: Array = []
var _clouds: Array = []
var _petals: Array = []
var speed := 1.0
var tint := Color(0.45, 0.30, 0.80)
var _tint_cur := Color(0.45, 0.30, 0.80)
var stage := 1
var _t := 0.0
var _path_y := 0.0


func _ready() -> void:
	z_index = Cfg.Z_STARS
	for layer in 3:
		var count: int = [80, 45, 20][layer]
		for i in count:
			_stars.append({
				"pos": Vector2(randf() * Cfg.W, randf() * Cfg.H),
				"layer": layer,
				"tw": randf() * TAU,
			})
	for i in 9:
		_clouds.append(_new_cloud(true))
	for i in 26:
		_petals.append(_new_petal(true))


func _new_cloud(anywhere: bool) -> Dictionary:
	var far := randf() < 0.5
	return {
		"pos": Vector2(randf_range(-100.0, Cfg.W + 100.0),
				randf_range(-200.0, Cfg.H) if anywhere else randf_range(-260.0, -140.0)),
		"w": randf_range(160.0, 320.0) * (0.7 if far else 1.0),
		"h": randf_range(28.0, 52.0) * (0.7 if far else 1.0),
		"far": far,
		"drift": randf_range(-8.0, 8.0),
	}


func _new_petal(anywhere: bool) -> Dictionary:
	return {
		"pos": Vector2(randf() * Cfg.W, randf() * Cfg.H if anywhere else -10.0),
		"vel": Vector2(randf_range(-30.0, 30.0), randf_range(70.0, 150.0)),
		"rot": randf() * TAU,
		"spin": randf_range(-4.0, 4.0),
		"size": randf_range(2.5, 5.0),
		"phase": randf() * TAU,
	}


func _process(delta: float) -> void:
	_t += delta
	_tint_cur = _tint_cur.lerp(tint, clampf(delta * 1.5, 0.0, 1.0))
	var base := [22.0, 55.0, 120.0]
	for s: Dictionary in _stars:
		s.pos.y += base[s.layer] * speed * delta
		if s.pos.y > Cfg.H + 4.0:
			s.pos.y = -4.0
			s.pos.x = randf() * Cfg.W
	for i in _clouds.size():
		var c: Dictionary = _clouds[i]
		c.pos.y += (36.0 if c.far else 78.0) * speed * delta
		c.pos.x += c.drift * delta
		if c.pos.y > Cfg.H + 120.0:
			_clouds[i] = _new_cloud(false)
	for i in _petals.size():
		var p: Dictionary = _petals[i]
		p.pos += p.vel * speed * delta
		p.pos.x += sin(_t * 1.3 + p.phase) * 22.0 * delta
		p.rot += p.spin * delta
		if p.pos.y > Cfg.H + 10.0 or p.pos.x < -20.0 or p.pos.x > Cfg.W + 20.0:
			_petals[i] = _new_petal(false)
	_path_y = fmod(_path_y + 90.0 * speed * delta, 120.0)
	queue_redraw()


func _draw() -> void:
	# 画面シェイクで端が見えないよう少し広めに塗る
	var stint: Color = Cfg.STAGE_TINT[clampi(stage - 1, 0, Cfg.STAGE_TINT.size() - 1)]
	var mix := _tint_cur.lerp(stint, 0.5)
	var top := Cfg.C_BG.lerp(mix, 0.18 + 0.06 * float(stage - 1))
	var bottom := Cfg.C_BG.lerp(mix, 0.05).darkened(0.3)
	var steps := 12
	for i in steps:
		var k0 := float(i) / float(steps)
		var k1 := float(i + 1) / float(steps)
		var y0 := -80.0 + (Cfg.H + 160.0) * k0
		var y1 := -80.0 + (Cfg.H + 160.0) * k1
		draw_rect(Rect2(-80, y0, Cfg.W + 160, y1 - y0 + 1.0), top.lerp(bottom, k0))

	# 月
	var mp := Vector2(Cfg.W - 110.0, 150.0)
	draw_circle(mp, 120.0, Cfg.with_a(_tint_cur.lightened(0.4), 0.05))
	draw_circle(mp, 70.0, Cfg.with_a(_tint_cur.lightened(0.5), 0.07))
	var moon_col: Color = [Color(0.93, 0.90, 0.80, 0.55), Color(1.0, 0.72, 0.55, 0.6), Color(0.85, 0.75, 1.0, 0.65)][clampi(stage - 1, 0, 2)]
	var mr := 42.0 + 10.0 * float(stage - 1)
	draw_circle(mp, mr, moon_col)
	if stage < 3:
		draw_circle(mp + Vector2(-14, -8), mr * 0.9, top.lerp(moon_col, 0.35))

	# 星
	var sizes := [1.0, 1.6, 2.4]
	var cols := [
		Color(0.65, 0.62, 0.90, 0.5),
		Color(0.85, 0.82, 1.0, 0.7),
		Color(1.0, 0.96, 0.85, 0.95),
	]
	for s: Dictionary in _stars:
		var tw: float = 0.7 + 0.3 * sin(_t * 3.0 + s.tw)
		var c: Color = cols[s.layer]
		c.a *= tw
		draw_circle(s.pos, sizes[s.layer], c)
		if s.layer == 2 and tw > 0.95:
			draw_line(s.pos + Vector2(-5, 0), s.pos + Vector2(5, 0), Cfg.with_a(c, 0.5), 1.0)
			draw_line(s.pos + Vector2(0, -5), s.pos + Vector2(0, 5), Cfg.with_a(c, 0.5), 1.0)

	# 参道（うっすら見える石段の帯）
	var pc := Cfg.with_a(_tint_cur.lightened(0.3), 0.045)
	for i in range(-1, 10):
		var y := float(i) * 120.0 + _path_y
		draw_line(Vector2(Cfg.W * 0.5 - 150.0, y), Vector2(Cfg.W * 0.5 + 150.0, y), pc, 2.0)
	draw_line(Vector2(Cfg.W * 0.5 - 150.0, -80), Vector2(Cfg.W * 0.5 - 150.0, Cfg.H + 80), pc, 2.0)
	draw_line(Vector2(Cfg.W * 0.5 + 150.0, -80), Vector2(Cfg.W * 0.5 + 150.0, Cfg.H + 80), pc, 2.0)

	# 雲（複数の楕円を重ねる）
	for c2: Dictionary in _clouds:
		var a := 0.05 if c2.far else 0.09
		var cc := Cfg.with_a(_tint_cur.lightened(0.55), a)
		var w: float = c2.w
		var h: float = c2.h
		for j in 5:
			var off := Vector2((float(j) - 2.0) * w * 0.18, sin(float(j) * 1.9) * h * 0.25)
			var rw: float = w * (0.22 + 0.10 * absf(sin(float(j) * 2.3)))
			var rh: float = h * (0.7 + 0.3 * cos(float(j) * 1.3))
			_ellipse(c2.pos + off, rw, rh, cc)

	# 花弁
	var petal_c := Cfg.with_a(_tint_cur.lightened(0.5), 0.55)
	for p: Dictionary in _petals:
		var d := Vector2(cos(p.rot), sin(p.rot))
		var n := d.orthogonal()
		var s2: float = p.size
		draw_colored_polygon(PackedVector2Array([
			p.pos + d * s2 * 1.5, p.pos + n * s2 * 0.7, p.pos - d * s2 * 1.5, p.pos - n * s2 * 0.7]), petal_c)


func _ellipse(c: Vector2, rw: float, rh: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * float(i) / 18.0
		pts.append(c + Vector2(cos(a) * rw, sin(a) * rh))
	draw_colored_polygon(pts, col)
