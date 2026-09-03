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
var _no_ai := false


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

	if _no_ai:
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
	if OS.get_cmdline_user_args().has("--boontest"):
		await _boon_test()
		return
	if OS.get_cmdline_user_args().has("--flicktest"):
		await _flick_test()
		return
	if OS.get_cmdline_user_args().has("--cleartest"):
		await _clear_test()
		return
	if OS.get_cmdline_user_args().has("--flowtest"):
		await _flow_test()
		return
	if OS.get_cmdline_user_args().has("--clicktest"):
		await _click_test()
		return
	if OS.get_cmdline_user_args().has("--fantest"):
		await _fan_test()
		return
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--abilitytest="):
			await _ability_test(String(a).trim_prefix("--abilitytest=").split(","))
			return

	Game.inst.start_game()
	# 自動プレイなので長く生き延びるようタフにしておく
	var p := Game.inst.player
	p.stats["max_hp"] = 400.0
	p.hp = 400.0

	var last := 0.0
	var idx := 10
	var boon_shots := 0
	var dbg_t := 0.0
	while _t < quit_at:
		await _wait(0.25)
		var g := Game.inst
		if g.state == Game.St.FAMILIAR and g.ui.familiar_view.visible:
			await _wait(0.8)
			g.ui.familiar_view.hover = 1
			await shot("01b_familiar.png")
			g._on_familiar_chosen(String(Familiar.LIST[randi() % 3]["id"]))
		if _t - dbg_t > 1.0 and OS.get_cmdline_user_args().has("--verbose-flow"):
			dbg_t = _t
			print("[tick] t=%.1f wave=%d state=%d lv=%d pend=%d enemies=%d" % [_t, g.wave, g.state, g.player.level, g.player.pending_levels, get_tree().get_nodes_in_group("enemy").size()])
		if g.state == Game.St.KAMI and g.ui.kami_view.visible:
			await _wait(0.9)
			await shot("02_kami.png")
			g.ui.kami_view.hover = 1
			await _wait(0.3)
			await shot("02_kami_hover.png")
			var kid := String(g.ui.kami_view.ids[randi() % g.ui.kami_view.ids.size()])
			g.ui.kami_view.visible = false
			g.ui.ask_contract(kid, g.ui.kami_view.role, func(): g._on_kami_chosen(kid))
			await _wait(0.8)
			g.ui.confirm_view.hover = 0
			await shot("02c_contract.png")
			g.ui.confirm_view.visible = false
			g._on_kami_chosen(kid)
		elif g.state == Game.St.BOON and g.ui.relic_view.visible:
			await _wait(0.8)
			await shot("05_relic.png")
			if g._relic_offers.is_empty():
				g.ui.relic_view.visible = false
			else:
				g._on_relic_chosen(randi() % g._relic_offers.size())
		elif g.state == Game.St.BOON and g.ui.boons_view.visible and not g._offers.is_empty():
			# 選択画面中に敵と自機が止まっているか
			var es := get_tree().get_nodes_in_group("enemy")
			var before: Vector2 = (es[0].position if not es.is_empty() else Vector2.ZERO)
			var pb := g.player.position
			await _wait(0.8)
			if not es.is_empty() and is_instance_valid(es[0]):
				print("[freeze] enemy moved=%.1f player moved=%.1f (both should be 0)" % [before.distance_to(es[0].position), pb.distance_to(g.player.position)])
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
		if g.state == Game.St.CLEAR and g.ui.overlay.visible:
			await shot("97_clear.png")
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
			print("[autoplay] t=%.0f wave=%d fps=%d enemies=%d bullets=%d state=%d lv=%d" % [_t, g.wave, Engine.get_frames_per_second(),
					get_tree().get_nodes_in_group("enemy").size(), get_tree().get_nodes_in_group("ebullet").size(), g.state, g.player.level])

	await shot("98_final.png")
	print("[autoplay] finished at t=%.1f wave=%d score=%d gods=%s boons=%s" % [
			_t, Game.inst.wave, Game.inst.score, str(Game.inst.player.gods), str(Game.inst.player.boons.keys())])
	get_tree().quit()


## 神ごとに神器と全強化を付けて戦わせ、能力と演出が動いているかを撮影する検証モード
func _boon_test() -> void:
	var g := Game.inst
	for kid in Boons.kami_ids():
		g.start_game()
		g._on_familiar_chosen("neko")
		var p := g.player
		p.stats["max_hp"] = 9999.0
		p.hp = 9999.0
		p.add_god(kid)
		for b in Kami.upgrades_of(kid):
			for i in 2:
				Boons.take(p, {"type": "upgrade", "boon": b, "rar": Cfg.Rar.EPIC, "kami": kid})
		var leg := Kami.legendary_of(kid)
		if not leg.is_empty():
			Boons.take(p, {"type": "legendary", "boon": leg, "rar": Cfg.Rar.LEGENDARY, "kami": kid})
		p.kami_lv[kid] = 4
		p.pending_levels = 0
		g.wave = 5
		print("[boontest] %s boons=%s" % [kid, str(p.boons.keys())])
		await _wait(4.5)
		_key(KEY_Z, true); await _wait(0.1); _key(KEY_Z, false)
		_key(KEY_SPACE, true); await _wait(0.1); _key(KEY_SPACE, false)
		await _wait(0.5)
		await shot("70_%s_a.png" % kid)
		await _wait(2.0)
		p.call_gauge = 1.0
		_key(KEY_X, true); await _wait(0.1); _key(KEY_X, false)
		await _wait(0.5)
		await shot("71_%s_call.png" % kid)
		await _wait(2.5)
		_key(KEY_Z, true); await _wait(0.1); _key(KEY_Z, false)
		await _wait(1.0)
		await shot("72_%s_b.png" % kid)
		g.player.pending_levels = 0
	# 3 柱 + 双神
	g.start_game()
	g._on_familiar_chosen("shiki")
	var p2 := g.player
	p2.stats["max_hp"] = 9999.0
	p2.hp = 9999.0
	for kid in ["ama", "take", "uzume"]:
		p2.add_god(kid)
		for b in Kami.upgrades_of(kid):
			Boons.take(p2, {"type": "upgrade", "boon": b, "rar": Cfg.Rar.RARE, "kami": kid})
	for b in Kami.BOONS:
		if b.has("kami2") and p2.gods.has(b["kami"]) and p2.gods.has(b["kami2"]):
			Boons.take(p2, {"type": "duo", "boon": b, "rar": Cfg.Rar.DUO, "kami": String(b["kami"])})
	g.wave = 6
	await _wait(6.0)
	await shot("73_trio.png")
	print("[boontest] done")
	get_tree().quit()


## 主神選択 → 恩恵 → 数回のレベルアップの流れを高速に確認する（ハング調査用）
func _flow_test() -> void:
	_no_ai = true
	var g := Game.inst
	g.start_game()
	g._on_familiar_chosen("karasu")
	await _wait(0.5)
	print("[flow] force level up")
	g.player.level = 2
	g.player.pending_levels = 1
	await _wait(0.3)
	print("[flow] state=%d kami_view=%s role=%s" % [g.state, str(g.ui.kami_view.visible), g.ui.kami_view.role])
	g._on_kami_chosen(String(g.ui.kami_view.ids[0]))
	print("[flow] after kami: state=%d (PLAY=%d) gods=%s" % [g.state, Game.St.PLAY, str(g.player.gods)])
	await _wait(0.3)
	# 位 3〜9 まで順に上げる：位 4 と 7 で副神の選択、それ以外は恩恵 3 択のはず
	for i in 7:
		g.player.level += 1
		g.player.pending_levels = 1
		await _wait(0.3)
		if g.state == Game.St.MIKI:
			var pick := String(g.ui.miki_view.ids[randi() % g.ui.miki_view.ids.size()])
			print("[flow] lv%d PICK ids=%s -> %s" % [g.player.level, str(g.ui.miki_view.ids), pick])
			await _wait(0.5)
			await shot("04_pick.png")
			g._on_miki_chosen(pick)
			await _wait(0.3)
		if g.state == Game.St.KAMI:
			print("[flow] lv%d KAMI role=%s ids=%s" % [g.player.level, g.ui.kami_view.role, str(g.ui.kami_view.ids)])
			g._on_kami_chosen(String(g.ui.kami_view.ids[0]))
		elif g.state == Game.St.BOON:
			var desc := g._offers.map(func(o):
				var b: Dictionary = o["boon"]
				var lv := int(g.player.boons[b["id"]]["lv"]) if (b.has("id") and g.player.boons.has(b["id"])) else 0
				return "%s:%s[%s]%s" % [o["type"], b.get("name", "?"), Cfg.RAR_NAME[int(o["rar"])], (" Lv%d→%d" % [lv, lv + 1]) if lv > 0 else " 新"])
			print("[flow] lv%d BOON from %s: %s" % [g.player.level, g._offer_kami, str(desc)])
			await _wait(0.4)
			await shot("03_boon_lv%d.png" % g.player.level)
			g._on_boon_chosen(randi() % g._offers.size())
		else:
			print("[flow] lv%d state=%d" % [g.player.level, g.state])
		await _wait(0.3)
		print("[flow]   -> state=%d gods=%s kami_lv=%s" % [g.state, str(g.player.gods), str(g.player.kami_lv)])
	# 記録の一覧
	g.ui.ranking_view.open()
	await _wait(0.4)
	await shot("06_ranking.png")
	g.ui.ranking_view._set_tab(1)
	await _wait(0.4)
	await shot("06b_ranking_global.png")
	g.ui.ranking_view.close()
	# 討伐の褒賞（神宝）
	g._open_relics()
	await _wait(0.5)
	print("[flow] relics offered: %s" % str(g._relic_offers.map(func(r): return r["name"])))
	await shot("05_relic.png")
	g._on_relic_chosen(0)
	await _wait(0.2)
	print("[flow] relics=%s state=%d" % [str(g.player.relics), g.state])
	print("[flow] done")
	get_tree().quit()


## ラスボス（第 3 ステージ最後）→ 踏破画面までを確認する
func _clear_test() -> void:
	var g := Game.inst
	g.start_game()
	g._on_familiar_chosen("karasu")
	var p := g.player
	for kid in ["take", "ama", "inari"]:
		p.add_god(kid)
		p.kami_lv[kid] = 8
	p.stats["max_hp"] = 9999.0
	p.hp = 9999.0
	g.wave = Cfg.STAGE_LEN * Cfg.STAGE_COUNT - 1   # 次の波がラスボス
	g._wave_active = false
	g._between = 0.5
	await _wait(3.0)
	await shot("80_lastboss.png")
	print("[cleartest] boss=%s final=%s music=%s" % [str(g.boss != null), str(g.boss.is_final if g.boss else false), Music.inst._current])
	# 流れの確認が目的なのでボスの HP は削っておく
	if g.boss != null:
		g.boss.hp = minf(g.boss.hp, 400.0)
	var t0 := 0.0
	while g.state != Game.St.CLEAR and g.state != Game.St.OVER and t0 < 90.0:
		await _wait(0.5)
		t0 += 0.5
		# 回復で上限に戻されないよう毎回タフにしておく（テスト用）
		p.stats["max_hp"] = 9999.0
		p.hp = 9999.0
		if g.state == Game.St.BOON or g.state == Game.St.KAMI or g.state == Game.St.MIKI:
			g._close_choice()
			p.pending_levels = 0
	print("[cleartest] state=%d (CLEAR=%d) after %.1fs" % [g.state, Game.St.CLEAR, t0])
	await _wait(3.0)
	await shot("81_clear.png")
	print("[cleartest] overlay=%s mode=%d music=%s best=%s" % [str(g.ui.overlay.visible), g.ui.overlay.mode, Music.inst._current, str(g.best)])
	g.continue_endless()
	await _wait(4.0)
	print("[cleartest] endless: state=%d wave=%d stage=%d music=%s" % [g.state, g.wave, Cfg.stage_of(g.wave), Music.inst._current])
	await shot("82_endless.png")
	get_tree().quit()


## スワイプで疾走が出るかを合成タッチイベントで確認する
func _touch(pressed: bool, pos: Vector2, idx := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(from: Vector2, to: Vector2, idx := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = to
	e.relative = to - from
	e.velocity = (to - from) * 60.0
	Input.parse_input_event(e)


func _flick_test() -> void:
	_no_ai = true
	Game.inst.start_game()
	Game.inst._on_familiar_chosen("karasu")
	await _wait(1.5)
	var p := Game.inst.player
	# 1) 短いスワイプ：120ms で 60px 動かして離す
	var a := Vector2(200, 600)
	_touch(true, a)
	var cur := a
	for i in 4:
		await _wait(0.03)
		var nxt := cur + Vector2(15, -5)
		_drag(cur, nxt)
		cur = nxt
	_touch(false, cur)
	await _wait(0.05)
	print("[flicktest] short swipe -> dash_t=%.2f active=%s move_id=%d" % [p.dash_t, str(Touch.inst.active), Touch.inst._move_id])
	await _wait(1.0)
	# 2) 速い動き（離さない）
	a = Vector2(300, 600)
	_touch(true, a)
	cur = a
	for i in 4:
		await _wait(0.016)
		var nxt := cur + Vector2(-30, 0)
		_drag(cur, nxt)
		cur = nxt
	await _wait(0.05)
	print("[flicktest] fast drag (no release) -> dash_t=%.2f (should be 0)" % p.dash_t)
	_touch(false, cur)
	await _wait(2.5)
	# 3) ゆっくり動かす（疾走してはいけない）
	a = Vector2(300, 600)
	_touch(true, a)
	cur = a
	for i in 10:
		await _wait(0.05)
		var nxt := cur + Vector2(6, 0)
		_drag(cur, nxt)
		cur = nxt
	_touch(false, cur)
	await _wait(0.05)
	print("[flicktest] slow drag -> dash_t=%.2f (should be 0)" % p.dash_t)
	get_tree().quit()


## ゲームオーバー → リスタートの動線を確認する短いテスト
func _death_test() -> void:
	Game.inst.start_game()
	Game.inst._on_familiar_chosen("shiki")
	await _wait(6.0)
	print("[autoplay] forcing death (wave=%d score=%d)" % [Game.inst.wave, Game.inst.score])
	Game.inst.player.take_damage(99999.0)
	await _wait(2.5)
	await shot("90_gameover.png")
	print("[autoplay] state after death = %d (OVER=%d)" % [Game.inst.state, Game.St.OVER])

	_key(KEY_ENTER, true)
	await _wait(0.1)
	_key(KEY_ENTER, false)
	await _wait(1.0)
	if Game.inst.state == Game.St.FAMILIAR:
		Game.inst._on_familiar_chosen("neko")
	await _wait(1.0)
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


## 指定した神を全部迎え、その能力 9 種をすべて（上限を無視して）付けて 40 秒戦わせる。
## 新しい能力の実装が例外を出さないかを見るためのもの。
func _ability_test(gods: Array) -> void:
	var g := Game.inst
	if OS.get_cmdline_user_args().has("--nohdr"):
		get_viewport().use_hdr_2d = false
		print("[ability] hdr_2d OFF")
	g.start_game()
	g._on_familiar_chosen("neko")
	var p := g.player
	for kid in gods:
		var id := String(kid).strip_edges()
		if id == "":
			continue
		p.add_god(id)
		p.kami_lv[id] = 4
		for b in Kami.upgrades_of(id):
			p.boons[String(b["id"])] = {"rar": int(b.get("tier", 0)), "lv": 2}
		var leg := Kami.legendary_of(id)
		if not leg.is_empty():
			p.boons[String(leg["id"])] = {"rar": Cfg.Rar.LEGENDARY, "lv": 1}
	p.on_boons_changed()
	p.stats["max_hp"] = 9999.0
	p.hp = 9999.0
	print("[ability] gods=%s boons=%d" % [str(p.gods), p.boons.size()])
	g.wave = 5
	var t0 := _t
	var dashes := 0
	var perf_acc := {"proc": 0.0, "phys": 0.0, "n": 0, "draw": 0.0, "nodes": 0.0, "obj": 0.0}
	while _t - t0 < 40.0:
		await _wait(0.5)
		if OS.get_cmdline_user_args().has("--perf") and g.state == Game.St.PLAY:
			perf_acc["proc"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			perf_acc["phys"] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			perf_acc["draw"] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			perf_acc["nodes"] += Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
			perf_acc["obj"] += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
			perf_acc["n"] += 1
			if int((_t - t0) * 2.0) % 10 == 0:
				print("[perf] t=%.0f fps=%d proc=%.1fms phys=%.1fms draw_calls=%d objs=%d nodes=%d enemies=%d bullets=%d parts=%d" % [
					_t - t0, Engine.get_frames_per_second(),
					Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
					int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
					int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
					get_tree().get_nodes_in_group("enemy").size(), get_tree().get_nodes_in_group("ebullet").size() + get_tree().get_nodes_in_group("pbullet").size(),
					Fx.inst._parts.size()])
		if not is_instance_valid(p) or not p.alive:
			break
		p.stats["max_hp"] = 9999.0
		p.hp = 9999.0
		if g.state == Game.St.PLAY and int(_t * 2.0) % 4 == 0:
			p._try_cast()
		if g.state == Game.St.PLAY and p.dash_cool <= 0.0 and dashes < 6:
			p._start_dash(Vector2.RIGHT if dashes % 2 == 0 else Vector2.LEFT)
			dashes += 1
		if g.state == Game.St.KAMI:
			g._on_kami_chosen(String(g.ui.kami_view.ids[0]))
		elif g.state == Game.St.BOON and g.ui.relic_view.visible:
			g._on_relic_chosen(0)
		elif g.state == Game.St.BOON and not g._offers.is_empty():
			g._on_boon_chosen(0)
		elif g.state == Game.St.MIKI:
			g._on_miki_chosen(String(g.ui.miki_view.ids[0]))
	await shot("70_ability_%s%s.png" % ["_".join(PackedStringArray(gods)), "_nohdr" if OS.get_cmdline_user_args().has("--nohdr") else ""])
	if perf_acc["n"] > 0:
		var n := float(perf_acc["n"])
		print("[perf] avg proc=%.2fms phys=%.2fms draw_calls=%.0f objs=%.0f nodes=%.0f" % [perf_acc["proc"] / n, perf_acc["phys"] / n, perf_acc["draw"] / n, perf_acc["obj"] / n, perf_acc["nodes"] / n])
	print("[ability] done wave=%d score=%d cast_charges=%d orbs_on_field=%d" % [g.wave, g.score, p.cast_charges,
			get_tree().get_nodes_in_group("pickup").filter(func(x): return x.kind == Pickup.Kind.ORB).size()])
	get_tree().quit()


## 舞扇が手元に戻るかを追跡する
func _fan_test() -> void:
	_no_ai = true
	var g := Game.inst
	g.start_game()
	g._on_familiar_chosen("karasu")
	var p := g.player
	p.add_god("uzume")
	p.stats["max_hp"] = 9999.0
	p.hp = 9999.0
	await _wait(0.3)
	var t0 := _t
	var tracked: Bullet = null
	var last_state := ""
	while _t - t0 < 8.0:
		await _wait(0.1)
		if tracked == null or not is_instance_valid(tracked):
			for b in g.world.get_children():
				if b is Bullet and b.mode == "boomerang" and is_instance_valid(b):
					if tracked != null and not is_instance_valid(tracked):
						print("[fan] previous fan freed at t=%.1f" % (_t - t0))
					tracked = b
					print("[fan] new fan at t=%.1f pos=%s" % [_t - t0, str(b.position)])
					break
		if tracked != null and is_instance_valid(tracked):
			var st := "return" if tracked._returning else "out"
			var d := tracked.position.distance_to(p.position)
			if st != last_state or (tracked._returning and int((_t - t0) * 10.0) % 3 == 0):
				print("[fan] t=%.1f %s travel=%.0f dist=%.0f life=%.2f pos=%s vel=%s" % [_t - t0, st, tracked.travel, d, tracked.life, str(tracked.position.round()), str(tracked.vel.round())])
				last_state = st
	print("[fan] done")
	get_tree().quit()


## 題目の「記録を見る」を本物のクリックで押す
func _click_test() -> void:
	_no_ai = true
	var g := Game.inst
	await _wait(1.0)
	var r := g.ui.overlay.menu_rect(1)
	print("[click] state=%d overlay=%s menu_rect=%s" % [g.state, str(g.ui.overlay.visible), str(r)])
	var c := r.get_center()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = c
		ev.global_position = c
		Input.parse_input_event(ev)
		await _wait(0.1)
	await _wait(0.5)
	print("[click] after: ranking_visible=%s state=%d overlay=%s rows=%d" % [str(g.ui.ranking_view.visible), g.state, str(g.ui.overlay.visible), g.ui.ranking_view.rows.size()])
	await shot("07_click_ranking.png")
	get_tree().quit()
