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
	return get_tree().get_nodes_in_group("enemy").filter(func(e): return is_instance_valid(e))


# ---------------------------------------------------------------------------
# 天照：日輪光線
# ---------------------------------------------------------------------------

func beam_width() -> float:
	return (14.0 + 3.0 * float(p.kami_lv.get(kami, 1) / 3)) * (1.0 + p.val("ama_u1") * 0.01) * (1.0 if p.is_main(kami) else 0.75)


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
	for d0 in beam_dirs():
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
				Combat.hit(e, dmg, e.position + Vector2(randf_range(-6, 6), randf_range(-6, 6)),
						{"tag": "beam", "kami": "ama", "dir": d, "crit": randf() < p.crit_chance(), "quiet": true})
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
	cd = _rate(0.95)
	var lv: int = p.kami_lv.get(kami, 1)
	var size := 70.0 * (1.0 + p.val("susa_u2") * 0.01) * (1.0 + 0.05 * float(lv / 3))
	var reach := 260.0 * (1.0 + p.val("susa_u3") * 0.01)
	var dmg := base_dmg() * 3.6 * power() * (1.0 + p.val("susa_u1") * 0.01)
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
	Combat.lightning(target, dmg, Vector2(target.position.x + randf_range(-40, 40), -30.0), chains)
	Fx.flash(Cfg.with_a(col, 0.08), 0.08)


# ---------------------------------------------------------------------------
# 月読：月輪
# ---------------------------------------------------------------------------

func blade_count() -> int:
	var lv: int = p.kami_lv.get(kami, 1)
	return 2 + (int(round(p.val("tsuki_u1"))) if p.has("tsuki_u1") else 0) + lv / 5


func blade_radius() -> float:
	return 72.0 * (1.0 + p.val("tsuki_u4") * 0.01)


func _blades(delta: float) -> void:
	var n := blade_count()
	var r := blade_radius()
	var dmg := base_dmg() * 1.1 * power() * (1.0 + p.val("tsuki_u5") * 0.01)
	var doom := base_dmg() * 3.0 * power() * (1.0 + p.val("tsuki_u2") * 0.01)
	var spin := t * 2.6
	for e in _enemies():
		var id: int = e.get_instance_id()
		if float(_blade_hit.get(id, 0.0)) > t:
			continue
		for i in n:
			var a := spin + TAU * float(i) / float(n)
			var bp := p.position + Vector2(cos(a), sin(a)) * r
			if bp.distance_to(e.position) <= 22.0 + e.radius:
				_blade_hit[id] = t + 0.28
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
	cd = _rate(1.6)
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
		b.life = 3.2
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
	cd = _rate(0.42)
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
	cd = _rate(2.2)
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
	b.zone_r = 62.0 * (1.0 + p.val("suku_u1") * 0.01) * (1.0 + 0.05 * float(lv / 3))
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
	cd = _rate(0.7)
	var n := 3 + (int(round(p.val("iza_u1"))) if p.has("iza_u1") else 0) + 2 * (lv / 5)
	var dmg := base_dmg() * 0.9 * power() * (1.0 + p.val("iza_u2") * 0.01)
	for i in n:
		var b := Bullet.new()
		b.shape_kind = 10
		b.radius = 5.0
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
	cd = _rate(0.13 / (1.0 + p.val("saru_u1") * 0.01))
	var dmg := base_dmg() * 0.45 * power() * (1.0 + p.val("saru_u2") * 0.01)
	var n := 1 + lv / 4
	_alt = (_alt + 1) % 2
	for i in n:
		var b := Bullet.new()
		b.shape_kind = 11
		b.radius = 4.0
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
			var spin := t * 2.6
			draw_arc(p.position, r, 0, TAU, 48, Cfg.with_a(col, 0.12), 1.0, true)
			for i in n:
				var a := spin + TAU * float(i) / float(n)
				var bp := p.position + Vector2(cos(a), sin(a)) * r
				var ang := a + PI * 0.5
				draw_circle(bp, 18.0, Cfg.with_a(col, 0.14))
				draw_arc(bp, 15.0, ang - 1.6, ang + 1.6, 14, Cfg.with_a(col, 0.95), 6.0, true)
				draw_arc(bp, 15.0, ang - 1.3, ang + 1.3, 12, Color(1, 1, 1, 0.85), 2.0, true)
				# 軌跡
				for j in 4:
					var aa := a - float(j + 1) * 0.12
					var tp := p.position + Vector2(cos(aa), sin(aa)) * r
					draw_circle(tp, 6.0 - float(j), Cfg.with_a(col, 0.25 - 0.05 * float(j)))
