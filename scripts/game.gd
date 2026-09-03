class_name Game
extends Node2D

## ゲーム全体の進行役：ウェーブ生成・状態遷移・神と恩恵の受け渡し・ヒットストップ。

enum St {TITLE, PLAY, KAMI, BOON, MIKI, PAUSE, OVER, CLEAR, FAMILIAR, STORY}
static var story_seen := false   # 開幕の物語は起動ごとに 1 回

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
var _hitstop_last := 0.0
var _kami_choices: Array = []
var _minion_t := 0.0
var _tut_step := 0
var _tut_t := 0.0
var endless := false
var best := {"score": 0, "wave": 0, "clears": 0}   # Records.best への参照
var run_id := -1                                     # 今回の走りの識別子（記録の置き換えに使う）
var run_key := ""                                    # 世界のランキング用の識別子（時刻＋乱数）
var run_start := 0.0                                 # 走りの開始時刻（秒）
var net: Net
var _relic_offers: Array = []                        # 討伐の褒賞（神宝）の候補
var _seen_items := {}                                # 初めて落ちたアイテムの案内を出したか
var resetting := false                               # やり直しで world を片付けている間（珠を落とさない）
var landscape_block := false                         # タッチ端末が横向き（縦にするまで止める）
var _freeze_t := 0.0                                 # 見せ場の停止（神招きのカットイン）
static var _en_cache: Array = []
static var _en_stamp := -1
static var _eb_cache: Array = []
static var _eb_stamp := -1


## 敵の一覧（物理フレームごとに 1 回だけ集める。毎回 get_nodes_in_group すると呼び出し元が多くて重い）
static func enemies() -> Array:
	var f := Engine.get_physics_frames()
	if _en_stamp != f:
		_en_stamp = f
		_en_cache = inst.get_tree().get_nodes_in_group("enemy").filter(func(e): return is_instance_valid(e))
	return _en_cache


static func ebullets() -> Array:
	var f := Engine.get_physics_frames()
	if _eb_stamp != f:
		_eb_stamp = f
		_eb_cache = inst.get_tree().get_nodes_in_group("ebullet").filter(func(b): return is_instance_valid(b))
	return _eb_cache

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
	# 発光の後処理は端末の解像度いっぱいで走り、スマホでは負荷の大きな部分になる。
	# 光の質感は Fx.GLOW（手描きの光輪の加算合成）で作っているので、後処理は切っておく（Cfg.GLOW_POST で切り替え）
	env.glow_enabled = Cfg.GLOW_POST
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

	net = Net.new()
	add_child(net)
	ui = Ui.new()
	add_child(ui)
	fx.font = ui.font
	fx.font_big = ui.font_display

	add_child(Touch.new())

	ui.kami_chosen.connect(_on_kami_chosen)
	ui.familiar_chosen.connect(_on_familiar_chosen)
	ui.boon_chosen.connect(_on_boon_chosen)
	ui.reroll_requested.connect(_on_reroll)
	ui.miki_chosen.connect(_on_miki_chosen)
	ui.relic_chosen.connect(_on_relic_chosen)
	ui.start_requested.connect(start_game)
	ui.restart_requested.connect(start_game)
	ui.continue_requested.connect(continue_endless)
	ui.title_requested.connect(_show_title)
	ui.name_submitted.connect(_on_name_submitted)
	ui.story_done.connect(_on_story_done)

	_load_best()
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
	# タッチ端末で横向きになったら止めて「縦にして」と促す
	var was_land := landscape_block
	landscape_block = DisplayServer.is_touchscreen_available() and size.x > size.y
	if landscape_block and not was_land and state == St.PLAY:
		toggle_pause()
	elif was_land and not landscape_block and state == St.PAUSE:
		toggle_pause()
	if aspect > base_aspect * 1.01:
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH
		Cfg.H = floorf(Cfg.W * aspect)
	else:
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		Cfg.H = Cfg.H_BASE
	# 文字をぼかさないため描画は常に等倍（content_scale_size を書き換えると size_changed が再び飛ぶので、変わるときだけ）
	var want_size := Vector2i(int(Cfg.W), int(Cfg.H))
	if win.content_scale_size != want_size:
		win.content_scale_size = want_size
	cam.position = Vector2(Cfg.W * 0.5, Cfg.H * 0.5)
	if player != null and is_instance_valid(player):
		var r := Cfg.play_rect()
		player.position.y = clampf(player.position.y, r.position.y + 60.0, r.end.y - 30.0)


## 記録の保存と読み込み（Web では IndexedDB に保存される）
func _load_best() -> void:
	Records.load_all()
	best = Records.best


## 今回の走りを記録に刻む（名前・功徳・到達・神々）。順位を結果画面に渡す
func _save_best(cleared: bool) -> void:
	var ok := player != null and is_instance_valid(player)
	var gods: Array = player.gods.duplicate() if ok else []
	var lv: int = player.level if ok else 1
	var extra := {
		"run_key": run_key,
		"kami_lv": player.kami_lv.duplicate() if ok else {},
		"relics": player.relics.duplicate() if ok else [],
		"boons": _boon_snapshot() if ok else {},
		"curses": (player.boons.keys().filter(func(id): return not Kami.curse(String(id)).is_empty())) if ok else [],
		"familiar": player.familiar_id if ok else "",
		"duration": Time.get_unix_time_from_system() - run_start,
	}
	ui.overlay.rank = Records.record(run_id, score, wave, lv, gods, cleared, endless, extra)
	best = Records.best
	_submit_global()


## 能力の一覧（id → {lv, rar}）。禍神の取引は含めない
func _boon_snapshot() -> Dictionary:
	var out := {}
	for id in player.boons.keys():
		if Kami.curse(String(id)).is_empty():
			out[String(id)] = {"lv": int(player.boons[id]["lv"]), "rar": int(player.boons[id]["rar"])}
	return out


## 世界のランキングへ送り、順位を結果画面に出す
func _submit_global() -> void:
	ui.overlay.global_rank = 0
	if net == null or not net.configured() or not net.can_submit():
		return
	ui.overlay.global_rank = -1   # 送信中
	var entry := Records.last_entry.duplicate()
	net.submit(entry, func(ok: bool):
		if not ok:
			ui.overlay.global_rank = -2
			return
		net.fetch_rank(int(entry["score"]), func(ok2: bool, rank: int):
			ui.overlay.global_rank = rank if ok2 else -2))


## 結果画面で名前が入力されたとき
func _on_name_submitted(n: String) -> void:
	Records.set_player_name(n, run_id)
	Sfx.play("suzu", -8.0)
	# 今回の記録が世界に送られていれば、名前も差し替える
	if net != null and net.configured() and not Records.last_entry.is_empty() and int(Records.last_entry.get("run", -2)) == run_id:
		Records.last_entry["name"] = Records.display_name()
		net.submit(Records.last_entry.duplicate(), func(_ok: bool): pass)


## 功徳の加算（禍神で倍率）
func add_score(n: int) -> void:
	score += n


## 踏破後に更に登る（エンドレス：祟りの参道）
func continue_endless() -> void:
	if state != St.CLEAR:
		return
	endless = true
	ui.overlay.visible = false
	state = St.PLAY
	get_tree().paused = false
	_wave_active = false
	_between = 2.0
	Music.play("stage")
	ui.banner("祟りの参道", "踏破の先へ。穢れはさらに濃くなる", Color(1, 0.5, 0.6))
	ui.cutin("dash", Color(1, 0.5, 0.6), 2.0)
	Sfx.play("taiko", -4.0, 0.8)


func _show_title() -> void:
	Music.stop()
	state = St.TITLE
	ui.overlay.mode = 0
	ui.overlay.visible = true
	ui.hide_cards()
	get_tree().paused = true


# ---------- ゲーム開始 ----------

func start_game() -> void:
	resetting = true
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
	endless = false
	run_id = int(Time.get_unix_time_from_system())
	run_key = "%d-%06d" % [run_id, randi() % 1000000]
	run_start = Time.get_unix_time_from_system()
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
	_tut_step = 0
	_tut_t = 0.0
	_seen_items.clear()
	resetting = false
	# 初回は開幕の物語を見せ、そのあと使い魔を選ぶ（時間は止まったまま）
	if not story_seen and Ui.art("cutin/opening") != null and not OS.get_cmdline_user_args().has("--capture"):
		story_seen = true
		_pause_for_choice(St.STORY)
		ui.show_story()
		return
	_pause_for_choice(St.FAMILIAR)
	ui.show_familiar_choice()


func _on_story_done() -> void:
	if state != St.STORY:
		return
	_pause_for_choice(St.FAMILIAR)
	ui.show_familiar_choice()


## アイテムが初めて落ちたとき、絵付きで何かを短く案内する
func _item_hint(kind: int) -> void:
	if _seen_items.has(kind):
		return
	_seen_items[kind] = true
	match kind:
		Pickup.Kind.XP: ui.banner("勾玉", "拾うと位が上がる", Cfg.C_XP, kind)
		Pickup.Kind.HEAL: ui.banner("団子", "拾うと HP 回復", Cfg.C_HP, kind)
		Pickup.Kind.ORB: ui.banner("詠唱の札", "拾うと詠唱を 1 回撃てる（3 枚まで）", player.kami_color(player.main_god()) if (player != null and player.main_god() != "") else Color(0.8, 0.85, 1.0), kind)


## 詠唱の札を落とす（まれなドロップ）。拾うと詠唱が 1 回撃てる
func drop_orb(pos: Vector2) -> void:
	if state == St.TITLE or player == null or not is_instance_valid(player):
		return
	var o := Pickup.new()
	var r := Cfg.play_rect()
	var p := Vector2(clampf(pos.x, r.position.x + 16.0, r.end.x - 16.0), clampf(pos.y, 40.0, r.end.y - 60.0))
	o.setup(p, Pickup.Kind.ORB, 1.0)
	spawn_deferred(o)
	_item_hint(Pickup.Kind.ORB)
	Fx.ring(p, player.kami_color(player.main_god()) if player.main_god() != "" else Color(1, 1, 1), 4.0, 26.0, 0.3, 2.0)


func _on_familiar_chosen(id: String) -> void:
	if state != St.FAMILIAR:
		return
	player.set_familiar(id)
	var f := Familiar.info(id)
	Sfx.play("suzu", -6.0)
	_close_choice()
	var touch := Touch.inst != null and Touch.inst.active
	ui.banner(String(f["name"]) + " が付いてきた", "なぞって移動、弾いて疾走" if touch else "WASD 移動　Space 疾走", f["color"])


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

	_tutorial(delta)
	_tick_freeze(delta)

	# レベルアップした瞬間に時間を止めて神との邂逅へ（敵も弾も止まる）
	#   位 2 → 主神、位 4・7 → 副神（迎えるだけで神器が付き、他の選択は続かない）
	#   それ以外 → 迎えている神の恩恵 3 択
	if player.pending_levels > 0:
		if Boons.recruit_due(player):
			_open_kami_choice()
		else:
			_open_level_pick("level")
		return

	_tick_wave(delta)


## 見せ場で世界を止める（UI だけ動く）。sec 秒後に自動で再開
func freeze_for(sec: float) -> void:
	if state != St.PLAY:
		return
	Engine.time_scale = 1.0
	_hitstop = 0.0
	_freeze_t = sec
	get_tree().paused = true


func _tick_freeze(delta: float) -> void:
	if _freeze_t <= 0.0:
		return
	# 停止中は時間倍率を 1 に固定（神招き自身のヒットストップで UI まで遅くならないように）
	if Engine.time_scale < 0.999:
		Engine.time_scale = 1.0
		_hitstop = 0.0
	_freeze_t -= delta
	if _freeze_t <= 0.0 and state == St.PLAY:
		get_tree().paused = false


## いまタッチ操作か（スマホ・タブレット）。説明文の出し分けに使う
func is_touch() -> bool:
	return Touch.inst != null and Touch.inst.active


## 序盤の導線：最初の 1 分だけ、状況に合わせて短い案内を出す
func _tutorial(delta: float) -> void:
	if _tut_step >= 3:
		return
	_tut_t += delta
	match _tut_step:
		0:
			if _tut_t > 4.0:
				_tut_step = 1
				ui.banner("穢れを祓え", "敵を倒す → 勾玉を拾う → 位が上がる", Cfg.C_XP)
		1:
			if player.xp > 0.0 or _tut_t > 14.0:
				_tut_step = 2
				_tut_t = 0.0
				ui.banner("位が上がると神が現れる", "3 柱から主神を選ぶ", Cfg.C_GOLD)
		2:
			# 詠唱・神招きの案内は主神を迎えてから
			if not player.gods.is_empty():
				_tut_t += delta
				if _tut_t > 4.0:
					_tut_step = 3
					if is_touch():
						ui.banner("右下の札", "詠唱：札を拾うと撃てる　　神招き：ゲージ 1/4 で", Color(0.9, 0.9, 1.0))
					else:
						ui.banner("Z 詠唱　X 神招き", "詠唱は札を拾うと撃てる　　神招きはゲージ 1/4 で", Color(0.9, 0.9, 1.0))
			else:
				_tut_t = 0.0


## ヒットストップ：dur 秒（実時間）だけ時間の流れを scale に落とす。
## 小さな止めは連続しすぎるとリズムが崩れるので間引く
func hitstop(dur: float, scale := 0.05) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if dur < 0.07 and now - _hitstop_last < 0.22:
		return
	_hitstop_last = now
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

	if _plan_i >= _plan.size() and Game.enemies().is_empty():
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
		ui.boss_intro(b.boss_name, b.title_text(), b.is_final, ["aratama", "dodomeki", "orochi"][mini(b.tier - 1, 2)])
		if b.is_final:
			Music.play("lastboss")
			Fx.flash(Color(1, 0.2, 0.3, 0.4), 0.6)
			Sfx.play("taiko", 0.0, 0.55)
			Sfx.play("flute", -6.0, 0.7)
		else:
			Music.play("boss")
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
		if player.has_relic("r_heal_wave"):
			player.heal(float(player.stats["max_hp"]) * 0.08, true)
		add_score(50 * wave)
	if _boss_reward:
		_boss_reward = false
		_open_relics()
		return
	ui.banner("第 %d 波　祓い清め" % wave, "功徳 +%d　HP +6" % (50 * wave), Cfg.C_HP)
	Sfx.play("suzu", -10.0)


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

	# 敵の総量。後半の増え方は緩やかに（数より個々の強さで難度を出す）
	var budget := (8.0 + float(w) * 2.2 + float(w * w) * 0.06) * 0.9
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
		col := Cfg.C_EBULLET, homing := 0.0, source := "敵の弾") -> void:
	var b := Bullet.new()
	b.radius = radius
	b.color = col
	b.shape_kind = 7
	b.trail_len = 10.0
	b.homing = homing
	b.source = source
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
	for b in Game.ebullets():
		if is_instance_valid(b) and b.position.distance_to(pos) <= r:
			b.vanish()


func erase_all_ebullets() -> void:
	for b in Game.ebullets():
		if is_instance_valid(b):
			b.vanish()


func on_enemy_killed(e: Enemy) -> void:
	kills += 1
	add_score(e.score)
	var xp_mult := 1.0
	if player != null and is_instance_valid(player) and player.has("susa_p3"):
		xp_mult += player.val("susa_p3") * 0.01
	_drop(e.position, e.xp * xp_mult)
	if player == null or not is_instance_valid(player) or not player.alive:
		return
	Combat.on_kill(e)


func on_boss_killed(b: Boss) -> void:
	kills += 1
	add_score(b.score)
	boss = null
	if b.is_final and not endless:
		add_score(5000)
		Music.stop()
		hitstop(1.2, 0.1)
		_on_cleared()
		return
	_boss_reward = true
	Music.play("stage")
	hitstop(0.9, 0.12)
	Fx.flash(Color(1, 1, 1, 0.6), 0.5)
	ui.banner("討伐", b.boss_name + "　+%d" % b.score, Color(1, 0.85, 0.4))
	for i in 10:
		_drop(b.position + Vector2(randf_range(-70, 70), randf_range(-70, 70)), b.xp / 10.0)
	for i in 2:
		var p := Pickup.new()
		p.setup(b.position + Vector2(randf_range(-50, 50), 0), Pickup.Kind.HEAL, 18.0)
		spawn_deferred(p)
	drop_orb(b.position)   # 大妖は必ず札を 1 枚落とす



func _drop(pos: Vector2, xp_total: float) -> void:
	# 勾玉は敵弾と紛れないよう数を絞る：確率で 1 個だけ落とし、価値をまとめる
	var chance := clampf(0.30 + xp_total * 0.03, 0.3, 0.8)
	if randf() < chance:
		var p := Pickup.new()
		p.setup(pos + Vector2(randf_range(-6, 6), randf_range(-6, 6)), Pickup.Kind.XP, xp_total / chance * 0.75)
		spawn_deferred(p)
		_item_hint(Pickup.Kind.XP)
	# 詠唱の札：まれに落ちる（建御雷の代償で落ちにくく、神宝で落ちやすく）
	if player != null and is_instance_valid(player) and player.main_god() != "":
		var oc := Cfg.TALISMAN_DROP * player.cost_mult("orb") * (2.0 if player.has_relic("r_talisman_luck") else 1.0)
		if randf() < oc:
			drop_orb(pos)
	# 油揚げの供物（稲荷）：余分な勾玉
	if player != null and is_instance_valid(player) and player.has("inari_u8") and randf() < player.val("inari_u8") * 0.01:
		var extra := Pickup.new()
		extra.setup(pos + Vector2(randf_range(-14, 14), randf_range(-8, 8)), Pickup.Kind.XP, xp_total * 0.6)
		spawn_deferred(extra)
	if randf() < (0.09 if (player != null and is_instance_valid(player) and player.has_relic("r_heal_drop")) else 0.045):
		var h := Pickup.new()
		h.setup(pos, Pickup.Kind.HEAL, 12.0)
		spawn_deferred(h)
		_item_hint(Pickup.Kind.HEAL)


# ---------- 神と恩恵 ----------

func _pause_for_choice(new_state: int) -> void:
	state = new_state
	get_tree().paused = true
	Engine.time_scale = 1.0
	_hitstop = 0.0
	ui.hud.banner_t = 0.0   # 選択画面とバナーが重ならないように


## 神を迎える（位 2 で主神、位 4・7 で副神）。迎えること自体が報酬で、他の選択は続かない
func _open_kami_choice() -> void:
	_pause_for_choice(St.KAMI)
	_kami_choices = Boons.roll_kami_choices(player, 3)
	Sfx.play("descend", -6.0)
	ui.show_kami_choice(_kami_choices, "主神" if player.gods.is_empty() else "副神")


func _on_kami_chosen(id: String) -> void:
	if state != St.KAMI:
		return
	var main := player.gods.is_empty()
	player.add_god(id)
	Sfx.play("descend", -4.0, 1.2 if main else 1.3)
	Fx.flash(Cfg.with_a(Kami.kami(id)["color"], 0.5 if main else 0.4), 0.5)
	var k := Kami.kami(id)
	if main:
		ui.banner(String(k["weapon"]) + " を授かった", String(k["weapon_desc"]), k["color"])
	else:
		ui.banner(String(k["name"]) + " が副神となった", String(k["weapon"]) + " が加わった", k["color"])
	player.pending_levels = maxi(0, player.pending_levels - 1)
	_close_choice()


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
		return
	_offer_kami = kid
	_offers = Boons.offer(player, kid, 3, min_rar)
	if _offers.is_empty():
		player.pending_levels = maxi(0, player.pending_levels - 1)
		_close_choice()
		return
	Sfx.play("levelup", -8.0)
	var title := "神との邂逅"
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
	var b: Dictionary = o["boon"]
	var col: Color = Cfg.RAR_COLOR[int(o["rar"])]
	if String(o["type"]) == "curse":
		ui.banner(String(b["name"]), String(b.get("desc", "")), Color(1, 0.4, 0.5))
		Sfx.play("doom", -8.0, 0.8)
	else:
		ui.banner(String(b["name"]), Kami.describe(b, int(player.boons[b["id"]]["rar"]), int(player.boons[b["id"]]["lv"])), col)
		Sfx.play("suzu", -6.0)
	if _offer_reason == "level":
		player.pending_levels = maxi(0, player.pending_levels - 1)
	_close_choice()


## レベルアップ：強化する神を自分で選ぶ → その神の神格が 1 上がり → その神の能力 3 枚を抽選
func _open_level_pick(_reason: String) -> void:
	if player.gods.size() <= 1:
		# 1 柱しかいなければ選ぶ余地がないので、そのまま神格を上げて抽選へ
		_level_pick_done(player.main_god())
		return
	_pause_for_choice(St.MIKI)
	Sfx.play("levelup", -8.0)
	ui.show_miki(player.gods.duplicate())


func _level_pick_done(id: String) -> void:
	if id != "" and int(player.kami_lv.get(id, 1)) < 10:
		Boons.miki_apply(player, id)
	_open_boons("level", Cfg.Rar.COMMON, id)


func _on_miki_chosen(id: String) -> void:
	if state != St.MIKI:
		return
	Sfx.play("suzu", -8.0, 1.2)
	_level_pick_done(id)


## 討伐の褒賞：神宝を 3 つから 1 つ選ぶ
func _open_relics() -> void:
	_relic_offers = Relics.offer(player, 3)
	if _relic_offers.is_empty():
		player.heal(float(player.stats["max_hp"]) * 0.5, true)
		ui.banner("討伐の褒賞", "HP を回復した", Cfg.C_GOLD)
		return
	_pause_for_choice(St.BOON)
	Sfx.play("levelup", -6.0, 0.9)
	ui.show_relics(_relic_offers)


func _on_relic_chosen(idx: int) -> void:
	if state != St.BOON or idx < 0 or idx >= _relic_offers.size():
		return
	var r: Dictionary = _relic_offers[idx]
	player.relics.append(String(r["id"]))
	player.on_boons_changed()
	ui.banner(String(r["name"]), String(r["desc"]), Cfg.C_GOLD)
	Sfx.play("levelup", -4.0, 1.1)
	Fx.flash(Cfg.with_a(Cfg.C_GOLD, 0.35), 0.4)
	_relic_offers = []
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
	_save_best(true)
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
	_save_best(false)
	ui.overlay.mode = 1
	var god_names := []
	for g in player.gods:
		god_names.append(String(Kami.kami(g)["name"]))
	var total := 0.0
	for k in player.kami_dmg.keys():
		total += float(player.kami_dmg[k])
	var best := ""
	var best_v := 0.0
	for k in player.kami_dmg.keys():
		if float(player.kami_dmg[k]) > best_v:
			best_v = float(player.kami_dmg[k])
			best = String(k)
	var mvp := "なし"
	if best != "" and total > 0.0:
		mvp = "%s（%d%%）" % [String(Kami.kami(best)["weapon"]), int(round(best_v / total * 100.0))]
	ui.overlay.stats_lines = [
		["到達", "第%sの段　第 %d 波" % [Cfg.STAGE_KANJI[Cfg.stage_of(maxi(wave, 1)) - 1], wave]],
		["功徳", str(score)],
		["討たれた相手", player.last_hit_by if player.last_hit_by != "" else "不明"],
		["最も働いた神器", mvp],
		["神々", "・".join(god_names) if not god_names.is_empty() else "なし"],
	]
	ui.overlay.tip = _death_tip()
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


## 次に試すことの一言
func _death_tip() -> String:
	if player.gods.is_empty():
		return "神を迎える前に倒れた。勾玉を優先して拾い、位を上げよう"
	if player.gods.size() < 3:
		return "副神の枠が空いていた。位 4 と位 7 で副神を迎えると神器が増え、火力が伸びる"
	if player.last_hit_by.ends_with("体当たり"):
		return "体当たりで倒れた。疾走（短くなぞる／Space）の無敵で抜けよう"
	return "神格は神器を当てるほど上がる。主神の神器が当たる位置取りを意識しよう"


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
		if ui.ranking_view.visible:
			ui.ranking_view.close()
			return
		if ui.confirm_view.visible:
			return   # 確認画面の「考え直す」に使う
		if state == St.TITLE:
			get_tree().quit()
		else:
			_show_title()
