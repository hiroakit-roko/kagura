class_name Autoplay
extends Node

## 開発用の自動プレイ。`godot -- --capture` で起動したときだけ Game が生成する。
## 入力をシミュレートしてゲームを進め、要所でスクリーンショットを保存する。

const SHOT_DIR := "user://shots"

var _t := 0.0
var _held := {}
var _shots_done := {}
var quit_at := 120.0
var _cast_t := 0.0
var _call_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	_run()


func _key(code: int, pressed: bool) -> void:
	if bool(_held.get(code, false)) == pressed:
		return
	_held[code] = pressed
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _release_all() -> void:
	for k: int in _held.keys():
		if _held[k]:
			_key(k, false)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func shot(name: String) -> void:
	if _shots_done.has(name):
		return
	_shots_done[name] = true
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := SHOT_DIR + "/" + name
	img.save_png(path)
	print("[autoplay] shot -> ", ProjectSettings.globalize_path(path))


func _process(delta: float) -> void:
	_t += delta / maxf(Engine.time_scale, 0.01)
	var g := Game.inst
	if g == null:
		return

	# 近くの敵に横位置を合わせつつ、画面下寄りに留まる（人間のプレイに近い動き）
	if g.state == Game.St.PLAY and g.player != null and is_instance_valid(g.player):
		var pp := g.player.position
		var want_x := Cfg.W * 0.5 + sin(_t * 0.9) * Cfg.W * 0.35
		var best := 1e9
		for e in get_tree().get_nodes_in_group("enemy"):
			var d: float = absf(e.global_position.y - pp.y)
			if d < best:
				best = d
				want_x = e.global_position.x
		var dx := pp.x - want_x
		_key(KEY_A, dx > 14.0)
		_key(KEY_D, dx < -14.0)
		var want_y := Cfg.H * (0.74 + 0.10 * sin(_t * 0.31))
		var dy := pp.y - want_y
		_key(KEY_W, dy > 20.0)
		_key(KEY_S, dy < -20.0)
		# 詠唱と神招きも定期的に使う
		_cast_t += delta
		_call_t += delta
		_key(KEY_Z, _cast_t > 3.0 and _cast_t < 3.15)
		if _cast_t > 3.2:
			_cast_t = 0.0
		_key(KEY_X, _call_t > 6.0 and _call_t < 6.15)
		if _call_t > 6.2:
			_call_t = 0.0
	else:
		_release_all()


func _run() -> void:
	await _wait(0.9)
	await shot("01_title.png")

	if OS.get_cmdline_user_args().has("--deathtest"):
		await _death_test()
		return

	Game.inst.start_game()
	# 自動プレイなので長く生き延びるようタフにしておく
	var p := Game.inst.player
	p.stats["max_hp"] = 400.0
	p.hp = 400.0

	var last := 0.0
	var idx := 10
	var boon_shots := 0
	while _t < quit_at:
		await _wait(0.25)
		var g := Game.inst
		if g.state == Game.St.KAMI and g.ui.kami_view.visible:
			await _wait(0.9)
			await shot("02_kami.png")
			g.ui.kami_view.hover = 1
			await _wait(0.3)
			await shot("02_kami_hover.png")
			g._on_kami_chosen(String(g.ui.kami_view.ids[randi() % g.ui.kami_view.ids.size()]))
		elif g.state == Game.St.BOON and g.ui.boons_view.visible and not g._offers.is_empty():
			await _wait(0.8)
			boon_shots += 1
			if boon_shots <= 4:
				g.ui.boons_view.hover = 0
				await shot("03_boon_%d.png" % boon_shots)
			g._on_boon_chosen(randi() % g._offers.size())
		elif g.state == Game.St.MIKI and g.ui.miki_view.visible:
			await _wait(0.8)
			await shot("04_miki.png")
			g._on_miki_chosen(String(g.ui.miki_view.ids[randi() % g.ui.miki_view.ids.size()]))
		if g.state == Game.St.OVER:
			await shot("99_gameover.png")
			break
		if g.boss != null and is_instance_valid(g.boss) and not g.boss.entering:
			await shot("50_boss.png")
			if g.boss.hp / g.boss.max_hp < 0.5:
				await shot("51_boss_p2.png")
		if g.player != null and is_instance_valid(g.player) and g.player.call_t > 0.0:
			await shot("60_call.png")
		if _t - last > 9.0:
			last = _t
			await shot("%02d_play_w%d.png" % [idx, g.wave])
			idx += 1

	await shot("98_final.png")
	print("[autoplay] finished at t=%.1f wave=%d score=%d gods=%s boons=%s" % [
			_t, Game.inst.wave, Game.inst.score, str(Game.inst.player.gods), str(Game.inst.player.boons.keys())])
	get_tree().quit()


## ゲームオーバー → リスタートの動線を確認する短いテスト
func _death_test() -> void:
	Game.inst.start_game()
	await _wait(6.0)
	print("[autoplay] forcing death (wave=%d score=%d)" % [Game.inst.wave, Game.inst.score])
	Game.inst.player.take_damage(99999.0)
	await _wait(2.5)
	await shot("90_gameover.png")
	print("[autoplay] state after death = %d (OVER=%d)" % [Game.inst.state, Game.St.OVER])

	_key(KEY_ENTER, true)
	await _wait(0.1)
	_key(KEY_ENTER, false)
	await _wait(2.0)
	print("[autoplay] state after restart = %d (PLAY=%d) wave=%d hp=%.0f"
			% [Game.inst.state, Game.St.PLAY, Game.inst.wave, Game.inst.player.hp])
	await shot("91_restarted.png")

	_key(KEY_P, true)
	await _wait(0.1)
	_key(KEY_P, false)
	await _wait(0.8)
	await shot("92_paused.png")
	print("[autoplay] state after pause = %d (PAUSE=%d)" % [Game.inst.state, Game.St.PAUSE])
	get_tree().quit()
