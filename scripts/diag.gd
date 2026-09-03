class_name Diag
extends Control
## 診断表示：fps・フレーム時間・描画呼び出し・物の数を左下に出す。
## 起動引数 --diag、または Web なら URL に ?diag を付けると表示。

var _acc := 0.0
var _lines: PackedStringArray = []
var _proc_max := 0.0


static func wanted() -> bool:
	if OS.get_cmdline_user_args().has("--diag"):
		return true
	if OS.has_feature("web"):
		var r = JavaScriptBridge.eval("(location.search + location.hash).indexOf('diag') >= 0")
		return bool(r)
	return false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_proc_max = maxf(_proc_max, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_acc += delta
	if _acc < 0.5:
		return
	_acc = 0.0
	var g := Game.inst
	var en := Game.enemies().size() if g != null else 0
	var eb := Game.ebullets().size() if g != null else 0
	var pb := get_tree().get_nodes_in_group("pbullet").size()
	_lines = PackedStringArray([
		"fps %d  frame %.1fms (max %.1f)  phys %.1fms" % [Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, _proc_max,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0],
		"draw %d  objs %d  nodes %d  mem %.0fMB" % [int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0],
		"enemies %d  ebullets %d  pbullets %d  parts %d  wave %d  dpr %.1f  %dx%d" % [en, eb, pb,
			Fx.inst._parts.size() if Fx.inst != null else 0, g.wave if g != null else 0,
			DisplayServer.screen_get_scale(), get_viewport().size.x, get_viewport().size.y],
	])
	_proc_max = 0.0
	queue_redraw()


func _draw() -> void:
	if Game.inst == null or Game.inst.ui == null:
		return
	var f: Font = Game.inst.ui.font
	var y := Cfg.H - 86.0
	draw_rect(Rect2(4, y - 14, Cfg.W - 8, 14 * _lines.size() + 8), Color(0, 0, 0, 0.6))
	for l in _lines:
		draw_string(f, Vector2(8, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 1.0, 0.6))
		y += 14.0
