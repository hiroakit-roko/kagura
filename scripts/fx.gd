class_name Fx
extends Node2D

## パーティクル・ダメージ表示・画面シェイク・稲妻・斬撃・残像などをまとめて描く軽量レイヤ。
## すべて配列で管理し、1 ノードの _draw で一括描画する。

static var inst: Fx

var _parts: Array = []
var _texts: Array = []
var _bolts: Array = []
var _rings: Array = []
var _slashes: Array = []
var _zones: Array = []
var _ghosts: Array = []
var _rays: Array = []
var _puffs: Array = []     # やわらかい光の膨らみ（爆発・宿命・撃破）
var shake := 0.0
static var GLOW: Texture2D   # 中心が白く外へ溶ける丸い光。発光の質感はほぼこれで作る
var flash_col := Color(1, 1, 1, 0)
var flash_t := 0.0
var font: Font
var font_big: Font


func _ready() -> void:
	inst = self
	z_index = Cfg.Z_FX
	top_level = true
	_ensure_glow()
	# 光は足し合わせで描く（重なった所が白く飽和し、ネオンの質感になる）
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


static func _ensure_glow() -> void:
	if GLOW != null:
		return
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(float(x) + 0.5 - float(n) * 0.5, float(y) + 0.5 - float(n) * 0.5).length() / (float(n) * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (1.0 + 0.6 * a)   # 中心を少し強く、外は滑らかに
			img.set_pixel(x, y, Color(1, 1, 1, minf(a, 1.0)))
	GLOW = ImageTexture.create_from_image(img)


## やわらかい光を 1 枚置く（どの CanvasItem からでも使える）
static func glow(ci: CanvasItem, pos: Vector2, r: float, color: Color) -> void:
	_ensure_glow()
	ci.draw_texture_rect(GLOW, Rect2(pos - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), false, color)


## 光の膨らみ：r0 → r1 に広がりながら消える
static func puff(pos: Vector2, r0: float, r1: float, color: Color, life := 0.35) -> void:
	if inst == null:
		return
	inst._puffs.append({"pos": pos, "r0": r0, "r1": r1, "color": color, "life": life, "maxlife": life})


func _process(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 34.0)
	flash_t = maxf(0.0, flash_t - delta)

	# 粒が多すぎるときは古いものから捨てる（処理落ち防止）
	if _parts.size() > 420:
		_parts = _parts.slice(_parts.size() - 420)
	for i in range(_parts.size() - 1, -1, -1):
		var p: Dictionary = _parts[i]
		p.life -= delta
		if p.life <= 0.0:
			_parts.remove_at(i)
			continue
		p.pos += p.vel * delta
		p.vel = p.vel.lerp(Vector2.ZERO, clampf(p.drag * delta, 0.0, 1.0))
		p.vel.y += p.grav * delta

	for i in range(_texts.size() - 1, -1, -1):
		var t: Dictionary = _texts[i]
		t.life -= delta
		if t.life <= 0.0:
			_texts.remove_at(i)
			continue
		t.pos += t.vel * delta
		t.vel.y += 130.0 * delta

	for arr in [_bolts, _rings, _slashes, _zones, _ghosts, _rays, _puffs]:
		for i in range(arr.size() - 1, -1, -1):
			arr[i].life -= delta
			if arr[i].life <= 0.0:
				arr.remove_at(i)

	queue_redraw()


func _draw() -> void:
	for pf: Dictionary in _puffs:
		var kp: float = 1.0 - pf.life / pf.maxlife
		var rr: float = lerpf(pf.r0, pf.r1, 1.0 - (1.0 - kp) * (1.0 - kp))
		var cp: Color = pf.color
		cp.a *= (1.0 - kp) * 0.9
		Fx.glow(self, pf.pos, rr, cp)
		Fx.glow(self, pf.pos, rr * 0.45, Color(1, 1, 1, cp.a * 0.7))
	for z: Dictionary in _zones:
		var k: float = 1.0 - z.life / z.maxlife
		var col: Color = z.color
		var a: float = minf(1.0, z.life * 3.0) * 0.22
		draw_circle(z.pos, z.r, Cfg.with_a(col, a))
		draw_arc(z.pos, z.r, 0.0, TAU, 48, Cfg.with_a(col, a * 3.0), 2.0, true)
		# ゆっくり回る内側の紋
		var rot: float = k * 3.0
		for i in 6:
			var ang := rot + TAU * float(i) / 6.0
			draw_line(z.pos + Vector2(cos(ang), sin(ang)) * z.r * 0.55,
					z.pos + Vector2(cos(ang), sin(ang)) * z.r * 0.92, Cfg.with_a(col, a * 2.0), 1.5, true)

	for g: Dictionary in _ghosts:
		var a2: float = g.life / g.maxlife
		var tex: Texture2D = g.tex
		var fw: float = tex.get_width() / float(g.hframes)
		var src := Rect2(fw * float(g.frame), 0, fw, tex.get_height())
		var sz: Vector2 = Vector2(fw, tex.get_height()) * float(g.scale)
		draw_set_transform(g.pos, g.rot, Vector2.ONE)
		draw_texture_rect_region(tex, Rect2(-sz * 0.5, sz), src, Cfg.with_a(g.color, a2 * 0.55))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for r: Dictionary in _rings:
		var k2: float = 1.0 - r.life / r.maxlife
		var col2: Color = r.color
		col2.a = (1.0 - k2) * 0.85
		draw_arc(r.pos, lerpf(r.r0, r.r1, k2), 0.0, TAU, 48, col2, lerpf(r.width, 1.0, k2), true)

	for s: Dictionary in _slashes:
		var k3: float = 1.0 - s.life / s.maxlife
		var col3: Color = s.color
		var a3: float = 1.0 - k3
		var sweep: float = s.sweep
		var a0: float = s.angle - sweep * 0.5
		# 三日月状：太い弧を段階的に細く重ねる
		var rr: float = s.r * (1.0 + k3 * 0.25)
		draw_arc(s.pos, rr, a0, a0 + sweep * minf(1.0, k3 * 3.0 + 0.3), 28,
				Cfg.with_a(col3, a3 * 0.9), s.width * (1.0 - k3 * 0.6), true)
		draw_arc(s.pos, rr, a0, a0 + sweep * minf(1.0, k3 * 3.0 + 0.3), 28,
				Color(1, 1, 1, a3 * 0.7), s.width * 0.35 * (1.0 - k3), true)

	for b: Dictionary in _bolts:
		var a4: float = b.life / b.maxlife
		var col4: Color = b.color
		var pts: PackedVector2Array = b.pts
		for i in range(pts.size() - 1):
			draw_line(pts[i], pts[i + 1], Cfg.with_a(col4, a4 * 0.45), 6.0 * a4 + 1.0, true)
		for i in range(pts.size() - 1):
			draw_line(pts[i], pts[i + 1], Color(1, 1, 1, a4), 2.0 * a4 + 0.5, true)

	for ry: Dictionary in _rays:
		var a5: float = ry.life / ry.maxlife
		var col5: Color = ry.color
		for i in ry.n:
			var ang: float = ry.rot + TAU * float(i) / float(ry.n)
			var len: float = ry.len * (0.6 + 0.4 * sin(float(i) * 1.7 + a5 * 6.0))
			var p0: Vector2 = ry.pos + Vector2(cos(ang), sin(ang)) * ry.r0
			var p1: Vector2 = ry.pos + Vector2(cos(ang), sin(ang)) * (ry.r0 + len)
			draw_line(p0, p1, Cfg.with_a(col5, a5 * 0.7), 3.0, true)

	for p: Dictionary in _parts:
		var k5: float = p.life / p.maxlife
		var col6: Color = p.color
		col6.a *= k5
		var s2: float = p.size * (k5 * 0.7 + 0.3)
		if int(p.shape) == 0:
			Fx.glow(self, p.pos, s2 * 3.0, Cfg.with_a(col6, col6.a * 0.35))
		match int(p.shape):
			0:
				draw_rect(Rect2(p.pos - Vector2(s2, s2) * 0.5, Vector2(s2, s2)), col6)
			1:
				draw_circle(p.pos, s2, col6)
			2: # 花弁：進行方向に伸びた小さな菱形
				var d: Vector2 = p.vel.normalized() if p.vel.length() > 1.0 else Vector2.UP
				var n: Vector2 = d.orthogonal()
				draw_colored_polygon(PackedVector2Array([
					p.pos + d * s2 * 1.4, p.pos + n * s2 * 0.6, p.pos - d * s2 * 1.4, p.pos - n * s2 * 0.6]), col6)
			_: # 火花：線
				draw_line(p.pos, p.pos - p.vel * 0.03, col6, maxf(1.0, s2 * 0.5), true)

	if flash_t > 0.0:
		var fa: float = flash_col.a * minf(1.0, flash_t * 6.0)
		draw_rect(Rect2(-100, -100, Cfg.W + 200, Cfg.H + 200), Cfg.with_a(flash_col, fa))

	if font != null:
		for t: Dictionary in _texts:
			var a6: float = clampf(t.life / t.maxlife * 1.6, 0.0, 1.0)
			var col7: Color = t.color
			col7.a = a6
			var f: Font = font_big if (t.big and font_big != null) else font
			var pop: float = 1.0 + 0.5 * clampf((t.life - t.maxlife + 0.12) / 0.12, 0.0, 1.0)
			var sz: int = int(t.size * pop)
			draw_string(f, t.pos + Vector2(1.5, 1.5), t.text, HORIZONTAL_ALIGNMENT_CENTER,
					120.0, sz, Color(0, 0, 0, a6 * 0.7))
			draw_string(f, t.pos, t.text, HORIZONTAL_ALIGNMENT_CENTER, 120.0, sz, col7)


# ---------- 静的ヘルパ ----------

static func burst(pos: Vector2, color: Color, count := 12, spd := 240.0, size := 4.0,
		life := 0.5, round_shape := false) -> void:
	if inst == null:
		return
	for i in count:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * spd * randf_range(0.25, 1.0)
		inst._parts.append({
			"pos": pos, "vel": v, "drag": 3.0, "grav": 0.0,
			"life": life * randf_range(0.6, 1.2), "maxlife": life,
			"size": size * randf_range(0.6, 1.3), "color": color, "shape": 1 if round_shape else 0,
		})


static func cone(pos: Vector2, dir: Vector2, color: Color, count := 6, spd := 200.0,
		spread := 0.6, size := 3.0, life := 0.3) -> void:
	if inst == null:
		return
	for i in count:
		var a := dir.angle() + randf_range(-spread, spread)
		var v := Vector2(cos(a), sin(a)) * spd * randf_range(0.4, 1.0)
		inst._parts.append({
			"pos": pos, "vel": v, "drag": 5.0, "grav": 0.0,
			"life": life * randf_range(0.6, 1.2), "maxlife": life,
			"size": size * randf_range(0.7, 1.2), "color": color, "shape": 1,
		})


## 火花：速く飛ぶ線状の粒（命中演出）
static func sparks(pos: Vector2, dir: Vector2, color: Color, count := 6, spd := 420.0) -> void:
	if inst == null:
		return
	for i in count:
		var a := dir.angle() + randf_range(-1.1, 1.1)
		var v := Vector2(cos(a), sin(a)) * spd * randf_range(0.5, 1.0)
		inst._parts.append({
			"pos": pos, "vel": v, "drag": 7.0, "grav": 300.0,
			"life": randf_range(0.12, 0.28), "maxlife": 0.28,
			"size": randf_range(2.0, 4.0), "color": color, "shape": 3,
		})


## 花弁：ゆっくり舞い落ちる菱形
static func petals(pos: Vector2, color: Color, count := 8, spd := 120.0) -> void:
	if inst == null:
		return
	for i in count:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * spd * randf_range(0.3, 1.0)
		inst._parts.append({
			"pos": pos, "vel": v, "drag": 1.5, "grav": 60.0,
			"life": randf_range(0.5, 0.9), "maxlife": 0.9,
			"size": randf_range(2.5, 4.5), "color": color, "shape": 2,
		})


static func ring(pos: Vector2, color: Color, r0 := 4.0, r1 := 70.0, life := 0.35, width := 4.0) -> void:
	if inst == null:
		return
	inst._rings.append({"pos": pos, "color": color, "r0": r0, "r1": r1,
			"life": life, "maxlife": life, "width": width})


static func slash(pos: Vector2, angle: float, r := 40.0, color := Color(1, 1, 1),
		sweep := 2.2, life := 0.18, width := 9.0) -> void:
	if inst == null:
		return
	inst._slashes.append({"pos": pos, "angle": angle, "r": r, "color": color,
			"sweep": sweep, "life": life, "maxlife": life, "width": width})


static func zone(pos: Vector2, r: float, color: Color, life := 1.0) -> void:
	if inst == null:
		return
	inst._zones.append({"pos": pos, "r": r, "color": color, "life": life, "maxlife": life})


static func rays(pos: Vector2, color: Color, n := 12, r0 := 20.0, len := 120.0, life := 0.35) -> void:
	if inst == null:
		return
	inst._rays.append({"pos": pos, "color": color, "n": n, "r0": r0, "len": len,
			"rot": randf() * TAU, "life": life, "maxlife": life})


static func bolt(from: Vector2, to: Vector2, color: Color, life := 0.18) -> void:
	if inst == null:
		return
	var pts := PackedVector2Array()
	var seg := 8
	var n := (to - from).normalized().orthogonal()
	var amp := clampf(from.distance_to(to) * 0.10, 6.0, 22.0)
	for i in range(seg + 1):
		var k := float(i) / float(seg)
		var jitter := 0.0 if (i == 0 or i == seg) else randf_range(-amp, amp)
		pts.append(from.lerp(to, k) + n * jitter)
	inst._bolts.append({"pts": pts, "color": color, "life": life, "maxlife": life})


## スプライトの残像（疾走時など）
static func ghost(tex: Texture2D, hframes: int, frame: int, pos: Vector2, scale: float,
		rot: float, color: Color, life := 0.25) -> void:
	if inst == null or tex == null:
		return
	inst._ghosts.append({"tex": tex, "hframes": hframes, "frame": frame, "pos": pos,
			"scale": scale, "rot": rot, "color": color, "life": life, "maxlife": life})


static func number(pos: Vector2, text: String, color: Color, size := 15.0, big := false) -> void:
	if inst == null:
		return
	inst._texts.append({
		"pos": pos + Vector2(randf_range(-8, 8), 0), "vel": Vector2(randf_range(-24, 24), -78.0),
		"life": 0.62, "maxlife": 0.62, "text": text, "color": color, "size": size, "big": big,
	})


static func flash(color: Color, life := 0.12) -> void:
	if inst == null:
		return
	inst.flash_col = color
	inst.flash_t = life


static func shake_add(amount: float) -> void:
	if inst != null:
		inst.shake = minf(inst.shake + amount, 26.0)


static func clear_all() -> void:
	if inst == null:
		return
	inst._parts.clear()
	inst._texts.clear()
	inst._bolts.clear()
	inst._rings.clear()
	inst._slashes.clear()
	inst._zones.clear()
	inst._ghosts.clear()
	inst._rays.clear()
	inst.shake = 0.0
	inst.flash_t = 0.0
