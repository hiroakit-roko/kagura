class_name Ui
extends CanvasLayer

## HUD・主神選択・恩恵選択・神酒・タイトル/ゲームオーバー画面。すべて _draw で描画する。
## 漆塗りの板に金の縁、和紙のカードという調子で、ゲージ類も装飾を付ける。

signal kami_chosen(id: String)
signal familiar_chosen(id: String)
signal story_done
signal boon_chosen(idx: int)
signal reroll_requested
signal miki_chosen(id: String)
signal relic_chosen(idx: int)
signal start_requested
signal restart_requested
signal title_requested
signal continue_requested
signal name_submitted(name: String)

var font: Font
var font_bold: Font
var font_display: Font
var hud: HudView
var name_box: NameBox
var kami_view: KamiChoiceView
var familiar_view: FamiliarView
var confirm_view: ConfirmView
var boons_view: BoonsView
var miki_view: MikiView
var relic_view: RelicView
var story_view: StoryView
var ranking_view: RankingView
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


## 小さい文字は少し大きく描く（本文は 1.12 倍、最小 11。大見出しはそのまま）
static func fsize(size: float) -> int:
	if size >= 26.0:
		return int(size)
	return maxi(11, int(round(size * 1.12)))


static func txt(ci: CanvasItem, f: Font, pos: Vector2, s: String, size: float, col: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, shadow := true) -> void:
	if f == null:
		return
	var sz := fsize(size)
	if shadow:
		ci.draw_string(f, pos + Vector2(1.5, 1.5), s, align, width, sz,
				Color(0, 0, 0, col.a * 0.65))
	ci.draw_string(f, pos, s, align, width, sz, col)


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
	var sz := fsize(float(size))
	ci.draw_multiline_string(f, pos + Vector2(1.2, 1.2), s, align, width, sz, lines, Color(0, 0, 0, col.a * 0.5), BRK)
	ci.draw_multiline_string(f, pos, s, align, width, sz, lines, col, BRK)


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
## 選択の操作ヒント（タッチ操作中はキー表記を出さない）
static func pick_hint(verb: String, n := 3) -> String:
	if Game.inst != null and Game.inst.is_touch():
		return "タップで" + verb
	var keys := ""
	for i in n:
		keys += "[%d] " % (i + 1)
	return keys + "またはタップで" + verb


## 絵はここで参照を保持する（_draw 内で load するだけだと毎フレーム作り直されて白く出る）
static var _art_cache: Dictionary = {}


## 透過 PNG の絵（顔絵など）
static func art_png(name: String) -> Texture2D:
	var key := "png:" + name
	if _art_cache.has(key):
		return _art_cache[key]
	var path := "res://image/%s.png" % name
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_art_cache[key] = tex
	return tex


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
	relic_view = RelicView.new()
	_setup_view(relic_view)
	relic_view.visible = false
	story_view = StoryView.new()
	_setup_view(story_view)
	story_view.visible = false
	ranking_view = RankingView.new()
	_setup_view(ranking_view)
	ranking_view.z_index = 20   # 題目・結果画面の上に重ねる
	ranking_view.visible = false
	var rot := RotateHint.new()
	rot.ui = self
	_setup_view(rot)
	rot.z_index = 40
	overlay = OverlayView.new()
	_setup_view(overlay)
	overlay.visible = false
	name_box = NameBox.new()
	name_box.ui = self
	name_box.build()
	add_child(name_box)
	name_box.visible = false


func _setup_view(v: Control) -> void:
	v.set("ui", self)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)


func show_story() -> void:
	hide_cards()
	story_view.t = 0.0
	story_view.visible = true


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


## 位上がり：神格を上げる神を 1 柱選ぶ画面
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
	relic_view.visible = false
	story_view.visible = false


## 討伐の褒賞：神宝を 3 つから選ぶ
func show_relics(offers: Array) -> void:
	hide_cards()
	relic_view.offers = offers
	relic_view.anim = 0.0
	relic_view.hover = -1
	relic_view.visible = true


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


func banner(text: String, sub := "", col := Color(1, 1, 1), icon := -1) -> void:
	hud.banner_text = text
	hud.banner_sub = sub
	hud.banner_col = col
	hud.banner_icon = icon
	hud.banner_t = 2.4 if icon < 0 else 3.2


## ボスの名乗り：縦書きの名前と二つ名を数秒見せる
func boss_intro(name: String, title: String, final: bool, key := "") -> void:
	hud.intro_name = name
	hud.intro_title = title
	hud.intro_key = key
	hud.intro_final = final
	hud.intro_t = 3.6


## 主人公のカットイン（帯）。key は image/cutin/<key>.jpg
func cutin(key: String, col := Color(1, 1, 1), sec := HudView.CUTIN_T) -> void:
	hud.cutin_key = key
	hud.cutin_col = col
	hud.cutin_len = sec
	hud.cutin_t = sec


## 神招きの見せ場：顔絵とセリフを大きく（世界は止まっている）
func call_cutin(kami_id: String, greater: bool) -> void:
	hud.call_kami = kami_id
	hud.call_greater = greater
	hud.call_t = HudView.CALL_T


## 小さな告知（詠唱名など）：画面下寄りに短く
func banner_small(text: String, col := Color(1, 1, 1)) -> void:
	hud.small_text = text
	hud.small_col = col
	hud.small_t = 1.0


func _unhandled_input(e: InputEvent) -> void:
	var idx := -1
	var click := Vector2(-1, -1)
	if ranking_view.visible:
		ranking_view.handle(e)
		return
	if story_view.visible:
		if (e is InputEventKey and e.pressed and not e.echo) or (e is InputEventMouseButton and e.pressed):
			if story_view.t > 0.6:
				story_view.visible = false
				story_done.emit()
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var k := (e as InputEventKey).keycode
		if overlay.visible and overlay.mode == 0 and k == KEY_R:
			ranking_view.open()
			return
		if overlay.visible and overlay.mode == 0 and k == KEY_N:
			name_box.open_at(overlay.menu_rect(2).position.y + 5.0)
			return
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
				title_requested.emit()
			return
		if overlay.visible and (overlay.mode == 2 or overlay.mode == 1) and k == KEY_R:
			restart_requested.emit()
			return
	elif e is InputEventMouseButton and e.pressed \
			and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		click = (e as InputEventMouseButton).position
		if overlay.visible:
			if overlay.mode == 0:
				match overlay.menu_at(click):
					0:
						Sfx.play("select", -6.0)
						start_requested.emit()
					1:
						Sfx.play("select", -10.0)
						ranking_view.open()
					2:
						Sfx.play("select", -10.0)
						name_box.open_at(overlay.menu_rect(2).position.y + 5.0)
				return
			elif overlay.mode == 2:
				continue_requested.emit()
			else:
				title_requested.emit()
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
	elif relic_view.visible:
		if click.x >= 0:
			idx = relic_view.card_at(click)
		if idx >= 0 and idx < relic_view.offers.size():
			Sfx.play("select", -8.0)
			Fx.shake_add(3.0)
			relic_chosen.emit(idx)


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
		# スマホにはカーソルが無いので、選択の強調はしない
		if Game.inst != null and Game.inst.is_touch():
			hover = -1
		else:
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
	var banner_icon := -1   # Pickup.Kind（アイテムの案内）。-1 なら絵なし
	var cutin_t := 0.0      # 主人公のカットイン（神招きなど）の残り秒
	var call_t := 0.0       # 神招きの見せ場の残り秒
	var call_kami := ""
	var call_greater := false
	const CALL_T := 1.9
	var cutin_len := 1.6
	var cutin_key := ""     # image/cutin/<key>.jpg
	var cutin_col := Color(1, 1, 1)
	const CUTIN_T := 1.6
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

	var _rd := 0.0

	func _process(delta: float) -> void:
		var _t0 := Time.get_ticks_usec()
		_perf_process(delta)
		Perf.add("hud", _t0)

	func _perf_process(delta: float) -> void:
		_t += delta
		banner_t = maxf(0.0, banner_t - delta)
		small_t = maxf(0.0, small_t - delta)
		intro_t = maxf(0.0, intro_t - delta)
		cutin_t = maxf(0.0, cutin_t - delta)
		call_t = maxf(0.0, call_t - delta)
		# HUD は文字が多く、毎フレーム描き直すと文字の整形が重い。30fps に間引く
		_rd += delta
		if _rd >= 1.0 / 30.0:
			_rd = 0.0
			queue_redraw()

	func _draw() -> void:
		if Cfg.SKIP.has("hud"):
			return
		var _t0 := Time.get_ticks_usec()
		_perf_draw()
		Perf.add("hud_draw", _t0)

	func _perf_draw() -> void:
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
		if cutin_t > 0.0:
			_draw_cutin()
		if call_t > 0.0:
			_draw_call_cutin()

		if banner_t > 0.0 and call_t <= 0.0:
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
			Ui.txt(self, ui.font, Vector2(c.x + r + 12.0, y + 43.0 if main else y + 40.0), String(k["weapon"]), 9,
					Color(1, 1, 1, 0.7))
			y += r * 2.0 + 22.0
		# 次に神を迎える位（枠が残っているとき）
		var nxt := Boons.next_recruit_level(p)
		if nxt > 0:
			var lbl := "位 %d で%s" % [nxt, "主神" if p.gods.is_empty() else "副神"]
			draw_rect(Rect2(12, y - 6.0, 110, 20), Color(0.5, 0.5, 0.65, 0.18))
			draw_rect(Rect2(12, y - 6.0, 110, 20), Color(0.7, 0.7, 0.85, 0.35), false, 1.0)
			Ui.txt(self, ui.font, Vector2(20, y + 8.0), lbl, 11, Color(0.9, 0.9, 1.0, 0.75))
			y += 20.0
		_draw_chips(p, y + 2.0)

	func _draw_chips(p: Player, y0: float) -> void:
		var x := 16.0
		var y := y0
		# 神宝（金の札）
		for rid: String in p.relics:
			var rl := Relics.get_relic(rid)
			if rl.is_empty():
				continue
			draw_rect(Rect2(x, y, 20, 20), Color(0.6, 0.45, 0.1, 0.45))
			draw_rect(Rect2(x, y, 20, 20), Cfg.with_a(Cfg.C_GOLD, 0.95), false, 1.5)
			Ui.txt(self, ui.font_display, Vector2(x, y + 15), String(rl["mark"]), 12, Color(1, 0.95, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 20)
			y += 24.0
			if y > Cfg.H - 200.0:
				y = y0
				x += 24.0
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

		# 詠唱の札と疾走の輪
		var px := Cfg.W - 150.0
		var py := Cfg.H - 88.0
		Ui.panel(self, Rect2(px - 8, py - 22, 108, 54), Ui.GOLD, 0.95, 0.7)
		var mx: int = int(p.stats["cast_max"])
		for i in mx:
			var c := Vector2(px + 10.0 + float(i) * 22.0, py)
			if i < p.cast_charges and main != "":
				# 手元にある札
				draw_rect(Rect2(c.x - 7, c.y - 11, 14, 22), Cfg.with_a(mc, 0.35))
				draw_rect(Rect2(c.x - 6, c.y - 10, 12, 20), Cfg.C_PAPER)
				draw_rect(Rect2(c.x - 6, c.y - 10, 12, 20), Cfg.with_a(mc, 0.95), false, 1.2)
				draw_rect(Rect2(c.x - 4, c.y - 7, 8, 2.5), Cfg.with_a(mc, 0.9))
				draw_line(c + Vector2(0, -3), c + Vector2(0, 5), Cfg.C_INK, 1.5)
				draw_circle(c + Vector2(0, 7), 1.8, Color(0.85, 0.2, 0.25, 0.95))
			else:
				# まだ無い札：枠だけ
				draw_rect(Rect2(c.x - 6, c.y - 10, 12, 20), Cfg.with_a(mc, 0.35 + 0.15 * sin(_t * 4.0)), false, 1.2)
		Ui.txt(self, ui.font, Vector2(px, py + 24), "詠唱 Z" if p.cast_charges > 0 or main == "" else "札を拾え", 10, Color(1, 1, 1, 0.6) if p.cast_charges > 0 or main == "" else Cfg.with_a(mc, 0.6 + 0.4 * sin(_t * 5.0)))
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
		var k := banner_t / (2.4 if banner_icon < 0 else 3.2)
		var a := clampf(sin(k * PI) * 2.2, 0.0, 1.0)
		var y := 300.0 - (1.0 - k) * 16.0
		var c := banner_col
		c.a = a
		draw_rect(Rect2(0, y - 44, Cfg.W, 82), Color(0, 0, 0, 0.45 * a))
		draw_rect(Rect2(0, y - 44, Cfg.W, 2), Color(c.r, c.g, c.b, a * 0.8))
		draw_rect(Rect2(0, y + 36, Cfg.W, 2), Color(c.r, c.g, c.b, a * 0.8))
		draw_rect(Rect2(0, y - 41, Cfg.W, 1), Color(1, 1, 1, a * 0.25))
		Ui.txt(self, ui.font_display, Vector2(0, y), banner_text, 32, c, HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		if banner_icon >= 0:
			# アイテムの絵を題の左に大きく（絵があれば絵、無ければ形）
			var tw := ui.font_display.get_string_size(banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
			var ip := Vector2(Cfg.W * 0.5 - tw * 0.5 - 40.0, y - 12.0)
			var itex := Ui.art("item/" + ["xp", "heal", "miki", "orb"][banner_icon] if banner_icon < 4 else "")
			if itex != null:
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				draw_texture_rect(itex, Rect2(ip - Vector2(30, 30), Vector2(60, 60)), false, Color(1, 1, 1, a))
				draw_rect(Rect2(ip - Vector2(30, 30), Vector2(60, 60)), Cfg.with_a(c, 0.8 * a), false, 1.5)
			else:
				draw_circle(ip, 22.0, Cfg.with_a(c, 0.18))
				draw_set_transform(ip, 0.0, Vector2(1.7, 1.7))
				Pickup.draw_shape(self, banner_icon, c, _t, 1.0)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if banner_sub != "":
			Ui.txt(self, ui.font, Vector2(0, y + 26), banner_sub, 15,
					Color(1, 1, 1, a * 0.85), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)

	## 主人公のカットイン：右から滑り込み、光の帯の上に絵を敷く
	func _draw_cutin() -> void:
		var tex := Ui.art("cutin/" + cutin_key)
		if tex == null:
			return
		var k := 1.0 - cutin_t / maxf(0.1, cutin_len)
		var a := clampf(minf(k * 8.0, (1.0 - k) * 5.0), 0.0, 1.0)
		var slide := (1.0 - minf(1.0, k * 6.0)) * 120.0
		# 帯は告知（y=300 前後）と重ならない高さに置く
		var band := Rect2(0, 96.0, Cfg.W, 156.0)
		draw_rect(band.grow(6.0), Color(0, 0, 0, 0.6 * a))
		draw_rect(band, Color(0.03, 0.02, 0.06, 0.85 * a))
		var pr := Rect2(slide, band.position.y, Cfg.W, band.size.y)
		Ui.draw_cover(self, tex, pr, a, 0.4)
		# 左右を暗く落として帯に馴染ませる
		for gi in 6:
			var kk := float(gi) / 6.0
			draw_rect(Rect2(kk * 60.0, band.position.y, 10.0, band.size.y), Color(0.03, 0.02, 0.06, 0.6 * (1.0 - kk) * a))
		draw_rect(Rect2(band.position.x, band.position.y, Cfg.W, 3), Cfg.with_a(cutin_col, a))
		draw_rect(Rect2(band.position.x, band.end.y - 3, Cfg.W, 3), Cfg.with_a(cutin_col, a))
		for i in 5:
			var ang := -0.3 + float(i) * 0.15
			var x := 40.0 + float(i) * 130.0 + slide * 0.5
			draw_line(Vector2(x, band.position.y), Vector2(x + 60.0 * ang, band.end.y), Color(1, 1, 1, 0.12 * a), 6.0)

	## 神招きの見せ場：右に大きな顔絵、左に技の名とセリフ。斜めの光の帯
	func _draw_call_cutin() -> void:
		var k := 1.0 - call_t / CALL_T
		var a := clampf(minf(k * 10.0, (1.0 - k) * 6.0), 0.0, 1.0)
		var kk := Kami.kami(call_kami)
		if kk.is_empty():
			return
		var col: Color = kk["color"]
		# 暗幕と斜めの帯
		draw_rect(Rect2(0, 0, Cfg.W, Cfg.H), Color(0.02, 0.01, 0.05, 0.78 * a))
		var cy := Cfg.H * 0.42
		var band := PackedVector2Array([Vector2(-40, cy - 150), Vector2(Cfg.W + 40, cy - 230), Vector2(Cfg.W + 40, cy + 230), Vector2(-40, cy + 150)])
		draw_colored_polygon(band, Cfg.with_a(col, 0.22 * a))
		for i in 7:
			var x0 := -60.0 + float(i) * 120.0 + (1.0 - a) * 80.0
			draw_line(Vector2(x0, cy + 240), Vector2(x0 + 140, cy - 240), Color(1, 1, 1, 0.10 * a), 10.0)
		# 絵：16:9 のカットイン絵を右寄せ（顔側）で大きく敷き、右から滑り込む
		var tex := Ui.art("cutin/call")
		var pr := Rect2(0, cy - 240.0, Cfg.W, 440.0)
		if tex != null:
			var slide := (1.0 - minf(1.0, k * 5.0)) * 90.0
			var tw := float(tex.get_width())
			var th := float(tex.get_height())
			var sw := minf(tw, th * pr.size.x / pr.size.y)
			var sx := clampf(tw - sw - 40.0 + slide, 0.0, tw - sw)
			draw_rect(pr.grow(3), Color(0, 0, 0, 0.6 * a))
			draw_texture_rect_region(tex, pr, Rect2(sx, 0.0, sw, th), Color(1, 1, 1, a))
			# 下端を暗く落として文字を載せる
			for gi in 10:
				var gk := float(gi) / 10.0
				draw_rect(Rect2(pr.position.x, pr.end.y - 170.0 + gk * 170.0, pr.size.x, 17.0 + 1.0), Color(0.03, 0.02, 0.06, 0.92 * gk * a))
			draw_rect(Rect2(0, pr.position.y, Cfg.W, 2), Cfg.with_a(col, a))
			draw_rect(Rect2(0, pr.end.y - 2, Cfg.W, 2), Cfg.with_a(col, a))
		else:
			var por := Ui.art_png("portrait/shout")
			if por != null:
				var aspect := float(por.get_width()) / float(por.get_height())
				var w := minf(Cfg.W, Cfg.H * 0.5 * aspect)
				draw_texture_rect(por, Rect2(Cfg.W - w, cy - w / aspect * 0.5, w, w / aspect), false, Color(1, 1, 1, a))
		# 技の名とセリフ（絵の下部に重ねる）
		var name_y := pr.end.y - 92.0
		Ui.txt(self, ui.font, Vector2(22, name_y - 34), String(kk["name"]) + ("　大神招き" if call_greater else "　神招き"), 13, Cfg.with_a(col, a))
		Ui.txt(self, ui.font_display, Vector2(20, name_y + 4), String(kk["call"]), 36, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_LEFT, Cfg.W * 0.6)
		draw_rect(Rect2(20, name_y + 14, Cfg.W * 0.5, 3), Cfg.with_a(col, a))
		var line := String(kk.get("call_line", ""))
		if line != "":
			Ui.para(self, ui.font_display, Vector2(24, name_y + 48), "「" + line + "」", Cfg.W - 48, 18, 2, Color(1, 0.97, 0.9, a))
		# どういう力か（主神ごとの一文）
		var desc := String(kk.get("call_desc", ""))
		if desc != "":
			draw_rect(Rect2(0, pr.end.y + 6, Cfg.W, 34), Color(0.03, 0.02, 0.06, 0.85 * a))
			Ui.txt(self, ui.font, Vector2(20, pr.end.y + 29), desc, 15, Cfg.with_a(col.lerp(Color.WHITE, 0.35), a), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W - 40)

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
		var hero := Ui.art_png("portrait/calm")
		if hero != null:
			# 主人公：左下に顔絵（大妖と向き合う）
			var hh := 230.0
			var hw := hh * float(hero.get_width()) / float(hero.get_height())
			draw_texture_rect(hero, Rect2(-10.0 - (1.0 - a) * 60.0, 400.0, hw, hh), false, Color(1, 1, 1, a))
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
		Ui.txt(self, ui.font, Vector2(x0 + 6, y + 36), "神器", 11, Color(1, 0.9, 0.7, a * 0.85))
		Ui.txt(self, ui.font_display, Vector2(x0 + 40, y + 38), String(k["weapon"]), 16, Color(1, 1, 1, a))
		var gr := int(round(Kami.growth_of(String(k["id"])) * 100.0))
		Ui.txt(self, ui.font, Vector2(x0 + 6, y + 38), "神格の伸び +%d%%" % gr, 11,
				Cfg.with_a(Cfg.C_GOLD if gr > 12 else Color(1, 1, 1), a * 0.85), HORIZONTAL_ALIGNMENT_RIGHT, w - 12)
		Ui.para(self, ui.font, Vector2(x0 + 6, y + 56), String(k["weapon_desc"]), w - 12, 12, 2, Color(0.9, 0.92, 1.0, a * 0.9))
		if role == "主神":
			Ui.txt(self, ui.font, Vector2(x0 + 6, y + 96), "詠唱　" + String(k["cast"]) + "：" + String(k["cast_desc"]), 11, Color(0.9, 0.92, 1.0, a * 0.85), HORIZONTAL_ALIGNMENT_LEFT, w - 12)
			Ui.txt(self, ui.font, Vector2(x0 + 6, y + 114), "神招き　" + String(k["call"]) + "：" + String(k["call_desc"]), 11, Color(0.9, 0.92, 1.0, a * 0.85), HORIZONTAL_ALIGNMENT_LEFT, w - 12)
		else:
			Ui.txt(self, ui.font, Vector2(x0 + 6, y + 98), "詠唱と神招きは主神のみ", 11, Color(0.9, 0.92, 1.0, a * 0.7))
		var st := String(k["status"])
		if st != "":
			Ui.txt(self, ui.font, Vector2(x0 + 6, y + 134), "神威 " + st + "：" + String(k["status_desc"]), 10, Color(0.85, 0.9, 1.0, a * 0.85), HORIZONTAL_ALIGNMENT_LEFT, w - 12)
		else:
			Ui.txt(self, ui.font, Vector2(x0 + 6, y + 134), String(k["status_desc"]), 10, Color(0.85, 0.9, 1.0, a * 0.85), HORIZONTAL_ALIGNMENT_LEFT, w - 12)
		Ui.txt(self, ui.font, Vector2(x0 + 6, y + 160), String(k["mark"]), 11, Cfg.with_a(col, a * 0.8))

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
			var touch := Game.inst != null and Game.inst.is_touch()
			var label := ("契約する" if touch else "契約する　[1] / Enter") if i == 0 else ("考え直す" if touch else "考え直す　[2] / Esc")
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
		var l1 := "選んだ神の神器（自動で撃つ武器）が付く" if main else "神器がもう 1 つ加わる"
		Ui.txt(self, ui.font, Vector2(0, 140), l1, 14,
				Color(0.9, 0.9, 1.0, 0.85 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		for i in ids.size():
			_draw_card(i)
		Ui.txt(self, ui.font, Vector2(0, CY + CH + 30), Ui.pick_hint("選ぶ"), 14,
				Color(0.85, 0.88, 1.0, 0.9 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		if hover >= 0 and hover < ids.size():
			var k := Kami.kami(ids[hover])
			Ui.txt(self, ui.font, Vector2(0, CY + CH + 54), "「" + String(k["intro"]) + "」", 14,
					Cfg.with_a(k["color"], 0.9), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)

	func _draw_howto(y0: float) -> void:
		var r := Rect2(40.0, y0, Cfg.W - 80.0, 96.0)
		if r.end.y > Cfg.H - 10.0:
			return
		var a := anim
		Ui.panel(self, r, Cfg.C_GOLD, a, 0.85)
		Ui.txt(self, ui.font_display, Vector2(r.position.x + 14, r.position.y + 22), "仕組み", 14, Cfg.with_a(Cfg.C_GOLD, a))
		var lines := [
			"① 神を迎えると神器（自動発射の武器）が付く。主神も副神も同じ威力。詠唱と神招きは主神のもの。",
			"② 位 2 で主神、位 4 と位 7 で副神を迎える。迎えるだけで報酬になり、他の選択は続かない。",
			"③ それ以外の位上がりでは神を 1 柱選ぶ。その神の神格が上がり、能力 3 枚（9 種・3 つまで）を示す。",
			"　 空き枠のぶんが新しい能力、残りは選んだ能力の強化。近距離の神器は神格ごとの伸びが大きい。",
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
		Ui.txt(self, ui.font, Vector2(rr.position.x, rr.position.y + 184), String(k["kana"]) + "　" + String(k["title"]), 11,
				Cfg.with_a(col, a * 0.9), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
		draw_line(Vector2(x0, rr.position.y + 196), Vector2(rr.end.x - 14, rr.position.y + 196), Cfg.with_a(col, 0.4 * a), 1.0)

		# 得意
		draw_rect(Rect2(x0, rr.position.y + 206, w, 20), Cfg.with_a(col, 0.18 * a))
		Ui.txt(self, ui.font_bold, Vector2(x0 + 6, rr.position.y + 221), String(k["role"]), 12, Cfg.with_a(col.lightened(0.2), a))

		# 神器
		Ui.txt(self, ui.font, Vector2(x0, rr.position.y + 248), "神器", 11, Color(1, 0.9, 0.7, a * 0.85))
		Ui.txt(self, ui.font_display, Vector2(x0 + 32, rr.position.y + 250), String(k["weapon"]), 17, Color(1, 1, 1, a))
		Ui.para(self, ui.font, Vector2(x0, rr.position.y + 270), String(k["weapon_desc"]), w, 12, 4, Color(0.9, 0.92, 1.0, a * 0.9))

		# 神威
		var y := rr.position.y + 352.0
		var st := String(k["status"])
		if st != "":
			draw_rect(Rect2(x0, y - 13, 56, 17), Cfg.with_a(col, 0.25 * a))
			Ui.txt(self, ui.font_bold, Vector2(x0, y), "神威 " + st, 11, Cfg.with_a(col, a), HORIZONTAL_ALIGNMENT_CENTER, 56)
			Ui.para(self, ui.font, Vector2(x0, y + 18), String(k["status_desc"]), w, 11, 3, Color(0.85, 0.9, 1.0, a * 0.85))
		else:
			Ui.para(self, ui.font, Vector2(x0, y + 2), String(k["status_desc"]), w, 11, 3, Color(0.85, 0.9, 1.0, a * 0.85))

		# 詠唱と神招き（主神のみ）／副神なら神格の伸びを見せる
		y = rr.position.y + 430.0
		draw_line(Vector2(x0, y - 8), Vector2(rr.end.x - 14, y - 8), Cfg.with_a(col, 0.4 * a), 1.0)
		var gr := int(round(Kami.growth_of(String(k["id"])) * 100.0))
		if role == "主神":
			Ui.txt(self, ui.font, Vector2(x0, y + 8), "詠唱", 11, Color(1, 0.9, 0.7, a * 0.85))
			Ui.txt(self, ui.font_display, Vector2(x0 + 32, y + 9), String(k["cast"]), 14, Color(1, 1, 1, a))
			Ui.para(self, ui.font, Vector2(x0, y + 26), String(k["cast_desc"]), w, 11, 2, Color(0.85, 0.9, 1.0, a * 0.85))
			Ui.txt(self, ui.font, Vector2(x0, y + 70), "神招き", 11, Color(1, 0.9, 0.7, a * 0.85))
			Ui.txt(self, ui.font_display, Vector2(x0 + 44, y + 71), String(k["call"]), 14, Color(1, 1, 1, a))
			Ui.para(self, ui.font, Vector2(x0, y + 88), String(k["call_desc"]), w, 11, 2, Color(0.85, 0.9, 1.0, a * 0.85))
		else:
			Ui.txt(self, ui.font, Vector2(x0, y + 8), "詠唱と神招きは主神のみ", 11, Color(0.85, 0.9, 1.0, a * 0.7))
		Ui.txt(self, ui.font_bold, Vector2(x0, y + 128), "神格の伸び +%d%%" % gr, 12,
				Cfg.with_a(Cfg.C_GOLD if gr > 12 else Color(0.85, 0.9, 1.0), a * 0.9))

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

		var hint := Ui.pick_hint("受け取る")
		if rerolls > 0:
			hint += ("　　[R] 神籤を引き直す ×%d" % rerolls) if not (Game.inst != null and Game.inst.is_touch()) else ("　　神籤 ×%d は下の札で" % rerolls)
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
		Ui.txt(self, ui.font, Vector2(0, y0 + 12), "神々", 12, Color(1, 0.9, 0.7, 0.85 * a),
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
				Ui.txt(self, ui.font, Vector2(r.position.x, r.position.y + 35), "位 %d で副神" % int(Boons.RECRUIT_LEVELS[i]), 12, Color(1, 1, 1, 0.5 * a), HORIZONTAL_ALIGNMENT_CENTER, w)

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
		# 新規か強化かを大きな札で示す（右上、斜めの帯）
		var pp := Game.inst.player
		var owned_now := pp != null and pp.boons.has(String(o["boon"].get("id", "")))
		var tag := "新"
		var tag_col := Color(0.55, 0.95, 1.0)
		if type == "legendary":
			tag = "伝説"
			tag_col = Cfg.RAR_COLOR[Cfg.Rar.LEGENDARY]
		elif type == "duo":
			tag = "双神"
			tag_col = Cfg.RAR_COLOR[Cfg.Rar.DUO]
		elif owned_now:
			tag = "強化"
			tag_col = Cfg.C_GOLD
		var tw := 58.0 if tag.length() <= 1 else 78.0
		var tr := Rect2(rr.end.x - tw - 8.0, rr.position.y + 38.0, tw, 30.0)
		draw_rect(tr.grow(2.0), Color(0, 0, 0, 0.5 * a))
		draw_rect(tr, Cfg.with_a(tag_col, 0.92 * a))
		draw_colored_polygon(PackedVector2Array([tr.position, tr.position + Vector2(-10, 15), tr.position + Vector2(0, 30)]), Cfg.with_a(tag_col, 0.92 * a))
		Ui.txt(self, ui.font_display, Vector2(tr.position.x, tr.position.y + 23), tag, 20 if tag.length() <= 1 else 17, Color(0.08, 0.05, 0.1, a), HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, false)

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
		Ui.para(self, ui.font, Vector2(x0, rr.position.y + 168), Kami.describe(b, show_rar, cur_lv + 1), w, 13, 5, Color(0.9, 0.92, 1.0, a * 0.95))
		if cur_lv > 0:
			var prev := Kami.fmt_value(b, Kami.value(b, show_rar, cur_lv))
			var nxt := Kami.fmt_value(b, Kami.value(b, show_rar, cur_lv + 1))
			draw_rect(Rect2(x0 - 4, rr.end.y - 58, w + 8, 38), Cfg.with_a(Cfg.C_GOLD, 0.12 * a))
			Ui.txt(self, ui.font_bold, Vector2(x0, rr.end.y - 42), "強化  Lv.%d → %d" % [cur_lv, cur_lv + 1], 12, Cfg.with_a(Cfg.C_GOLD, a))
			Ui.txt(self, ui.font, Vector2(x0, rr.end.y - 25), prev + "  →  " + nxt, 12, Color(1, 1, 1, a * 0.9))
		elif type == "upgrade" and p != null:
			var owned := Boons.owned_of(p, String(b["kami"])).size()
			draw_rect(Rect2(x0 - 4, rr.end.y - 52, w + 8, 30), Cfg.with_a(kc, 0.10 * a))
			Ui.txt(self, ui.font_bold, Vector2(x0, rr.end.y - 33), "新しい能力  %d / %d" % [owned + 1, Boons.MAX_PER_KAMI], 13, Cfg.with_a(kc.lightened(0.3), a))
		elif special:
			Ui.txt(self, ui.font, Vector2(rr.position.x, rr.end.y - 26), "重ねることはできない", 10, Cfg.with_a(col, a * 0.8), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
		Ui.txt(self, ui.font_bold, Vector2(rr.position.x + 10, rr.end.y - 12), "[%d]" % (i + 1), 14, Cfg.with_a(col, a))


# =====================================================================
## 神を 1 柱選んで神格を上げる（神酒／位上がり／討伐の褒賞）
class MikiView:
	extends ChoiceView

	var ids: Array = []

	const CW := 190.0
	const CH := 330.0
	const CY := 236.0

	func count() -> int:
		return ids.size()

	func rect_of(i: int) -> Rect2:
		var total := ids.size()
		var gap := 12.0
		var w := float(total) * CW + float(total - 1) * gap
		var x := (Cfg.W - w) * 0.5 + float(i) * (CW + gap)
		return Rect2(x, CY, CW, CH)

	func _draw() -> void:
		backdrop(Cfg.C_GOLD)
		var pray := Ui.art("cutin/kami")
		if pray != null:
			var prr := Rect2(0, 0, Cfg.W, 120)
			Ui.draw_cover(self, pray, prr, 0.55 * anim, 0.3)
			for gi in 6:
				var kk := float(gi) / 6.0
				draw_rect(Rect2(0, prr.end.y - 60.0 + kk * 60.0, Cfg.W, 60.0 / 6.0 + 1.0), Color(0.03, 0.02, 0.06, 0.9 * kk * anim))
		Ui.txt(self, ui.font_display, Vector2(0, 150), "神との邂逅", 48, Cfg.with_a(Cfg.C_GOLD, anim),
				HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		Ui.txt(self, ui.font, Vector2(0, 188), "強化する神を選ぶ", 15,
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
			# 神の絵（能力のカードとは違う選択だと一目で分かるように）
			var tex := Ui.art("kami/" + id)
			var pr := Rect2(rr.position.x + 4, rr.position.y + 4, rr.size.x - 8, 190)
			if tex != null:
				Ui.draw_cover(self, tex, pr, pop, 0.2)
				for gi in 6:
					var kk := float(gi) / 6.0
					draw_rect(Rect2(pr.position.x, pr.end.y - 60.0 + kk * 60.0, pr.size.x, 60.0 / 6.0 + 1.0), Color(0.08, 0.06, 0.12, 0.9 * kk * pop))
			else:
				Ui.kami_ring(self, p, id, pr.get_center(), 40.0, _t, pop, false)
			Ui.txt(self, ui.font, rr.position + Vector2(10, 22), "主神" if p.is_main(id) else "副神", 11, Color(1, 0.9, 0.7, 0.9 * pop))
			Ui.txt(self, ui.font_display, rr.position + Vector2(0, 216), String(k["name"]), 19, Color(1, 1, 1, pop), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
			var capped := lv >= 10
			Ui.txt(self, ui.font_bold, rr.position + Vector2(0, 244), ("神格 %d（上限）" % lv) if capped else ("神格 %d → %d" % [lv, lv + 1]), 16, Cfg.with_a(Cfg.C_GOLD, pop), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
			Ui.txt(self, ui.font, rr.position + Vector2(0, 266), "%s  威力 ×%.2f → ×%.2f" % [String(k["weapon"]),
					p.kami_power(id), Kami.kami_power(mini(lv + 1, 10), Kami.growth_of(id))], 11,
					Color(0.9, 0.92, 1.0, pop * 0.9), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
			var owned := Boons.owned_of(p, id).size()
			Ui.txt(self, ui.font, rr.position + Vector2(0, 286), "能力 %d / %d" % [owned, Boons.MAX_PER_KAMI], 12,
					Cfg.with_a(kc, pop * 0.9), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
			Ui.txt(self, ui.font_bold, Vector2(rr.position.x + 10, rr.end.y - 10), "[%d]" % (i + 1), 12, Cfg.with_a(kc, pop))
		Ui.txt(self, ui.font, Vector2(0, CY + CH + 30.0), Ui.pick_hint("選ぶ", ids.size()), 14,
				Color(0.85, 0.88, 1.0, 0.9 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)


# =====================================================================
class OverlayView:
	extends Control

	var ui: Ui
	var mode := 0  # 0=タイトル 1=ゲームオーバー 2=踏破
	var stats_lines: Array = []
	var tip := ""
	var rank := 0   # 今回の走りの順位（0 なら上位 10 件に入らなかった）
	var global_rank := 0   # 世界の順位。-1 送信中、-2 失敗、0 なし
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
		if not visible:
			ui.name_box.visible = false

	## 記録表（上位 n 件）。highlight_run の行を強調する
	func _draw_records(y0: float, n: int, highlight_run: int, a := 1.0) -> float:
		var rows: Array = Records.entries.slice(0, n)
		var x0 := 36.0
		var w := Cfg.W - 72.0
		var h := 26.0 + 20.0 * float(maxi(rows.size(), 1))
		Ui.panel(self, Rect2(x0, y0, w, h), Cfg.C_GOLD, a, 0.78)
		Ui.txt(self, ui.font_display, Vector2(x0 + 12, y0 + 17), "この端末の記録", 12, Cfg.with_a(Cfg.C_GOLD, a))
		Ui.txt(self, ui.font, Vector2(x0 + 110, y0 + 16), "巫女 %s" % Records.display_name(), 10, Color(1, 1, 1, 0.75 * a))
		Ui.txt(self, ui.font, Vector2(x0, y0 + 16), "功徳", 9, Color(1, 1, 1, 0.5 * a), HORIZONTAL_ALIGNMENT_RIGHT, w - 250.0)
		Ui.txt(self, ui.font, Vector2(x0, y0 + 16), "到達", 9, Color(1, 1, 1, 0.5 * a), HORIZONTAL_ALIGNMENT_RIGHT, w - 130.0)
		Ui.txt(self, ui.font, Vector2(x0, y0 + 16), "神々", 9, Color(1, 1, 1, 0.5 * a), HORIZONTAL_ALIGNMENT_RIGHT, w - 12.0)
		if rows.is_empty():
			Ui.txt(self, ui.font, Vector2(x0, y0 + 40), "まだ記録がない。参道を登り、名を刻め", 11, Color(1, 1, 1, 0.55 * a), HORIZONTAL_ALIGNMENT_CENTER, w)
		var y := y0 + 40.0
		for i in rows.size():
			var e: Dictionary = rows[i]
			var mine := int(e.get("run", -2)) == highlight_run and highlight_run >= 0
			var col := Cfg.C_GOLD if mine else Color(0.92, 0.92, 1.0)
			if mine:
				draw_rect(Rect2(x0 + 4, y - 14, w - 8, 19), Cfg.with_a(Cfg.C_GOLD, 0.14 * a))
			Ui.txt(self, ui.font_bold, Vector2(x0 + 12, y), "%d" % (i + 1), 11, Cfg.with_a(col, a * (1.0 if i < 3 else 0.7)))
			Ui.txt(self, ui.font, Vector2(x0 + 34, y), String(e.get("name", "")), 11, Cfg.with_a(col, a))
			Ui.txt(self, ui.font_bold, Vector2(x0, y), str(int(e.get("score", 0))), 11, Cfg.with_a(col, a), HORIZONTAL_ALIGNMENT_RIGHT, w - 250.0)
			Ui.txt(self, ui.font, Vector2(x0, y), Records.reach_text(e), 10, Cfg.with_a(col, a * 0.9), HORIZONTAL_ALIGNMENT_RIGHT, w - 130.0)
			Ui.txt(self, ui.font, Vector2(x0, y), Records.gods_text(e), 10, Cfg.with_a(col, a * 0.8), HORIZONTAL_ALIGNMENT_RIGHT, w - 12.0)
			y += 20.0
		return y0 + h

	## 結果画面の順位と名前入力
	func _draw_rank(y: float) -> float:
		var g := Game.inst
		if global_rank != 0:
			var gtxt := "世界の記録　送信中…"
			if global_rank > 0:
				gtxt = "世界の記録　第 %d 位" % global_rank
			elif global_rank == -2:
				gtxt = "世界の記録　送れなかった"
			Ui.txt(self, ui.font_display, Vector2(0, y + 2), gtxt, 17, Color(0.75, 0.9, 1.0) if global_rank > 0 else Color(0.8, 0.8, 0.9, 0.8), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
			y += 22.0
		if rank > 0:
			Ui.txt(self, ui.font_display, Vector2(0, y + 18), "この端末の記録　第 %d 位に刻まれた" % rank, 17, Cfg.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
			Ui.txt(self, ui.font, Vector2(0, y + 36), "巫女 %s として刻まれる。名は下のボタンで付けられる（10 文字まで）" % Records.display_name(), 10, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
			ui.name_box.place(y + 44.0, g.run_id if g != null else -1)
			return y + 84.0
		ui.name_box.visible = false
		return y

	func _clear() -> void:
		draw_rect(Rect2(0, 0, Cfg.W, Cfg.H), Color(0.03, 0.02, 0.06, 0.82))
		var tex := Ui.art("scene/clear")
		if tex != null:
			Ui.draw_cover(self, tex, Rect2(0, 0, Cfg.W, Cfg.H), 0.55, 0.3)
			for gi in 10:
				var kk := float(gi) / 10.0
				draw_rect(Rect2(0, 260.0 + kk * (Cfg.H - 260.0), Cfg.W, (Cfg.H - 260.0) / 10.0 + 1.0), Color(0.03, 0.02, 0.06, 0.85 * minf(1.0, kk * 2.0)))
		Ui.pattern(self, Rect2(0, 0, Cfg.W, Cfg.H), Cfg.with_a(Cfg.C_GOLD, 0.06), 52.0, _t)
		var win := Ui.art("cutin/clear")
		if win != null:
			var wr := Rect2(0, 40, Cfg.W, 170)
			Ui.draw_cover(self, win, wr, 0.95, 0.3)
			for gi in 6:
				var kk := float(gi) / 6.0
				draw_rect(Rect2(0, wr.end.y - 60.0 + kk * 60.0, Cfg.W, 60.0 / 6.0 + 1.0), Color(0.03, 0.02, 0.06, 0.9 * kk))
			draw_rect(Rect2(0, wr.position.y, Cfg.W, 2), Cfg.with_a(Cfg.C_GOLD, 0.9))
			var sm := Ui.art_png("portrait/smile")
			if sm != null:
				var sh := 250.0
				var sw := sh * float(sm.get_width()) / float(sm.get_height())
				draw_texture_rect(sm, Rect2(Cfg.W - sw + 30.0, 10.0, sw, sh), false, Color(1, 1, 1, 0.95))
		else:
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
		y = _draw_rank(y)
		var g := Game.inst
		if g != null and g.player != null and is_instance_valid(g.player):
			ui.hud._draw_build_on(self, g.player, y + 16.0)
		var blink := 0.55 + 0.45 * sin(_t * 4.0)
		var touch := Game.inst != null and Game.inst.is_touch()
		Ui.txt(self, ui.font_display, Vector2(0, Cfg.H - 96.0), "タップで更に登る（祟りの参道）" if touch else "タップ / ENTER で更に登る（祟りの参道）", 20,
				Color(1, 1, 1, blink), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		Ui.txt(self, ui.font, Vector2(0, Cfg.H - 66.0), "右上の「休」から題目へ戻れる" if touch else "R で最初から　　ESC で題目へ", 13,
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

		var touch := Game.inst != null and Game.inst.is_touch()
		# この端末の記録（上位 3 件）
		var rows := mini(Records.entries.size(), 3)
		var rh := 26.0 + 20.0 * float(maxi(rows, 1))
		var ry := menu_rect(0).position.y - rh - 34.0
		_draw_records(ry, 3, -1, 0.95)
		if int(Records.best["clears"]) > 0:
			Ui.txt(self, ui.font, Vector2(0, ry - 8.0), "踏破 %d 回　最高功徳 %d" % [int(Records.best["clears"]), int(Records.best["score"])], 11,
					Cfg.with_a(Cfg.C_GOLD, 0.9), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		# メニュー：大きく、押す場所を分ける
		var labels := ["はじめる", "記録を見る", "名を刻む" if Records.player_name.strip_edges() == "" else "名を変える（%s）" % Records.display_name()]
		var keys := ["Enter", "R", "N"]
		var blink := 0.75 + 0.25 * sin(_t * 4.0)
		for i in 3:
			var r := menu_rect(i)
			var main := i == 0
			var col := Cfg.C_GOLD if main else Color(0.8, 0.8, 0.95)
			draw_rect(r.grow(3.0), Color(0, 0, 0, 0.45))
			draw_rect(r, Color(0.09, 0.06, 0.14, 0.92) if not main else Color(0.16, 0.11, 0.08, 0.95))
			draw_rect(r, Cfg.with_a(col, (blink if main else 0.55)), false, 2.0 if main else 1.2)
			for cx in [r.position.x + 6.0, r.end.x - 6.0]:
				draw_circle(Vector2(cx, r.get_center().y), 2.0, Cfg.with_a(col, 0.9))
			Ui.txt(self, ui.font_display, Vector2(r.position.x, r.get_center().y + 9.0), labels[i], 24 if main else 19,
					Color(1, 1, 1) if main else Cfg.with_a(col, 0.95), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			if not touch:
				Ui.txt(self, ui.font, Vector2(r.end.x - 60.0, r.get_center().y + 5.0), keys[i], 11, Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_RIGHT, 48.0)
		Ui.txt(self, ui.font, Vector2(0, Cfg.H - 12), BuildInfo.label(), 10, Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_RIGHT, Cfg.W - 12.0)

	## 題目のメニューの枡。0 はじめる / 1 記録 / 2 名前
	func menu_rect(i: int) -> Rect2:
		var w := Cfg.W - 140.0
		var h := 58.0 if i == 0 else 48.0
		var y0 := Cfg.H - 62.0 - 48.0 - 48.0 - 58.0 - 12.0 * 2.0
		var y := y0
		for j in i:
			y += (58.0 if j == 0 else 48.0) + 12.0
		return Rect2(70.0, y, w, h)

	func menu_at(p: Vector2) -> int:
		for i in 3:
			if menu_rect(i).has_point(p):
				return i
		return -1

	func _over() -> void:
		draw_rect(Rect2(0, 0, Cfg.W, Cfg.H), Color(0.02, 0.01, 0.05, 0.8))
		var tex := Ui.art("scene/gameover")
		if tex != null:
			Ui.draw_cover(self, tex, Rect2(0, 0, Cfg.W, Cfg.H), 0.5, 0.3)
			for gi in 10:
				var kk := float(gi) / 10.0
				draw_rect(Rect2(0, 240.0 + kk * (Cfg.H - 240.0), Cfg.W, (Cfg.H - 240.0) / 10.0 + 1.0), Color(0.02, 0.01, 0.05, 0.88 * minf(1.0, kk * 2.0)))
		Ui.pattern(self, Rect2(0, 0, Cfg.W, Cfg.H), Color(1, 0.3, 0.4, 0.04), 52.0, _t)
		var pain := Ui.art_png("portrait/pain")
		if pain != null:
			var ph := 300.0
			var pw := ph * float(pain.get_width()) / float(pain.get_height())
			draw_texture_rect(pain, Rect2(Cfg.W - pw + 40.0, 20.0, pw, ph), false, Color(1, 1, 1, 0.9))
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
		y = _draw_rank(y)
		var g := Game.inst
		if g != null and g.player != null and is_instance_valid(g.player):
			ui.hud._draw_build_on(self, g.player, y + 16.0)
		var blink := 0.55 + 0.45 * sin(_t * 4.0)
		Ui.txt(self, ui.font_display, Vector2(0, Cfg.H - 80.0), "タップで題目へ" if (Game.inst != null and Game.inst.is_touch()) else "タップ / ENTER で題目へ　　R でもう一度", 20,
				Color(1, 1, 1, blink), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)


# =====================================================================
## 名前の入力。常設せず「名を刻む」ボタンだけを置き、押したときにだけ入力する。
##   Web 版：ブラウザ標準の入力ダイアログ（prompt）。スマホでも確実にキーボードが出る
##   デスクトップ版：その場に LineEdit を開き、Enter か「刻む」で確定
class NameBox:
	extends Control

	var ui: Ui
	var open_btn: Button
	var rank_btn: Button
	var edit: LineEdit
	var ok_btn: Button
	var run_id := -1
	var _editing := false
	var _y := 0.0
	var _small := false

	func _process(_delta: float) -> void:
		# 題目・結果画面が閉じたら一緒に消える。記録画面の間も隠す
		if visible and (not ui.overlay.visible or ui.ranking_view.visible):
			visible = false
			_editing = false

	func build() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		open_btn = _button("名を刻む", 12)
		open_btn.pressed.connect(_open)
		add_child(open_btn)
		rank_btn = _button("記録を見る", 12)
		rank_btn.pressed.connect(func():
			Sfx.play("select", -10.0)
			ui.ranking_view.open())
		rank_btn.visible = false
		add_child(rank_btn)
		edit = LineEdit.new()
		edit.max_length = 10
		edit.placeholder_text = "巫女の名"
		edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		edit.context_menu_enabled = false
		edit.add_theme_font_override("font", ui.font)
		edit.add_theme_font_size_override("font_size", 15)
		edit.add_theme_color_override("font_color", Color(1, 1, 1))
		edit.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.35))
		edit.add_theme_color_override("caret_color", Cfg.C_GOLD)
		edit.add_theme_stylebox_override("normal", _style(Color(0.08, 0.06, 0.12, 0.95), Cfg.with_a(Cfg.C_GOLD, 0.5)))
		edit.add_theme_stylebox_override("focus", _style(Color(0.10, 0.08, 0.16, 0.98), Cfg.C_GOLD))
		edit.text_submitted.connect(_submit)
		edit.visible = false
		add_child(edit)
		ok_btn = _button("刻む", 13)
		ok_btn.pressed.connect(func(): _submit(edit.text))
		ok_btn.visible = false
		add_child(ok_btn)

	func _button(label: String, size: int) -> Button:
		var b := Button.new()
		b.text = label
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", ui.font_bold)
		b.add_theme_font_size_override("font_size", size)
		b.add_theme_color_override("font_color", Cfg.C_GOLD)
		b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
		b.add_theme_stylebox_override("normal", _style(Color(0.12, 0.09, 0.18, 0.92), Cfg.with_a(Cfg.C_GOLD, 0.6)))
		b.add_theme_stylebox_override("hover", _style(Color(0.18, 0.14, 0.26, 0.98), Cfg.C_GOLD))
		b.add_theme_stylebox_override("pressed", _style(Color(0.25, 0.2, 0.35, 1.0), Cfg.C_GOLD))
		return b

	func _style(bg: Color, border: Color) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = border
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(2)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		return sb

	## 結果画面：順位の下にボタンを置く
	func place(y: float, rid: int) -> void:
		if run_id != rid or not visible:
			_editing = false
		run_id = rid
		_small = false
		_menu_mode = false
		_layout(y)

	## 題目：メニューの「名を刻む」から開く（枡の位置に入力欄が出る。Web は入力ダイアログ）
	func open_at(y: float) -> void:
		run_id = -1
		_small = true
		_menu_mode = true
		_y = y
		visible = true
		_open()

	var _menu_mode := false

	func _layout(y: float) -> void:
		_y = y
		visible = true
		var h := 26.0 if _small else 32.0
		open_btn.text = "名を刻む" if Records.player_name.strip_edges() == "" else "名を変える（%s）" % Records.display_name()
		open_btn.visible = not _editing and not _menu_mode
		open_btn.size = Vector2(0, h)
		open_btn.reset_size()
		rank_btn.visible = _small and not _editing and not _menu_mode
		if _small:
			rank_btn.size = Vector2(0, h)
			rank_btn.reset_size()
			var total := open_btn.size.x + 10.0 + rank_btn.size.x
			open_btn.position = Vector2(Cfg.W * 0.5 - total * 0.5, y)
			rank_btn.position = Vector2(open_btn.position.x + open_btn.size.x + 10.0, y)
		else:
			open_btn.position = Vector2(Cfg.W * 0.5 - open_btn.size.x * 0.5, y)
		edit.visible = _editing
		ok_btn.visible = _editing
		if _editing:
			var eh := 38.0 if _menu_mode else h
			edit.position = Vector2(Cfg.W * 0.5 - 150.0, y)
			edit.size = Vector2(220.0, eh)
			ok_btn.position = Vector2(Cfg.W * 0.5 + 78.0, y)
			ok_btn.size = Vector2(72.0, eh)

	func _open() -> void:
		Sfx.play("select", -10.0)
		if OS.has_feature("web"):
			# ブラウザの入力ダイアログ。スマホでもキーボードが確実に出る
			var js := "window.prompt(%s, %s)" % [JSON.stringify("巫女の名（10 文字まで）"), JSON.stringify(Records.player_name)]
			var r = JavaScriptBridge.eval(js, true)
			if r != null and r is String:
				_submit(String(r))
			return
		_editing = true
		edit.text = Records.player_name
		_layout(_y)
		edit.grab_focus()
		edit.caret_column = edit.text.length()

	func _submit(text: String) -> void:
		_editing = false
		edit.release_focus()
		ui.name_submitted.emit(text)
		_layout(_y)
		Fx.sparks(open_btn.position + open_btn.size * 0.5, Vector2.UP, Cfg.C_GOLD, 8, 200.0)


# =====================================================================
## 討伐の褒賞：神宝を 3 つから 1 つ選ぶ
class RelicView:
	extends ChoiceView

	var offers: Array = []

	const CW := 190.0
	const CH := 250.0
	const CY := 300.0

	func count() -> int:
		return offers.size()

	func rect_of(i: int) -> Rect2:
		var total := offers.size()
		var gap := 12.0
		var w := float(total) * CW + float(total - 1) * gap
		var x := (Cfg.W - w) * 0.5 + float(i) * (CW + gap)
		return Rect2(x, CY, CW, CH)

	func _draw() -> void:
		backdrop(Cfg.C_GOLD)
		Ui.txt(self, ui.font_display, Vector2(0, 150), "討伐の褒賞", 48, Cfg.with_a(Cfg.C_GOLD, anim),
				HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		Ui.txt(self, ui.font, Vector2(0, 188), "神宝を 1 つ選ぶ", 15,
				Color(0.9, 0.9, 1.0, 0.85 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		for i in offers.size():
			var o: Dictionary = offers[i]
			var r := rect_of(i)
			var sel := i == hover
			var pop := clampf(anim * 1.5 - float(i) * 0.1, 0.0, 1.0)
			if pop <= 0.0:
				continue
			var rr := r.grow((3.0 if sel else 0.0) - (1.0 - pop) * 20.0)
			card_bg(rr, Cfg.C_GOLD, sel, pop)
			var c := rr.position + Vector2(rr.size.x * 0.5, 74)
			var tex := Ui.art("relic/" + String(o["id"]))
			if tex != null:
				# 宝物の絵（正方形）
				var pr := Rect2(rr.position.x + 4, rr.position.y + 4, rr.size.x - 8, 126)
				Ui.draw_cover(self, tex, pr, pop, 0.5)
				for gi in 5:
					var kk := float(gi) / 5.0
					draw_rect(Rect2(pr.position.x, pr.end.y - 30.0 + kk * 30.0, pr.size.x, 30.0 / 5.0 + 1.0), Color(0.08, 0.06, 0.12, 0.85 * kk * pop))
			else:
				# 宝物の印：金の輪と文字
				draw_circle(c, 40.0 + (4.0 * sin(_t * 3.0) if sel else 0.0), Cfg.with_a(Cfg.C_GOLD, 0.12 * pop))
				draw_arc(c, 32.0, 0, TAU, 40, Cfg.with_a(Cfg.C_GOLD, 0.9 * pop), 2.0, true)
				draw_arc(c, 26.0, _t * 1.2, _t * 1.2 + 4.0, 24, Cfg.with_a(Cfg.C_GOLD, 0.5 * pop), 1.0, true)
				Ui.txt(self, ui.font_display, Vector2(c.x - 30, c.y + 12), String(o["mark"]), 30, Color(1, 0.96, 0.85, pop), HORIZONTAL_ALIGNMENT_CENTER, 60, false)
			Ui.txt(self, ui.font_display, rr.position + Vector2(0, 148), String(o["name"]), 20, Color(1, 1, 1, pop), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
			Ui.para(self, ui.font, Vector2(rr.position.x + 14, rr.position.y + 172), String(o["desc"]), rr.size.x - 28, 13, 3, Color(0.92, 0.94, 1.0, pop * 0.95), HORIZONTAL_ALIGNMENT_CENTER)
			Ui.txt(self, ui.font_bold, Vector2(rr.position.x + 10, rr.end.y - 10), "[%d]" % (i + 1), 12, Cfg.with_a(Cfg.C_GOLD, pop))
		Ui.txt(self, ui.font, Vector2(0, CY + CH + 30.0), Ui.pick_hint("選ぶ"), 14,
				Color(0.85, 0.88, 1.0, 0.9 * anim), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)


# =====================================================================
## 記録の一覧（この端末／世界）。行を選ぶとその走りの中身（神々・神宝・版）が見える
class RankingView:
	extends Control

	var ui: Ui
	var tab := 0            # 0 この端末 / 1 世界
	var rows: Array = []
	var sel := 0
	var status := ""
	var _t := 0.0
	var _loaded_global := false

	const ROW_H := 26.0
	const LIST_Y := 150.0
	const MAX_ROWS := 12

	func _process(delta: float) -> void:
		_t += delta
		if visible:
			queue_redraw()

	func open() -> void:
		visible = true
		sel = 0
		_set_tab(0)

	func close() -> void:
		visible = false

	func _set_tab(t: int) -> void:
		tab = t
		sel = 0
		if tab == 0:
			rows = Records.entries.duplicate()
			status = "" if not rows.is_empty() else "まだ記録がない"
		else:
			var net := Net.inst
			if net == null or not net.configured():
				rows = []
				status = "世界の記録はまだ繋がっていない"
				return
			rows = []
			status = "読み込み中…"
			net.fetch_top(MAX_ROWS, func(ok: bool, got: Array):
				if tab != 1:
					return
				if not ok:
					status = "読み込めなかった"
					return
				rows = []
				for r in got:
					if r is Dictionary:
						rows.append(_from_remote(r))
				status = "" if not rows.is_empty() else "まだ誰の記録もない")

	## 世界の行を端末の記録と同じ形にする
	func _from_remote(r: Dictionary) -> Dictionary:
		var date := String(r.get("created_at", ""))
		if date.length() >= 10:
			date = date.substr(0, 10).replace("-", "/")
		return {
			"name": String(r.get("name", "")), "score": int(r.get("score", 0)), "wave": int(r.get("wave", 0)),
			"stage": int(r.get("stage", 1)), "lv": int(r.get("level", 1)), "gods": r.get("gods", []) if r.get("gods") is Array else [],
			"kami_lv": r.get("kami_lv", {}) if r.get("kami_lv") is Dictionary else {}, "relics": r.get("relics", []) if r.get("relics") is Array else [],
			"boons": r.get("boons", {}) if r.get("boons") is Dictionary else {}, "curses": r.get("curses", []) if r.get("curses") is Array else [],
			"familiar": String(r.get("familiar", "")),
			"cleared": bool(r.get("cleared", false)), "endless": bool(r.get("endless", false)),
			"date": date, "version": String(r.get("version", "")), "commit": String(r.get("commit", "")),
			"build_time": String(r.get("build_time", "")), "platform": String(r.get("platform", "")), "duration": float(r.get("duration", 0.0)),
		}

	func _tab_rect(i: int) -> Rect2:
		return Rect2(Cfg.W * 0.5 - 150.0 + float(i) * 150.0, 96.0, 140.0, 34.0)

	func _close_rect() -> Rect2:
		return Rect2(Cfg.W - 96.0, 20.0, 76.0, 32.0)

	func _row_rect(i: int) -> Rect2:
		return Rect2(24.0, LIST_Y + float(i) * ROW_H, Cfg.W - 48.0, ROW_H)

	func handle(e: InputEvent) -> void:
		if e is InputEventKey and e.pressed and not e.echo:
			var k := (e as InputEventKey).keycode
			match k:
				KEY_LEFT, KEY_A: _set_tab(0)
				KEY_RIGHT, KEY_D: _set_tab(1)
				KEY_UP, KEY_W: sel = maxi(0, sel - 1)
				KEY_DOWN, KEY_S: sel = mini(maxi(_rows_shown() - 1, 0), sel + 1)
				KEY_ESCAPE, KEY_R, KEY_ENTER, KEY_SPACE: close()
			return
		if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var p := (e as InputEventMouseButton).position
			if _close_rect().has_point(p):
				close()
				return
			for i in 2:
				if _tab_rect(i).has_point(p):
					_set_tab(i)
					return
			for i in _rows_shown():
				if _row_rect(i).has_point(p):
					sel = i
					return

	func _draw() -> void:
		draw_rect(Rect2(0, 0, Cfg.W, Cfg.H), Color(0.03, 0.02, 0.06, 0.94))
		Ui.pattern(self, Rect2(0, 0, Cfg.W, Cfg.H), Cfg.with_a(Cfg.C_GOLD, 0.05), 52.0, _t)
		Ui.txt(self, ui.font_display, Vector2(0, 66), "記録", 40, Cfg.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		# 閉じる
		var cr := _close_rect()
		Ui.panel(self, cr, Cfg.C_GOLD, 1.0, 0.8)
		Ui.txt(self, ui.font_bold, Vector2(cr.position.x, cr.position.y + 21), "閉じる", 13, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, cr.size.x)
		# タブ
		for i in 2:
			var r := _tab_rect(i)
			var on := i == tab
			Ui.panel(self, r, Cfg.C_GOLD if on else Color(0.5, 0.5, 0.6), 1.0, 0.85 if on else 0.5)
			Ui.txt(self, ui.font_bold, Vector2(r.position.x, r.position.y + 22), ["この端末", "世界"][i], 14,
					Color(1, 1, 1) if on else Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		# 見出し
		var hx := 24.0
		var w := Cfg.W - 48.0
		Ui.txt(self, ui.font, Vector2(hx + 34, LIST_Y - 8), "名", 10, Color(1, 1, 1, 0.5))
		Ui.txt(self, ui.font, Vector2(hx, LIST_Y - 8), "功徳", 10, Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_RIGHT, w - 250.0)
		Ui.txt(self, ui.font, Vector2(hx, LIST_Y - 8), "到達", 10, Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_RIGHT, w - 130.0)
		Ui.txt(self, ui.font, Vector2(hx, LIST_Y - 8), "版", 10, Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_RIGHT, w - 12.0)
		if status != "":
			Ui.txt(self, ui.font, Vector2(0, LIST_Y + 40), status, 13, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
		var shown := _rows_shown()
		for i in shown:
			var e: Dictionary = rows[i]
			var r := _row_rect(i)
			var on := i == sel
			if on:
				draw_rect(r, Cfg.with_a(Cfg.C_GOLD, 0.16))
				draw_rect(r, Cfg.with_a(Cfg.C_GOLD, 0.6), false, 1.0)
			var col := Cfg.C_GOLD if on else Color(0.92, 0.92, 1.0)
			var ty := r.position.y + 18.0
			Ui.txt(self, ui.font_bold, Vector2(hx + 8, ty), "%d" % (i + 1), 12, Cfg.with_a(col, 1.0 if i < 3 else 0.7))
			Ui.txt(self, ui.font, Vector2(hx + 34, ty), String(e.get("name", "")), 13, col)
			Ui.txt(self, ui.font_bold, Vector2(hx, ty), str(int(e.get("score", 0))), 13, col, HORIZONTAL_ALIGNMENT_RIGHT, w - 250.0)
			Ui.txt(self, ui.font, Vector2(hx, ty), Records.reach_text(e), 12, Cfg.with_a(col, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, w - 130.0)
			var ver := String(e.get("version", ""))
			Ui.txt(self, ui.font, Vector2(hx, ty), ("v" + ver) if ver != "" else "-", 11, Cfg.with_a(col, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, w - 12.0)
		# 選んだ行の中身
		if sel >= 0 and sel < rows.size():
			_draw_detail(rows[sel], LIST_Y + float(shown) * ROW_H + 16.0)

	const DETAIL_H := 330.0

	## 一覧に出す行数：中身の枡が入るぶんだけ
	func _rows_shown() -> int:
		var avail := Cfg.H - LIST_Y - DETAIL_H - 40.0
		return clampi(int(avail / ROW_H), 4, mini(rows.size(), MAX_ROWS))

	func _draw_detail(e: Dictionary, y0: float) -> void:
		var x0 := 24.0
		var w := Cfg.W - 48.0
		var h := DETAIL_H
		if y0 + h > Cfg.H - 16.0:
			y0 = Cfg.H - 16.0 - h
		Ui.panel(self, Rect2(x0, y0, w, h), Cfg.C_GOLD, 1.0, 0.88)
		var y := y0 + 24.0
		Ui.txt(self, ui.font_display, Vector2(x0 + 14, y), "%s　%d" % [String(e.get("name", "")), int(e.get("score", 0))], 18, Color(1, 1, 1))
		Ui.txt(self, ui.font, Vector2(x0, y), "%s　%s　位 %d" % [String(e.get("date", "")), Records.reach_text(e), int(e.get("lv", 1))], 11, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_RIGHT, w - 14.0)
		y += 14.0
		# 神ごとに：名前・神格・能力（Lv）・伝説
		var gods: Array = e.get("gods", [])
		var klv: Dictionary = e.get("kami_lv", {})
		var boons: Dictionary = e.get("boons", {}) if e.get("boons") is Dictionary else {}
		var duos: Array = []
		for gi in gods.size():
			var gid := String(gods[gi])
			var k := Kami.kami(gid)
			if k.is_empty():
				continue
			y += 22.0
			var c := Vector2(x0 + 26.0, y + 2.0)
			Emblem.draw(self, String(k["emblem"]), c, 11.0, k["color"], k["color2"], _t, 1.0)
			Ui.txt(self, ui.font_bold, Vector2(x0 + 42.0, y + 6.0), "%s %s　神格 %d" % ["主神" if gi == 0 else "副神", String(k["name"]), int(klv.get(gid, 1))], 12, Cfg.with_a(k["color"], 0.95))
			var parts: Array = []
			for bid in boons.keys():
				var b := Kami.boon(String(bid))
				if b.is_empty() or String(b["kami"]) != gid:
					continue
				if b.has("kami2"):
					if not duos.has(bid):
						duos.append(bid)
					continue
				var info: Dictionary = boons[bid]
				var lv := int(info.get("lv", 1))
				var tag := "伝説 " if b.has("rar") and int(b["rar"]) == Cfg.Rar.LEGENDARY else ""
				parts.append("%s%s%s" % [tag, String(b["name"]), (" Lv%d" % lv) if lv > 1 and tag == "" else ""])
			y += 18.0
			Ui.txt(self, ui.font, Vector2(x0 + 42.0, y + 4.0), "・".join(parts) if not parts.is_empty() else "能力なし", 11, Color(0.92, 0.94, 1.0, 0.9), HORIZONTAL_ALIGNMENT_LEFT, w - 56.0)
		if gods.is_empty():
			y += 22.0
			Ui.txt(self, ui.font, Vector2(x0 + 14, y + 6.0), "神なし", 12, Color(1, 1, 1, 0.6))
		# 双神・禍神
		var extra_parts: Array = []
		for did in duos:
			extra_parts.append("双神 " + String(Kami.boon(String(did))["name"]))
		for cid in e.get("curses", []):
			var cu := Kami.curse(String(cid))
			if not cu.is_empty():
				extra_parts.append("禍 " + String(cu["name"]))
		if not extra_parts.is_empty():
			y += 20.0
			Ui.txt(self, ui.font, Vector2(x0 + 14, y + 6.0), "・".join(extra_parts), 11, Color(1, 0.85, 0.9, 0.9), HORIZONTAL_ALIGNMENT_LEFT, w - 28.0)
		# 使い魔・神宝
		y += 22.0
		var fam := Familiar.info(String(e.get("familiar", "")))
		var relics: Array = e.get("relics", [])
		var names: Array = []
		for rid in relics:
			var rl := Relics.get_relic(String(rid))
			if not rl.is_empty():
				names.append(String(rl["name"]))
		Ui.txt(self, ui.font, Vector2(x0 + 14, y + 6.0), "使い魔 %s　　神宝 %s" % [String(fam.get("name", "なし")), "・".join(names) if not names.is_empty() else "なし"], 11, Color(0.92, 0.94, 1.0, 0.9), HORIZONTAL_ALIGNMENT_LEFT, w - 28.0)
		# 版・環境
		var dur := float(e.get("duration", 0.0))
		var dur_txt := ("%d 分 %02d 秒" % [int(dur) / 60, int(dur) % 60]) if dur > 0.0 else ""
		var ver2 := String(e.get("version", ""))
		var vtxt := ("版 v%s（%s）" % [ver2, String(e.get("commit", ""))]) if ver2 != "" else "版 不明（古い記録）"
		Ui.txt(self, ui.font, Vector2(x0 + 14, y0 + h - 12.0), "%s　%s　%s" % [vtxt, String(e.get("platform", "")), dur_txt], 11, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_LEFT, w - 28.0)


# =====================================================================
## タッチ端末が横向きのとき、すべての上に「縦にしてください」を出す
class RotateHint:
	extends Control

	var ui: Ui
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		var g := Game.inst
		var show := g != null and g.landscape_block
		if show != visible:
			visible = show
		if visible:
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-3000, -3000, 7000, 7000), Color(0.03, 0.02, 0.06, 0.97))
		var c := Vector2(Cfg.W * 0.5, Cfg.H * 0.5)
		var ang := sin(_t * 2.0) * 0.35
		draw_set_transform(c, ang, Vector2.ONE)
		draw_rect(Rect2(-26, -46, 52, 92), Color(1, 1, 1, 0.12))
		draw_rect(Rect2(-26, -46, 52, 92), Cfg.C_GOLD, false, 2.5)
		draw_circle(Vector2(0, 38), 3.0, Cfg.C_GOLD)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		Ui.txt(self, ui.font_display, Vector2(0, c.y + 90), "縦にしてください", 26, Cfg.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)


# =====================================================================
## 開幕の物語：一枚絵と短い言葉。タップで先へ
class StoryView:
	extends Control

	var ui: Ui
	var t := 0.0
	const LINES := ["参道は穢れに沈み、灯は消えた。", "神楽の巫女はひとり、八百万の神々に呼びかける。", "わたしが、やらなきゃ。"]

	func _process(delta: float) -> void:
		if visible:
			t += delta
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0, 0, Cfg.W, Cfg.H), Color(0.03, 0.02, 0.06, 1.0))
		var tex := Ui.art("cutin/opening")
		var a := clampf(t * 1.5, 0.0, 1.0)
		if tex != null:
			var pr := Rect2(0, 120, Cfg.W, 360)
			Ui.draw_cover(self, tex, pr, a, 0.4)
			for gi in 8:
				var kk := float(gi) / 8.0
				draw_rect(Rect2(0, pr.end.y - 100.0 + kk * 100.0, Cfg.W, 100.0 / 8.0 + 1.0), Color(0.03, 0.02, 0.06, 0.95 * kk * a))
				draw_rect(Rect2(0, pr.position.y + kk * 60.0, Cfg.W, 60.0 / 8.0 + 1.0), Color(0.03, 0.02, 0.06, 0.9 * (1.0 - kk) * a))
		var y := 540.0
		for i in LINES.size():
			var la := clampf((t - 0.8 - float(i) * 0.9) * 1.5, 0.0, 1.0)
			Ui.txt(self, ui.font_display, Vector2(0, y), LINES[i], 20 if i < 2 else 24, Color(1, 0.96, 0.9, la) if i < 2 else Cfg.with_a(Cfg.C_GOLD, la), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
			y += 44.0
		if t > 0.6:
			var blink := 0.5 + 0.5 * sin(t * 4.0)
			Ui.txt(self, ui.font, Vector2(0, Cfg.H - 60.0), "タップで進む", 14, Color(1, 1, 1, 0.6 * blink), HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
