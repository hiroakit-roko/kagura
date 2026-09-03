class_name Weapon
extends Node2D

## 神器：神を迎えると自機に付く、自動で発射される武器。神ごとに挙動がまったく違う。
## 威力は Player.kami_power(kami)（主神 1.0 / 副神 0.5 × 神格レベル）で決まる。
##
##   ama   日輪光線  正面へ伸び続ける光線。触れた敵すべてに毎 0.1 秒ダメージ（貫通）
##   susa  荒波      前方へ短距離の大波。高威力、押し戻し
##   take  神鳴り    一定間隔で画面内の敵に落雷、連鎖
##   tsuki 月輪      自機を回る三日月の刃。触れた敵に宿命
##   uzume 舞扇      往復する扇。貫通、敵弾を消す、弱体
##   inari 狐火      追尾する狐火を連発
##   suku  酒霧の瓢  瓢箪を投げて酒気の霧（酩酊の領域）を作る
##   iza   氷柱      3 方向へ氷柱。冷気
##   saru  神風の刃  小さな刃を高速連射

var kami := ""
var p: Player
var col := Color(1, 1, 1)
var col2 := Color(1, 1, 1)
var cd := 0.0
var t := 0.0
var _blade_hit := {}      # 月輪：敵ごとの次に当たる時刻
var _beam_tick := 0.0
var _beam_hits := 0
var _eclipse_t := 0.0
var _fans: Array = []      # 舞扇：飛んでいる扇（Bullet）
var _alt := 0
var _focus := {}           # 天照：敵ごとに光線を当て続けた秒数（暁の熱）
var _flare_t := 0.0        # 天照：陽炎の閃きまでの秒数
var flare_fx := 0.0        # 天照：閃きの余光（描画用）
var _spin := 0.0           # 月読：刃の回転角


func setup(kami_id: String, player: Player) -> void:
	kami = kami_id
	p = player
	var k := Kami.kami(kami_id)
	col = k["color"]
	col2 = k["color2"]
	z_index = Cfg.Z_PBULLET
	name = "Weapon_" + kami_id


func power() -> float:
	return p.kami_power(kami)


func base_dmg() -> float:
	return p.base_damage()


func _physics_process(delta: float) -> void:
	if p == null or not is_instance_valid(p) or not p.alive:
		return
	t += delta
	cd -= delta
	match kami:
		"ama": _beam(delta)
		"susa": _wave()
		"take": _lightning()
		"tsuki": _blades(delta)
		"uzume": _fan()
		"inari": _foxfire()
		"suku": _gourd()
		"iza": _shards()
		"saru": _wind()
	queue_redraw()


func _rate(mult: float) -> float:
	return mult / p.fire_rate_mult()


func _enemies() -> Array:
	return Game.enemies()


# ---------------------------------------------------------------------------
# 天照：日輪光線
# ---------------------------------------------------------------------------

func beam_width() -> float:
	return (14.0 + 3.0 * float(p.kami_lv.get(kami, 1) / 3)) * (1.0 + p.val("ama_u1") * 0.01)


func beam_dirs() -> Array:
	var dirs := [Vector2.UP]
	var extra := int(round(p.val("ama_u3"))) if p.has("ama_u3") else 0
	for i in extra:
		var a := deg_to_rad(14.0 + 10.0 * float(i))
		dirs.append(Vector2.UP.rotated(a))
		dirs.append(Vector2.UP.rotated(-a))
	return dirs


func _beam(delta: float) -> void:
	_beam_tick -= delta
	if _beam_tick > 0.0:
		return
	_beam_tick = 0.1
	var dmg := base_dmg() * 0.24 * power() * (1.0 + p.val("ama_u2") * 0.01)   # 毎 0.1 秒 → 約 2.4 倍/秒
	var w := beam_width()
	var origin := p.position + Vector2(0, -30)
	var hit_any := false
	var focus_max := p.val("ama_u9") * 0.01 if p.has("ama_u9") else 0.0
	var hit_ids := {}
	var dirs := beam_dirs()
	for d0 in dirs:
		var d: Vector2 = d0
		var n: Vector2 = d.orthogonal()
		for e in _enemies():
			var rel: Vector2 = e.position - origin
			var along: float = rel.dot(d)
			if along < -10.0:
				continue
			var side: float = absf(rel.dot(n))
			if side <= w * 0.5 + e.radius * 0.8:
				hit_any = true
				var id: int = e.get_instance_id()
				hit_ids[id] = true
				if p.has("ama_u6"):
					e.st["sunslow"] = 0.25   # 灼き付く光：光線の中にいる間は遅い
				var dmg_e := dmg
				if focus_max > 0.0:
					# 暁の熱：同じ敵に当て続けるほど威力が上がる（2 秒で最大）
					var f: float = float(_focus.get(id, 0.0)) + 0.1
					_focus[id] = f
					dmg_e *= 1.0 + focus_max * clampf(f / 2.0, 0.0, 1.0)
				Combat.hit(e, dmg_e, e.position + Vector2(randf_range(-6, 6), randf_range(-6, 6)),
						{"tag": "beam", "kami": "ama", "dir": d, "crit": randf() < p.crit_chance(), "quiet": true})
	if focus_max > 0.0:
		for id in _focus.keys():
			if not hit_ids.has(id):
				_focus.erase(id)
	# 陽炎：一定間隔で光線が閃き、その瞬間に光線の中にある敵弾を蒸発させる（常時消弾ではない）
	flare_fx = maxf(0.0, flare_fx - 0.1)
	if p.has("ama_u7"):
		_flare_t += 0.1
		if _flare_t >= p.val("ama_u7"):
			_flare_t = 0.0
			flare_fx = 0.35
			var n_erased := 0
			for eb in Game.ebullets():
				if not is_instance_valid(eb):
					continue
				for d0 in dirs:
					var d: Vector2 = d0
					var rel: Vector2 = eb.position - origin
					if rel.dot(d) < 0.0 or absf(rel.dot(d.orthogonal())) > w * 0.5 + 6.0:
						continue
					Fx.sparks(eb.position, Vector2.UP, col, 3, 200.0)
					eb.vanish()
					n_erased += 1
					break
			Fx.ring(origin, col, 8.0, 60.0, 0.25, 3.0)
			Sfx.play("hit_light", -10.0, 1.4, 0.05)
			if n_erased > 0:
				Fx.number(origin + Vector2(0, -30), "陽炎", col, 12.0)
	if hit_any and randf() < 0.5:
		Sfx.play("hit_light", -22.0, randf_range(0.9, 1.1), 0.08)
	# 日食（伝説）
	if p.has("ama_leg"):
		_eclipse_t += 0.1
		if _eclipse_t >= p.val("ama_leg"):
			_eclipse_t = 0.0
			Fx.flash(Cfg.with_a(col, 0.6), 0.4)
			Fx.rays(p.position, col, 24, 40.0, 900.0, 0.5)
			Sfx.play("flute", -8.0, 1.3)
			for e in _enemies():
				e.add_exposed(Combat.EXPOSED_T)
				Combat.hit(e, dmg * 10.0, e.position, {"tag": "light", "kami": "ama"})


# ---------------------------------------------------------------------------
# 須佐之男：荒波
# ---------------------------------------------------------------------------

func _wave() -> void:
	if cd > 0.0:
		return
	cd = _rate(0.95 * (1.0 - p.val("susa_u6") * 0.01))
	var lv: int = p.kami_lv.get(kami, 1)
	var size := 70.0 * (1.0 + p.val("susa_u2") * 0.01) * (1.0 + 0.05 * float(lv / 3))
	var reach := 260.0 * (1.0 + p.val("susa_u3") * 0.01)
	var dmg := base_dmg() * 3.42 * power() * (1.0 + p.val("susa_u1") * 0.01)   # 押し戻しが強いので素の威力は 5% 控えめ
	if p.has("susa_u9"):
		# 怒りの海：画面の敵が多いほど強い
		dmg *= 1.0 + p.val("susa_u9") * 0.01 * float(mini(_enemies().size(), 10))
	var count := 2 if p.has("susa_leg") else 1
	for i in count:
		var b := Bullet.new()
		b.shape_kind = 4
		b.radius = size
		b.pierce = 999
		b.kb = 620.0
		b.kami = "susa"
		b.tag = "wave"
		b.color = col
		b.life = reach / 420.0
		b.crit_chance = p.crit_chance()
		if p.has("susa_leg"):
			b.eraser = true
			b.erase_chance = 0.7
		elif p.has("susa_u7"):
			b.eraser = true
			b.erase_chance = p.val("susa_u7") * 0.01   # 潮騒：確率で消す
		var start := p.position + Vector2(0, -30 - float(i) * 60.0)
		b.setup(start, Vector2(0, -420.0), dmg, true)
		Game.inst.world.add_child(b)
	Fx.ring(p.position + Vector2(0, -30), col, 10.0, size * 0.8, 0.25, 4.0)
	Sfx.play("hit_storm", -12.0, randf_range(0.7, 0.85), 0.2)


# ---------------------------------------------------------------------------
# 建御雷：神鳴り
# ---------------------------------------------------------------------------

func _lightning() -> void:
	if cd > 0.0:
		return
	var es := _enemies()
	if es.is_empty():
		cd = 0.2
		return
	var lv: int = p.kami_lv.get(kami, 1)
	cd = _rate(1.4 * (1.0 - p.val("take_u2") * 0.01) * (1.0 - 0.04 * float(lv / 3)))
	var dmg := base_dmg() * 3.0 * power() * (1.0 + p.val("take_u1") * 0.01)
	# 近い敵を優先しつつ、たまに遠くも
	var target: Node2D = es[randi() % es.size()]
	if randf() < 0.6:
		var best: Node2D = null
		var bd := 1e9
		for e in es:
			var d: float = e.position.distance_squared_to(p.position)
			if d < bd:
				bd = d
				best = e
		if best != null:
			target = best
	var chains := 1 + (int(round(p.val("take_u3"))) if p.has("take_u3") else 0)
	var tpos: Vector2 = target.position
	Combat.lightning(target, dmg, Vector2(tpos.x + randf_range(-40, 40), -30.0), chains)
	# 遠雷：もう 1 体にも同時に落ちる
	if p.has("take_u9") and es.size() > 1 and randf() < p.val("take_u9") * 0.01:
		var other: Node2D = es[randi() % es.size()]
		if other == target:
			other = es[(es.find(other) + 1) % es.size()]
		if other != target and is_instance_valid(other):
			Combat.lightning(other, dmg * 0.8, Vector2(other.position.x + randf_range(-40, 40), -30.0), 0)
	# 雷雲：落ちた所に雲が残り、落雷を続ける
	if p.has("take_u7"):
		var z := Zone.new()
		z.setup(tpos + Vector2(0, -40), "cloud", 90.0, p.val("take_u7"), dmg * 0.3, col)
		Game.inst.spawn_deferred(z)
	Fx.flash(Cfg.with_a(col, 0.08), 0.08)


# ---------------------------------------------------------------------------
# 月読：月輪
# ---------------------------------------------------------------------------

func blade_count() -> int:
	var lv: int = p.kami_lv.get(kami, 1)
	return 2 + (int(round(p.val("tsuki_u1"))) if p.has("tsuki_u1") else 0) + lv / 5


func blade_radius() -> float:
	return 72.0 * (1.0 + p.val("tsuki_u4") * 0.01)


func blade_size() -> float:
	return 22.0 * (1.15 if p.has("tsuki_u8") else 1.0)


func _blades(delta: float) -> void:
	var n := blade_count()
	var r := blade_radius()
	var dmg := base_dmg() * 1.1 * power() * (1.0 + p.val("tsuki_u5") * 0.01)
	var doom := base_dmg() * 3.0 * power() * (1.0 + p.val("tsuki_u2") * 0.01)
	_spin += delta * 2.6 * (1.0 + p.val("tsuki_u6") * 0.01)
	var spin := _spin
	var br := blade_size()
	# 月の盾：刃が触れた敵弾を消す
	if p.has("tsuki_u8"):
		for eb in Game.ebullets():
			if not is_instance_valid(eb):
				continue
			for i in n:
				var a := spin + TAU * float(i) / float(n)
				var bp := p.position + Vector2(cos(a), sin(a)) * r
				if bp.distance_to(eb.position) <= br + eb.radius:
					if randf() < p.val("tsuki_u8") * 0.01:   # 月の盾：確率で消す
						Fx.sparks(eb.position, Vector2.UP, col, 2, 160.0)
						eb.vanish()
					break
	for e in _enemies():
		var id: int = e.get_instance_id()
		if float(_blade_hit.get(id, 0.0)) > t:
			continue
		for i in n:
			var a := spin + TAU * float(i) / float(n)
			var bp := p.position + Vector2(cos(a), sin(a)) * r
			if bp.distance_to(e.position) <= br + e.radius:
				_blade_hit[id] = t + 0.28 / (1.0 + p.val("tsuki_u6") * 0.01)
				Combat.hit(e, dmg, e.position, {"tag": "blade", "kami": "tsuki", "dir": (e.position - p.position).normalized(),
						"crit": randf() < p.crit_chance(), "doom": doom})
				Fx.slash(e.position, a + PI * 0.5, 22.0, col, 2.0, 0.15, 5.0)
				break
	if _blade_hit.size() > 200:
		_blade_hit.clear()


# ---------------------------------------------------------------------------
# 天宇受売：舞扇
# ---------------------------------------------------------------------------

func _fan() -> void:
	if cd > 0.0:
		return
	var lv: int = p.kami_lv.get(kami, 1)
	cd = _rate(1.6 * (1.0 - p.val("uzume_u7") * 0.01))
	var n := 1 + (int(round(p.val("uzume_u1"))) if p.has("uzume_u1") else 0)
	var size := 1.0 + p.val("uzume_u2") * 0.01 + 0.06 * float(lv / 3)
	var dmg := base_dmg() * 1.5 * power() * size
	for i in n:
		var b := Bullet.new()
		b.shape_kind = 8
		b.radius = 16.0 * size
		b.pierce = 999
		b.eraser = true
		b.kami = "uzume"
		b.tag = "fan"
		b.color = col
		b.mode = "boomerang"
		b.turn_dist = 330.0 * (1.0 + p.val("uzume_u6") * 0.01)
		b.return_mult = 1.0 + p.val("uzume_u8") * 0.01
		b.life = 3.2 + p.val("uzume_u6") * 0.01
		b.crit_chance = p.crit_chance()
		b.charm_chance = p.val("uzume_u4") * 0.01 if p.has("uzume_u4") else 0.0
		var a := -PI * 0.5 + (float(i) - float(n - 1) * 0.5) * deg_to_rad(22.0)
		b.setup(p.position + Vector2(0, -20), Vector2(cos(a), sin(a)) * 520.0, dmg, true)
		Game.inst.world.add_child(b)
	Sfx.play("clap", -12.0, 1.3, 0.1)


# ---------------------------------------------------------------------------
# 稲荷：狐火
# ---------------------------------------------------------------------------

func _foxfire() -> void:
	if cd > 0.0:
		return
	var lv: int = p.kami_lv.get(kami, 1)
	cd = _rate(0.42 * (1.0 - p.val("inari_u6") * 0.01))
	var n := 1 + (int(round(p.val("inari_u1"))) if p.has("inari_u1") else 0) + lv / 4
	var dmg := base_dmg() * 0.75 * power() * (1.0 + p.val("inari_u2") * 0.01)
	var target := Combat.nearest_enemy(p.position, 900.0)
	for i in n:
		var from := p.position + Vector2((float(i) - float(n - 1) * 0.5) * 14.0, -24.0)
		p.spawn_foxfire(from, target, dmg, "foxfire")


# ---------------------------------------------------------------------------
# 少名毘古那：酒霧の瓢
# ---------------------------------------------------------------------------

func _gourd() -> void:
	if cd > 0.0:
		return
	cd = _rate(2.2 * (1.0 - p.val("suku_u6") * 0.01))
	var lv: int = p.kami_lv.get(kami, 1)
	var target := Combat.nearest_enemy(p.position, 900.0)
	var to := Vector2(p.position.x, p.position.y - 300.0)
	if target != null:
		to = target.position
	var b := Bullet.new()
	b.shape_kind = 9
	b.radius = 9.0
	b.kami = "suku"
	b.tag = "gourd"
	b.color = col
	b.zone_kind = "fog"
	b.zone_r = 62.0 * (1.0 + p.val("suku_u1") * 0.01 + p.val("duo_ama_suku") * 0.01) * (1.0 + 0.05 * float(lv / 3))
	b.zone_life = 3.0 * (1.0 + p.val("suku_u2") * 0.01)
	b.zone_dmg = 0.0
	b.life = clampf(p.position.distance_to(to) / 520.0, 0.25, 1.4)
	var dir := (to - p.position).normalized()
	b.setup(p.position + Vector2(0, -20), dir * 520.0, base_dmg() * 0.8 * power(), true)
	Game.inst.world.add_child(b)
	Sfx.play("miki", -20.0, 1.6, 0.2)


# ---------------------------------------------------------------------------
# 伊邪那美：氷柱
# ---------------------------------------------------------------------------

func _shards() -> void:
	if cd > 0.0:
		return
	var lv: int = p.kami_lv.get(kami, 1)
	cd = _rate(0.7 * (1.0 - p.val("iza_u6") * 0.01))
	var n := 3 + (int(round(p.val("iza_u1"))) if p.has("iza_u1") else 0) + 2 * (lv / 5)
	var dmg := base_dmg() * 0.9 * power() * (1.0 + p.val("iza_u2") * 0.01)
	var pierce := int(round(p.val("iza_u8"))) if p.has("iza_u8") else 0
	for i in n:
		var b := Bullet.new()
		b.shape_kind = 10
		b.radius = 5.0
		b.pierce = pierce
		b.kami = "iza"
		b.tag = "shard"
		b.color = Color(0.85, 0.95, 1.0)
		b.crit_chance = p.crit_chance()
		var a := -PI * 0.5 + (float(i) - float(n - 1) * 0.5) * deg_to_rad(11.0)
		b.setup(p.position + Vector2(0, -26), Vector2(cos(a), sin(a)) * 640.0, dmg, true)
		Game.inst.world.add_child(b)
	Sfx.play("hit_ice", -22.0, 1.4, 0.15)


# ---------------------------------------------------------------------------
# 猿田彦：神風の刃
# ---------------------------------------------------------------------------

func _wind() -> void:
	if cd > 0.0:
		return
	var lv: int = p.kami_lv.get(kami, 1)
	var rate := 1.0 + p.val("saru_u1") * 0.01
	cd = _rate(0.13 / rate)
	var dmg := base_dmg() * 0.45 * power() * (1.0 + p.val("saru_u2") * 0.01)
	if p.has("saru_u7") and p.dash_buff_t > 0.0:
		dmg *= 1.0 + p.val("saru_u7") * 0.01     # 追い風：疾走直後は威力が高い
	var n := 1 + lv / 4 + (int(round(p.val("saru_u5"))) if p.has("saru_u5") else 0)   # 神風二列
	var pierce := int(round(p.val("saru_u6"))) if p.has("saru_u6") else 0
	_alt = (_alt + 1) % 2
	for i in n:
		var b := Bullet.new()
		b.shape_kind = 11
		b.radius = 4.0
		b.pierce = pierce
		b.kami = "saru"
		b.tag = "wind"
		b.color = col
		b.crit_chance = p.crit_chance()
		var x := (float(_alt) - 0.5) * 16.0 + (float(i) - float(n - 1) * 0.5) * 22.0
		var a := -PI * 0.5 + deg_to_rad(randf_range(-3.0, 3.0))
		b.setup(p.position + Vector2(x, -30), Vector2(cos(a), sin(a)) * 980.0, dmg, true)
		Game.inst.world.add_child(b)


# ---------------------------------------------------------------------------
# 描画（光線と月輪は自分で描く）
# ---------------------------------------------------------------------------

func _draw() -> void:
	if p == null or not is_instance_valid(p) or not p.alive:
		return
	match kami:
		"ama":
			var w := beam_width()
			var origin := p.position + Vector2(0, -30)
			var flick := 0.85 + 0.15 * sin(t * 40.0)
			if flare_fx > 0.0:
				# 陽炎の閃き：光線が一瞬太く白く光る
				for d0 in beam_dirs():
					var d: Vector2 = d0
					draw_line(origin, origin + d * 1400.0, Color(1, 1, 1, flare_fx * 1.6), w * 2.6 * (0.5 + flare_fx), true)
			for d0 in beam_dirs():
				var d: Vector2 = d0
				var far: Vector2 = origin + d * 1400.0
				draw_line(origin, far, Cfg.with_a(col, 0.18 * flick), w * 2.2, true)
				draw_line(origin, far, Cfg.with_a(col, 0.55 * flick), w, true)
				draw_line(origin, far, Color(1, 1, 0.95, 0.9 * flick), w * 0.35, true)
				# 光の粒
				for i in 6:
					var k := fmod(t * 1.6 + float(i) / 6.0, 1.0)
					var pos: Vector2 = origin + d * (k * 900.0)
					draw_circle(pos + d.orthogonal() * sin(t * 9.0 + float(i)) * w * 0.4, 2.5, Color(1, 1, 1, (1.0 - k) * 0.8))
			draw_circle(origin, w * 0.9, Cfg.with_a(col, 0.5))
			draw_circle(origin, w * 0.5, Color(1, 1, 1, 0.9))
		"tsuki":
			var n := blade_count()
			var r := blade_radius()
			var spin := _spin
			var bs := blade_size() / 22.0
			draw_arc(p.position, r, 0, TAU, 48, Cfg.with_a(col, 0.12), 1.0, true)
			for i in n:
				var a := spin + TAU * float(i) / float(n)
				var bp := p.position + Vector2(cos(a), sin(a)) * r
				var ang := a + PI * 0.5
				draw_circle(bp, 18.0 * bs, Cfg.with_a(col, 0.14))
				draw_arc(bp, 15.0 * bs, ang - 1.6, ang + 1.6, 14, Cfg.with_a(col, 0.95), 6.0 * bs, true)
				draw_arc(bp, 15.0 * bs, ang - 1.3, ang + 1.3, 12, Color(1, 1, 1, 0.85), 2.0, true)
				# 軌跡
				for j in 4:
					var aa := a - float(j + 1) * 0.12
					var tp := p.position + Vector2(cos(aa), sin(aa)) * r
					draw_circle(tp, 6.0 - float(j), Cfg.with_a(col, 0.25 - 0.05 * float(j)))
