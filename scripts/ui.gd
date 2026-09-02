class_name Ui
extends CanvasLayer

## HUD・主神選択・恩恵選択・神酒・タイトル/ゲームオーバー画面。すべて _draw で描画する。
## 漆塗りの板に金の縁、和紙のカードという調子で、ゲージ類も装飾を付ける。

signal kami_chosen(id: String)
signal familiar_chosen(id: String)
signal boon_chosen(idx: int)
signal reroll_requested
signal miki_chosen(id: String)
signal start_requested
signal restart_requested
signal continue_requested

var font: Font
var font_bold: Font
var font_display: Font
var hud: HudView
var kami_view: KamiChoiceView
var familiar_view: FamiliarView
var confirm_view: ConfirmView
var boons_view: BoonsView
var miki_view: MikiView
var overlay: OverlayView

const LACQUER := Color(0.07, 0.045, 0.10, 0.92)
const GOLD := Color(0.95, 0.80, 0.45)


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


const BRK := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_GRAPHEME_BOUND


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


static func para(ci: CanvasItem, f: Font, pos: Vector2, s: String, width: float, size: int, lines: int, col: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	ci.draw_multiline_string(f, pos + Vector2(1.2, 1.2), s, align, width, size, lines, Color(0, 0, 0, col.a * 0.5), BRK)
	ci.draw_multiline_string(f, pos, s, align, width, size, lines, col, BRK)


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


## 絵があれば読み込む（無ければ null）
## 絵はここで参照を保持する（_draw 内で load するだけだと毎フレーム作り直されて白く出る）
static var _art_cache: Dictionary = {}


static func art(name: String) -> Texture2D:
	if _art_cache.has(name):
		return _art_cache[name]
	var path := "res://image/%s.jpg" % name
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_art_cache[name] = tex
	return tex


## 絵を枠いっぱいに敷く（cover。中心寄せ、上寄せ率 focus_y）
static func draw_cover(ci: CanvasItem, tex: Texture2D, r: Rect2, a := 1.0, focus_y := 0.35) -> void:
	if tex == null:
		return
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var scale := maxf(r.size.x / tw, r.size.y / th)
	var sw := r.size.x / scale
	var sh := r.size.y / scale
	ci.draw_texture_rect_region(tex, r, Rect2((tw - sw) * 0.5, (th - sh) * focus_y, sw, sh), Color(1, 1, 1, a))


## 漆の板：暗い地に金の細縁と角飾り
static func panel(ci: CanvasItem, r: Rect2, col := GOLD, a := 1.0, fill_a := 0.85) -> void:
	ci.draw_rect(r.grow(2.0), Color(0, 0, 0, 0.35 * a))
	ci.draw_rect(r, Color(LACQUER.r, LACQUER.g, LACQUER.b, fill_a * a))
	ci.draw_rect(r, Cfg.with_a(col, 0.55 * a), false, 1.2)
	ci.draw_rect(r.grow(-3.0), Cfg.with_a(col, 0.18 * a), false, 1.0)
	for cx in [r.position.x + 5.0, r.end.x - 5.0]:
		for cy in [r.position.y + 5.0, r.end.y - 5.0]:
			ci.draw_circle(Vector2(cx, cy), 1.6, Cfg.with_a(col, 0.9 * a))


## 装飾つきの横ゲージ：内側の光、上端のハイライト、目盛り、流れる光沢
static func bar(ci: CanvasItem, r: Rect2, k: float, col: Color, t: float, ticks := 4, frame := GOLD) -> void:
	ci.draw_rect(r.grow(3.0), Color(0, 0, 0, 0.5))
	ci.draw_rect(r.grow(1.0), Cfg.with_a(frame, 0.55), false, 1.0)
	ci.draw_rect(r, Color(0.06, 0.04, 0.09, 0.95))
	k = clampf(k, 0.0, 1.0)
	if k > 0.0:
		var f := Rect2(r.position, Vector2(r.size.x * k, r.size.y))
		ci.draw_rect(f, col.darkened(0.35))
		ci.draw_rect(Rect2(f.position, Vector2(f.size.x, f.size.y * 0.55)), col)
		ci.draw_rect(Rect2(f.position, Vector2(f.size.x, 2.0)), Color(1, 1, 1, 0.35))
		# 流れる光沢
		var sx := fmod(t * 120.0, r.size.x + 60.0) - 30.0
		var gx := clampf(sx, 0.0, f.size.x)
		if sx > 0.0 and sx < f.size.x:
			ci.draw_rect(Rect2(f.position.x + gx - 8.0, f.position.y, 16.0, f.size.y), Color(1, 1, 1, 0.16))
		# 先端の輝き
		ci.draw_circle(Vector2(f.end.x, f.position.y + f.size.y * 0.5), f.size.y * 0.55, Cfg.with_a(col.lightened(0.4), 0.55))
	for i in range(1, ticks):
		var x := r.position.x + r.size.x * float(i) / float(ticks)
		ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0, 0, 0, 0.45), 1.0)
	ci.draw_rect(r, Color(1, 1, 1, 0.12), false, 1.0)


## 神格の輪：紋章の周りに神徳の溜まりを弧で示す
static func kami_ring(ci: CanvasItem, p: Player, id: String, c: Vector2, r: float, t: float, a := 1.0, show_lv := true) -> void:
	var k := Kami.kami(id)
	var col: Color = k["color"]
	var lv: int = p.kami_lv.get(id, 1)
	var need := Kami.kami_xp_need(lv)
	var frac := clampf(float(p.kami_xp.get(id, 0.0)) / maxf(1.0, need), 0.0, 1.0) if lv < 10 else 1.0
	ci.draw_circle(c, r + 6.0, Color(0.05, 0.03, 0.08, 0.7 * a))
	ci.draw_arc(c, r + 5.0, 0, TAU, 40, Cfg.with_a(col, 0.25 * a), 3.0, true)
	ci.draw_arc(c, r + 5.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 40, Cfg.with_a(col, 0.95 * a), 3.0, true)
	Emblem.draw(ci, String(k["emblem"]), c, r, col, k["color2"], t, a)
	if show_lv:
		var bp := c + Vector2(r * 0.75, r * 0.75)
		ci.draw_circle(bp, 8.5, Color(0.05, 0.03, 0.08, 0.95 * a))
		ci.draw_arc(bp, 8.5, 0, TAU, 16, Cfg.with_a(col, 0.9 * a), 1.2, true)
		var ui := Game.inst.ui
		Ui.txt(ci, ui.font_bold, bp + Vector2(-8.5, 4.0), str(lv), 10, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 17.0, false)


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
	familiar_view = FamiliarView.new()
	_setup_view(familiar_view)
	familiar_view.visible = false
	confirm_view = ConfirmView.new()
	_setup_view(confirm_view)
	confirm_view.visible = false
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


func show_familiar_choice() -> void:
	hide_cards()
	familiar_view.anim = 0.0
	familiar_view.hover = -1
	familiar_view.visible = true


func show_kami_choice(ids: Array, role := "主神") -> void:
	hide_cards()
	kami_view.ids = ids
	kami_view.role = role
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
	familiar_view.visible = false
	confirm_view.visible = false
	boons_view.visible = false
	miki_view.visible = false


func choice_visible() -> bool:
	return kami_view.visible or boons_view.visible or miki_view.visible or familiar_view.visible or confirm_view.visible


## 契約の確認：主神／副神を迎える前に、神の絵と代償を見せる
func ask_contract(kami_id: String, role: String, on_ok: Callable) -> void:
	confirm_view.kami_id = kami_id
	confirm_view.role = role
	confirm_view.on_ok = on_ok
	confirm_view.anim = 0.0
	confirm_view.hover = -1
	confirm_view.load_portrait()
	confirm_view.visible = true
	Sfx.play("descend", -10.0, 1.1)


func banner(text: String, sub := "", col := Color(1, 1, 1)) -> void:
	hud.banner_text = text
	hud.banner_sub = sub
	hud.banner_col = col
	hud.banner_t = 2.4


## ボスの名乗り：縦書きの名前と二つ名を数秒見せる
func boss_intro(name: String, title: String, final: bool, key := "") -> void:
	hud.intro_name = name
	hud.intro_title = title
	hud.intro_key = key
	hud.intro_final = final
	hud.intro_t = 3.6


## 小さな告知（詠唱名など）：画面下寄りに短く
func banner_small(text: String, col := Color(1, 1, 1)) -> void:
	hud.small_text = text
	hud.small_col = col
	hud.small_t = 1.0


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
			elif overlay.mode == 2:
				continue_requested.emit()
			else:
				restart_requested.emit()
			return
		if overlay.visible and overlay.mode == 2 and k == KEY_R:
			restart_requested.emit()
			return
	elif e is InputEventMouseButton and e.pressed \
			and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		click = (e as InputEventMouseButton).position
		if overlay.visible:
			if overlay.mode == 0:
				start_requested.emit()
			elif overlay.mode == 2:
				continue_requested.emit()
			else:
				restart_requested.emit()
			return

	if confirm_view.visible:
		var ok := false
		var cancel := false
		if e is InputEventKey and e.pressed and not e.echo:
			var kk := (e as InputEventKey).keycode
			ok = kk in [KEY_1, KEY_KP_1, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
			cancel = kk in [KEY_2, KEY_KP_2, KEY_ESCAPE, KEY_BACKSPACE]
		elif click.x >= 0:
			var ci := confirm_view.card_at(click)
			ok = ci == 0
			cancel = ci == 1
		if ok:
			Sfx.play("descend", -4.0, 1.3)
			confirm_view.visible = false
			confirm_view.on_ok.call()
		elif cancel:
			Sfx.play("clap", -12.0)
			confirm_view.visible = false
			# 元の選択画面へ戻す
			if kami_view.ids.size() > 0 and Game.inst.state == Game.St.KAMI:
				kami_view.visible = true
			elif Game.inst.state == Game.St.BOON:
				boons_view.visible = true
		return

	if familiar_view.visible:
		if click.x >= 0:
			idx = familiar_view.card_at(click)
		if idx >= 0 and idx < Familiar.LIST.size():
			Sfx.play("select", -8.0)
			familiar_chosen.emit(String(Familiar.LIST[idx]["id"]))
	elif kami_view.visible:
		if click.x >= 0:
			idx = kami_view.card_at(click)
		if idx >= 0 and idx < kami_view.ids.size():
			Sfx.play("select", -8.0)
			var kid := String(kami_view.ids[idx])
			kami_view.visible = false
			ask_contract(kid, kami_view.role, func(): kami_chosen.emit(kid))
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
## 選択系ビューの共通部分
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
		draw_rect(Rect2(0, 0, Cfg.W, Cfg.H), Color(0.03, 0.02, 0.06, 0.88 * anim))
		Ui.pattern(self, Rect2(0, 0, Cfg.W, Cfg.H), Cfg.with_a(col, 0.05 * anim), 52.0, _t)
		draw_rect(Rect2(0, 0, Cfg.W, 6), Cfg.with_a(col, 0.6 * anim))
		draw_rect(Rect2(0, Cfg.H - 6, Cfg.W, 6), Cfg.with_a(col, 0.6 * anim))
		draw_rect(Rect2(0, 6, Cfg.W, 1), Color(1, 1, 1, 0.15 * anim))
		draw_rect(Rect2(0, Cfg.H - 7, Cfg.W, 1), Color(1, 1, 1, 0.15 * anim))

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
	var small_text := ""
	var small_col := Color(1, 1, 1)
	var small_t := 0.0
	var intro_name := ""
	var intro_title := ""
	var intro_key := ""
	var intro_final := false
	var intro_t := 0.0
	var _t := 0.0
	var _hp_shown := 1.0

	func _process(delta: float) -> void:
		_t += delta
		banner_t = maxf(0.0, banner_t - delta)
		small_t = maxf(0.0, small_t - delta)
		intro_t = maxf(0.0, intro_t - delta)
		queue_redraw()

	func _draw() -> void:
		var g := Game.inst
		if g == null:
			return
		var p := g.player
		if g.state in [Game.St.PLAY, Game.St.KAMI, Game.St.BOON, Game.St.MIKI, Game.St.PAUSE, Game.St.CLEAR]:
			if p != null and is_instance_valid(p):
				_draw_hp(p)
				_draw_xp(p)
				_draw_gods(p)
				if not (Touch.inst != null and Touch.inst.active):
					_draw_skills(p)
			_draw_top(g)
			_draw_boss(g)
		if banner_t > 0.0:
			_draw_banner()
		if intro_t > 0.0:
			_draw_intro()
		if small_t > 0.0:
			var a := clampf(small_t * 2.0, 0.0, 1.0)
			Ui.txt(self, ui.font_display, Vector2(0, Cfg.H - 150.0), small_text, 20, Cfg.with_a(small_col, a),
					HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		if g.state == Game.St.PAUSE:
			draw_rect(Rect2(0, 0, Cfg.W, Cfg.H), Color(0.02, 0.03, 0.06, 0.62))
			Ui.txt(self, ui.font_display, Vector2(0, 300), "小休止", 52, Color(1, 1, 1),
					HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
			Ui.txt(self, ui.font, Vector2(0, 336), "画面をタップ か P で再開" if (Touch.inst != null and Touch.inst.active) else "P で再開", 16,
					Color(0.85, 0.9, 1.0, 0.85), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
			if p != null and is_instance_valid(p):
				_draw_build(p, 390.0)

	## HP：命の帯
	func _draw_hp(p: Player) -> void:
		var k: float = p.hp / maxf(1.0, float(p.stats["max_hp"]))
		_hp_shown = lerpf(_hp_shown, k, 0.15)
		var r := Rect2(44, 16, 224, 14)
		Ui.panel(self, Rect2(12, 8, 270, 32), Ui.GOLD, 1.0, 0.7)
		Ui.txt(self, ui.font_display, Vector2(20, 30), "命", 18, Ui.GOLD)
		var col := Cfg.C_HP.lerp(Color(1, 0.35, 0.35), clampf(1.0 - k * 1.6, 0.0, 1.0))
		# 減った直後は白い残り帯を見せる
		if _hp_shown > k + 0.005:
			draw_rect(Rect2(r.position + Vector2(r.size.x * k, 0), Vector2(r.size.x * (_hp_shown - k), r.size.y)), Color(1, 1, 1, 0.55))
		Ui.bar(self, r, k, col, _t, 5)
		Ui.txt(self, ui.font_bold, Vector2(r.position.x, r.position.y + 11), "%d / %d" % [int(ceil(p.hp)), int(p.stats["max_hp"])],
				11, Color(1, 1, 1, 0.95), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 6.0)
		if p.shield > 0:
			draw_circle(Vector2(292, 24), 8.0, Cfg.with_a(Cfg.C_GOLD, 0.9))
			draw_arc(Vector2(292, 24), 10.5, 0, TAU, 16, Color(1, 1, 1, 0.5), 1.0, true)
			Ui.txt(self, ui.font_display, Vector2(284, 29), "鏡", 11, Cfg.C_INK, HORIZONTAL_ALIGNMENT_CENTER, 16, false)

	## 経験値：位の帯（下端）
	func _draw_xp(p: Player) -> void:
		var r := Rect2(70, Cfg.H - 22, Cfg.W - 90, 8)
		Ui.panel(self, Rect2(10, Cfg.H - 34, Cfg.W - 20, 30), Ui.GOLD, 1.0, 0.6)
		# 勾玉の印と位
		var mp := Vector2(28, Cfg.H - 19)
		draw_circle(mp, 7.0, Cfg.C_XP)
		draw_circle(mp + Vector2(-2, -2), 2.0, Color(1, 1, 1, 0.9))
		Ui.txt(self, ui.font_display, Vector2(40, Cfg.H - 13), "位 %d" % p.level, 14, Color(0.9, 0.97, 1.0))
		Ui.bar(self, r, p.xp / maxf(1.0, p.xp_next), Cfg.C_XP, _t, 8)
		Ui.txt(self, ui.font, Vector2(0, Cfg.H - 25), "%d / %d" % [int(p.xp), int(p.xp_next)],
				10, Color(0.7, 0.85, 1.0, 0.85), HORIZONTAL_ALIGNMENT_RIGHT, Cfg.W - 22)

	## 左側：迎えた神々（紋章＋神格の輪＋神器名）
	func _draw_gods(p: Player) -> void:
		var y := 52.0
		for i in p.gods.size():
			var id := String(p.gods[i])
			var k := Kami.kami(id)
			var main := i == 0
			var r := 17.0 if main else 13.0
			var c := Vector2(14.0 + 24.0, y + r + 6.0)
			var w := 176.0 if main else 150.0
			Ui.panel(self, Rect2(12, y, w, r * 2.0 + 14.0), k["color"], 0.9, 0.55)
			Ui.kami_ring(self, p, id, c, r, _t, 1.0, true)
			Ui.txt(self, ui.font, Vector2(c.x + r + 12.0, y + 14.0), "主神" if main else "副神", 9,
					Cfg.with_a(Color(1, 0.9, 0.7) if main else Color(0.85, 0.85, 1.0), 0.8))
			Ui.txt(self, ui.font_display, Vector2(c.x + r + 12.0, y + 30.0), String(k["name"]), 14 if main else 12,
					Cfg.with_a(k["color"], 0.95))
			Ui.txt(self, ui.font, Vector2(c.x + r + 12.0, y + 43.0 if main else y + 40.0), String(k["weapon"]) + ("" if main else "（半）"), 9,
					Color(1, 1, 1, 0.7))
			y += r * 2.0 + 22.0
		# 次に神を迎える位（枠が残っているとき）
		var nxt := Boons.next_recruit_level(p)
		if nxt > 0:
			var lbl := ("主神" if p.gods.is_empty() else "副神") + "　位 %d で迎える" % nxt
			draw_rect(Rect2(12, y - 6.0, 150, 18), Color(0.5, 0.5, 0.65, 0.18))
			draw_rect(Rect2(12, y - 6.0, 150, 18), Color(0.7, 0.7, 0.85, 0.35), false, 1.0)
			Ui.txt(self, ui.font, Vector2(20, y + 7.0), lbl, 9, Color(0.9, 0.9, 1.0, 0.7))
			y += 20.0
		_draw_chips(p, y + 2.0)

	func _draw_chips(p: Player, y0: float) -> void:
		var x := 16.0
		var y := y0
		for id: String in p.boons.keys():
			var b := Kami.boon(id)
			if b.is_empty():
				var cu := Kami.curse(id)
				if cu.is_empty():
					continue
				draw_rect(Rect2(x, y, 20, 20), Color(0.6, 0.1, 0.2, 0.5))
				draw_rect(Rect2(x, y, 20, 20), Color(1, 0.4, 0.5, 0.9), false, 1.5)
				Ui.txt(self, ui.font_display, Vector2(x, y + 15), "禍", 12, Color(1, 0.85, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 20)
				y += 24.0
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
			if y > Cfg.H - 200.0:
				y = y0
				x += 24.0

	## 右下：詠唱・疾走・神招き（御札の形のゲージ）
	func _draw_skills(p: Player) -> void:
		var main := p.main_god()
		var mc := p.kami_color(main) if main != "" else Color(0.6, 0.6, 0.7)
		# 神招き：縦長の御札
		var gx := Cfg.W - 44.0
		var gy := Cfg.H - 270.0
		var gw := 26.0
		var gh := 150.0
		Ui.panel(self, Rect2(gx - 6, gy - 30, gw + 12, gh + 60), mc if main != "" else Ui.GOLD, 0.95, 0.75)
		var k := p.call_gauge
		draw_rect(Rect2(gx, gy, gw, gh), Color(0.05, 0.03, 0.08, 0.9))
		if k > 0.0:
			var fh := gh * k
			var pulse := 1.0 if k < 0.999 else 0.75 + 0.25 * sin(_t * 8.0)
			draw_rect(Rect2(gx, gy + gh - fh, gw, fh), Cfg.with_a(mc.darkened(0.3), pulse))
			draw_rect(Rect2(gx + 4, gy + gh - fh, gw - 8, fh), Cfg.with_a(mc, pulse))
			# 炎のように揺れる上端
			for i in 3:
				var fx := gx + 4.0 + float(i) * (gw - 8.0) * 0.5
				var fh2 := 6.0 + 5.0 * sin(_t * 9.0 + float(i) * 2.0)
				draw_colored_polygon(PackedVector2Array([Vector2(fx - 4, gy + gh - fh), Vector2(fx + 4, gy + gh - fh), Vector2(fx, gy + gh - fh - fh2)]), Cfg.with_a(mc.lightened(0.4), 0.8 * pulse))
		for i in range(1, 4):
			var yy := gy + gh * (1.0 - 0.25 * float(i))
			draw_line(Vector2(gx, yy), Vector2(gx + gw, yy), Color(0, 0, 0, 0.55), 1.5)
		draw_rect(Rect2(gx, gy, gw, gh), Cfg.with_a(Ui.GOLD, 0.5), false, 1.0)
		var ready := main != "" and k >= 0.25
		Ui.txt(self, ui.font_display, Vector2(gx - 6, gy - 8), "招", 20,
				Cfg.with_a(mc if main != "" else Color(1, 1, 1, 0.3), 0.7 + 0.3 * float(ready) * (0.5 + 0.5 * sin(_t * 6.0))), HORIZONTAL_ALIGNMENT_CENTER, gw + 12)
		Ui.txt(self, ui.font, Vector2(gx - 6, gy + gh + 18), "X", 11, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, gw + 12)

		# 詠唱の珠と疾走の輪
		var px := Cfg.W - 150.0
		var py := Cfg.H - 88.0
		Ui.panel(self, Rect2(px - 8, py - 22, 108, 54), Ui.GOLD, 0.95, 0.7)
		var mx: int = int(p.stats["cast_max"])
		for i in mx:
			var c := Vector2(px + 10.0 + float(i) * 22.0, py)
			if i < p.cast_charges and main != "":
				draw_circle(c, 9.0, Cfg.with_a(mc, 0.3))
				draw_circle(c, 7.0, Cfg.with_a(mc, 0.95))
				draw_circle(c + Vector2(-2, -2), 2.5, Color(1, 1, 1, 0.85))
			else:
				draw_arc(c, 7.0, 0, TAU, 20, Cfg.with_a(mc, 0.35), 1.5, true)
				if i == p.cast_charges:
					var kk := 1.0 - p.cast_cd / maxf(0.01, p.cast_cd_time())
					draw_arc(c, 7.0, -PI * 0.5, -PI * 0.5 + TAU * kk, 20, Cfg.with_a(mc, 0.9), 2.5, true)
		Ui.txt(self, ui.font, Vector2(px, py + 24), "詠唱 Z", 10, Color(1, 1, 1, 0.6))
		var dx := px + 84.0
		var dk := 1.0 - p.dash_cool / maxf(0.01, p.dash_cd_time())
		draw_arc(Vector2(dx, py), 9.0, 0, TAU, 20, Color(1, 1, 1, 0.25), 1.5, true)
		draw_arc(Vector2(dx, py), 9.0, -PI * 0.5, -PI * 0.5 + TAU * dk, 20, Color(1, 1, 1, 0.9) if dk >= 1.0 else Color(0.8, 0.85, 1.0, 0.7), 2.5, true)
		if dk >= 1.0:
			draw_circle(Vector2(dx, py), 3.0, Color(1, 1, 1, 0.8))
		Ui.txt(self, ui.font, Vector2(dx - 20, py + 24), "疾走", 10, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 40)

	func _draw_top(g: Game) -> void:
		var cx := Cfg.W * 0.5
		var st := Cfg.stage_of(maxi(g.wave, 1))
		Ui.txt(self, ui.font, Vector2(0, 14), "第%sの段　%s" % [Cfg.STAGE_KANJI[st - 1], Cfg.STAGE_NAME[st - 1]], 10,
				Cfg.with_a(Ui.GOLD, 0.85), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		Ui.txt(self, ui.font_display, Vector2(0, 38), "第 %d 波" % g.wave, 22,
				Color(1, 1, 1, 0.95), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		draw_line(Vector2(cx - 96, 27), Vector2(cx - 58, 27), Cfg.with_a(Ui.GOLD, 0.7), 1.0)
		draw_line(Vector2(cx + 58, 27), Vector2(cx + 96, 27), Cfg.with_a(Ui.GOLD, 0.7), 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 54, 27), Vector2(cx - 50, 23), Vector2(cx - 46, 27), Vector2(cx - 50, 31)]), Cfg.with_a(Ui.GOLD, 0.9))
		draw_colored_polygon(PackedVector2Array([Vector2(cx + 46, 27), Vector2(cx + 50, 23), Vector2(cx + 54, 27), Vector2(cx + 50, 31)]), Cfg.with_a(Ui.GOLD, 0.9))
		Ui.txt(self, ui.font, Vector2(0, 22), "功徳", 10, Color(0.85, 0.8, 0.95, 0.85),
				HORIZONTAL_ALIGNMENT_RIGHT, Cfg.W - 18)
		Ui.txt(self, ui.font_display, Vector2(0, 42), str(g.score), 18, Color(1, 1, 1, 0.95),
				HORIZONTAL_ALIGNMENT_RIGHT, Cfg.W - 18)

	func _draw_boss(g: Game) -> void:
		var b := g.boss
		if b == null or not is_instance_valid(b):
			return
		var r := Rect2(110, 82, Cfg.W - 220, 10)
		Ui.panel(self, Rect2(92, 60, Cfg.W - 184, 40), Color(1, 0.4, 0.5), 0.95, 0.7)
		Ui.txt(self, ui.font_display, Vector2(0, 77), b.boss_name, 13, Color(1, 0.75, 0.8),
				HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		Ui.bar(self, r, b.hp / b.max_hp, Color(1, 0.3, 0.4), _t, 3, Color(1, 0.5, 0.6))
		for i in b.phase():
			draw_circle(Vector2(Cfg.W - 108 + i * 10, 74), 3.5, Color(1, 0.85, 0.4))

	func _draw_banner() -> void:
		var k := banner_t / 2.4
		var a := clampf(sin(k * PI) * 2.2, 0.0, 1.0)
		var y := 300.0 - (1.0 - k) * 16.0
		var c := banner_col
		c.a = a
		draw_rect(Rect2(0, y - 44, Cfg.W, 82), Color(0, 0, 0, 0.45 * a))
		draw_rect(Rect2(0, y - 44, Cfg.W, 2), Color(c.r, c.g, c.b, a * 0.8))
		draw_rect(Rect2(0, y + 36, Cfg.W, 2), Color(c.r, c.g, c.b, a * 0.8))
		draw_rect(Rect2(0, y - 41, Cfg.W, 1), Color(1, 1, 1, a * 0.25))
		Ui.txt(self, ui.font_display, Vector2(0, y), banner_text, 32, c, HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		if banner_sub != "":
			Ui.txt(self, ui.font, Vector2(0, y + 26), banner_sub, 14,
					Color(1, 1, 1, a * 0.85), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)

	## ボスの名乗り
	func _draw_intro() -> void:
		var k := intro_t / 3.2
		var a := clampf(minf(k * 6.0, (1.0 - k) * 6.0), 0.0, 1.0)
		var col := Color(1, 0.3, 0.35) if intro_final else Color(1, 0.6, 0.65)
		var tex := Ui.art("boss/" + intro_key)
		if tex != null:
			# 絵：画面上部に帯として敷き、下端を暗く落とす
			var pr := Rect2(0, 100, Cfg.W, 300)
			draw_rect(pr.grow(4), Color(0, 0, 0, 0.5 * a))
			Ui.draw_cover(self, tex, pr, a, 0.3)
			for gi in 8:
				var kk := float(gi) / 8.0
				draw_rect(Rect2(0, pr.end.y - 120.0 + kk * 120.0, Cfg.W, 120.0 / 8.0 + 1.0), Color(0.03, 0.02, 0.06, 0.9 * kk * a))
			draw_rect(Rect2(0, pr.position.y, Cfg.W, 2), Cfg.with_a(col, a))
			draw_rect(Rect2(0, pr.end.y - 2, Cfg.W, 2), Cfg.with_a(col, a))
		var x := Cfg.W - 90.0
		draw_rect(Rect2(x - 46, 110, 92, 330), Color(0, 0, 0, 0.55 * a))
		draw_rect(Rect2(x - 46, 110, 92, 330), Cfg.with_a(col, 0.7 * a), false, 1.5)
		draw_rect(Rect2(x - 40, 116, 80, 318), Cfg.with_a(col, 0.25 * a), false, 1.0)
		Ui.vtxt(self, ui.font_display, Vector2(x + 10, 150), intro_name, 34 if intro_name.length() <= 4 else 30, Cfg.with_a(Color(1, 1, 1), a))
		Ui.vtxt(self, ui.font, Vector2(x - 24, 136), intro_title, 13, Cfg.with_a(col, a))

	## 現在の構成（小休止・ゲームオーバーで使う）：神々と神器、恩恵
	func _draw_build(p: Player, y0: float) -> void:
		_draw_build_on(self, p, y0)

	func _draw_build_on(ci: CanvasItem, p: Player, y0: float) -> void:
		var y := y0
		for id in p.gods:
			var k := Kami.kami(id)
			Ui.kami_ring(ci, p, String(id), Vector2(90, y + 4), 14.0, _t, 1.0, true)
			Ui.txt(ci, ui.font_display, Vector2(116, y), String(k["name"]) + ("（主神）" if p.is_main(id) else "（副神）"), 14, Cfg.with_a(k["color"], 0.95))
			Ui.txt(ci, ui.font, Vector2(116, y + 16), String(k["weapon"]) + "　神格 Lv.%d　威力 ×%.2f" % [int(p.kami_lv.get(id, 1)), p.kami_power(id)], 11, Color(0.9, 0.92, 1.0, 0.85))
			y += 42.0
		y += 6.0
		for id: String in p.boons.keys():
			var b := Kami.boon(id)
			if b.is_empty():
				continue
			var rar := int(p.boons[id]["rar"])
			var lv := int(p.boons[id]["lv"])
			Ui.txt(ci, ui.font, Vector2(90, y), Cfg.RAR_NAME[rar], 12, Cfg.RAR_COLOR[rar])
			Ui.txt(ci, ui.font_bold, Vector2(112, y), String(b["name"]) + ("  ×%d" % lv if lv > 1 else ""), 13, Color(1, 1, 1))
			Ui.txt(ci, ui.font, Vector2(270, y), Kami.describe(b, rar, lv), 10, Color(0.85, 0.88, 1.0, 0.85), HORIZONTAL_ALIGNMENT_LEFT, 300)
			y += 20.0
			if y > Cfg.H - 100.0:
				break


# =====================================================================
## 契約の確認：神の絵と詳しい説明、契約の代償
class ConfirmView:
	extends ChoiceView

	var kami_id := ""
	var role := "主神"
	var on_ok: Callable
	var portrait: Texture2D

	const BW := 200.0
	const BH := 48.0

	func load_portrait() -> void:
		portrait = null
		var path := "res://image/kami/%s.jpg" % kami_id
		if ResourceLoader.exists(path):
			portrait = load(path)

	func count() -> int:
		return 2

	func rect_of(i: int) -> Rect2:
		var y := Cfg.H - 150.0
		var x := Cfg.W * 0.5 + (-BW - 12.0 if i == 0 else 12.0)
		return Rect2(x, y, BW, BH)

	func _draw() -> void:
		var k := Kami.kami(kami_id)
		if k.is_empty():
			return
		var col: Color = k["color"]
		backdrop(col)
		var a := anim
		# 絵（あれば）または大きな紋章
		var pr := Rect2(60, 60, Cfg.W - 120, 300)
		Ui.panel(self, pr.grow(6), col, a, 0.9)
		if portrait != null:
			var tw := float(portrait.get_width())
			var th := float(portrait.get_height())
			var scale := maxf(pr.size.x / tw, pr.size.y / th)
			var sw := pr.size.x / scale
			var sh := pr.size.y / scale
			draw_texture_rect_region(portrait, pr, Rect2((tw - sw) * 0.5, (th - sh) * 0.35, sw, sh), Color(1, 1, 1, a))
			# 下端を暗くして名前を載せる
			for i in 8:
				var kk := float(i) / 8.0
				draw_rect(Rect2(pr.position.x, pr.end.y - 90.0 + kk * 90.0, pr.size.x, 90.0 / 8.0 + 1.0), Color(0.03, 0.02, 0.06, 0.8 * kk * a))
		else:
			draw_rect(pr, Color(0.05, 0.03, 0.09, 0.95 * a))
			for i in 14:
				var ang := _t * 0.3 + TAU * float(i) / 14.0
				draw_line(pr.get_center() + Vector2(cos(ang), sin(ang)) * 70.0, pr.get_center() + Vector2(cos(ang), sin(ang)) * 200.0, Cfg.with_a(col, 0.08 * a), 8.0, true)
			Emblem.draw(self, String(k["emblem"]), pr.get_center() + Vector2(0, -20), 70.0, col, k["color2"], _t, a)
		Ui.txt(self, ui.font_display, Vector2(pr.position.x + 16, pr.end.y - 22), String(k["name"]), 34, Color(1, 1, 1, a))
		Ui.txt(self, ui.font, Vector2(pr.position.x + 18, pr.end.y - 6), String(k["kana"]) + "　" + String(k["title"]), 12, Cfg.with_a(col, a))
		Ui.txt(self, ui.font_display, Vector2(pr.end.x - 100, pr.position.y + 26), role + "として", 16, Cfg.with_a(Cfg.C_GOLD, a), HORIZONTAL_ALIGNMENT_RIGHT, 88)

		# 神の言葉
		Ui.txt(self, ui.font, Vector2(0, 392), "「" + String(k["intro"]) + "」", 14, Color(0.95, 0.93, 1.0, 0.9 * a), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)

		# 詳しい説明
		var x0 := 60.0
		var w := Cfg.W - 120.0
		var y := 420.0
		Ui.panel(self, Rect2(x0 - 8, y - 6, w + 16, 190), col, a, 0.8)
		Ui.txt(self, ui.font_bold, Vector2(x0 + 6, y + 14), "得意　" + String(k["role"]), 12, Cfg.with_a(col.lightened(0.2), a))
		Ui.txt(self, ui.font, Vector2(x0 + 6, y + 36), "神器", 10, Color(1, 0.9, 0.7, a * 0.85))
		Ui.txt(self, ui.font_display, Vector2(x0 + 36, y + 38), String(k["weapon"]) + ("（半分の威力）" if role == "副神" else ""), 15, Color(1, 1, 1, a))
		Ui.para(self, ui.font, Vector2(x0 + 6, y + 56), String(k["weapon_desc"]), w - 12, 11, 2, Color(0.9, 0.92, 1.0, a * 0.9))
		if role == "主神":
			Ui.txt(self, ui.font, Vector2(x0 + 6, y + 96), "詠唱 Z　" + String(k["cast"]) + "：" + String(k["cast_desc"]), 10, Color(0.9, 0.92, 1.0, a * 0.85), HORIZONTAL_ALIGNMENT_LEFT, w - 12)
			Ui.txt(self, ui.font, Vector2(x0 + 6, y + 112), "神招き X　" + String(k["call"]) + "：" + String(k["call_desc"]), 10, Color(0.9, 0.92, 1.0, a * 0.85), HORIZONTAL_ALIGNMENT_LEFT, w - 12)
		else:
			Ui.txt(self, ui.font, Vector2(x0 + 6, y + 96), "副神は神器のみ加わる。詠唱と神招きは主神の技のまま", 10, Color(0.9, 0.92, 1.0, a * 0.85))
		var st := String(k["status"])
		if st != "":
			Ui.txt(self, ui.font, Vector2(x0 + 6, y + 134), "神威 " + st + "：" + String(k["status_desc"]), 10, Color(0.85, 0.9, 1.0, a * 0.85), HORIZONTAL_ALIGNMENT_LEFT, w - 12)
		else:
			Ui.txt(self, ui.font, Vector2(x0 + 6, y + 134), String(k["status_desc"]), 10, Color(0.85, 0.9, 1.0, a * 0.85), HORIZONTAL_ALIGNMENT_LEFT, w - 12)
		Ui.txt(self, ui.font, Vector2(x0 + 6, y + 156), String(k["mark"]), 10, Cfg.with_a(col, a * 0.8))
		Ui.txt(self, ui.font, Vector2(x0 + 6, y + 174), "神器は当てるほど神格が上がる。神酒でも 1 段上がる", 10, Color(1, 1, 1, 0.55 * a))

		# 契約の代償
		y = 626.0
		Ui.panel(self, Rect2(x0 - 8, y - 6, w + 16, 96), Color(0.85, 0.2, 0.3), a, 0.9)
		# 血の滴り（縁の飾り）
		for i in 5:
			var bx := x0 + 20.0 + float(i) * (w - 40.0) / 4.0 + sin(_t * 0.7 + float(i)) * 3.0
			draw_circle(Vector2(bx, y - 6.0), 2.0 + 0.6 * float(i % 2), Color(0.7, 0.08, 0.15, 0.8 * a))
		Ui.txt(self, ui.font_display, Vector2(x0 + 6, y + 16), "契約の代償", 14, Cfg.with_a(Color(1, 0.45, 0.5), a))
		Ui.txt(self, ui.font, Vector2(x0 + 96, y + 15), "神との契りは血判に等しい。捧げたものは、二度と戻らぬ", 10, Color(1, 0.72, 0.76, 0.9 * a))
		Ui.txt(self, ui.font_bold, Vector2(x0 + 6, y + 40), "一、", 12, Color(1, 0.7, 0.75, a))
		Ui.para(self, ui.font, Vector2(x0 + 30, y + 40), String(k["cost"]), w - 40, 12, 1, Color(1, 0.92, 0.94, a))
		Ui.txt(self, ui.font_bold, Vector2(x0 + 6, y + 66), "二、", 12, Color(1, 0.7, 0.75, a))
		Ui.para(self, ui.font, Vector2(x0 + 30, y + 66), String(k["flavor"]), w - 40, 12, 2, Color(1, 0.92, 0.94, a * 0.9))

		# ボタン
		for i in 2:
			var r := rect_of(i)
			var sel := hover == i
			var bc := col if i == 0 else Color(0.7, 0.7, 0.8)
			draw_rect(r, Color(0.08, 0.06, 0.12, 0.95 * a))
			draw_rect(r, Cfg.with_a(bc, (1.0 if sel else 0.55) * a), false, 2.0 if sel else 1.2)
			if sel:
				draw_rect(r, Cfg.with_a(bc, 0.12 * a))
			var label := "契約する　[1] / Enter" if i == 0 else "考え直す　[2] / Esc"
			Ui.txt(self, ui.font_display if i == 0 else ui.font_bold, Vector2(r.position.x, r.position.y + 31), label, 15 if i == 0 else 13,
					Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


# =====================================================================
## 使い魔の選択（開始時）
class FamiliarView:
	extends ChoiceView

	const CW := 190.0
	const CH := 330.0
	const CY := 300.0

	func count() -> int:
		return Familiar.LIST.size()

	func rect_of(i: int) -> Rect2:
		var total := Familiar.LIST.size()
		var gap := 12.0
		var w := float(total) * CW + float(total - 1) * gap
		var x := (Cfg.W - w) * 0.5 + float(i) * (CW + gap)
		return Rect2(x, CY, CW, CH)

	func _draw() -> void:
		backdrop(Color(0.85, 0.75, 1.0))
		Ui.txt(self, ui.font_display, Vector2(0, 200), "使い魔を選べ", 44, Cfg.with_a(Cfg.C_GOLD, anim),
				HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		Ui.txt(self, ui.font, Vector2(0, 232), "後ろに付いて回り、自動で撃ってくれる相棒。神を迎える前の頼りになる。", 13,
				Color(0.9, 0.9, 1.0, 0.85 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		Ui.txt(self, ui.font, Vector2(0, 252), "威力は位（レベル）とともに少しずつ伸びる。", 12,
				Color(0.9, 0.9, 1.0, 0.65 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		for i in Familiar.LIST.size():
			var f: Dictionary = Familiar.LIST[i]
			var r := rect_of(i)
			var sel := i == hover
			var pop := clampf(anim * 1.4 - float(i) * 0.15, 0.0, 1.0)
			if pop <= 0.0:
				continue
			var col: Color = f["color"]
			var rr := r.grow((4.0 if sel else 0.0) - (1.0 - pop) * 30.0)
			card_bg(rr, col, sel, pop)
			var a := pop
			var x0 := rr.position.x + 14.0
			var w := rr.size.x - 28.0
			# 使い魔の姿（絵があれば絵、無ければ実演）
			var c := Vector2(rr.position.x + rr.size.x * 0.5, rr.position.y + 70.0)
			var tex := Ui.art("familiar/" + String(f["id"]))
			if tex != null:
				var pr := Rect2(rr.position.x + 4, rr.position.y + 4, rr.size.x - 8, 124)
				Ui.draw_cover(self, tex, pr, a, 0.3)
				for gi in 6:
					var kk := float(gi) / 6.0
					draw_rect(Rect2(pr.position.x, pr.end.y - 40.0 + kk * 40.0, pr.size.x, 40.0 / 6.0 + 1.0), Color(0.08, 0.06, 0.12, 0.85 * kk * a))
			else:
				draw_circle(c, 40.0, Cfg.with_a(col, 0.10 * a))
				Emblem.familiar_preview(self, String(f["id"]), c, _t, col, a)
			Ui.txt(self, ui.font_display, Vector2(rr.position.x, rr.position.y + 142), String(f["name"]), 26, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
			Ui.txt(self, ui.font, Vector2(rr.position.x, rr.position.y + 160), String(f["kana"]), 10, Cfg.with_a(col, 0.9 * a), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
			draw_rect(Rect2(x0, rr.position.y + 172, w, 20), Cfg.with_a(col, 0.18 * a))
			Ui.txt(self, ui.font_bold, Vector2(x0 + 6, rr.position.y + 187), String(f["role"]), 11, Cfg.with_a(col.lightened(0.2), a))
			Ui.para(self, ui.font, Vector2(x0, rr.position.y + 212), String(f["desc"]), w, 11, 5, Color(0.9, 0.92, 1.0, a * 0.9))
			Ui.txt(self, ui.font_bold, Vector2(x0, rr.end.y - 26), "加護　" + String(f["passive"]), 11, Cfg.with_a(Cfg.C_GOLD, a))
			Ui.txt(self, ui.font_bold, Vector2(rr.position.x + 10, rr.end.y - 10), "[%d]" % (i + 1), 12, Cfg.with_a(col, a))
		Ui.txt(self, ui.font, Vector2(0, CY + CH + 30), "[1] [2] [3] またはタップで選ぶ", 14,
				Color(0.85, 0.88, 1.0, 0.9 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)


# =====================================================================
## 主神の選択
class KamiChoiceView:
	extends ChoiceView

	var ids: Array = []
	var role := "主神"

	const CW := 190.0
	const CH := 590.0
	const CY := 176.0

	func count() -> int:
		return ids.size()

	func rect_of(i: int) -> Rect2:
		var total := ids.size()
		var gap := 12.0
		var w := float(total) * CW + float(total - 1) * gap
		var x := (Cfg.W - w) * 0.5 + float(i) * (CW + gap)
		return Rect2(x, CY, CW, CH)

	func _draw() -> void:
		var main := role == "主神"
		backdrop(Cfg.C_GOLD)
		Ui.txt(self, ui.font_display, Vector2(0, 104), "主神を選べ" if main else "副神を迎えよ", 44, Cfg.with_a(Cfg.C_GOLD, anim),
				HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		var l1 := "選んだ瞬間に、その神の神器（自動で撃つ武器）が付く。伝説の恩恵は主神からのみ。" if main \
				else "迎えた瞬間に、その神の神器が半分の威力で加わる。迎えること自体が今回の報酬。"
		var l2 := "位 4 と位 7 で新たな神が現れ、副神として 2 柱まで迎えられる。" if main \
				else "詠唱と神招きは主神の技のまま。副神の神器も当てるほど神格が上がる。"
		Ui.txt(self, ui.font, Vector2(0, 134), l1, 12,
				Color(0.9, 0.9, 1.0, 0.85 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		Ui.txt(self, ui.font, Vector2(0, 152), l2, 12,
				Color(0.9, 0.9, 1.0, 0.7 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		for i in ids.size():
			_draw_card(i)
		Ui.txt(self, ui.font, Vector2(0, CY + CH + 30), "[1] [2] [3] またはタップで選ぶ", 14,
				Color(0.85, 0.88, 1.0, 0.9 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		if hover >= 0 and hover < ids.size():
			var k := Kami.kami(ids[hover])
			Ui.txt(self, ui.font, Vector2(0, CY + CH + 52), "「" + String(k["intro"]) + "」", 13,
					Cfg.with_a(k["color"], 0.9), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		_draw_howto(CY + CH + 70.0)

	func _draw_howto(y0: float) -> void:
		var r := Rect2(40.0, y0, Cfg.W - 80.0, 96.0)
		if r.end.y > Cfg.H - 10.0:
			return
		var a := anim
		Ui.panel(self, r, Cfg.C_GOLD, a, 0.85)
		Ui.txt(self, ui.font_display, Vector2(r.position.x + 14, r.position.y + 22), "仕組み", 14, Cfg.with_a(Cfg.C_GOLD, a))
		var lines := [
			"① 神を迎えると神器（自動発射の武器）が付く。主神は 100%、副神は 50% の威力。",
			"② 位 2 で主神、位 4 と位 7 で副神を迎える。迎えるだけで報酬になり、他の選択は続かない。",
			"③ それ以外の位上がりでは神が現れ、能力を 3 枚提示する。神ごとに 9 種（凡 4・稀 3・秀 2）から 3 つまで。",
			"　 空き枠のぶんが新しい能力、残りは選んだ能力の強化（重ねると数値が伸びる）。",
		]
		var y := r.position.y + 42.0
		for l: String in lines:
			Ui.txt(self, ui.font, Vector2(r.position.x + 14, y), l, 11, Color(0.9, 0.92, 1.0, 0.9 * a))
			y += 18.0

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
		var x0 := rr.position.x + 14.0
		var w := rr.size.x - 28.0

		var ec := Vector2(cx - 44.0, rr.position.y + 76.0)
		if sel:
			draw_circle(ec, 48.0 + 4.0 * sin(_t * 3.0), Cfg.with_a(col, 0.10 * a))
		Emblem.draw(self, String(k["emblem"]), ec, 34.0, col, k["color2"], _t, a)
		# 神器の実演（小さな枡の中で動く）
		Emblem.weapon_preview(self, String(k["id"]), Rect2(cx + 4.0, rr.position.y + 26.0, 72.0, 100.0), _t, col, a)

		Ui.txt(self, ui.font_display, Vector2(rr.position.x, rr.position.y + 166), String(k["name"]), 23,
				Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
		Ui.txt(self, ui.font, Vector2(rr.position.x, rr.position.y + 184), String(k["kana"]) + "　" + String(k["title"]), 10,
				Cfg.with_a(col, a * 0.9), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
		draw_line(Vector2(x0, rr.position.y + 196), Vector2(rr.end.x - 14, rr.position.y + 196), Cfg.with_a(col, 0.4 * a), 1.0)

		# 得意
		draw_rect(Rect2(x0, rr.position.y + 206, w, 20), Cfg.with_a(col, 0.18 * a))
		Ui.txt(self, ui.font_bold, Vector2(x0 + 6, rr.position.y + 221), String(k["role"]), 11, Cfg.with_a(col.lightened(0.2), a))

		# 神器
		Ui.txt(self, ui.font, Vector2(x0, rr.position.y + 248), "神器", 10, Color(1, 0.9, 0.7, a * 0.85))
		Ui.txt(self, ui.font_display, Vector2(x0 + 30, rr.position.y + 250), String(k["weapon"]), 16, Color(1, 1, 1, a))
		Ui.para(self, ui.font, Vector2(x0, rr.position.y + 270), String(k["weapon_desc"]), w, 11, 4, Color(0.9, 0.92, 1.0, a * 0.9))

		# 神威
		var y := rr.position.y + 352.0
		var st := String(k["status"])
		if st != "":
			draw_rect(Rect2(x0, y - 13, 56, 17), Cfg.with_a(col, 0.25 * a))
			Ui.txt(self, ui.font_bold, Vector2(x0, y), "神威 " + st, 11, Cfg.with_a(col, a), HORIZONTAL_ALIGNMENT_CENTER, 56)
			Ui.para(self, ui.font, Vector2(x0, y + 18), String(k["status_desc"]), w, 10, 3, Color(0.85, 0.9, 1.0, a * 0.85))
		else:
			Ui.para(self, ui.font, Vector2(x0, y + 2), String(k["status_desc"]), w, 10, 3, Color(0.85, 0.9, 1.0, a * 0.85))

		# 詠唱と神招き
		y = rr.position.y + 430.0
		draw_line(Vector2(x0, y - 8), Vector2(rr.end.x - 14, y - 8), Cfg.with_a(col, 0.4 * a), 1.0)
		Ui.txt(self, ui.font, Vector2(x0, y + 8), "詠唱 Z", 10, Color(1, 0.9, 0.7, a * 0.85))
		Ui.txt(self, ui.font_display, Vector2(x0 + 44, y + 9), String(k["cast"]), 13, Color(1, 1, 1, a))
		Ui.para(self, ui.font, Vector2(x0, y + 26), String(k["cast_desc"]), w, 10, 2, Color(0.85, 0.9, 1.0, a * 0.85))
		Ui.txt(self, ui.font, Vector2(x0, y + 70), "神招き X", 10, Color(1, 0.9, 0.7, a * 0.85))
		Ui.txt(self, ui.font_display, Vector2(x0 + 56, y + 71), String(k["call"]), 13, Color(1, 1, 1, a))
		Ui.para(self, ui.font, Vector2(x0, y + 88), String(k["call_desc"]), w, 10, 2, Color(0.85, 0.9, 1.0, a * 0.85))

		Ui.txt(self, ui.font_bold, Vector2(rr.position.x + 10, rr.end.y - 12), "[%d]" % (i + 1), 14, Cfg.with_a(col, a))


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
	const CH := 300.0
	const CY := 296.0

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

		var ec := Vector2(Cfg.W * 0.5, 122.0)
		for i in 3:
			var rr := 66.0 + float(i) * 22.0 + 6.0 * sin(_t * 2.0 + float(i))
			draw_arc(ec, rr, 0, TAU, 64, Cfg.with_a(col, (0.25 - 0.06 * float(i)) * anim), 1.5, true)
		for i in 16:
			var ang := _t * 0.25 + TAU * float(i) / 16.0
			var l := 150.0 + 30.0 * sin(_t * 1.5 + float(i) * 1.3)
			draw_line(ec + Vector2(cos(ang), sin(ang)) * 60.0, ec + Vector2(cos(ang), sin(ang)) * l,
					Cfg.with_a(col, 0.10 * anim), 6.0, true)
		if not k.is_empty():
			Emblem.draw(self, String(k["emblem"]), ec, 46.0, col, k["color2"], _t, anim)

		Ui.txt(self, ui.font, Vector2(0, 40), title, 14, Cfg.with_a(Cfg.C_GOLD, anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		if not k.is_empty():
			var role := ""
			if p != null:
				role = "主神" if p.main_god() == kami_id else "副神"
			Ui.txt(self, ui.font_display, Vector2(0, 212), String(k["name"]), 32, Color(1, 1, 1, anim),
					HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
			Ui.txt(self, ui.font, Vector2(0, 232), String(k["kana"]) + "　・　" + String(k["title"]) + "　［" + role + "］　神器：" + String(k["weapon"]), 11,
					Cfg.with_a(col, 0.9 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
			Ui.txt(self, ui.font, Vector2(0, 262), "「" + quote + "」", 14,
					Color(0.95, 0.93, 1.0, 0.9 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)

		for i in offers.size():
			_draw_card(i)

		var hint := "[1] [2] [3] またはタップで受け取る"
		if rerolls > 0:
			hint += "　　[R] 神籤を引き直す ×%d" % rerolls
		Ui.txt(self, ui.font, Vector2(0, CY + CH + 30), hint, 14,
				Color(0.85, 0.88, 1.0, 0.9 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		_draw_pantheon(CY + CH + 52.0)

	## 禍神の取引カード
	func _draw_curse_card(i: int, o: Dictionary, r: Rect2, sel: bool, pop: float) -> void:
		var c: Dictionary = o["boon"]
		var col := Color(0.85, 0.25, 0.35)
		var rr := r.grow((4.0 if sel else 0.0) - (1.0 - pop) * 30.0)
		var a := pop
		var x0 := rr.position.x + 14.0
		var w := rr.size.x - 28.0
		draw_rect(rr.grow(6.0), Color(0, 0, 0, 0.4 * a))
		draw_rect(rr, Color(0.10, 0.03, 0.06, 0.97 * a))
		draw_rect(rr, Cfg.with_a(col, (1.0 if sel else 0.6) * a), false, 2.0 if sel else 1.2)
		for j in 12:
			var ang := -_t * 0.4 + TAU * float(j) / 12.0
			var cc := rr.position + rr.size * 0.5
			draw_line(cc + Vector2(cos(ang), sin(ang)) * rr.size.x * 0.5, cc + Vector2(cos(ang), sin(ang)) * rr.size.x * 0.72,
					Cfg.with_a(col, 0.10 * a), 6.0, true)
		draw_rect(Rect2(rr.position + Vector2(0, 3), Vector2(rr.size.x, 30.0)), Cfg.with_a(col, 0.28 * a))
		Ui.txt(self, ui.font_display, rr.position + Vector2(12, 25), "禍神の取引", 16, Cfg.with_a(Color(1, 0.7, 0.75), a))
		Ui.txt(self, ui.font, rr.position + Vector2(104, 24), "力と代償", 10, Color(1, 0.85, 0.9, a * 0.85))
		# 禍の印：黒い日輪に赤い裂け目
		var ec := rr.position + Vector2(rr.size.x * 0.5, 76)
		draw_circle(ec, 30.0, Cfg.with_a(col, 0.15 * a))
		draw_circle(ec, 22.0, Color(0.05, 0.02, 0.04, a))
		draw_arc(ec, 22.0, 0, TAU, 32, Cfg.with_a(col, 0.9 * a), 2.0, true)
		draw_line(ec + Vector2(-6, -14), ec + Vector2(4, 12), Cfg.with_a(col, a), 3.0, true)
		draw_line(ec + Vector2(-2, -2), ec + Vector2(8, -10), Cfg.with_a(col, a), 2.0, true)
		Ui.txt(self, ui.font_display, Vector2(ec.x - 20, ec.y + 8), "禍", 22, Cfg.with_a(Color(1, 0.8, 0.85), a), HORIZONTAL_ALIGNMENT_CENTER, 40, false)
		Ui.txt(self, ui.font_display, rr.position + Vector2(0, 128), String(c["name"]), 19, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
		Ui.para(self, ui.font, Vector2(x0, rr.position.y + 150), String(c["desc"]), w, 11, 2, Color(1, 0.92, 0.94, a * 0.85))
		draw_rect(Rect2(x0 - 4, rr.position.y + 184, w + 8, 44), Color(0.2, 0.6, 0.35, 0.18 * a))
		Ui.txt(self, ui.font_bold, Vector2(x0 + 2, rr.position.y + 200), "得", 12, Color(0.6, 1.0, 0.7, a))
		Ui.para(self, ui.font, Vector2(x0 + 22, rr.position.y + 200), String(c["gain"]), w - 26, 11, 2, Color(0.9, 1.0, 0.92, a))
		draw_rect(Rect2(x0 - 4, rr.position.y + 232, w + 8, 44), Color(0.7, 0.2, 0.3, 0.18 * a))
		Ui.txt(self, ui.font_bold, Vector2(x0 + 2, rr.position.y + 248), "失", 12, Color(1.0, 0.6, 0.65, a))
		Ui.para(self, ui.font, Vector2(x0 + 22, rr.position.y + 248), String(c["loss"]), w - 26, 11, 2, Color(1.0, 0.9, 0.92, a))
		Ui.txt(self, ui.font, Vector2(rr.position.x, rr.end.y - 26), "取り消せない。一度だけ結べる", 10, Cfg.with_a(col, a * 0.85), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
		Ui.txt(self, ui.font_bold, Vector2(rr.position.x + 10, rr.end.y - 12), "[%d]" % (i + 1), 14, Cfg.with_a(col, a))

	## いま迎えている神々と神格
	func _draw_pantheon(y0: float) -> void:
		var p := Game.inst.player
		if p == null:
			return
		var a := anim
		Ui.txt(self, ui.font, Vector2(0, y0 + 12), "迎えている神々（神器は当てるほど神格が上がる）", 11, Color(1, 0.9, 0.7, 0.85 * a),
				HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		var n := Boons.MAX_KAMI
		var w := 180.0
		var gap := 10.0
		var x0 := (Cfg.W - (float(n) * w + float(n - 1) * gap)) * 0.5
		for i in n:
			var r := Rect2(x0 + float(i) * (w + gap), y0 + 20.0, w, 58.0)
			if i < p.gods.size():
				var id := String(p.gods[i])
				var k := Kami.kami(id)
				Ui.panel(self, r, k["color"], a, 0.85)
				Ui.kami_ring(self, p, id, r.position + Vector2(28, 29), 14.0, _t, a, true)
				Ui.txt(self, ui.font, Vector2(r.position.x + 54, r.position.y + 16), "主神" if i == 0 else "副神", 9, Color(1, 0.9, 0.7, 0.8 * a))
				Ui.txt(self, ui.font_display, Vector2(r.position.x + 54, r.position.y + 32), String(k["name"]), 12, Cfg.with_a(k["color"], a))
				Ui.txt(self, ui.font, Vector2(r.position.x + 54, r.position.y + 48), String(k["weapon"]) + "  ×%.2f" % p.kami_power(id), 10, Color(1, 1, 1, 0.75 * a))
				# 能力の枠：選んだ数ぶん埋まる
				var owned := Boons.owned_of(p, id).size()
				for j in Boons.MAX_PER_KAMI:
					var filled := j < owned
					var dot := Vector2(r.end.x - 14.0 - float(Boons.MAX_PER_KAMI - 1 - j) * 12.0, r.position.y + 14.0)
					draw_circle(dot, 3.5, Cfg.with_a(k["color"], (0.95 if filled else 0.25) * a))
					if not filled:
						draw_arc(dot, 3.5, 0, TAU, 12, Cfg.with_a(k["color"], 0.6 * a), 1.0, true)
			else:
				Ui.panel(self, r, Color(0.5, 0.5, 0.6), a * 0.6, 0.5)
				Ui.txt(self, ui.font, Vector2(r.position.x, r.position.y + 34), "空き（位 %d で副神を迎える）" % int(Boons.RECRUIT_LEVELS[i]), 10, Color(1, 1, 1, 0.45 * a), HORIZONTAL_ALIGNMENT_CENTER, w)

	func _draw_card(i: int) -> void:
		var o: Dictionary = offers[i]
		var type := String(o["type"])
		var rar := int(o["rar"])
		var r := rect_of(i)
		var sel := (i == hover)
		var pop := clampf(anim * 1.4 - float(i) * 0.12, 0.0, 1.0)
		if pop <= 0.0:
			return
		var k := Kami.kami(String(o["kami"]))
		var kc: Color = k["color"]
		var col: Color = Cfg.RAR_COLOR[rar]
		if type == "curse":
			_draw_curse_card(i, o, r, sel, pop)
			return
		var rr := r.grow((4.0 if sel else 0.0) - (1.0 - pop) * 30.0)
		var a := pop
		var x0 := rr.position.x + 14.0
		var w := rr.size.x - 28.0
		card_bg(rr, col, sel, a)
		var special := type == "legendary" or type == "duo"
		if special:
			for j in 10:
				var ang := _t * 0.5 + TAU * float(j) / 10.0
				var c := rr.position + rr.size * 0.5
				draw_line(c + Vector2(cos(ang), sin(ang)) * rr.size.x * 0.55, c + Vector2(cos(ang), sin(ang)) * rr.size.x * 0.75,
						Cfg.with_a(col, 0.12 * a), 8.0, true)

		# 上帯：種類とレアリティ
		draw_rect(Rect2(rr.position + Vector2(0, 3), Vector2(rr.size.x, 30.0)), Cfg.with_a(col, (0.30 if sel else 0.20) * a))
		Ui.txt(self, ui.font_display, rr.position + Vector2(12, 26), Cfg.RAR_NAME[rar], 18, Cfg.with_a(col, a))
		Ui.txt(self, ui.font, rr.position + Vector2(36, 24), Cfg.RAR_LONG[rar], 10, Cfg.with_a(col, a * 0.9))
		var label: String = {"upgrade": "神器の強化", "legendary": "伝説", "duo": "双神"}[type]
		draw_rect(Rect2(rr.end.x - 78, rr.position.y + 8, 68, 20), Cfg.with_a(kc, 0.35 * a))
		Ui.txt(self, ui.font_bold, Vector2(rr.end.x - 78, rr.position.y + 23), label, 11, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 68)

		Emblem.draw(self, String(k["emblem"]), rr.position + Vector2(rr.size.x * 0.5, 74), 26.0, kc, k["color2"], _t, a * 0.95)
		if type == "duo":
			var k2 := Kami.kami(String(o["boon"]["kami2"]))
			Emblem.draw(self, String(k2["emblem"]), rr.position + Vector2(rr.size.x * 0.5 + 34, 88), 16.0, k2["color"], k2["color2"], _t, a * 0.95)

		var p := Game.inst.player
		var b: Dictionary = o["boon"]
		var cur_lv := int(p.boons[b["id"]]["lv"]) if (p != null and p.boons.has(b["id"])) else 0
		var show_rar := maxi(rar, int(p.boons[b["id"]]["rar"])) if (p != null and p.boons.has(b["id"])) else rar
		Ui.txt(self, ui.font_display, rr.position + Vector2(0, 128), String(b["name"]), 19,
				Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
		Ui.txt(self, ui.font, rr.position + Vector2(0, 146), String(k["name"]) + "の神器 " + String(k["weapon"]) + " を強める" if type == "upgrade" else String(k["name"]), 10,
				Cfg.with_a(kc, a * 0.9), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
		Ui.para(self, ui.font, Vector2(x0, rr.position.y + 168), Kami.describe(b, show_rar, cur_lv + 1), w, 12, 5, Color(0.9, 0.92, 1.0, a * 0.95))
		if cur_lv > 0:
			var prev := Kami.fmt_value(b, Kami.value(b, show_rar, cur_lv))
			var nxt := Kami.fmt_value(b, Kami.value(b, show_rar, cur_lv + 1))
			draw_rect(Rect2(x0 - 4, rr.end.y - 52, w + 8, 30), Cfg.with_a(Cfg.C_GOLD, 0.12 * a))
			Ui.txt(self, ui.font_bold, Vector2(x0, rr.end.y - 38), "強化  Lv.%d → Lv.%d（最大 %d）" % [cur_lv, cur_lv + 1, int(b.get("maxlv", 3))], 11, Cfg.with_a(Cfg.C_GOLD, a))
			Ui.txt(self, ui.font, Vector2(x0, rr.end.y - 26), prev + "  →  " + nxt, 11, Color(1, 1, 1, a * 0.9))
		elif type == "upgrade" and p != null:
			var owned := Boons.owned_of(p, String(b["kami"])).size()
			draw_rect(Rect2(x0 - 4, rr.end.y - 52, w + 8, 30), Cfg.with_a(kc, 0.10 * a))
			Ui.txt(self, ui.font_bold, Vector2(x0, rr.end.y - 38), "新しい能力  %d / %d 枠目" % [owned + 1, Boons.MAX_PER_KAMI], 11, Cfg.with_a(kc.lightened(0.3), a))
			Ui.txt(self, ui.font, Vector2(x0, rr.end.y - 26), "重ねて Lv.%d まで強化できる" % int(b.get("maxlv", 3)), 10, Color(1, 1, 1, a * 0.8))
		elif special:
			Ui.txt(self, ui.font, Vector2(rr.position.x, rr.end.y - 26), "重ねることはできない", 10, Cfg.with_a(col, a * 0.8), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
		Ui.txt(self, ui.font_bold, Vector2(rr.position.x + 10, rr.end.y - 12), "[%d]" % (i + 1), 14, Cfg.with_a(col, a))


# =====================================================================
## 神酒：神を 1 柱選んで神格を上げる
class MikiView:
	extends ChoiceView

	var ids: Array = []

	const CW := 190.0
	const CH := 180.0

	func count() -> int:
		return ids.size()

	func rect_of(i: int) -> Rect2:
		var total := ids.size()
		var gap := 12.0
		var w := float(total) * CW + float(total - 1) * gap
		var x := (Cfg.W - w) * 0.5 + float(i) * (CW + gap)
		return Rect2(x, 300.0, CW, CH)

	func _draw() -> void:
		backdrop(Cfg.C_GOLD)
		Ui.txt(self, ui.font_display, Vector2(0, 150), "神酒", 48, Cfg.with_a(Cfg.C_GOLD, anim),
				HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		Ui.txt(self, ui.font, Vector2(0, 186), "神を 1 柱選び、神格を 1 段上げる。神器の威力が上がり、節目では弾数や大きさも増える。", 13,
				Color(0.9, 0.9, 1.0, 0.85 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		var p := Game.inst.player
		for i in ids.size():
			var id := String(ids[i])
			var k := Kami.kami(id)
			var r := rect_of(i)
			var sel := i == hover
			var pop := clampf(anim * 1.5 - float(i) * 0.1, 0.0, 1.0)
			if pop <= 0.0:
				continue
			var kc: Color = k["color"]
			var rr := r.grow((3.0 if sel else 0.0) - (1.0 - pop) * 20.0)
			card_bg(rr, kc, sel, pop)
			var lv: int = p.kami_lv.get(id, 1)
			Ui.kami_ring(self, p, id, rr.position + Vector2(rr.size.x * 0.5, 54), 30.0, _t, pop, false)
			Ui.txt(self, ui.font_display, rr.position + Vector2(0, 112), String(k["name"]), 16, Color(1, 1, 1, pop), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
			Ui.txt(self, ui.font_bold, rr.position + Vector2(0, 134), "神格 %d → %d" % [lv, lv + 1], 14, Cfg.with_a(Cfg.C_GOLD, pop), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
			Ui.txt(self, ui.font, rr.position + Vector2(0, 152), "%s  威力 ×%.2f → ×%.2f" % [String(k["weapon"]),
					p.kami_power(id), (1.0 if p.is_main(id) else 0.5) * Kami.kami_power(lv + 1)], 10,
					Color(0.9, 0.92, 1.0, pop * 0.9), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
			Ui.txt(self, ui.font_bold, Vector2(rr.position.x + 10, rr.end.y - 10), "[%d]" % (i + 1), 12, Cfg.with_a(kc, pop))
		Ui.txt(self, ui.font, Vector2(0, 300.0 + CH + 30.0), "数字キー またはタップで選ぶ", 14,
				Color(0.85, 0.88, 1.0, 0.9 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)


# =====================================================================
class OverlayView:
	extends Control

	var ui: Ui
	var mode := 0  # 0=タイトル 1=ゲームオーバー 2=踏破
	var stats_lines: Array = []
	var tip := ""
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
		elif mode == 2:
			_clear()
		else:
			_over()

	func _clear() -> void:
		draw_rect(Rect2(0, 0, Cfg.W, Cfg.H), Color(0.03, 0.02, 0.06, 0.82))
		var tex := Ui.art("scene/clear")
		if tex != null:
			Ui.draw_cover(self, tex, Rect2(0, 0, Cfg.W, Cfg.H), 0.55, 0.3)
			for gi in 10:
				var kk := float(gi) / 10.0
				draw_rect(Rect2(0, 260.0 + kk * (Cfg.H - 260.0), Cfg.W, (Cfg.H - 260.0) / 10.0 + 1.0), Color(0.03, 0.02, 0.06, 0.85 * minf(1.0, kk * 2.0)))
		Ui.pattern(self, Rect2(0, 0, Cfg.W, Cfg.H), Cfg.with_a(Cfg.C_GOLD, 0.06), 52.0, _t)
		var c := Vector2(Cfg.W * 0.5, 150.0)
		for i in 16:
			var ang := _t * 0.3 + TAU * float(i) / 16.0
			draw_line(c + Vector2(cos(ang), sin(ang)) * 40.0, c + Vector2(cos(ang), sin(ang)) * (160.0 + 30.0 * sin(_t * 2.0 + float(i))),
					Cfg.with_a(Cfg.C_GOLD, 0.12), 6.0, true)
		draw_circle(c, 46.0, Cfg.with_a(Cfg.C_GOLD, 0.25))
		draw_circle(c, 34.0, Color(1, 0.97, 0.85, 0.9))
		Ui.txt(self, ui.font_display, Vector2(0, 250), "踏破", 66, Cfg.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		Ui.txt(self, ui.font, Vector2(0, 284), "奥宮の穢れは祓われ、参道に朝日が差した", 13, Color(1, 0.95, 0.85, 0.9),
				HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		var y := 340.0
		for row: Array in stats_lines:
			Ui.txt(self, ui.font, Vector2(0, y), String(row[0]), 15,
					Color(0.85, 0.8, 0.65), HORIZONTAL_ALIGNMENT_RIGHT, Cfg.W * 0.5 - 14.0)
			Ui.txt(self, ui.font_display, Vector2(Cfg.W * 0.5 + 14.0, y), String(row[1]), 18,
					Color(1, 1, 1), HORIZONTAL_ALIGNMENT_LEFT)
			y += 30.0
		var g := Game.inst
		if g != null and g.player != null and is_instance_valid(g.player):
			ui.hud._draw_build_on(self, g.player, y + 20.0)
		var blink := 0.55 + 0.45 * sin(_t * 4.0)
		Ui.txt(self, ui.font_display, Vector2(0, Cfg.H - 96.0), "タップ / ENTER で更に登る（祟りの参道）", 20,
				Color(1, 1, 1, blink), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		Ui.txt(self, ui.font, Vector2(0, Cfg.H - 66.0), "R で最初から　　ESC で題目へ", 13,
				Color(0.9, 0.9, 1.0, 0.8), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)

	func _title() -> void:
		if _tex != null:
			var tw := float(_tex.get_width())
			var th := float(_tex.get_height())
			var scale := Cfg.H / th
			var src_w := Cfg.W / scale
			var src_x := clampf(1100.0 - src_w * 0.5, 0.0, tw - src_w)
			draw_texture_rect_region(_tex, Rect2(0, 0, Cfg.W, Cfg.H), Rect2(src_x, 0, src_w, th),
					Color(0.92, 0.88, 1.0))
		else:
			draw_rect(Rect2(0, 0, Cfg.W, Cfg.H), Cfg.C_BG)
		for i in 14:
			var k := float(i) / 14.0
			draw_rect(Rect2(0, k * 330.0, Cfg.W, 330.0 / 14.0 + 1.0), Color(0.05, 0.02, 0.10, 0.85 * (1.0 - k)))
			draw_rect(Rect2(0, Cfg.H - 330.0 + k * 330.0, Cfg.W, 330.0 / 14.0 + 1.0), Color(0.05, 0.02, 0.10, 0.88 * k))
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

		var y := Cfg.H - 254.0
		var lines := [
			["移動", "WASD / 矢印　　スマホ：画面をなぞる"], ["疾走", "Space（無敵）　　スマホ：指を弾く"], ["詠唱", "Z / J（主神の技・2 発）"],
			["神招き", "X / K（ゲージ 1/4 以上）"], ["低速", "Shift"], ["小休止 / 音", "P / M"],
		]
		for l: Array in lines:
			Ui.txt(self, ui.font_bold, Vector2(120, y), String(l[0]), 13, Color(1, 0.9, 0.75, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 90)
			Ui.txt(self, ui.font, Vector2(230, y), String(l[1]), 13, Color(0.9, 0.92, 1.0, 0.9))
			y += 22.0

		Ui.txt(self, ui.font, Vector2(0, Cfg.H - 104.0), "神を迎えれば神器が付く。主神と 2 柱の副神とともに参道を登れ。", 13,
				Color(0.85, 0.86, 1.0, 0.85), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		var g := Game.inst
		if g != null and (int(g.best["score"]) > 0 or int(g.best["clears"]) > 0):
			Ui.panel(self, Rect2(Cfg.W * 0.5 - 150, Cfg.H - 300, 300, 34), Cfg.C_GOLD, 1.0, 0.7)
			Ui.txt(self, ui.font, Vector2(Cfg.W * 0.5 - 150, Cfg.H - 278), "最高功徳 %d　　最高到達 第 %d 波　　踏破 %d 回" % [int(g.best["score"]), int(g.best["wave"]), int(g.best["clears"])], 12,
					Cfg.with_a(Cfg.C_GOLD, 0.95), HORIZONTAL_ALIGNMENT_CENTER, 300)
		var blink := 0.55 + 0.45 * sin(_t * 4.0)
		Ui.txt(self, ui.font_display, Vector2(0, Cfg.H - 52.0), "タップ / ENTER で はじめる", 22,
				Color(1, 1, 1, blink), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)

	func _over() -> void:
		draw_rect(Rect2(0, 0, Cfg.W, Cfg.H), Color(0.02, 0.01, 0.05, 0.8))
		var tex := Ui.art("scene/gameover")
		if tex != null:
			Ui.draw_cover(self, tex, Rect2(0, 0, Cfg.W, Cfg.H), 0.5, 0.3)
			for gi in 10:
				var kk := float(gi) / 10.0
				draw_rect(Rect2(0, 240.0 + kk * (Cfg.H - 240.0), Cfg.W, (Cfg.H - 240.0) / 10.0 + 1.0), Color(0.02, 0.01, 0.05, 0.88 * minf(1.0, kk * 2.0)))
		Ui.pattern(self, Rect2(0, 0, Cfg.W, Cfg.H), Color(1, 0.3, 0.4, 0.04), 52.0, _t)
		Ui.txt(self, ui.font_display, Vector2(0, 200), "討たれた", 58, Color(1, 0.3, 0.4),
				HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		Ui.txt(self, ui.font, Vector2(0, 234), "神楽は途切れ、参道は闇に沈んだ", 13, Color(0.9, 0.8, 0.85, 0.8),
				HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		var y := 290.0
		for row: Array in stats_lines:
			Ui.txt(self, ui.font, Vector2(0, y), String(row[0]), 15,
					Color(0.65, 0.75, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, Cfg.W * 0.5 - 14.0)
			Ui.txt(self, ui.font_display, Vector2(Cfg.W * 0.5 + 14.0, y), String(row[1]), 18,
					Color(1, 1, 1), HORIZONTAL_ALIGNMENT_LEFT)
			y += 30.0
		if tip != "":
			Ui.panel(self, Rect2(50, y + 4, Cfg.W - 100, 48), Cfg.C_GOLD, 1.0, 0.8)
			Ui.txt(self, ui.font_bold, Vector2(62, y + 22), "次の一手", 11, Cfg.C_GOLD)
			Ui.para(self, ui.font, Vector2(62, y + 40), tip, Cfg.W - 124, 11, 2, Color(0.95, 0.95, 1.0, 0.95))
			y += 60.0
		var g := Game.inst
		if g != null and g.player != null and is_instance_valid(g.player):
			ui.hud._draw_build_on(self, g.player, y + 20.0)
		var blink := 0.55 + 0.45 * sin(_t * 4.0)
		Ui.txt(self, ui.font_display, Vector2(0, Cfg.H - 80.0), "タップ / ENTER でもう一度　　ESC で題目へ", 20,
				Color(1, 1, 1, blink), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
