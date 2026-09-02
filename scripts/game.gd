class_name Game
extends Node2D

## ゲーム全体の進行役：ウェーブ生成・状態遷移・神と恩恵の受け渡し・ヒットストップ。

enum St {TITLE, PLAY, KAMI, BOON, MIKI, PAUSE, OVER, CLEAR}

static var inst: Game
static var enemy_bullet_slow := 0.0
static var enemy_slow := 1.0       # 敵の動きの倍率（大導きで遅くなる）

var state := St.TITLE
var wave := 0
var score := 0
var kills := 0

var world: Node2D
var stars: Starfield
var fx: Fx
var sfx: Sfx
var ui: Ui
var cam: Camera2D
var player: Player
var boss: Boss

var _plan: Array = []
var _plan_i := 0
var _wave_t := 0.0
var _wave_active := false
var _between := 0.0
var _boss_reward := false
var _offer_kami := ""
var _offers: Array = []
var _offer_min_rar := 0
var _offer_reason := "level"
var _rerolls := 0
var _hitstop := 0.0
var _kami_choices: Array = []
var _minion_t := 0.0

const COST := {"grunt": 1.0, "weaver": 1.4, "charger": 1.8, "turret": 2.4, "splitter": 2.6,
	"spirit": 0.5, "lantern": 2.0, "kite": 1.2, "oni": 3.6, "caster": 3.0, "bomber": 1.5}
## 敵の解禁ウェーブ
const UNLOCK := {"grunt": 1, "spirit": 2, "weaver": 2, "charger": 3, "lantern": 4, "kite": 5,
	"turret": 6, "oni": 7, "splitter": 8, "caster": 9, "bomber": 11}


func _ready() -> void:
	inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()

	# 2D グロー（ネオン感の要）。Compatibility レンダラ（Web）でも動くよう、
	# 使えるプロパティだけを設定し、閾値は 1.0 未満にしておく。
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.82
	env.glow_hdr_scale = 2.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	cam = Camera2D.new()
	cam.ignore_rotation = true
	add_child(cam)
	cam.make_current()
	_fit_viewport()
	get_tree().root.size_changed.connect(_fit_viewport)

	# Game は PROCESS_MODE_ALWAYS なので、子はそのまま継承すると選択画面中も動いてしまう。
	# 敵・弾・自機・背景は明示的にポーズ対象にする（UI・エフェクト・BGM だけ動き続ける）。
	stars = Starfield.new()
	stars.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(stars)

	world = Node2D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)

	fx = Fx.new()
	add_child(fx)

	sfx = Sfx.new()
	add_child(sfx)
	add_child(Music.new())

	ui = Ui.new()
	add_child(ui)
	fx.font = ui.font
	fx.font_big = ui.font_display

	add_child(Touch.new())

	ui.kami_chosen.connect(_on_kami_chosen)
	ui.boon_chosen.connect(_on_boon_chosen)
	ui.reroll_requested.connect(_on_reroll)
	ui.miki_chosen.connect(_on_miki_chosen)
	ui.start_requested.connect(start_game)
	ui.restart_requested.connect(start_game)

	_show_title()

	# 開発用：`godot -- --capture` で自動プレイ＆スクリーンショット
	if OS.get_cmdline_user_args().has("--capture"):
		add_child(Autoplay.new())


## 画面の縦横比に合わせて表示領域を決める。
## 基準（640×960）より縦長の画面（スマホ）では、横幅を合わせて高さを伸ばし、黒帯をなくす。
func _fit_viewport() -> void:
	var win := get_tree().root
	var size := Vector2(win.size)
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var aspect := size.y / size.x
	var base_aspect := Cfg.H_BASE / Cfg.W
	if aspect > base_aspect * 1.01:
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH
		Cfg.H = floorf(Cfg.W * aspect)
	else:
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		Cfg.H = Cfg.H_BASE
	cam.position = Vector2(Cfg.W * 0.5, Cfg.H * 0.5)
	if player != null and is_instance_valid(player):
		var r := Cfg.play_rect()
		player.position.y = clampf(player.position.y, r.position.y + 60.0, r.end.y - 30.0)


func _show_title() -> void:
	Music.stop()
	state = St.TITLE
	ui.overlay.mode = 0
	ui.overlay.visible = true
	ui.hide_cards()
	get_tree().paused = true


# ---------- ゲーム開始 ----------

func start_game() -> void:
	for c in world.get_children():
		c.queue_free()
	Fx.clear_all()
	enemy_bullet_slow = 0.0
	enemy_slow = 1.0
	boss = null
	wave = 0
	score = 0
	kills = 0
	_plan.clear()
	_plan_i = 0
	_wave_active = false
	_between = 1.2
	_boss_reward = false
	_hitstop = 0.0
	Engine.time_scale = 1.0
	stars.tint = Color(0.45, 0.30, 0.80)

	player = Player.new()
	player.position = Vector2(Cfg.W * 0.5, Cfg.H - 190.0)
	world.add_child(player)
	player.died.connect(_on_player_died)
	player.leveled_up.connect(_on_leveled_up)

	ui.overlay.visible = false
	ui.hide_cards()
	Music.play("stage")
	ui.banner("参道を進め", "穢れを祓い、勾玉を集めよ。波を祓うと神が現れる", Cfg.C_PLAYER)
	state = St.PLAY
	get_tree().paused = false


# ---------- メインループ ----------

func _process(delta: float) -> void:
	# 画面シェイク
	var s := fx.shake
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * s

	if _hitstop > 0.0:
		_hitstop -= delta / maxf(Engine.time_scale, 0.01)
		if _hitstop <= 0.0:
			Engine.time_scale = 1.0

	if state != St.PLAY:
		return

	stars.speed = 1.0 + float(wave) * 0.04

	if player == null or not is_instance_valid(player) or not player.alive:
		return

	# レベルアップした瞬間に時間を止めて神との邂逅へ（敵も弾も止まる）
	if player.pending_levels > 0:
		if player.gods.is_empty():
			_open_kami_choice()
		else:
			_open_boons("level", Cfg.Rar.COMMON, "")
		return

	_tick_wave(delta)


## ヒットストップ：dur 秒（実時間）だけ時間の流れを scale に落とす
func hitstop(dur: float, scale := 0.05) -> void:
	if dur <= _hitstop:
		return
	_hitstop = dur
	Engine.time_scale = scale


func _tick_wave(delta: float) -> void:
	if not _wave_active:
		_between -= delta
		if _between <= 0.0:
			_start_wave()
		return

	_wave_t += delta
	while _plan_i < _plan.size() and float(_plan[_plan_i]["t"]) <= _wave_t:
		var e: Dictionary = _plan[_plan_i]
		_plan_i += 1
		var en := Enemy.new()
		en.setup(String(e["kind"]), wave)
		en.position = Vector2(float(e["x"]), float(e["y"]))
		world.add_child(en)

	# ボス戦中は雑魚の増援が周期的に出る
	if boss != null and is_instance_valid(boss) and not boss.entering:
		_minion_t -= delta
		if _minion_t <= 0.0:
			_minion_t = maxf(3.0, 6.5 - float(boss.tier) * 1.0 - (1.0 if boss.is_final else 0.0))
			var kinds := ["grunt", "weaver", "spirit"]
			if boss.tier >= 2: kinds.append_array(["charger", "kite"])
			if boss.tier >= 3: kinds.append_array(["splitter", "bomber"])
			var n := 2 + boss.tier
			for i in n:
				var en2 := Enemy.new()
				en2.setup(kinds[randi() % kinds.size()], wave)
				en2.position = Vector2(Cfg.W * (float(i + 1) / float(n + 1)), -46.0 - float(i) * 20.0)
				world.add_child(en2)
			Sfx.play("warn", -18.0, 1.5, 0.5)

	if _plan_i >= _plan.size() and get_tree().get_nodes_in_group("enemy").is_empty():
		_clear_wave()


func _start_wave() -> void:
	wave += 1
	_wave_t = 0.0
	_plan_i = 0
	_wave_active = true
	var st := Cfg.stage_of(wave)
	stars.stage = st

	if Cfg.is_boss_wave(wave):
		_plan.clear()
		var b := Boss.new()
		b.setup_boss(wave)
		world.add_child(b)
		boss = b
		_minion_t = 5.0
		if b.is_final:
			Music.play("lastboss")
			ui.banner("大禍、顕現", b.boss_name + "　奥宮の主", Color(1, 0.3, 0.35))
			Fx.flash(Color(1, 0.2, 0.3, 0.4), 0.6)
			Sfx.play("taiko", 0.0, 0.55)
			Sfx.play("flute", -6.0, 0.7)
		else:
			Music.play("boss")
			ui.banner("大妖、来たる", b.boss_name, Color(1, 0.35, 0.4))
			Sfx.play("taiko", -2.0, 0.7)
		Sfx.play("warn", -6.0)
		Fx.shake_add(6.0)
	else:
		_plan = _build_wave(wave)
		if (wave - 1) % Cfg.STAGE_LEN == 0:
			ui.banner("第%sの段　%s" % [Cfg.STAGE_KANJI[st - 1], Cfg.STAGE_NAME[st - 1]], "第 %d 波" % wave, Cfg.C_GOLD)
			Sfx.play("taiko", -8.0, 1.0)
			Sfx.play("suzu", -10.0)
		else:
			ui.banner("第 %d 波" % wave, "", Color(0.85, 0.8, 1.0))
			Sfx.play("clap", -10.0)


func _on_leveled_up() -> void:
	if player == null or not is_instance_valid(player):
		return
	Sfx.play("suzu", -10.0, 1.2)
	Fx.ring(player.position, Cfg.C_GOLD, 10.0, 120.0, 0.5, 4.0)
	Fx.flash(Cfg.with_a(Cfg.C_GOLD, 0.25), 0.3)


func _clear_wave() -> void:
	_wave_active = false
	_between = 1.5
	if player != null and is_instance_valid(player):
		player.heal(6.0, true)
		player.add_xp(8.0 + float(wave) * 2.5)   # 取りこぼしても必ず成長できるよう保証
		score += 50 * wave
	if _boss_reward:
		_boss_reward = false
		_open_boons("boss", Cfg.Rar.EPIC, player.main_god())
		return
	ui.banner("祓い清め", "+%d" % (50 * wave), Cfg.C_HP)
	Sfx.play("suzu", -10.0)
	# 3 波ごとに神酒が降りてくる
	if wave % 3 == 0 and not player.boons.is_empty():
		var m := Pickup.new()
		m.setup(Vector2(Cfg.W * 0.5, 80.0), Pickup.Kind.MIKI, 0.0)
		spawn_deferred(m)


func _build_wave(w: int) -> Array:
	# 解禁済みの敵から毎回 3〜4 種を選び、順番に混ぜて単調にならないようにする
	var avail: Array = []
	for k in UNLOCK.keys():
		if w >= int(UNLOCK[k]):
			avail.append(k)
	avail.shuffle()
	var kinds: Array = avail.slice(0, mini(avail.size(), 3 + (1 if w >= 6 else 0)))
	if w >= 3 and not kinds.has("grunt") and randf() < 0.5:
		kinds.append("grunt")
	var ki := 0

	var budget := 8.0 + float(w) * 3.0 + float(w * w) * 0.12
	var out: Array = []
	var tt := 0.7
	var pace := clampf(1.0 - float(w) * 0.02, 0.55, 1.0)   # 後半は間隔が詰まる
	var guard := 0
	while budget > 0.0 and guard < 80:
		guard += 1
		var k: String = kinds[ki % kinds.size()]
		ki += 1
		var n := randi_range(3, 5)
		match k:
			"turret", "splitter", "oni": n = randi_range(1, 2)
			"charger", "lantern", "caster": n = randi_range(2, 3)
			"spirit": n = randi_range(5, 7)
			"kite", "bomber": n = randi_range(3, 4)
		var pattern := randi() % 4
		var side := 1.0 if randf() < 0.5 else -1.0
		for i in n:
			var x := 0.0
			var y := -46.0
			if k == "kite":
				# 凧は横から入ってくる
				x = -40.0 if side > 0.0 else Cfg.W + 40.0
				y = randf_range(40.0, 220.0)
				out.append({"kind": k, "x": x, "y": y, "t": tt})
				tt += 0.25 * pace
				budget -= float(COST[k])
				continue
			match pattern:
				0: # 横一列
					x = Cfg.W * (float(i + 1) / float(n + 1))
				1: # V字
					x = Cfg.W * 0.5 + (float(i) - float(n - 1) * 0.5) * 66.0
					y -= absf(float(i) - float(n - 1) * 0.5) * 42.0
				2: # 縦の列（片側から蛇行）
					x = Cfg.W * 0.5 + side * 180.0
					y -= float(i) * 46.0
				_: # ばらまき
					x = randf_range(60.0, Cfg.W - 60.0)
			out.append({"kind": k, "x": clampf(x, 44.0, Cfg.W - 44.0), "y": y, "t": tt})
			tt += 0.2 * pace
			budget -= float(COST[k])
		tt += randf_range(0.6, 1.1) * pace
	out.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	return out


# ---------- 弾・撃破のコールバック ----------

## 当たり判定を持つノードは、シグナル処理中でも安全なように必ず遅延追加する。
func spawn_deferred(n: Node) -> void:
	world.add_child.call_deferred(n)


func spawn_ebullet(pos: Vector2, vel: Vector2, dmg: float, radius := 5.0,
		col := Cfg.C_EBULLET, homing := 0.0) -> void:
	var b := Bullet.new()
	b.radius = radius
	b.color = col
	b.shape_kind = 7
	b.trail_len = 10.0
	b.homing = homing
	b.setup(pos, vel, dmg, false)
	world.add_child(b)


## 魅了された敵が撃つ弾（自機側の弾として飛ぶ）
func spawn_charmed_bullet(pos: Vector2, vel: Vector2, dmg: float) -> void:
	var b := Bullet.new()
	b.radius = 5.0
	b.color = Color(1.0, 0.55, 0.8)
	b.charmed = true
	b.slot = Cfg.Slot.PASSIVE
	b.kami = ""
	b.tag = "charm"
	b.trail_len = 12.0
	b.setup(pos, vel, dmg, true)
	world.add_child(b)


func erase_ebullets_near(pos: Vector2, r: float) -> void:
	for b in get_tree().get_nodes_in_group("ebullet"):
		if is_instance_valid(b) and b.position.distance_to(pos) <= r:
			b.vanish()


func erase_all_ebullets() -> void:
	for b in get_tree().get_nodes_in_group("ebullet"):
		if is_instance_valid(b):
			b.vanish()


func on_enemy_killed(e: Enemy) -> void:
	kills += 1
	score += e.score
	var xp_mult := 1.0
	if player != null and is_instance_valid(player) and player.has("susa_p3"):
		xp_mult += player.val("susa_p3") * 0.01
	_drop(e.position, e.xp * xp_mult)
	if player == null or not is_instance_valid(player) or not player.alive:
		return
	Combat.on_kill(e)


func on_boss_killed(b: Boss) -> void:
	kills += 1
	score += b.score
	boss = null
	if b.is_final:
		score += 5000
		Music.stop()
		hitstop(1.2, 0.1)
		_on_cleared()
		return
	_boss_reward = true
	Music.play("stage")
	hitstop(0.6, 0.15)
	for i in 10:
		_drop(b.position + Vector2(randf_range(-70, 70), randf_range(-70, 70)), b.xp / 10.0)
	for i in 2:
		var p := Pickup.new()
		p.setup(b.position + Vector2(randf_range(-50, 50), 0), Pickup.Kind.HEAL, 18.0)
		spawn_deferred(p)
	var m := Pickup.new()
	m.setup(b.position, Pickup.Kind.MIKI, 0.0)
	spawn_deferred(m)
	ui.banner("大妖、討伐", "+%d" % b.score, Color(1, 0.85, 0.4))


func _drop(pos: Vector2, xp_total: float) -> void:
	# 勾玉は敵弾と紛れないよう数を絞る：確率で 1 個だけ落とし、価値をまとめる
	var chance := clampf(0.30 + xp_total * 0.03, 0.3, 0.8)
	if randf() < chance:
		var p := Pickup.new()
		p.setup(pos + Vector2(randf_range(-6, 6), randf_range(-6, 6)), Pickup.Kind.XP, xp_total / chance * 0.75)
		spawn_deferred(p)
	if randf() < 0.045:
		var h := Pickup.new()
		h.setup(pos, Pickup.Kind.HEAL, 12.0)
		spawn_deferred(h)


# ---------- 神と恩恵 ----------

func _pause_for_choice(new_state: int) -> void:
	state = new_state
	get_tree().paused = true
	Engine.time_scale = 1.0
	_hitstop = 0.0
	ui.hud.banner_t = 0.0   # 選択画面とバナーが重ならないように


## 主神の選択（最初のレベルアップ）
func _open_kami_choice() -> void:
	_pause_for_choice(St.KAMI)
	_kami_choices = Boons.roll_kami_choices(3)
	Sfx.play("descend", -6.0)
	ui.show_kami_choice(_kami_choices)


func _on_kami_chosen(id: String) -> void:
	if state != St.KAMI:
		return
	player.add_god(id)
	Sfx.play("descend", -4.0, 1.2)
	Fx.flash(Cfg.with_a(Kami.kami(id)["color"], 0.5), 0.5)
	var k := Kami.kami(id)
	ui.banner(String(k["weapon"]) + " を授かった", String(k["weapon_desc"]), k["color"])
	# 主神はすぐに神器の強化も授ける（稀以上）
	_open_boons("main", Cfg.Rar.RARE, id)


## 恩恵の提示。kami_id を省略すると抽選で神を決める
func _open_boons(reason: String, min_rar: int, kami_id: String) -> void:
	_pause_for_choice(St.BOON)
	_offer_reason = reason
	_offer_min_rar = min_rar
	_rerolls = 1
	var kid := kami_id
	if kid == "":
		kid = Boons.pick_kami(player)
	if kid == "":
		# すべて取得済み：神酒で代替
		player.pending_levels = maxi(0, player.pending_levels - 1)
		_close_choice()
		on_miki_picked()
		return
	_offer_kami = kid
	_offers = Boons.offer(player, kid, 3, min_rar)
	if _offers.is_empty():
		player.pending_levels = maxi(0, player.pending_levels - 1)
		_close_choice()
		on_miki_picked()
		return
	Sfx.play("levelup", -8.0)
	var title := "神との邂逅"
	match reason:
		"main": title = "主神の恩恵"
		"boss": title = "討伐の褒賞"
	ui.show_boons(kid, _offers, _rerolls, title)


func _on_reroll() -> void:
	if state != St.BOON or _rerolls <= 0:
		return
	_rerolls -= 1
	Sfx.play("clap", -6.0)
	_offers = Boons.offer(player, _offer_kami, 3, _offer_min_rar)
	ui.show_boons(_offer_kami, _offers, _rerolls, ui.boons_view.title)


func _on_boon_chosen(idx: int) -> void:
	if state != St.BOON or idx < 0 or idx >= _offers.size():
		return
	var o: Dictionary = _offers[idx]
	Boons.take(player, o)
	if String(o["type"]) == "recruit":
		var k := Kami.kami(String(o["kami"]))
		ui.banner(String(k["name"]) + " が副神となった", String(k["weapon"]) + "（半分の威力）が加わった", k["color"])
		Sfx.play("descend", -6.0, 1.3)
		Fx.flash(Cfg.with_a(k["color"], 0.4), 0.4)
	else:
		var b: Dictionary = o["boon"]
		var col: Color = Cfg.RAR_COLOR[int(o["rar"])]
		ui.banner(String(b["name"]), Kami.describe(b, int(player.boons[b["id"]]["rar"]), int(player.boons[b["id"]]["lv"])), col)
		Sfx.play("suzu", -6.0)
	if _offer_reason in ["level", "main"]:
		player.pending_levels = maxi(0, player.pending_levels - 1)
	_close_choice()


func on_miki_picked() -> void:
	if state != St.PLAY:
		return
	var targets := Boons.miki_targets(player)
	if targets.is_empty():
		player.heal(30.0, true)
		ui.banner("神酒", "神格を上げられる神がいないので HP を回復した", Cfg.C_GOLD)
		return
	_pause_for_choice(St.MIKI)
	Sfx.play("miki", -4.0)
	ui.show_miki(targets)


func _on_miki_chosen(id: String) -> void:
	if state != St.MIKI:
		return
	Boons.miki_apply(player, id)
	Sfx.play("miki", -4.0, 1.1)
	_close_choice()


func _close_choice() -> void:
	ui.hide_cards()
	state = St.PLAY
	get_tree().paused = false


# ---------- 状態 ----------

## 踏破：ラスボス撃破
func _on_cleared() -> void:
	state = St.CLEAR
	_wave_active = false
	Fx.flash(Color(1, 1, 1, 0.8), 1.0)
	Sfx.play("flute", 0.0)
	Sfx.play("suzu", -4.0)
	Sfx.play("levelup", -4.0)
	ui.overlay.mode = 2
	var god_names := []
	for g in player.gods:
		god_names.append(String(Kami.kami(g)["name"]))
	ui.overlay.stats_lines = [
		["功徳", str(score)],
		["位", "Lv.%d" % player.level],
		["討伐", str(kills)],
		["神々", "・".join(god_names) if not god_names.is_empty() else "なし"],
		["神格", "・".join(player.gods.map(func(g): return "Lv.%d" % int(player.kami_lv.get(g, 1)))) if not player.gods.is_empty() else "なし"],
	]
	ui.hide_cards()
	await get_tree().create_timer(2.4, true, false, true).timeout
	if state != St.CLEAR:
		return
	ui.overlay.visible = true
	get_tree().paused = true


func _on_player_died() -> void:
	Music.stop()
	state = St.OVER
	ui.overlay.mode = 1
	var god_names := []
	for g in player.gods:
		god_names.append(String(Kami.kami(g)["name"]))
	ui.overlay.stats_lines = [
		["到達", "第 %d 波" % wave],
		["功徳", str(score)],
		["位", "Lv.%d" % player.level],
		["討伐", str(kills)],
		["神々", "・".join(god_names) if not god_names.is_empty() else "なし"],
		["神格", "・".join(player.gods.map(func(g): return "Lv.%d" % int(player.kami_lv.get(g, 1)))) if not player.gods.is_empty() else "なし"],
		["恩恵", str(player.boons.size())],
	]
	ui.hide_cards()
	await get_tree().create_timer(1.3, true, false, true).timeout
	ui.overlay.visible = true
	get_tree().paused = true


func toggle_pause() -> void:
	if state == St.PLAY:
		state = St.PAUSE
		get_tree().paused = true
	elif state == St.PAUSE:
		state = St.PLAY
		get_tree().paused = false


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k := (e as InputEventKey).keycode
	if k == KEY_M:
		if sfx != null:
			sfx.muted = not sfx.muted
			Music.set_muted(sfx.muted)
			ui.banner("音 " + ("OFF" if sfx.muted else "ON"), "", Color(0.8, 0.9, 1.0))
	elif k == KEY_P:
		toggle_pause()
	elif k == KEY_ESCAPE:
		if state == St.TITLE:
			get_tree().quit()
		else:
			_show_title()
