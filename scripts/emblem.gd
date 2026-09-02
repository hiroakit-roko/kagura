class_name Emblem
extends RefCounted

## 神々の紋章を _draw で描く。UI（選択画面・HUD）と共用。


## 神器の動きを小さな枡の中で実演する（カード用）
static func weapon_preview(ci: CanvasItem, kami: String, r: Rect2, t: float, col: Color, alpha := 1.0) -> void:
	var a := alpha
	ci.draw_rect(r, Color(0.03, 0.02, 0.06, 0.7 * a))
	ci.draw_rect(r, Cfg.with_a(col, 0.35 * a), false, 1.0)
	var base := Vector2(r.position.x + r.size.x * 0.5, r.end.y - 12.0)
	# 自機（小さな印）
	ci.draw_circle(base, 3.0, Color(1, 1, 1, 0.9 * a))
	ci.draw_arc(base, 5.5, 0, TAU, 12, Cfg.with_a(col, 0.6 * a), 1.0, true)
	# 敵（枡の上部）
	var foes := [Vector2(r.position.x + 16, r.position.y + 16), Vector2(r.end.x - 16, r.position.y + 26), Vector2(r.position.x + r.size.x * 0.5, r.position.y + 12)]
	for f in foes:
		ci.draw_circle(f, 4.0, Color(1, 0.4, 0.5, 0.8 * a))
	var k := fmod(t, 1.4) / 1.4
	match kami:
		"ama":
			ci.draw_line(base, Vector2(base.x, r.position.y + 4), Cfg.with_a(col, 0.3 * a), 9.0, true)
			ci.draw_line(base, Vector2(base.x, r.position.y + 4), Cfg.with_a(col, 0.9 * a), 4.0, true)
			ci.draw_line(base, Vector2(base.x, r.position.y + 4), Color(1, 1, 1, 0.9 * a), 1.5, true)
		"susa":
			var y := base.y - 12.0 - k * 48.0
			ci.draw_arc(Vector2(base.x, y + 14), 22.0, PI + 0.4, TAU - 0.4, 14, Cfg.with_a(col, (1.0 - k) * a), 5.0, true)
		"take":
			if k < 0.35:
				var f: Vector2 = foes[int(t) % 3]
				ci.draw_line(Vector2(f.x + 8, r.position.y - 2), f, Color(1, 1, 0.8, a), 2.0, true)
				ci.draw_line(f, foes[(int(t) + 1) % 3], Cfg.with_a(col, 0.8 * a), 1.5, true)
		"tsuki":
			for i in 2:
				var ang := t * 3.0 + PI * float(i)
				var bp := base + Vector2(cos(ang), sin(ang)) * 18.0
				ci.draw_arc(bp, 6.0, ang + 0.2, ang + 3.0, 8, Cfg.with_a(col, 0.95 * a), 3.0, true)
			ci.draw_arc(base, 18.0, 0, TAU, 24, Cfg.with_a(col, 0.2 * a), 1.0, true)
		"uzume":
			var kk := sin(k * PI)
			var fp := Vector2(base.x + sin(t * 4.0) * 10.0, base.y - kk * 70.0)
			ci.draw_arc(fp, 8.0, -PI * 0.5 - 1.1 + t * 8.0, -PI * 0.5 + 1.1 + t * 8.0, 10, Cfg.with_a(col, a), 4.0, true)
		"inari":
			for i in 3:
				var kk2 := fmod(k + float(i) / 3.0, 1.0)
				var f2: Vector2 = foes[i]
				var pos := base.lerp(f2, kk2) + Vector2(sin(kk2 * 9.0 + float(i)) * 8.0, 0)
				ci.draw_circle(pos, 3.0, Cfg.with_a(col, (1.0 - kk2 * 0.5) * a))
		"suku":
			var fp2 := Vector2(r.position.x + r.size.x * 0.5, r.position.y + 30.0)
			ci.draw_circle(fp2, 18.0 + 4.0 * sin(t * 2.0), Cfg.with_a(col, 0.22 * a))
			ci.draw_arc(fp2, 18.0 + 4.0 * sin(t * 2.0), 0, TAU, 20, Cfg.with_a(col, 0.6 * a), 1.0, true)
			var gy := base.y - k * (base.y - fp2.y)
			ci.draw_circle(Vector2(base.x, gy), 3.0, Cfg.C_PAPER)
		"iza":
			for i in 3:
				var ang := -PI * 0.5 + (float(i) - 1.0) * 0.3
				var pos := base + Vector2(cos(ang), sin(ang)) * (10.0 + k * 60.0)
				ci.draw_line(pos, pos + Vector2(cos(ang), sin(ang)) * 8.0, Color(0.85, 0.95, 1.0, (1.0 - k) * a), 2.0, true)
		"saru":
			for i in 5:
				var kk3 := fmod(k * 2.0 + float(i) * 0.2, 1.0)
				var pos := Vector2(base.x + (float(i % 2) - 0.5) * 8.0, base.y - kk3 * 70.0)
				ci.draw_arc(pos, 5.0, PI + 0.6, TAU - 0.6, 6, Cfg.with_a(col, (1.0 - kk3) * a), 2.0, true)


## 使い魔の姿（カード用）
static func familiar_preview(ci: CanvasItem, id: String, c: Vector2, t: float, col: Color, alpha := 1.0) -> void:
	var bob := sin(t * 4.0) * 3.0
	var a := alpha
	match id:
		"karasu":
			var flap := sin(t * 10.0) * 8.0
			var dark := Cfg.with_a(Color(0.12, 0.10, 0.18), a)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-4, bob), c + Vector2(-34, bob - 12 + flap), c + Vector2(-28, bob + 4)]), dark)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(4, bob), c + Vector2(34, bob - 12 + flap), c + Vector2(28, bob + 4)]), dark)
			ci.draw_circle(c + Vector2(0, bob), 13.0, dark)
			ci.draw_circle(c + Vector2(0, bob - 13), 9.0, Cfg.with_a(Color(0.16, 0.14, 0.22), a))
			ci.draw_circle(c + Vector2(-3.5, bob - 15), 2.5, Cfg.with_a(Color(1, 0.85, 0.2), a))
			ci.draw_circle(c + Vector2(3.5, bob - 15), 2.5, Cfg.with_a(Color(1, 0.85, 0.2), a))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-3, bob - 10), c + Vector2(3, bob - 10), c + Vector2(0, bob - 3)]), Cfg.with_a(Color(0.6, 0.5, 0.3), a))
		"neko":
			var cc := Cfg.with_a(col, a)
			ci.draw_circle(c + Vector2(0, bob + 4), 16.0, cc)
			ci.draw_circle(c + Vector2(0, bob - 14), 12.0, cc)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-11, bob - 18), c + Vector2(-7, bob - 32), c + Vector2(-2, bob - 21)]), cc)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(11, bob - 18), c + Vector2(7, bob - 32), c + Vector2(2, bob - 21)]), cc)
			for sgn in [-1.0, 1.0]:
				var pts := PackedVector2Array()
				for i in 7:
					var kk := float(i) / 6.0
					pts.append(c + Vector2(sgn * (8.0 + kk * 22.0) + sin(t * 4.0 + kk * 3.0 + sgn) * 4.0, bob + 8.0 + kk * 14.0))
				ci.draw_polyline(pts, Cfg.with_a(col.darkened(0.15), a), 4.0, true)
			ci.draw_circle(c + Vector2(-4.5, bob - 15), 2.2, Cfg.with_a(Cfg.C_INK, a))
			ci.draw_circle(c + Vector2(4.5, bob - 15), 2.2, Cfg.with_a(Cfg.C_INK, a))
			ci.draw_line(c + Vector2(-4, bob - 9), c + Vector2(4, bob - 9), Cfg.with_a(Cfg.C_INK, a), 1.5)
		"shiki":
			ci.draw_circle(c + Vector2(0, bob), 26.0, Cfg.with_a(Color(0.85, 0.75, 1.0), 0.15 * a))
			var paper := Cfg.with_a(Cfg.C_PAPER, a)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, bob - 26), c + Vector2(10, bob - 8), c + Vector2(6, bob - 8), c + Vector2(13, bob + 18), c + Vector2(-13, bob + 18), c + Vector2(-6, bob - 8), c + Vector2(-10, bob - 8)]), paper)
			ci.draw_line(c + Vector2(-20, bob - 4), c + Vector2(-6, bob - 6), paper, 4.0)
			ci.draw_line(c + Vector2(20, bob - 4), c + Vector2(6, bob - 6), paper, 4.0)
			ci.draw_rect(Rect2(c + Vector2(-4, bob - 2), Vector2(8, 10)), Cfg.with_a(Color(0.85, 0.2, 0.25), a))
			ci.draw_line(c + Vector2(0, bob - 26), c + Vector2(0, bob - 18), Cfg.with_a(Cfg.C_INK, a), 1.5)


static func draw(ci: CanvasItem, kind: String, c: Vector2, r: float, col: Color, col2: Color,
		t: float, alpha := 1.0) -> void:
	var a := Cfg.with_a(col, alpha)
	var a2 := Cfg.with_a(col2, alpha)
	var wt := Color(1, 1, 1, alpha * 0.9)
	var ink := Cfg.with_a(Cfg.C_INK, alpha)
	# 共通の台座：淡い円と細い輪
	ci.draw_circle(c, r * 1.15, Cfg.with_a(col, 0.10 * alpha))
	ci.draw_arc(c, r * 1.15, 0, TAU, 48, Cfg.with_a(col, 0.35 * alpha), 1.5, true)
	match kind:
		"sun":
			for i in 12:
				var ang := t * 0.3 + TAU * float(i) / 12.0
				var l := r * (1.0 if i % 2 == 0 else 0.82)
				ci.draw_line(c + Vector2(cos(ang), sin(ang)) * r * 0.62, c + Vector2(cos(ang), sin(ang)) * l, a2, r * 0.07, true)
			ci.draw_circle(c, r * 0.55, a)
			ci.draw_circle(c, r * 0.40, Cfg.with_a(Color(1, 0.97, 0.85), alpha))
			ci.draw_arc(c, r * 0.5, 0, TAU, 32, wt, 1.5, true)
		"storm":
			for i in 3:
				var y := c.y - r * 0.35 + float(i) * r * 0.32
				var pts := PackedVector2Array()
				for j in 13:
					var k := float(j) / 12.0
					var x := c.x - r * 0.85 + k * r * 1.7
					pts.append(Vector2(x, y + sin(k * TAU * 1.5 + t * 2.0 + float(i)) * r * 0.12))
				ci.draw_polyline(pts, Cfg.with_a(col, alpha * (1.0 - float(i) * 0.25)), r * 0.09, true)
			# 剣
			ci.draw_line(c + Vector2(r * 0.45, r * 0.6), c + Vector2(-r * 0.3, -r * 0.75), wt, r * 0.08, true)
			ci.draw_line(c + Vector2(-r * 0.05, -r * 0.35), c + Vector2(-r * 0.4, -r * 0.05), a2, r * 0.09, true)
		"thunder":
			var pts2 := PackedVector2Array([
				c + Vector2(r * 0.15, -r * 0.95), c + Vector2(-r * 0.35, r * 0.05), c + Vector2(r * 0.02, r * 0.05),
				c + Vector2(-r * 0.2, r * 0.95), c + Vector2(r * 0.45, -r * 0.15), c + Vector2(r * 0.08, -r * 0.15)])
			ci.draw_colored_polygon(pts2, a)
			ci.draw_polyline(pts2 + PackedVector2Array([pts2[0]]), wt, 1.5, true)
			for i in 4:
				var ang := t * 1.5 + TAU * float(i) / 4.0
				ci.draw_circle(c + Vector2(cos(ang), sin(ang)) * r * 0.95, 2.0, a2)
		"moon":
			ci.draw_circle(c, r * 0.75, a)
			ci.draw_circle(c + Vector2(r * 0.3, -r * 0.15), r * 0.62, Cfg.with_a(Cfg.C_BG.lerp(col2, 0.25), alpha))
			ci.draw_circle(c + Vector2(-r * 0.55, r * 0.4), r * 0.06, wt)
			ci.draw_circle(c + Vector2(r * 0.7, r * 0.6), r * 0.05, wt)
			ci.draw_circle(c + Vector2(r * 0.5, -r * 0.8), r * 0.04, wt)
		"fan":
			var a0 := PI * 1.15
			var a1 := PI * 1.85
			ci.draw_arc(c + Vector2(0, r * 0.5), r * 1.0, a0, a1, 24, a, r * 0.16, true)
			ci.draw_arc(c + Vector2(0, r * 0.5), r * 0.86, a0, a1, 24, a2, r * 0.06, true)
			for i in 7:
				var ang := lerpf(a0, a1, float(i) / 6.0)
				ci.draw_line(c + Vector2(0, r * 0.5), c + Vector2(0, r * 0.5) + Vector2(cos(ang), sin(ang)) * r * 0.9, ink, 1.2, true)
			ci.draw_circle(c + Vector2(0, r * 0.5), r * 0.08, wt)
			ci.draw_circle(c + Vector2(0, -r * 0.35), r * 0.16, Cfg.with_a(Color(0.85, 0.2, 0.3), alpha))
		"fox":
			var face := PackedVector2Array([
				c + Vector2(0, r * 0.95), c + Vector2(r * 0.7, r * 0.1), c + Vector2(r * 0.55, -r * 0.9),
				c + Vector2(r * 0.2, -r * 0.35), c + Vector2(-r * 0.2, -r * 0.35), c + Vector2(-r * 0.55, -r * 0.9),
				c + Vector2(-r * 0.7, r * 0.1)])
			ci.draw_colored_polygon(face, Cfg.with_a(Cfg.C_PAPER, alpha))
			ci.draw_polyline(face + PackedVector2Array([face[0]]), a, 2.0, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.55, -r * 0.9), c + Vector2(r * 0.2, -r * 0.35), c + Vector2(r * 0.45, -r * 0.3)]), a2)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.55, -r * 0.9), c + Vector2(-r * 0.2, -r * 0.35), c + Vector2(-r * 0.45, -r * 0.3)]), a2)
			ci.draw_line(c + Vector2(-r * 0.45, -r * 0.05), c + Vector2(-r * 0.2, r * 0.1), Cfg.with_a(Color(0.85, 0.2, 0.3), alpha), r * 0.08, true)
			ci.draw_line(c + Vector2(r * 0.45, -r * 0.05), c + Vector2(r * 0.2, r * 0.1), Cfg.with_a(Color(0.85, 0.2, 0.3), alpha), r * 0.08, true)
			ci.draw_circle(c + Vector2(0, r * 0.45), r * 0.06, ink)
		"gourd":
			ci.draw_circle(c + Vector2(0, r * 0.35), r * 0.55, a)
			ci.draw_circle(c + Vector2(0, -r * 0.35), r * 0.38, a)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.12, -r * 0.95), Vector2(r * 0.24, r * 0.25)), a2)
			ci.draw_arc(c + Vector2(0, r * 0.35), r * 0.55, 0, TAU, 32, wt, 1.5, true)
			ci.draw_arc(c + Vector2(0, -r * 0.35), r * 0.38, 0, TAU, 24, wt, 1.5, true)
			ci.draw_line(c + Vector2(-r * 0.3, -r * 0.05), c + Vector2(r * 0.3, -r * 0.05), a2, r * 0.06, true)
			ci.draw_circle(c + Vector2(r * 0.18, r * 0.2), r * 0.08, Cfg.with_a(Color(1, 1, 1), alpha * 0.6))
		"gate":
			# 千引の岩：割れ目のある巨岩と黄泉の光
			var rock := PackedVector2Array([
				c + Vector2(-r * 0.8, r * 0.8), c + Vector2(-r * 0.9, -r * 0.2), c + Vector2(-r * 0.5, -r * 0.85),
				c + Vector2(r * 0.3, -r * 0.9), c + Vector2(r * 0.85, -r * 0.3), c + Vector2(r * 0.75, r * 0.8)])
			ci.draw_colored_polygon(rock, Cfg.with_a(col2.darkened(0.4), alpha))
			ci.draw_polyline(rock + PackedVector2Array([rock[0]]), a, 2.0, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(r * 0.05, -r * 0.9), c + Vector2(-r * 0.1, -r * 0.3),
				c + Vector2(r * 0.15, r * 0.1), c + Vector2(0, r * 0.8)]), a, r * 0.07, true)
			for i in 3:
				var y := c.y + r * 0.7 - fmod(t * 0.6 + float(i) * 0.5, 1.5) * r
				ci.draw_circle(Vector2(c.x + sin(t * 2.0 + float(i)) * r * 0.15, y), r * 0.06, wt)
		"road":
			# 鳥居と道
			ci.draw_line(c + Vector2(-r * 0.95, r * 0.05), c + Vector2(r * 0.95, -r * 0.05), a, r * 0.16, true)
			ci.draw_line(c + Vector2(-r * 0.7, r * 0.32), c + Vector2(r * 0.7, r * 0.32), a, r * 0.1, true)
			ci.draw_line(c + Vector2(-r * 0.5, r * 0.0), c + Vector2(-r * 0.5, r * 0.95), a, r * 0.11, true)
			ci.draw_line(c + Vector2(r * 0.5, r * 0.0), c + Vector2(r * 0.5, r * 0.95), a, r * 0.11, true)
			ci.draw_line(c + Vector2(0, r * 0.05), c + Vector2(0, r * 0.32), a2, r * 0.08, true)
			for i in 3:
				var k := fmod(t * 0.5 + float(i) / 3.0, 1.0)
				ci.draw_circle(c + Vector2(0, r * 0.95 - k * r * 0.6), r * (0.05 + 0.03 * (1.0 - k)), Cfg.with_a(Color(1, 1, 1), alpha * (1.0 - k)))
		_:
			ci.draw_circle(c, r * 0.6, a)
