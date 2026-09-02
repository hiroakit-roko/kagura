class_name Ui
extends CanvasLayer

## HUD・主神選択・恩恵選択・神酒・タイトル/ゲームオーバー画面。すべて _draw で描画する。
## フォントは Web 版でも日本語が出るようプロジェクトに同梱した TTF を使う。

signal kami_chosen(id: String)
signal boon_chosen(idx: int)
signal reroll_requested
signal miki_chosen(id: String)
signal start_requested
signal restart_requested

var font: Font
var font_bold: Font
var font_display: Font
var hud: HudView
var kami_view: KamiChoiceView
var boons_view: BoonsView
var miki_view: MikiView
var overlay: OverlayView


static func load_fonts() -> Array:
	var body: Font = load("res://fonts/ZenKakuGothicNew-Medium.ttf")
	if body == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Hiragino Sans", "Noto Sans CJK JP", "Yu Gothic", "Sans-Serif"])
		body = sf
	var bold := FontVariation.new()
	bold.base_font = body
	bold.variation_embolden = 0.7
	var disp: Font = load("res://fonts/ShipporiMinchoB1-Bold.subset.ttf")
	if disp == null:
		disp = bold
	elif disp is FontFile:
		(disp as FontFile).fallbacks = [body]
	return [body, bold, disp]


static func txt(ci: CanvasItem, f: Font, pos: Vector2, s: String, size: float, col: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, shadow := true) -> void:
	if f == null:
		return
	if shadow:
		ci.draw_string(f, pos + Vector2(1.5, 1.5), s, align, width, int(size),
				Color(0, 0, 0, col.a * 0.65))
	ci.draw_string(f, pos, s, align, width, int(size), col)


## 縦書き（1 文字ずつ下へ）
static func vtxt(ci: CanvasItem, f: Font, pos: Vector2, s: String, size: float, col: Color) -> void:
	if f == null:
		return
	var y := pos.y
	for ch in s:
		ci.draw_string(f, Vector2(pos.x - size * 0.5, y) + Vector2(1.5, 1.5), ch, HORIZONTAL_ALIGNMENT_CENTER, size, int(size), Color(0, 0, 0, col.a * 0.6))
		ci.draw_string(f, Vector2(pos.x - size * 0.5, y), ch, HORIZONTAL_ALIGNMENT_CENTER, size, int(size), col)
		y += size * 1.08


## 麻の葉風の背景模様
static func pattern(ci: CanvasItem, rect: Rect2, col: Color, step := 46.0, t := 0.0) -> void:
	var off := fmod(t * 6.0, step)
	var y := rect.position.y - step + off
	var row := 0
	while y < rect.end.y + step:
		var x := rect.position.x - step + (step * 0.5 if row % 2 == 1 else 0.0)
		while x < rect.end.x + step:
			var c := Vector2(x, y)
			for i in 6:
				var a0 := TAU * float(i) / 6.0
				var a1 := TAU * float(i + 1) / 6.0
				var p0 := c + Vector2(cos(a0), sin(a0)) * step * 0.5
				var p1 := c + Vector2(cos(a1), sin(a1)) * step * 0.5
				ci.draw_line(p0, p1, col, 1.0)
				ci.draw_line(c, p0, col, 1.0)
			x += step
		y += step * 0.87
		row += 1


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fs := load_fonts()
	font = fs[0]
	font_bold = fs[1]
	font_display = fs[2]

	hud = HudView.new()
	_setup_view(hud)
	kami_view = KamiChoiceView.new()
	_setup_view(kami_view)
	kami_view.visible = false
	boons_view = BoonsView.new()
	_setup_view(boons_view)
	boons_view.visible = false
	miki_view = MikiView.new()
	_setup_view(miki_view)
	miki_view.visible = false
	overlay = OverlayView.new()
	_setup_view(overlay)
	overlay.visible = false


func _setup_view(v: Control) -> void:
	v.set("ui", self)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)


func show_kami_choice(ids: Array) -> void:
	hide_cards()
	kami_view.ids = ids
	kami_view.anim = 0.0
	kami_view.hover = -1
	kami_view.visible = true


func show_boons(kami_id: String, offers: Array, rerolls: int, title: String) -> void:
	hide_cards()
	boons_view.kami_id = kami_id
	boons_view.offers = offers
	boons_view.rerolls = rerolls
	boons_view.title = title
	boons_view.anim = 0.0
	boons_view.hover = -1
	var k := Kami.kami(kami_id)
	var lines: Array = k["lines"]
	boons_view.quote = String(lines[randi() % lines.size()])
	boons_view.visible = true


func show_miki(ids: Array) -> void:
	hide_cards()
	miki_view.ids = ids
	miki_view.anim = 0.0
	miki_view.hover = -1
	miki_view.visible = true


func hide_cards() -> void:
	kami_view.visible = false
	boons_view.visible = false
	miki_view.visible = false


func choice_visible() -> bool:
	return kami_view.visible or boons_view.visible or miki_view.visible


func banner(text: String, sub := "", col := Color(1, 1, 1)) -> void:
	hud.banner_text = text
	hud.banner_sub = sub
	hud.banner_col = col
	hud.banner_t = 2.2


func _unhandled_input(e: InputEvent) -> void:
	var idx := -1
	var click := Vector2(-1, -1)
	if e is InputEventKey and e.pressed and not e.echo:
		var k := (e as InputEventKey).keycode
		match k:
			KEY_1, KEY_KP_1: idx = 0
			KEY_2, KEY_KP_2: idx = 1
			KEY_3, KEY_KP_3: idx = 2
			KEY_4, KEY_KP_4: idx = 3
			KEY_5, KEY_KP_5: idx = 4
			KEY_6, KEY_KP_6: idx = 5
			KEY_7, KEY_KP_7: idx = 6
			KEY_8, KEY_KP_8: idx = 7
			KEY_9, KEY_KP_9: idx = 8
		if boons_view.visible and k == KEY_R and boons_view.rerolls > 0:
			reroll_requested.emit()
			return
		if overlay.visible and (k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE):
			if overlay.mode == 0:
				start_requested.emit()
			else:
				restart_requested.emit()
			return
	elif e is InputEventMouseButton and e.pressed \
			and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		click = (e as InputEventMouseButton).position
		if overlay.visible:
			if overlay.mode == 0:
				start_requested.emit()
			else:
				restart_requested.emit()
			return

	if kami_view.visible:
		if click.x >= 0:
			idx = kami_view.card_at(click)
		if idx >= 0 and idx < kami_view.ids.size():
			Sfx.play("select", -8.0)
			kami_chosen.emit(String(kami_view.ids[idx]))
	elif boons_view.visible:
		if click.x >= 0:
			idx = boons_view.card_at(click)
		if idx >= 0 and idx < boons_view.offers.size():
			Sfx.play("select", -8.0)
			Fx.shake_add(3.0)
			boon_chosen.emit(idx)
	elif miki_view.visible:
		if click.x >= 0:
			idx = miki_view.card_at(click)
		if idx >= 0 and idx < miki_view.ids.size():
			Sfx.play("select", -8.0)
			miki_chosen.emit(String(miki_view.ids[idx]))


# =====================================================================
## 選択系ビューの共通部分（カード矩形・ホバー・フェード）
class ChoiceView:
	extends Control

	var ui: Ui
	var anim := 0.0
	var hover := -1
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		anim = minf(1.0, anim + delta * 3.0)
		var h := card_at(get_local_mouse_position())
		if h != hover:
			hover = h
			if h >= 0:
				Sfx.play("hover", -18.0, 1.0, 0.05)
		queue_redraw()

	func count() -> int:
		return 0

	func rect_of(_i: int) -> Rect2:
		return Rect2()

	func card_at(p: Vector2) -> int:
		for i in count():
			if rect_of(i).has_point(p):
				return i
		return -1

	func backdrop(col: Color) -> void:
		draw_rect(Rect2(0, 0, Cfg.W, Cfg.H), Color(0.03, 0.02, 0.06, 0.86 * anim))
		Ui.pattern(self, Rect2(0, 0, Cfg.W, Cfg.H), Cfg.with_a(col, 0.05 * anim), 52.0, _t)
		# 上下の帯
		draw_rect(Rect2(0, 0, Cfg.W, 6), Cfg.with_a(col, 0.6 * anim))
		draw_rect(Rect2(0, Cfg.H - 6, Cfg.W, 6), Cfg.with_a(col, 0.6 * anim))

	## 和紙風のカード地
	func card_bg(r: Rect2, col: Color, sel: bool, a: float) -> void:
		draw_rect(r.grow(6.0), Color(0, 0, 0, 0.35 * a))
		draw_rect(r, Color(0.08, 0.06, 0.12, 0.97 * a))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3.0)), Cfg.with_a(col, a))
		draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3.0), Vector2(r.size.x, 3.0)), Cfg.with_a(col, a * 0.6))
		draw_rect(r, Cfg.with_a(col, (1.0 if sel else 0.5) * a), false, 2.0 if sel else 1.2)
		if sel:
			draw_rect(r.grow(5.0), Cfg.with_a(col, 0.35 * a), false, 1.5)
			draw_rect(r, Cfg.with_a(col, 0.06 * a))
		# 角飾り
		for cx in [r.position.x + 8.0, r.end.x - 8.0]:
			for cy in [r.position.y + 10.0, r.end.y - 10.0]:
				draw_circle(Vector2(cx, cy), 1.8, Cfg.with_a(col, 0.8 * a))


# =====================================================================
class HudView:
	extends Control

	var ui: Ui
	var banner_text := ""
	var banner_sub := ""
	var banner_col := Color(1, 1, 1)
	var banner_t := 0.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if banner_t > 0.0:
			banner_t = maxf(0.0, banner_t - delta)
		queue_redraw()

	func _draw() -> void:
		var g := Game.inst
		if g == null:
			return
		var p := g.player
		if g.state in [Game.St.PLAY, Game.St.KAMI, Game.St.BOON, Game.St.MIKI, Game.St.PAUSE]:
			if p != null and is_instance_valid(p):
				_draw_hp(p)
				_draw_xp(p)
				_draw_gods(p)
				_draw_skills(p)
			_draw_top(g)
			_draw_boss(g)
		if banner_t > 0.0:
			_draw_banner()
		if g.state == Game.St.PAUSE:
			draw_rect(Rect2(0, 0, Cfg.W, Cfg.H), Color(0.02, 0.03, 0.06, 0.6))
			Ui.txt(self, ui.font_display, Vector2(0, 460), "小休止", 52, Color(1, 1, 1),
					HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
			Ui.txt(self, ui.font, Vector2(0, 500), "P で再開", 18,
					Color(0.85, 0.9, 1.0, 0.85), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
			if p != null and is_instance_valid(p):
				_draw_boon_list(p, 560.0)

	func _bar(r: Rect2, k: float, col: Color, bg := Color(0.08, 0.06, 0.12, 0.85)) -> void:
		draw_rect(r.grow(2.0), Color(0, 0, 0, 0.45))
		draw_rect(r, bg)
		if k > 0.0:
			var f := r
			f.size.x = r.size.x * clampf(k, 0.0, 1.0)
			draw_rect(f, col)
			draw_rect(Rect2(f.position, Vector2(f.size.x, 2.0)), Color(1, 1, 1, 0.28))
		draw_rect(r, Color(1, 1, 1, 0.16), false, 1.0)

	func _draw_hp(p: Player) -> void:
		var r := Rect2(18, 18, 240, 15)
		var k: float = p.hp / maxf(1.0, float(p.stats["max_hp"]))
		var col := Cfg.C_HP.lerp(Color(1, 0.35, 0.35), clampf(1.0 - k * 1.6, 0.0, 1.0))
		_bar(r, k, col)
		Ui.txt(self, ui.font_bold, Vector2(24, 30), "%d / %d" % [int(ceil(p.hp)),
				int(p.stats["max_hp"])], 12, Color(1, 1, 1, 0.95))
		if p.shield > 0:
			draw_circle(Vector2(272, 26), 7.0, Cfg.with_a(Cfg.C_GOLD, 0.9))
			draw_arc(Vector2(272, 26), 9.5, 0, TAU, 16, Color(1, 1, 1, 0.5), 1.0, true)

	func _draw_xp(p: Player) -> void:
		var r := Rect2(18, Cfg.H - 24, Cfg.W - 36, 9)
		_bar(r, p.xp / maxf(1.0, p.xp_next), Cfg.C_XP)
		Ui.txt(self, ui.font_bold, Vector2(18, Cfg.H - 31), "位 %d" % p.level, 13,
				Color(0.8, 0.95, 1.0))
		Ui.txt(self, ui.font, Vector2(0, Cfg.H - 31), "%d / %d" % [int(p.xp), int(p.xp_next)],
				11, Color(0.7, 0.85, 1.0, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, Cfg.W - 18)

	## 左側：主神と副神の紋章、その下に所持恩恵のチップ
	func _draw_gods(p: Player) -> void:
		var y := 62.0
		for i in p.gods.size():
			var k := Kami.kami(p.gods[i])
			var r := 17.0 if i == 0 else 12.0
			var c := Vector2(18.0 + r + 2.0, y + r)
			Emblem.draw(self, String(k["emblem"]), c, r, k["color"], k["color2"], _t, 0.95)
			Ui.txt(self, ui.font_display, Vector2(c.x + r + 8.0, y + r + 5.0),
					String(k["name"]), 14 if i == 0 else 12, Cfg.with_a(k["color"], 0.95))
			if i == 0:
				Ui.txt(self, ui.font, Vector2(c.x + r + 8.0, y + 6.0), "主神", 9, Color(1, 0.9, 0.7, 0.8))
			else:
				Ui.txt(self, ui.font, Vector2(c.x + r + 8.0, y + 4.0), "副神", 9, Color(0.85, 0.85, 1.0, 0.7))
			y += r * 2.0 + 12.0
		_draw_chips(p, y + 4.0)

	func _draw_chips(p: Player, y0: float) -> void:
		var x := 20.0
		var y := y0
		var ids: Array = p.boons.keys()
		for id: String in ids:
			var b := Kami.boon(id)
			if b.is_empty():
				continue
			var rar := int(p.boons[id]["rar"])
			var col: Color = Cfg.RAR_COLOR[rar]
			var kc: Color = Kami.kami(String(b["kami"]))["color"]
			draw_rect(Rect2(x, y, 20, 20), Cfg.with_a(kc, 0.22))
			draw_rect(Rect2(x, y, 20, 20), Cfg.with_a(col, 0.85), false, 1.5)
			Ui.txt(self, ui.font_display, Vector2(x, y + 15), String(b["name"]).substr(0, 1), 12,
					Color(1, 1, 1, 0.95), HORIZONTAL_ALIGNMENT_CENTER, 20)
			var lv: int = int(p.boons[id]["lv"])
			if lv > 1:
				Ui.txt(self, ui.font_bold, Vector2(x + 11, y + 22), str(lv), 9, Cfg.C_GOLD)
			y += 24.0
			if y > Cfg.H - 180.0:
				y = y0
				x += 24.0

	## 右下：詠唱の残弾・疾走・神招きゲージ
	func _draw_skills(p: Player) -> void:
		# 神招きゲージ（縦）
		var gx := Cfg.W - 34.0
		var gy := Cfg.H - 262.0
		var gh := 130.0
		var has_call: bool = p.slots.get(Cfg.Slot.CALL, "") != ""
		draw_rect(Rect2(gx - 2, gy - 2, 16, gh + 4), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(gx, gy, 12, gh), Color(0.08, 0.06, 0.12, 0.85))
		var kc := p.kami_color(p.slot_kami(Cfg.Slot.CALL)) if has_call else Color(0.5, 0.5, 0.6)
		var k := p.call_gauge
		if k > 0.0:
			var fh := gh * k
			var pulse := 1.0 if k < 0.999 else 0.8 + 0.2 * sin(_t * 8.0)
			draw_rect(Rect2(gx, gy + gh - fh, 12, fh), Cfg.with_a(kc, pulse))
		for i in range(1, 4):
			var yy := gy + gh * (1.0 - 0.25 * float(i))
			draw_line(Vector2(gx, yy), Vector2(gx + 12, yy), Color(0, 0, 0, 0.6), 1.5)
		draw_rect(Rect2(gx, gy, 12, gh), Color(1, 1, 1, 0.2), false, 1.0)
		if has_call:
			var ready := k >= 0.25
			Ui.txt(self, ui.font_display, Vector2(gx - 6, gy - 10), "招", 18,
					Cfg.with_a(kc, 0.6 + 0.4 * float(ready) * (0.5 + 0.5 * sin(_t * 6.0))), HORIZONTAL_ALIGNMENT_CENTER, 24)
			Ui.txt(self, ui.font, Vector2(gx - 8, gy + gh + 16), "X", 11, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 28)
		else:
			Ui.txt(self, ui.font, Vector2(gx - 10, gy - 10), "招", 12, Color(1, 1, 1, 0.25), HORIZONTAL_ALIGNMENT_CENTER, 32)

		# 詠唱の残弾
		var cx := Cfg.W - 70.0
		var cy := Cfg.H - 92.0
		var cc := p.kami_color(p.slot_kami(Cfg.Slot.CAST)) if p.slot_kami(Cfg.Slot.CAST) != "" else Cfg.C_PBULLET
		var mx: int = int(p.stats["cast_max"])
		for i in mx:
			var c := Vector2(cx - float(mx - 1 - i) * 22.0, cy)
			if i < p.cast_charges:
				draw_circle(c, 8.0, Cfg.with_a(cc, 0.9))
				draw_circle(c + Vector2(-2, -2), 3.0, Color(1, 1, 1, 0.8))
			else:
				draw_arc(c, 8.0, 0, TAU, 20, Cfg.with_a(cc, 0.35), 1.5, true)
				if i == p.cast_charges:
					var kk := 1.0 - p.cast_cd / maxf(0.01, p.cast_cd_time())
					draw_arc(c, 8.0, -PI * 0.5, -PI * 0.5 + TAU * kk, 20, Cfg.with_a(cc, 0.9), 2.5, true)
		Ui.txt(self, ui.font, Vector2(cx - float(mx) * 22.0 + 6.0, cy + 26), "詠唱 Z", 11, Color(1, 1, 1, 0.6))

		# 疾走
		var dx := Cfg.W - 34.0
		var dy := Cfg.H - 92.0
		var dk := 1.0 - p.dash_cool / maxf(0.01, p.dash_cd_time())
		var dc := p.kami_color(p.slot_kami(Cfg.Slot.DASH)) if p.slot_kami(Cfg.Slot.DASH) != "" else Color(0.9, 0.9, 1.0)
		draw_arc(Vector2(dx, dy), 9.0, 0, TAU, 20, Cfg.with_a(dc, 0.3), 1.5, true)
		draw_arc(Vector2(dx, dy), 9.0, -PI * 0.5, -PI * 0.5 + TAU * dk, 20, Cfg.with_a(dc, 0.9), 2.5, true)
		Ui.txt(self, ui.font, Vector2(dx - 20, dy + 26), "疾走", 11, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 40)

	func _draw_top(g: Game) -> void:
		Ui.txt(self, ui.font_display, Vector2(0, 34), "第 %d 波" % g.wave, 22,
				Color(1, 1, 1, 0.95), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		Ui.txt(self, ui.font, Vector2(0, 24), "功徳", 10, Color(0.85, 0.8, 0.95, 0.85),
				HORIZONTAL_ALIGNMENT_RIGHT, Cfg.W - 18)
		Ui.txt(self, ui.font_bold, Vector2(0, 42), str(g.score), 17, Color(1, 1, 1, 0.95),
				HORIZONTAL_ALIGNMENT_RIGHT, Cfg.W - 18)

	func _draw_boss(g: Game) -> void:
		var b := g.boss
		if b == null or not is_instance_valid(b):
			return
		var r := Rect2(90, 78, Cfg.W - 180, 11)
		_bar(r, b.hp / b.max_hp, Color(1, 0.3, 0.4))
		Ui.txt(self, ui.font_display, Vector2(0, 70), b.boss_name, 14, Color(1, 0.75, 0.8),
				HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		for i in b.phase():
			draw_circle(Vector2(Cfg.W - 76 + i * 12, 84), 4.0, Color(1, 0.85, 0.4))

	func _draw_banner() -> void:
		var k := banner_t / 2.2
		var a := clampf(sin(k * PI) * 2.2, 0.0, 1.0)
		var y := 330.0 - (1.0 - k) * 16.0
		var c := banner_col
		c.a = a
		draw_rect(Rect2(0, y - 42, Cfg.W, 78), Color(0, 0, 0, 0.4 * a))
		draw_rect(Rect2(0, y - 42, Cfg.W, 2), Color(c.r, c.g, c.b, a * 0.7))
		draw_rect(Rect2(0, y + 34, Cfg.W, 2), Color(c.r, c.g, c.b, a * 0.7))
		Ui.txt(self, ui.font_display, Vector2(0, y), banner_text, 32, c, HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		if banner_sub != "":
			Ui.txt(self, ui.font, Vector2(0, y + 26), banner_sub, 14,
					Color(1, 1, 1, a * 0.85), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)

	## 所持恩恵の一覧（小休止・ゲームオーバーで使う）
	func _draw_boon_list(p: Player, y0: float) -> void:
		var y := y0
		for id: String in p.boons.keys():
			var b := Kami.boon(id)
			if b.is_empty():
				continue
			var rar := int(p.boons[id]["rar"])
			var lv := int(p.boons[id]["lv"])
			var col: Color = Cfg.RAR_COLOR[rar]
			Ui.txt(self, ui.font, Vector2(90, y), Cfg.RAR_NAME[rar], 13, col)
			Ui.txt(self, ui.font_bold, Vector2(112, y), String(b["name"]) + ("  Lv.%d" % lv if lv > 1 else ""), 14, Color(1, 1, 1))
			Ui.txt(self, ui.font, Vector2(280, y), Kami.describe(b, rar, lv), 11, Color(0.85, 0.88, 1.0, 0.85), HORIZONTAL_ALIGNMENT_LEFT, 280)
			y += 22.0
			if y > Cfg.H - 60.0:
				break


# =====================================================================
## 主神の選択
class KamiChoiceView:
	extends ChoiceView

	var ids: Array = []

	const CW := 188.0
	const CH := 560.0
	const CY := 190.0

	func count() -> int:
		return ids.size()

	func rect_of(i: int) -> Rect2:
		var total := ids.size()
		var gap := 14.0
		var w := float(total) * CW + float(total - 1) * gap
		var x := (Cfg.W - w) * 0.5 + float(i) * (CW + gap)
		return Rect2(x, CY, CW, CH)

	func _draw() -> void:
		backdrop(Cfg.C_GOLD)
		Ui.txt(self, ui.font_display, Vector2(0, 112), "主神を選べ", 44, Cfg.with_a(Cfg.C_GOLD, anim),
				HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		Ui.txt(self, ui.font, Vector2(0, 146), "最初に選んだ神が主神となる。伝説の恩恵は主神からのみ授かる。", 13,
				Color(0.9, 0.9, 1.0, 0.85 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		Ui.txt(self, ui.font, Vector2(0, 166), "のちに恩恵を受けた 2 柱が副神として加わる。", 13,
				Color(0.9, 0.9, 1.0, 0.7 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		for i in ids.size():
			_draw_card(i)
		var hint := "[1] [2] [3] またはクリックで選ぶ"
		Ui.txt(self, ui.font, Vector2(0, CY + CH + 40), hint, 14,
				Color(0.85, 0.88, 1.0, 0.9 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		if hover >= 0 and hover < ids.size():
			var k := Kami.kami(ids[hover])
			Ui.txt(self, ui.font, Vector2(0, CY + CH + 70), "「" + String(k["intro"]) + "」", 13,
					Cfg.with_a(k["color"], 0.9), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)

	func _draw_card(i: int) -> void:
		var k := Kami.kami(ids[i])
		var r := rect_of(i)
		var sel := (i == hover)
		var pop := clampf(anim * 1.4 - float(i) * 0.15, 0.0, 1.0)
		if pop <= 0.0:
			return
		var col: Color = k["color"]
		var rr := r.grow((4.0 if sel else 0.0) - (1.0 - pop) * 30.0)
		card_bg(rr, col, sel, pop)
		var a := pop
		var cx := rr.position.x + rr.size.x * 0.5

		# 紋章と後光
		var ec := Vector2(cx, rr.position.y + 92.0)
		if sel:
			draw_circle(ec, 62.0 + 4.0 * sin(_t * 3.0), Cfg.with_a(col, 0.10 * a))
		Emblem.draw(self, String(k["emblem"]), ec, 46.0, col, k["color2"], _t, a)

		Ui.txt(self, ui.font_display, Vector2(rr.position.x, rr.position.y + 188), String(k["name"]), 24,
				Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
		Ui.txt(self, ui.font, Vector2(rr.position.x, rr.position.y + 208), String(k["kana"]), 11,
				Cfg.with_a(col, a * 0.9), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
		Ui.txt(self, ui.font, Vector2(rr.position.x, rr.position.y + 230), String(k["title"]), 13,
				Color(0.9, 0.9, 1.0, a * 0.85), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
		draw_line(Vector2(rr.position.x + 24, rr.position.y + 246), Vector2(rr.end.x - 24, rr.position.y + 246), Cfg.with_a(col, 0.4 * a), 1.0)

		# 神威
		var st := String(k["status"])
		Ui.txt(self, ui.font, Vector2(rr.position.x + 16, rr.position.y + 270), "司るもの　" + String(k["domain"]), 12,
				Color(0.85, 0.85, 1.0, a * 0.9))
		if st != "":
			draw_rect(Rect2(rr.position.x + 16, rr.position.y + 282, 62, 20), Cfg.with_a(col, 0.25 * a))
			Ui.txt(self, ui.font_bold, Vector2(rr.position.x + 16, rr.position.y + 297), "神威 " + st, 12,
					Cfg.with_a(col, a), HORIZONTAL_ALIGNMENT_CENTER, 62)
		draw_multiline_string(ui.font, Vector2(rr.position.x + 16, rr.position.y + 322), String(k["status_desc"]),
				HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 32, 12, 3, Color(0.85, 0.9, 1.0, a * 0.9),
				TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_GRAPHEME_BOUND)

		# 攻撃の恩恵（主神から最初に授かる恩恵の例）
		var boons := Kami.boons_of(String(k["id"]))
		var atk := {}
		for b in boons:
			if int(b["slot"]) == Cfg.Slot.ATTACK:
				atk = b
		draw_line(Vector2(rr.position.x + 24, rr.position.y + 380), Vector2(rr.end.x - 24, rr.position.y + 380), Cfg.with_a(col, 0.4 * a), 1.0)
		Ui.txt(self, ui.font, Vector2(rr.position.x + 16, rr.position.y + 402), "授かる恩恵の例", 11,
				Color(1, 0.9, 0.7, a * 0.8))
		if not atk.is_empty():
			Ui.txt(self, ui.font_display, Vector2(rr.position.x + 16, rr.position.y + 424), String(atk["name"]), 16,
					Color(1, 1, 1, a))
			draw_multiline_string(ui.font, Vector2(rr.position.x + 16, rr.position.y + 446), Kami.describe(atk, Cfg.Rar.RARE, 1),
					HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 32, 11, 4, Color(0.85, 0.9, 1.0, a * 0.85),
				TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_GRAPHEME_BOUND)

		Ui.txt(self, ui.font_bold, Vector2(rr.position.x + 10, rr.end.y - 12), "[%d]" % (i + 1), 14,
				Cfg.with_a(col, a))


# =====================================================================
## 恩恵の選択（神が現れる）
class BoonsView:
	extends ChoiceView

	var kami_id := ""
	var offers: Array = []
	var rerolls := 0
	var title := "神との邂逅"
	var quote := ""

	const CW := 192.0
	const CH := 318.0
	const CY := 318.0

	func count() -> int:
		return offers.size()

	func rect_of(i: int) -> Rect2:
		var total := offers.size()
		var gap := 12.0
		var w := float(total) * CW + float(total - 1) * gap
		var x := (Cfg.W - w) * 0.5 + float(i) * (CW + gap)
		return Rect2(x, CY, CW, CH)

	func _draw() -> void:
		var k := Kami.kami(kami_id)
		var col: Color = k["color"] if not k.is_empty() else Cfg.C_GOLD
		backdrop(col)
		var p := Game.inst.player

		# 神の顕現：紋章と後光
		var ec := Vector2(Cfg.W * 0.5, 128.0)
		for i in 3:
			var rr := 70.0 + float(i) * 22.0 + 6.0 * sin(_t * 2.0 + float(i))
			draw_arc(ec, rr, 0, TAU, 64, Cfg.with_a(col, (0.25 - 0.06 * float(i)) * anim), 1.5, true)
		for i in 16:
			var ang := _t * 0.25 + TAU * float(i) / 16.0
			var l := 150.0 + 30.0 * sin(_t * 1.5 + float(i) * 1.3)
			draw_line(ec + Vector2(cos(ang), sin(ang)) * 60.0, ec + Vector2(cos(ang), sin(ang)) * l,
					Cfg.with_a(col, 0.10 * anim), 6.0, true)
		if not k.is_empty():
			Emblem.draw(self, String(k["emblem"]), ec, 48.0, col, k["color2"], _t, anim)

		Ui.txt(self, ui.font, Vector2(0, 40), title, 14, Cfg.with_a(Cfg.C_GOLD, anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		if not k.is_empty():
			var role := ""
			if p != null:
				if p.main_god() == kami_id: role = "主神"
				elif p.gods.has(kami_id): role = "副神"
				else: role = "新たな神"
			Ui.txt(self, ui.font_display, Vector2(0, 224), String(k["name"]), 34, Color(1, 1, 1, anim),
					HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
			Ui.txt(self, ui.font, Vector2(0, 246), String(k["kana"]) + "　・　" + String(k["title"]) + "　［" + role + "］", 12,
					Cfg.with_a(col, 0.9 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
			Ui.txt(self, ui.font, Vector2(0, 280), "「" + quote + "」", 14,
					Color(0.95, 0.93, 1.0, 0.9 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)

		for i in offers.size():
			_draw_card(i)

		var hint := "[1] [2] [3] またはクリックで受け取る"
		if rerolls > 0:
			hint += "　　[R] 神籤を引き直す ×%d" % rerolls
		Ui.txt(self, ui.font, Vector2(0, CY + CH + 34), hint, 14,
				Color(0.85, 0.88, 1.0, 0.9 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		# スロットの説明
		if hover >= 0 and hover < offers.size():
			var b: Dictionary = offers[hover]["boon"]
			Ui.txt(self, ui.font, Vector2(0, CY + CH + 60), Cfg.SLOT_HINT[int(b["slot"])], 12,
					Color(0.85, 0.88, 1.0, 0.7 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)

	func _draw_card(i: int) -> void:
		var o: Dictionary = offers[i]
		var b: Dictionary = o["boon"]
		var rar := int(o["rar"])
		var r := rect_of(i)
		var sel := (i == hover)
		var pop := clampf(anim * 1.4 - float(i) * 0.12, 0.0, 1.0)
		if pop <= 0.0:
			return
		var col: Color = Cfg.RAR_COLOR[rar]
		var kc: Color = Kami.kami(String(b["kami"]))["color"]
		var rr := r.grow((4.0 if sel else 0.0) - (1.0 - pop) * 30.0)
		var a := pop
		card_bg(rr, col, sel, a)
		var special := rar == Cfg.Rar.LEGENDARY or rar == Cfg.Rar.DUO
		if special:
			# 伝説・双神は後光を足す
			for j in 10:
				var ang := _t * 0.5 + TAU * float(j) / 10.0
				var c := rr.position + rr.size * 0.5
				draw_line(c + Vector2(cos(ang), sin(ang)) * rr.size.x * 0.55, c + Vector2(cos(ang), sin(ang)) * rr.size.x * 0.75,
						Cfg.with_a(col, 0.12 * a), 8.0, true)

		# レアリティ帯
		draw_rect(Rect2(rr.position + Vector2(0, 3), Vector2(rr.size.x, 30.0)), Cfg.with_a(col, (0.30 if sel else 0.20) * a))
		Ui.txt(self, ui.font_display, rr.position + Vector2(12, 26), Cfg.RAR_NAME[rar], 18, Cfg.with_a(col, a))
		Ui.txt(self, ui.font, rr.position + Vector2(36, 24), Cfg.RAR_LONG[rar], 10, Cfg.with_a(col, a * 0.9))
		# スロット札
		var slot := int(b["slot"])
		var sname: String = Cfg.SLOT_NAME[slot]
		if b.has("kami2"):
			sname = "双神"
		draw_rect(Rect2(rr.end.x - 58, rr.position.y + 8, 48, 20), Cfg.with_a(kc, 0.35 * a))
		Ui.txt(self, ui.font_bold, Vector2(rr.end.x - 58, rr.position.y + 23), sname, 12, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 48)

		# 神の紋章（小）と名前
		var k := Kami.kami(String(b["kami"]))
		Emblem.draw(self, String(k["emblem"]), rr.position + Vector2(rr.size.x * 0.5, 76), 26.0, kc, k["color2"], _t, a * 0.95)
		if b.has("kami2"):
			var k2 := Kami.kami(String(b["kami2"]))
			Emblem.draw(self, String(k2["emblem"]), rr.position + Vector2(rr.size.x * 0.5 + 34, 90), 16.0, k2["color"], k2["color2"], _t, a * 0.95)

		Ui.txt(self, ui.font_display, rr.position + Vector2(0, 132), String(b["name"]), 19,
				Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
		var p := Game.inst.player
		var lv := 1
		if o["exchange"] and p != null and p.boons.has(o["cur"]):
			lv = int(p.boons[o["cur"]]["lv"])
		draw_multiline_string(ui.font, rr.position + Vector2(14, 160), Kami.describe(b, rar, lv),
				HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 28, 12, 6, Color(0.9, 0.92, 1.0, a * 0.95),
				TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_GRAPHEME_BOUND)

		# 交換
		if o["exchange"]:
			var cur := Kami.boon(String(o["cur"]))
			draw_rect(Rect2(rr.position.x + 8, rr.end.y - 52, rr.size.x - 16, 34), Color(1, 0.6, 0.3, 0.15 * a))
			Ui.txt(self, ui.font_bold, Vector2(rr.position.x + 14, rr.end.y - 37), "交換", 11, Color(1, 0.75, 0.4, a))
			Ui.txt(self, ui.font, Vector2(rr.position.x + 44, rr.end.y - 37), "← " + String(cur.get("name", "")), 11, Color(1, 0.9, 0.8, a * 0.9))
			Ui.txt(self, ui.font, Vector2(rr.position.x + 14, rr.end.y - 24), "レアリティが 1 段上がる", 10, Color(1, 0.8, 0.6, a * 0.8))
		elif special:
			Ui.txt(self, ui.font, Vector2(rr.position.x, rr.end.y - 26),
					"神酒では深められない" , 10, Cfg.with_a(col, a * 0.8), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)

		Ui.txt(self, ui.font_bold, Vector2(rr.position.x + 10, rr.end.y - 12), "[%d]" % (i + 1), 14, Cfg.with_a(col, a))


# =====================================================================
## 神酒：恩恵のレベルを 1 つ上げる
class MikiView:
	extends ChoiceView

	var ids: Array = []

	const CW := 186.0
	const CH := 138.0
	const COLS := 3

	func count() -> int:
		return ids.size()

	func rect_of(i: int) -> Rect2:
		var col := i % COLS
		var row := int(i / COLS)
		var gap := 12.0
		var w := float(COLS) * CW + float(COLS - 1) * gap
		var x := (Cfg.W - w) * 0.5 + float(col) * (CW + gap)
		return Rect2(x, 250.0 + float(row) * (CH + gap), CW, CH)

	func _draw() -> void:
		backdrop(Cfg.C_GOLD)
		Ui.txt(self, ui.font_display, Vector2(0, 120), "神酒", 48, Cfg.with_a(Cfg.C_GOLD, anim),
				HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		Ui.txt(self, ui.font, Vector2(0, 156), "恩恵をひとつ選び、その位を深める。", 14,
				Color(0.9, 0.9, 1.0, 0.85 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		Ui.txt(self, ui.font, Vector2(0, 178), "深めるほど伸びは緩やかになる。", 12,
				Color(0.9, 0.9, 1.0, 0.6 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		var p := Game.inst.player
		for i in ids.size():
			var id := String(ids[i])
			var b := Kami.boon(id)
			var rar := int(p.boons[id]["rar"])
			var lv := int(p.boons[id]["lv"])
			var r := rect_of(i)
			var sel := i == hover
			var pop := clampf(anim * 1.5 - float(i) * 0.08, 0.0, 1.0)
			if pop <= 0.0:
				continue
			var col: Color = Cfg.RAR_COLOR[rar]
			var kc: Color = Kami.kami(String(b["kami"]))["color"]
			var rr := r.grow((3.0 if sel else 0.0) - (1.0 - pop) * 20.0)
			card_bg(rr, col, sel, pop)
			Emblem.draw(self, String(Kami.kami(String(b["kami"]))["emblem"]), rr.position + Vector2(24, 28), 14.0, kc, Kami.kami(String(b["kami"]))["color2"], _t, pop)
			Ui.txt(self, ui.font_display, rr.position + Vector2(46, 32), String(b["name"]), 15, Color(1, 1, 1, pop))
			Ui.txt(self, ui.font, rr.position + Vector2(46, 48), "%s  Lv.%d → Lv.%d" % [Cfg.RAR_LONG[rar], lv, lv + 1], 10, Cfg.with_a(col, pop))
			var v0 := Kami.fmt_value(b, Kami.value(b, rar, lv))
			var v1 := Kami.fmt_value(b, Kami.value(b, rar, lv + 1))
			Ui.txt(self, ui.font_bold, rr.position + Vector2(14, 76), v0 + "  →  " + v1, 15, Cfg.with_a(Cfg.C_GOLD, pop))
			draw_multiline_string(ui.font, rr.position + Vector2(14, 96), Kami.describe(b, rar, lv + 1),
					HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 28, 10, 3, Color(0.85, 0.9, 1.0, pop * 0.85),
				TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_GRAPHEME_BOUND)
			Ui.txt(self, ui.font_bold, Vector2(rr.end.x - 30, rr.position.y + 18), "[%d]" % (i + 1), 12, Cfg.with_a(col, pop))
		var rows := int((ids.size() + COLS - 1) / COLS)
		Ui.txt(self, ui.font, Vector2(0, 250.0 + float(rows) * (CH + 12.0) + 24.0), "数字キー またはクリックで選ぶ", 14,
				Color(0.85, 0.88, 1.0, 0.9 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)


# =====================================================================
class OverlayView:
	extends Control

	var ui: Ui
	var mode := 0  # 0=タイトル 1=ゲームオーバー
	var stats_lines: Array = []
	var _t := 0.0
	var _tex: Texture2D
	var _petals: Array = []

	func _ready() -> void:
		_tex = load("res://image/title.png")
		for i in 40:
			_petals.append({"pos": Vector2(randf() * Cfg.W, randf() * Cfg.H), "vel": Vector2(randf_range(-20, 20), randf_range(40, 110)),
				"rot": randf() * TAU, "spin": randf_range(-3, 3), "size": randf_range(2.5, 5.0)})

	func _process(delta: float) -> void:
		_t += delta
		for p: Dictionary in _petals:
			p.pos += p.vel * delta
			p.pos.x += sin(_t + p.rot) * 20.0 * delta
			p.rot += p.spin * delta
			if p.pos.y > Cfg.H + 10.0:
				p.pos = Vector2(randf() * Cfg.W, -10.0)
		queue_redraw()

	func _draw() -> void:
		if mode == 0:
			_title()
		else:
			_over()

	func _title() -> void:
		# タイトル絵：縦画面に合わせて少女のいる右側を切り出す
		if _tex != null:
			var tw := float(_tex.get_width())
			var th := float(_tex.get_height())
			var scale := Cfg.H / th
			var src_w := Cfg.W / scale
			var src_x := clampf(1100.0 - src_w * 0.5, 0.0, tw - src_w)   # 少女の位置（x≈1100）を中央に
			draw_texture_rect_region(_tex, Rect2(0, 0, Cfg.W, Cfg.H), Rect2(src_x, 0, src_w, th),
					Color(0.92, 0.88, 1.0))
		else:
			draw_rect(Rect2(0, 0, Cfg.W, Cfg.H), Cfg.C_BG)
		# 上下のグラデーション帯（文字を載せるため）
		for i in 14:
			var k := float(i) / 14.0
			draw_rect(Rect2(0, k * 330.0, Cfg.W, 330.0 / 14.0 + 1.0), Color(0.05, 0.02, 0.10, 0.85 * (1.0 - k)))
			draw_rect(Rect2(0, Cfg.H - 330.0 + k * 330.0, Cfg.W, 330.0 / 14.0 + 1.0), Color(0.05, 0.02, 0.10, 0.88 * k))
		# 花弁
		for p: Dictionary in _petals:
			var d := Vector2(cos(p.rot), sin(p.rot))
			var n := d.orthogonal()
			var s: float = p.size
			draw_colored_polygon(PackedVector2Array([p.pos + d * s * 1.5, p.pos + n * s * 0.7, p.pos - d * s * 1.5, p.pos - n * s * 0.7]),
					Color(0.9, 0.7, 1.0, 0.5))

		var bob := sin(_t * 1.6) * 3.0
		Ui.txt(self, ui.font_display, Vector2(0, 178 + bob), "神楽", 122, Color(0.98, 0.94, 1.0),
				HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		Ui.txt(self, ui.font, Vector2(0, 214 + bob), "K A G U R A   A S C E N T", 17, Color(0.85, 0.6, 1.0),
				HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		Ui.txt(self, ui.font_display, Vector2(0, 252 + bob), "八百万の加護を纏いて、穢れを祓え", 17, Color(1, 0.9, 0.75, 0.95),
				HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)

		var y := 706.0
		var lines := [
			["移動", "WASD / 矢印"], ["疾走", "Space（短い無敵）"], ["詠唱", "Z / J（強い一撃・2 発）"],
			["神招き", "X / K（ゲージが 1/4 以上で発動）"], ["低速", "Shift"], ["小休止 / 音", "P / M"],
		]
		for l: Array in lines:
			Ui.txt(self, ui.font_bold, Vector2(150, y), String(l[0]), 13, Color(1, 0.9, 0.75, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 90)
			Ui.txt(self, ui.font, Vector2(260, y), String(l[1]), 13, Color(0.9, 0.92, 1.0, 0.9))
			y += 22.0

		Ui.txt(self, ui.font, Vector2(0, 856), "神々から恩恵を受け、主神と 2 柱の副神とともに参道を登れ。", 13,
				Color(0.85, 0.86, 1.0, 0.85), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		var blink := 0.55 + 0.45 * sin(_t * 4.0)
		Ui.txt(self, ui.font_display, Vector2(0, 908), "ENTER / SPACE で はじめる", 22,
				Color(1, 1, 1, blink), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)

	func _over() -> void:
		draw_rect(Rect2(0, 0, Cfg.W, Cfg.H), Color(0.02, 0.01, 0.05, 0.78))
		Ui.pattern(self, Rect2(0, 0, Cfg.W, Cfg.H), Color(1, 0.3, 0.4, 0.04), 52.0, _t)
		Ui.txt(self, ui.font_display, Vector2(0, 250), "討たれた", 58, Color(1, 0.3, 0.4),
				HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		Ui.txt(self, ui.font, Vector2(0, 284), "神楽は途切れ、参道は闇に沈んだ", 13, Color(0.9, 0.8, 0.85, 0.8),
				HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		var y := 350.0
		for row: Array in stats_lines:
			Ui.txt(self, ui.font, Vector2(0, y), String(row[0]), 16,
					Color(0.65, 0.75, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, Cfg.W * 0.5 - 14.0)
			Ui.txt(self, ui.font_display, Vector2(Cfg.W * 0.5 + 14.0, y), String(row[1]), 20,
					Color(1, 1, 1), HORIZONTAL_ALIGNMENT_LEFT)
			y += 34.0
		var g := Game.inst
		if g != null and g.player != null and is_instance_valid(g.player):
			_draw_boons(g.player, y + 20.0)
		var blink := 0.55 + 0.45 * sin(_t * 4.0)
		Ui.txt(self, ui.font_display, Vector2(0, 880), "ENTER でもう一度　　ESC で題目へ", 20,
				Color(1, 1, 1, blink), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)

	func _draw_boons(p: Player, y0: float) -> void:
		var y := y0
		for id: String in p.boons.keys():
			var b := Kami.boon(id)
			if b.is_empty():
				continue
			var rar := int(p.boons[id]["rar"])
			var lv := int(p.boons[id]["lv"])
			Ui.txt(self, ui.font, Vector2(110, y), Cfg.RAR_NAME[rar], 12, Cfg.RAR_COLOR[rar])
			Ui.txt(self, ui.font_bold, Vector2(130, y), String(b["name"]) + ("  Lv.%d" % lv if lv > 1 else ""), 13, Color(1, 1, 1, 0.95))
			Ui.txt(self, ui.font, Vector2(290, y), Kami.kami(String(b["kami"]))["name"], 11, Cfg.with_a(Kami.kami(String(b["kami"]))["color"], 0.9))
			y += 20.0
			if y > 850.0:
				break
