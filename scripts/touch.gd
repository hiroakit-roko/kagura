class_name Touch
extends CanvasLayer

## スマホ向けのタッチ操作。
##   - 画面のどこでも指を滑らせると、その移動量ぶん自機が動く（相対移動。指で自機が隠れない）
##   - 短くなぞってすぐ離す（スワイプ）と、その方向へ疾走。指を離さない速い移動では出ない
##   - 画面下の丸ボタンで 詠唱 / 神招き、右上の小ボタンで小休止
##   - 最初のタッチで表示され、キーボードを触ると隠れる
##   - 選択画面やタイトルは、タッチから生成されるマウスイベントで既存の UI がそのまま動く

static var inst: Touch

const SENS := 1.0           # 指の移動量はそのまま渡す（倍率は Player 側の Cfg.TOUCH_SENS に一本化）
const BTN_R := 50.0
const SWIPE_TIME := 0.30    # 置いてから離すまでがこれより短く
const SWIPE_FRAMES := 20    # （低 fps 端末向け）またはこのフレーム数以内で
const SWIPE_DIST := 22.0    # これ以上動いていれば、スワイプとして疾走

var active := false
var move_dir := Vector2.ZERO
var _move_id := -1
var _delta := Vector2.ZERO
var _last_drag := Vector2.ZERO
var _view: Control
var _t := 0.0
var _flick := Vector2.ZERO
var _flick_cd := 0.0
var _hist: Array = []        # 移動指の履歴 [時刻, 位置]
var _touch_start_t := 0.0
var _touch_start_frame := 0
var _touch_start_pos := Vector2.ZERO

var buttons := {
	"call": {"pos": Vector2.ZERO, "r": BTN_R, "id": -1, "just": false, "label": "神招き"},
	"cast": {"pos": Vector2.ZERO, "r": BTN_R, "id": -1, "just": false, "label": "詠唱"},
	"pause": {"pos": Vector2.ZERO, "r": 20.0, "id": -1, "just": false, "label": "休"},
}


## 画面の高さは端末で変わるので、ボタン位置は毎回計算する
func layout() -> void:
	buttons["call"]["pos"] = Vector2(84.0, Cfg.H - 128.0)
	buttons["cast"]["pos"] = Vector2(Cfg.W - 84.0, Cfg.H - 128.0)
	buttons["pause"]["pos"] = Vector2(Cfg.W - 26.0, 112.0)


## 指を弾いた方向（疾走）。一度だけ返す
func take_flick() -> Vector2:
	var f := _flick
	_flick = Vector2.ZERO
	return f


func _ready() -> void:
	inst = self
	layout()
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view = TouchView.new()
	_view.owner_layer = self
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	# タッチ画面の端末では最初から表示しておく
	if DisplayServer.is_touchscreen_available():
		active = true


func _process(delta: float) -> void:
	var _t0 := Time.get_ticks_usec()
	_perf_process(delta)
	Perf.add("touch", _t0)


func _perf_process(delta: float) -> void:
	_t += delta
	_flick_cd = maxf(0.0, _flick_cd - delta)
	layout()
	_view.queue_redraw()


## この物理フレームぶんの移動量を取り出す（Player が呼ぶ）
func consume_move() -> Vector2:
	var d := _delta
	_delta = Vector2.ZERO
	return d


## ボタンが今フレーム押されたか（一度だけ true）
func take(name: String) -> bool:
	var b: Dictionary = buttons[name]
	if b["just"]:
		b["just"] = false
		return true
	return false


func held(name: String) -> bool:
	return int(buttons[name]["id"]) >= 0


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		active = false
		return
	var g := Game.inst
	if g == null:
		return
	if e is InputEventScreenTouch:
		var st := e as InputEventScreenTouch
		if st.pressed:
			active = true
			if g.state == Game.St.PAUSE:
				# 小休止中はどこをタップしても再開
				g.toggle_pause()
				return
			if g.state != Game.St.PLAY:
				return
			for name in buttons.keys():
				var b: Dictionary = buttons[name]
				if int(b["id"]) < 0 and st.position.distance_to(b["pos"]) <= float(b["r"]) * 1.25:
					b["id"] = st.index
					b["just"] = true
					if name == "pause":
						g.toggle_pause()
					return
			if _move_id < 0:
				_move_id = st.index
				_last_drag = st.position
				_hist.clear()
				_touch_start_t = Time.get_ticks_msec() / 1000.0
				_touch_start_frame = Engine.get_process_frames()
				_touch_start_pos = st.position
		else:
			if st.index == _move_id:
				# 置いてすぐ短く払って離した → 疾走
				var dt := Time.get_ticks_msec() / 1000.0 - _touch_start_t
				var df := Engine.get_process_frames() - _touch_start_frame
				var dp := st.position - _touch_start_pos
				# 低 fps の端末でも判定がぶれないよう、時間かフレーム数のどちらかで「短い」とみなす
				if _flick_cd <= 0.0 and (dt < SWIPE_TIME or df <= SWIPE_FRAMES) and dp.length() >= SWIPE_DIST and g.state == Game.St.PLAY:
					_flick = dp.normalized()
					_flick_cd = 0.5
				_move_id = -1
				move_dir = Vector2.ZERO
				_hist.clear()
			for name in buttons.keys():
				if int(buttons[name]["id"]) == st.index:
					buttons[name]["id"] = -1
	elif e is InputEventScreenDrag:
		var dg := e as InputEventScreenDrag
		if dg.index == _move_id and g.state == Game.St.PLAY:
			_delta += dg.relative * SENS
			if dg.relative.length() > 0.5:
				move_dir = move_dir.lerp(dg.relative.normalized(), 0.5)
			# 疾走はスワイプ（離したとき）のみ。指を離さない速い移動では出さない


# =====================================================================
class TouchView:
	extends Control

	var owner_layer: Touch

	func _draw() -> void:
		var tc := owner_layer
		var g := Game.inst
		if tc == null or not tc.active or g == null:
			return
		if g.state != Game.St.PLAY and g.state != Game.St.PAUSE:
			return
		var p := g.player
		if p == null or not is_instance_valid(p):
			return
		var ui := g.ui

		for name in tc.buttons.keys():
			var b: Dictionary = tc.buttons[name]
			var c: Vector2 = b["pos"]
			var r: float = b["r"]
			var pressed := int(b["id"]) >= 0
			var col := Color(1, 1, 1)
			var enabled := true
			var fill := 0.0
			var sub := ""
			match name:
				"dash":
					col = p.kami_color(p.slot_kami(Cfg.Slot.DASH)) if p.slot_kami(Cfg.Slot.DASH) != "" else Color(0.9, 0.9, 1.0)
					fill = 1.0 - p.dash_cool / maxf(0.01, p.dash_cd_time())
					enabled = p.dash_cool <= 0.0
				"cast":
					col = p.kami_color(p.main_god()) if p.main_god() != "" else Cfg.C_PBULLET
					fill = 1.0 if p.cast_charges > 0 else 0.0
					enabled = p.cast_charges > 0 and p.main_god() != ""
					sub = "×%d" % p.cast_charges
				"call":
					var has_call: bool = p.main_god() != ""
					col = p.kami_color(p.main_god()) if has_call else Color(0.5, 0.5, 0.6)
					fill = p.call_gauge
					enabled = has_call and p.call_gauge >= 0.25
					if not has_call:
						sub = "未"
				"pause":
					col = Color(0.9, 0.9, 1.0)
					fill = 0.0
					enabled = true
			var a := 0.9 if enabled else 0.45
			# 台座
			draw_circle(c, r, Color(0.05, 0.03, 0.09, 0.55))
			draw_arc(c, r, 0, TAU, 40, Cfg.with_a(col, 0.35 * a), 2.0, true)
			if fill > 0.0 and name != "pause":
				draw_arc(c, r - 5.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(fill, 0.0, 1.0), 40, Cfg.with_a(col, a), 5.0, true)
			if enabled and name != "pause":
				var pulse := 0.10 + 0.06 * sin(tc._t * 4.0)
				draw_circle(c, r - 8.0, Cfg.with_a(col, pulse))
			if pressed:
				draw_circle(c, r - 4.0, Cfg.with_a(col, 0.35))
			# 表記
			var fnt: Font = ui.font_display if name != "pause" else ui.font_bold
			var size := 16 if name != "pause" else 14
			Ui.txt(self, fnt, Vector2(c.x - r, c.y + (6.0 if sub == "" else 0.0)), String(b["label"]), size,
					Cfg.with_a(Color(1, 1, 1), a), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)
			if sub != "":
				Ui.txt(self, ui.font, Vector2(c.x - r, c.y + 20.0), sub, 12, Cfg.with_a(col, a),
						HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)

		# 疾走の状態（画面下中央の小さな札）
		var dk := 1.0 - p.dash_cool / maxf(0.01, p.dash_cd_time())
		var dc := Vector2(Cfg.W * 0.5, Cfg.H - 110.0)
		var dcol := p.kami_color(p.main_god()) if p.main_god() != "" else Color(0.9, 0.9, 1.0)
		draw_rect(Rect2(dc.x - 46, dc.y - 14, 92, 28), Color(0.05, 0.03, 0.09, 0.55))
		draw_rect(Rect2(dc.x - 46, dc.y - 14, 92, 28), Cfg.with_a(dcol, 0.35), false, 1.0)
		draw_rect(Rect2(dc.x - 42, dc.y + 6, 84.0 * dk, 4), Cfg.with_a(dcol if dk >= 1.0 else Color(0.8, 0.85, 1.0), 0.9))
		Ui.txt(self, ui.font_display, Vector2(dc.x - 46, dc.y + 2), "疾走" if dk >= 1.0 else "疾走 %.1f" % p.dash_cool, 12,
				Color(1, 1, 1, 0.9 if dk >= 1.0 else 0.6), HORIZONTAL_ALIGNMENT_CENTER, 92)

		# 操作ヒント（最初の数秒だけ）
		if g.wave <= 1 and tc._t < 12.0:
			var a2 := clampf(12.0 - tc._t, 0.0, 1.0) * 0.8
			Ui.txt(self, ui.font, Vector2(0, Cfg.H * 0.56), "画面をなぞって移動", 15, Color(1, 1, 1, a2),
					HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
			Ui.txt(self, ui.font, Vector2(0, Cfg.H * 0.56 + 22.0), "指をすばやく弾くと疾走", 13, Color(1, 1, 1, a2 * 0.85),
					HORIZONTAL_ALIGNMENT_CENTER, Cfg.W)
