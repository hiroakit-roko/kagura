class_name Emblem
extends RefCounted

## 神々の紋章を _draw で描く。UI（選択画面・HUD）と共用。


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
