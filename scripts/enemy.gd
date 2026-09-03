class_name Enemy
extends Area2D

## 雑魚敵（穢れ）。kind ごとに移動・射撃パターンを切り替える。Boss はこれを継承する。
## 神威（状態異常）は st 辞書で管理し、毎フレーム tick する。

var kind := "grunt"
var hp := 10.0
var max_hp := 10.0
var speed := 90.0
var contact_dmg := 12.0
var score := 10
var xp := 3.0
var radius := 15.0
var color := Cfg.C_ENEMY
var wave := 1
var is_boss := false

var t := 0.0
var fire_t := 0.0
var flash := 0.0
var kb := Vector2.ZERO          # 押し戻しの速度
var _phase := 0.0
var _dir := 1.0
var _state := 0
var _state_t := 0.0
var _charge_dir := Vector2.DOWN
var _spawn_in := 0.35
var _tick := 0.0
var _kb_hit_cd := 0.0

# ---- 神威 ----
var st := {
	"exposed": 0.0,
	"rupture": 0.0,
	"jolted": 0.0,
	"weak": 0.0,
	"charm": 0.0,
	"frozen": 0.0,
	"marked": false,
	"doom": {},          # {"t": 残り秒, "dmg": float}
	"hangover": {"stacks": 0, "t": 0.0, "dps": 0.0},
	"chill": {"stacks": 0, "t": 0.0},
	"sunslow": 0.0,      # 灼き付く光：光線の中にいる間の減速（残り秒）
	"stagger": 0.0,      # 怯み：動けず撃てない（残り秒）
}
var _last_pos := Vector2.ZERO
var last_tag := ""          # 最後に受けた攻撃の種類（撃破時の派生に使う）
var _rupture_acc := 0.0
var _hang_t := 0.0

const KIND_NAMES := {"grunt": "鬼火", "weaver": "傘の怪", "charger": "突撃鬼", "turret": "百目", "splitter": "分かれ玉", "mini": "小玉",
	"spirit": "人魂", "lantern": "提灯お化け", "kite": "凧", "oni": "小鬼", "caster": "陰陽師", "bomber": "火の玉", "boss": "大妖"}


func display_name() -> String:
	if is_boss:
		return String(get("boss_name")) if get("boss_name") != null else "大妖"
	return String(KIND_NAMES.get(kind, kind))


const STATUS_GLYPH := {
	"exposed": ["照", Color(1.0, 0.84, 0.42)],
	"rupture": ["裂", Color(0.35, 0.82, 0.95)],
	"jolted": ["雷", Color(1.0, 0.95, 0.5)],
	"doom": ["宿", Color(0.78, 0.72, 1.0)],
	"weak": ["弱", Color(1.0, 0.58, 0.78)],
	"charm": ["魅", Color(1.0, 0.45, 0.7)],
	"marked": ["狐", Color(1.0, 0.62, 0.3)],
	"hangover": ["酔", Color(0.62, 1.0, 0.55)],
	"chill": ["冷", Color(0.58, 0.82, 1.0)],
	"frozen": ["凍", Color(0.8, 0.95, 1.0)],
}


func setup(k: String, w: int) -> void:
	kind = k
	wave = w
	# 後半は神器も強くなるので、HP は二乗で伸ばして終盤ほど厳しくする
	var hs := 1.2 + float(w) * 0.30 + float(w * w) * 0.017
	var ss := 1.08 + float(w) * 0.03
	_phase = randf() * TAU
	_dir = 1.0 if randf() < 0.5 else -1.0
	match k:
		"grunt":
			max_hp = 16.0 * hs
			speed = 118.0 * ss
			radius = 15.0
			score = 10
			xp = 4.0
			contact_dmg = 12.0
			color = Cfg.C_ENEMY
			fire_t = randf_range(1.0, 2.6)
		"weaver":
			max_hp = 22.0 * hs
			speed = 98.0 * ss
			radius = 16.0
			score = 18
			xp = 5.0
			contact_dmg = 12.0
			color = Cfg.C_ENEMY2
			fire_t = randf_range(1.4, 3.0)
		"charger":
			max_hp = 30.0 * hs
			speed = 470.0 * ss
			radius = 17.0
			score = 25
			xp = 7.0
			contact_dmg = 22.0
			color = Cfg.C_ENEMY3
		"turret":
			max_hp = 46.0 * hs
			speed = 60.0
			radius = 20.0
			score = 35
			xp = 10.0
			contact_dmg = 14.0
			color = Color(0.55, 0.85, 1.0)
			fire_t = 1.6
		"splitter":
			max_hp = 40.0 * hs
			speed = 84.0 * ss
			radius = 21.0
			score = 30
			xp = 9.0
			contact_dmg = 14.0
			color = Color(0.45, 1.0, 0.65)
			fire_t = randf_range(1.5, 3.0)
		"mini":
			max_hp = 10.0 * hs
			speed = 210.0 * ss
			radius = 10.0
			score = 8
			xp = 2.5
			contact_dmg = 9.0
			color = Color(0.45, 1.0, 0.65)
		"spirit":   # 人魂：群れで漂う。すぐ死ぬが数が多い
			max_hp = 8.0 * hs
			speed = 150.0 * ss
			radius = 11.0
			score = 6
			xp = 2.0
			contact_dmg = 8.0
			color = Color(0.70, 0.85, 1.0)
		"lantern":  # 提灯お化け：上部に留まり、大きく遅い弾を 3 方向に
			max_hp = 34.0 * hs
			speed = 60.0
			radius = 18.0
			score = 30
			xp = 8.0
			contact_dmg = 14.0
			color = Color(1.0, 0.55, 0.35)
			fire_t = randf_range(1.5, 2.5)
		"kite":     # 凧：横から斜めに横切る
			max_hp = 20.0 * hs
			speed = 230.0 * ss
			radius = 14.0
			score = 22
			xp = 6.0
			contact_dmg = 12.0
			color = Color(1.0, 0.35, 0.35)
			fire_t = randf_range(0.8, 1.6)
		"oni":      # 小鬼：硬くて遅い。定期的に全方位弾
			max_hp = 95.0 * hs
			speed = 42.0 * ss
			radius = 24.0
			score = 60
			xp = 16.0
			contact_dmg = 26.0
			color = Color(0.85, 0.25, 0.30)
			fire_t = 2.0
		"caster":   # 陰陽師：上部で瞬間移動しながら誘導弾
			max_hp = 40.0 * hs
			speed = 80.0
			radius = 16.0
			score = 45
			xp = 12.0
			contact_dmg = 12.0
			color = Color(0.85, 0.75, 1.0)
			fire_t = 1.8
			_state_t = 3.0
		"bomber":   # 火の玉：自機へ突っ込み、近づくか死ぬと弾を撒く
			max_hp = 26.0 * hs
			speed = 120.0 * ss
			radius = 13.0
			score = 20
			xp = 7.0
			contact_dmg = 18.0
			color = Color(1.0, 0.62, 0.25)
	var pl := Game.inst.player if Game.inst != null else null
	hp = max_hp


func _ready() -> void:
	z_index = Cfg.Z_ENEMY
	collision_layer = Cfg.L_ENEMY
	collision_mask = 0
	set_deferred("monitoring", false)   # 衝突シグナル中に生成されても安全に
	set_deferred("monitorable", true)
	add_to_group("enemy")
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius * 0.88
	cs.shape = c
	add_child(cs)
	_last_pos = position


func _physics_process(delta: float) -> void:
	t += delta
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 6.0)
	if _spawn_in > 0.0:
		_spawn_in = maxf(0.0, _spawn_in - delta)
	_kb_hit_cd = maxf(0.0, _kb_hit_cd - delta)

	_tick_status(delta)

	if st["frozen"] <= 0.0 and st["stagger"] <= 0.0:
		_behavior(delta * speed_mult() * Game.enemy_slow)

	# 押し戻し
	if kb.length_squared() > 1.0:
		var before := position
		position += kb * delta
		kb = kb.lerp(Vector2.ZERO, clampf(6.0 * delta, 0.0, 1.0))
		_check_kb_collision(before)
	else:
		kb = Vector2.ZERO

	# 裂傷：移動距離に応じたダメージ
	if st["rupture"] > 0.0:
		_rupture_acc += position.distance_to(_last_pos)
		if _rupture_acc >= 24.0:
			_rupture_acc -= 24.0
			Combat.status_damage(self, Combat.rupture_dmg(), "rupture")
	_last_pos = position

	# 画面外に出た個体は回収する（チャージャーが上に抜けても止まらないように）
	if position.y > Cfg.H + 90.0 or position.y < -420.0 \
			or position.x < -260.0 or position.x > Cfg.W + 260.0:
		queue_free()
		return
	# 見た目の描き直しは 1 フレームおき（30fps）。動き自体は毎フレーム
	if (Engine.get_physics_frames() + (get_instance_id() & 1)) % 2 == 0 or flash > 0.0:
		queue_redraw()


# ---------- 神威 ----------

func _tick_status(delta: float) -> void:
	for key in ["exposed", "rupture", "jolted", "weak", "charm", "frozen", "sunslow", "stagger"]:
		if st[key] > 0.0:
			st[key] = maxf(0.0, st[key] - delta)

	var d: Dictionary = st["doom"]
	if not d.is_empty():
		d["t"] = float(d["t"]) - delta
		if float(d["t"]) <= 0.0:
			st["doom"] = {}
			Combat.doom_trigger(self, float(d["dmg"]))

	var h: Dictionary = st["hangover"]
	if int(h["stacks"]) > 0:
		h["t"] = float(h["t"]) - delta
		_hang_t += delta
		if _hang_t >= 0.5:
			_hang_t -= 0.5
			Combat.status_damage(self, float(h["dps"]) * float(h["stacks"]) * 0.5, "hangover")
		if float(h["t"]) <= 0.0:
			h["stacks"] = 0

	var c: Dictionary = st["chill"]
	if int(c["stacks"]) > 0:
		c["t"] = float(c["t"]) - delta
		if float(c["t"]) <= 0.0:
			c["stacks"] = 0


## 冷気は弾の発射頻度も落とす（雑魚は最大 -50%、ボスは -25%）
func fire_mult() -> float:
	var m := 1.0
	var c: Dictionary = st["chill"]
	if int(c["stacks"]) > 0:
		m *= 1.0 - minf(0.1 * float(c["stacks"]), 0.5 if not is_boss else 0.25)
	if int(st["hangover"]["stacks"]) > 0:
		m *= 1.0 - (0.2 if not is_boss else 0.1)   # 酩酊：手元が狂って撃つのも遅くなる
	return m


func speed_mult() -> float:
	var m := 1.0
	var c: Dictionary = st["chill"]
	if int(c["stacks"]) > 0:
		m *= 1.0 - minf(0.12 * float(c["stacks"]), 0.6 if not is_boss else 0.3)
	if int(st["hangover"]["stacks"]) > 0:
		m *= 1.0 - Combat.hangover_slow()
	if st["charm"] > 0.0:
		m *= 0.6
	if st["sunslow"] > 0.0:
		var pl := Game.inst.player if Game.inst != null else null
		if pl != null and is_instance_valid(pl):
			m *= 1.0 - minf(pl.val("ama_u6") * 0.01, 0.5 if not is_boss else 0.25)
	return m


## 敵が与えるダメージの倍率（弱体・酩酊）
func out_dmg_mult() -> float:
	var m := 1.0
	if st["weak"] > 0.0:
		m *= 1.0 - Combat.weak_amount()
	if int(st["hangover"]["stacks"]) > 0:
		m *= 1.0 - Combat.hangover_slow()
	return m


func add_exposed(sec: float) -> void:
	st["exposed"] = maxf(float(st["exposed"]), sec)


func add_rupture(sec: float) -> void:
	st["rupture"] = maxf(float(st["rupture"]), sec)


func add_jolt(sec: float) -> void:
	st["jolted"] = maxf(float(st["jolted"]), sec)


func add_weak(sec: float) -> void:
	st["weak"] = maxf(float(st["weak"]), sec)


func add_charm(sec: float) -> void:
	if is_boss:
		sec *= 0.4
	st["charm"] = maxf(float(st["charm"]), sec)
	Fx.petals(position, Color(1.0, 0.5, 0.75), 6, 90.0)


func mark() -> void:
	st["marked"] = true


func add_doom(dmg: float, delay := 1.1) -> void:
	var d: Dictionary = st["doom"]
	if d.is_empty():
		st["doom"] = {"t": delay, "dmg": dmg}
	else:
		# 既にある宿命は上書きせず、強い方を残す（Hades の Doom と同じ）
		d["dmg"] = maxf(float(d["dmg"]), dmg)


func add_hangover(stacks: int, dps: float) -> void:
	var h: Dictionary = st["hangover"]
	h["stacks"] = mini(int(h["stacks"]) + stacks, Combat.hangover_max())
	h["t"] = 4.0
	h["dps"] = maxf(float(h["dps"]), dps)


func add_chill(stacks: int) -> void:
	var c: Dictionary = st["chill"]
	c["stacks"] = int(c["stacks"]) + stacks
	c["t"] = 5.0
	if int(c["stacks"]) >= Combat.CHILL_MAX:
		c["stacks"] = 0
		Combat.shatter(self)


## 怯み（須佐之男：怯み波）。動けず撃てない
func stagger(sec: float) -> void:
	if is_boss:
		sec *= 0.4
	st["stagger"] = maxf(float(st["stagger"]), sec)
	Fx.sparks(position, Vector2.UP, Color(1, 1, 1), 5, 200.0)


func freeze(sec: float) -> void:
	if is_boss:
		sec *= 0.5
	st["frozen"] = maxf(float(st["frozen"]), sec)
	Fx.burst(position, Color(0.8, 0.95, 1.0), 8, 120.0, 3.0, 0.4, true)


func knockback(v: Vector2) -> void:
	if is_boss:
		v *= 0.12
	kb += v
	_kb_hit_cd = 0.0


func _check_kb_collision(before: Vector2) -> void:
	if _kb_hit_cd > 0.0 or kb.length() < 120.0:
		return
	# 画面端
	var r := Rect2(radius, -400.0, Cfg.W - radius * 2.0, Cfg.H + 400.0)
	var hit_wall := false
	if position.x < r.position.x or position.x > r.end.x:
		position.x = clampf(position.x, r.position.x, r.end.x)
		kb.x = -kb.x * 0.4
		hit_wall = true
	if hit_wall:
		_kb_hit_cd = 0.3
		Combat.collide(self, null)
		return
	# 他の敵
	for o in Game.enemies():
		if o == self or not is_instance_valid(o):
			continue
		if o.position.distance_to(position) < radius + o.radius:
			_kb_hit_cd = 0.3
			Combat.collide(self, o)
			o.kb += kb * 0.5
			kb *= 0.3
			return


# ---------- 行動 ----------

func _player() -> Node2D:
	if Game.inst == null:
		return null
	var p := Game.inst.player
	return p if (p != null and is_instance_valid(p)) else null


func _behavior(delta: float) -> void:
	match kind:
		"grunt":
			position.y += speed * delta
			position.x += sin(t * 1.4 + _phase) * 26.0 * delta
			fire_t -= delta * fire_mult()
			if fire_t <= 0.0 and position.y > 40.0 and position.y < Cfg.H * 0.75:
				fire_t = _cool(2.4, 3.8)
				_shoot_aimed(1 if wave < 4 else 2, 10.0, _spd(285.0))
		"weaver":
			position.y += speed * delta
			position.x += cos(t * 2.1 + _phase) * 165.0 * delta * _dir
			fire_t -= delta * fire_mult()
			if fire_t <= 0.0 and position.y > 40.0 and position.y < Cfg.H * 0.8:
				fire_t = _cool(2.6, 4.0)
				_shoot_spread(2 if wave < 4 else 3, 22.0, _spd(240.0))
		"charger":
			match _state:
				0: # 侵入
					position.y += 150.0 * delta
					if position.y > randf_range(120.0, 300.0):
						_state = 1
						_state_t = 0.55
				1: # 狙いを定める
					_state_t -= delta
					position.y += 14.0 * delta
					if _state_t <= 0.0:
						_state = 2
						var p := _player()
						_charge_dir = ((p.position - position).normalized() if p != null else Vector2.DOWN)
						Sfx.play("eshot", -16.0, 0.7, 0.05)
				2: # 突撃
					position += _charge_dir * speed * delta
					Fx.cone(position, -_charge_dir, color, 1, 60.0, 0.5, 3.0, 0.25)
		"turret":
			if position.y < 130.0:
				position.y += speed * delta
			else:
				position.x += sin(t * 0.8 + _phase) * 60.0 * delta
			fire_t -= delta * fire_mult()
			if fire_t <= 0.0 and position.y >= 100.0:
				fire_t = _cool(2.6, 3.2)
				_shoot_radial(8 + mini(5, int(wave / 4)), _spd(215.0), t * 0.6)
		"splitter":
			position.y += speed * delta
			position.x += sin(t * 1.1 + _phase) * 40.0 * delta
			fire_t -= delta * fire_mult()
			if fire_t <= 0.0 and position.y > 40.0 and position.y < Cfg.H * 0.8:
				fire_t = _cool(2.8, 4.2)
				_shoot_aimed(2, 14.0, _spd(235.0))
		"mini":
			var p2 := _player()
			var dir := Vector2.DOWN
			if p2 != null:
				dir = (p2.position - position).normalized()
			position += dir.lerp(Vector2.DOWN, 0.35) * speed * delta
		"spirit":
			position.y += speed * 0.6 * delta
			position.x += sin(t * 2.6 + _phase) * 120.0 * delta
			position.y += cos(t * 1.7 + _phase) * 40.0 * delta
		"lantern":
			var target_y := 160.0 + 100.0 * (0.5 + 0.5 * sin(_phase))
			if position.y < target_y:
				position.y += speed * delta
			else:
				position.x += sin(t * 0.7 + _phase) * 50.0 * delta
				position.y += 8.0 * delta
			fire_t -= delta * fire_mult()
			if fire_t <= 0.0 and position.y >= target_y - 20.0:
				fire_t = _cool(2.6, 3.4)
				_shoot_aimed(3, 16.0, _spd(150.0), 9.0)
		"kite":
			if _state == 0:
				_state = 1
				_dir = 1.0 if position.x < Cfg.W * 0.5 else -1.0
			position.x += speed * _dir * delta
			position.y += (70.0 + sin(t * 3.0 + _phase) * 90.0) * delta
			fire_t -= delta * fire_mult()
			if fire_t <= 0.0 and position.x > 30.0 and position.x < Cfg.W - 30.0:
				fire_t = _cool(1.2, 2.0)
				_emit(PI * 0.5, 1, 0.0, _spd(220.0))
			if (position.x < -60.0 and _dir < 0.0) or (position.x > Cfg.W + 60.0 and _dir > 0.0):
				queue_free()
		"oni":
			position.y += speed * delta
			fire_t -= delta * fire_mult()
			if fire_t <= 0.0 and position.y > 40.0:
				fire_t = _cool(3.2, 4.0)
				_shoot_radial(10 + mini(6, int(wave / 5)), _spd(170.0), randf() * TAU)
				Fx.ring(position, color, radius * 0.6, radius * 1.8, 0.25)
		"caster":
			if position.y < 130.0:
				position.y += speed * delta
			else:
				_state_t -= delta
				if _state_t <= 0.0:
					# 瞬間移動
					_state_t = randf_range(3.0, 4.5)
					Fx.burst(position, color, 10, 160.0, 3.0, 0.35, true)
					position.x = randf_range(60.0, Cfg.W - 60.0)
					position.y = randf_range(110.0, 220.0)
					Fx.ring(position, color, 4.0, radius * 3.0, 0.3, 2.0)
					_spawn_in = 0.3
				fire_t -= delta * fire_mult()
				if fire_t <= 0.0 and _spawn_in <= 0.0:
					fire_t = _cool(2.4, 3.2)
					var p3 := _player()
					if p3 != null:
						for i in 2:
							var a := (p3.position - position).normalized().angle() + (float(i) - 0.5) * 0.6
							Game.inst.spawn_ebullet(position, Vector2(cos(a), sin(a)) * _spd(180.0), _bullet_dmg(), 6.0, Color(0.85, 0.7, 1.0), 1.8, "陰陽師の式神")
						_on_fire()
						Sfx.play("eshot", -14.0, 1.3, 0.05)
		"bomber":
			var p4 := _player()
			if _state == 0 and position.y > 90.0:
				_state = 1
				if p4 != null:
					_charge_dir = (p4.position - position).normalized()
			if _state == 0:
				position.y += speed * delta
			else:
				speed = minf(speed + 260.0 * delta, 420.0)
				position += _charge_dir * speed * delta
				Fx.cone(position, -_charge_dir, color, 1, 60.0, 0.5, 3.0, 0.25)
				if p4 != null and position.distance_to(p4.position) < 70.0:
					_explode()
					return


# ---------- 射撃 ----------

## ウェーブが進むほど発射間隔を少しずつ詰める
func _cool(lo: float, hi: float) -> float:
	# 弾は少し控えめに（×1.18）。後半ほど間隔は詰まるが下限は 0.55
	return randf_range(lo, hi) * 1.18 * clampf(0.88 - float(wave) * 0.012, 0.62, 1.0)


## 弾速もウェーブでじわじわ上がる
func _spd(base: float) -> float:
	var pl := Game.inst.player if Game.inst != null else null
	var curse := 1.15 if (pl != null and is_instance_valid(pl) and pl.has("curse_edge")) else 1.0
	return base * (1.15 + float(wave) * 0.02) * curse


func _bullet_dmg() -> float:
	return (9.0 + float(wave) * 1.1 + float(wave * wave) * 0.02) * out_dmg_mult()


func _shoot_aimed(count: int, spread_deg: float, spd: float, radius_b := 5.0) -> void:
	var target := _aim_target()
	if target == null:
		return
	var base := (target.position - position).normalized().angle()
	_emit(base, count, spread_deg, spd, radius_b)


func _shoot_spread(count: int, spread_deg: float, spd: float) -> void:
	if st["charm"] > 0.0:
		_shoot_aimed(count, spread_deg, spd)
		return
	_emit(Vector2.DOWN.angle(), count, spread_deg, spd)


func _shoot_radial(count: int, spd: float, offset := 0.0) -> void:
	_on_fire()
	for i in count:
		var a := offset + TAU * float(i) / float(count)
		_spawn(Vector2(cos(a), sin(a)) * spd)
	Sfx.play("eshot", -14.0, 0.85, 0.04)


func _emit(base: float, count: int, spread_deg: float, spd: float, radius_b := 5.0) -> void:
	_on_fire()
	var step := deg_to_rad(spread_deg)
	for i in count:
		var a := base + (float(i) - float(count - 1) * 0.5) * step
		_spawn(Vector2(cos(a), sin(a)) * spd, radius_b)
	Sfx.play("eshot", -16.0, randf_range(0.9, 1.1), 0.04)


## 火の玉：弾を撒いて消える
func _explode() -> void:
	if hp <= 0.0:
		return
	Fx.burst(position, color, 16, 260.0, 4.0, 0.5)
	Fx.ring(position, color, 6.0, 60.0, 0.3, 4.0)
	Sfx.play("explode", -10.0, 1.2)
	_on_fire()
	for i in 8:
		var a := TAU * float(i) / 8.0 + randf_range(-0.1, 0.1)
		_spawn(Vector2(cos(a), sin(a)) * _spd(190.0), 6.0)
	hp = 0.0
	Game.inst.on_enemy_killed(self)
	queue_free()


## 魅了中は仲間を狙う
func _aim_target() -> Node2D:
	if st["charm"] > 0.0:
		var best: Node2D = null
		var bd := 1e9
		for e in Game.enemies():
			if e == self or not is_instance_valid(e):
				continue
			var d: float = position.distance_squared_to(e.position)
			if d < bd:
				bd = d
				best = e
		if best != null:
			return best
		return null   # 魅了中に他の敵がいなければ撃たない（自機を狙わない）
	return _player()


func _spawn(vel: Vector2, radius_b := 5.0) -> void:
	if st["charm"] > 0.0:
		# 魅了された敵の弾は自機側の弾として飛ぶ
		Game.inst.spawn_charmed_bullet(position, vel * 1.3, _bullet_dmg() * 1.5)
	else:
		Game.inst.spawn_ebullet(position, vel, _bullet_dmg() * (1.0 + (radius_b - 5.0) * 0.08), radius_b, Cfg.C_EBULLET, 0.0, display_name() + "の弾")


## 攻撃するたび帯電ダメージ
func _on_fire() -> void:
	if st["jolted"] > 0.0:
		Combat.jolt_trigger(self)


# ---------- 被弾・撃破 ----------

func take_damage(d: float, crit: bool, at: Vector2, quiet := false) -> void:
	if hp <= 0.0:
		return
	hp -= d
	flash = 1.0 if not quiet else maxf(flash, 0.5)
	if crit:
		# 会心：大きな橙金の数字に「会心」を添え、光条と閃きで一目で分かるように
		Fx.number(at + Vector2(0, -radius - 6.0), str(int(round(d))) + "!", Cfg.C_CRIT, 26.0, true)
		Fx.rays(at, Cfg.C_CRIT, 8, 6.0, 34.0, 0.22)
		Fx.puff(at, 6.0, radius * 2.4, Cfg.with_a(Cfg.C_CRIT, 0.9), 0.25)
		Fx.sparks(at, Vector2.UP, Cfg.C_CRIT, 8, 420.0)
	elif not quiet or randf() < 0.3:
		Fx.number(at + Vector2(0, -radius), str(int(round(d))), Color(1, 1, 1, 0.92), 14.0 if not quiet else 11.0, false)
	if hp <= 0.0:
		die()


func die() -> void:
	if not is_inside_tree():
		return
	Fx.burst(position, color, 16, 300.0, 5.0, 0.55)
	Fx.ring(position, color, radius * 0.5, radius * 4.0, 0.3)
	Fx.puff(position, radius * 1.2, radius * 4.5, Cfg.with_a(color, 0.9), 0.4)
	Fx.shake_add(3.0)
	Sfx.play("explode", -10.0, randf_range(0.9, 1.15), 0.02)

	if kind == "splitter":
		for i in 2:
			var m := Enemy.new()
			m.setup("mini", wave)
			m.position = position + Vector2(-22.0 + 44.0 * float(i), 0)
			Game.inst.spawn_deferred(m)
	if kind == "bomber":
		# 撃たれて死んでも弾を撒く（弱め）
		for i in 6:
			var a := TAU * float(i) / 6.0
			Game.inst.spawn_ebullet(position, Vector2(cos(a), sin(a)) * _spd(150.0), _bullet_dmg() * 0.7, 5.0, Cfg.C_EBULLET, 0.0, "火の玉の爆散")

	Game.inst.on_enemy_killed(self)
	queue_free()


# ---------- 描画 ----------

func _draw() -> void:
	var c := color
	if flash > 0.0:
		c = c.lerp(Color(1, 1, 1), flash * 0.85)
	if st["frozen"] > 0.0:
		c = c.lerp(Color(0.75, 0.92, 1.0), 0.7)
	elif int(st["chill"]["stacks"]) > 0:
		c = c.lerp(Color(0.6, 0.85, 1.0), 0.06 * float(st["chill"]["stacks"]))
	Fx.glow(self, Vector2.ZERO, radius * 2.6, Cfg.with_a(color, 0.5))

	if _spawn_in > 0.0:
		var k := _spawn_in / 0.35
		draw_arc(Vector2.ZERO, radius * (1.0 + k * 2.5), 0.0, TAU, 24,
				Color(c.r, c.g, c.b, 1.0 - k), 2.0, true)

	_draw_body(c)
	_draw_status()
	# 攻撃の予兆：撃つ直前に光り、輪が縮む
	if fire_t > 0.0 and fire_t < 0.35 and kind in ["grunt", "weaver", "turret", "splitter", "lantern", "oni", "caster", "kite"]:
		var k := fire_t / 0.35
		draw_arc(Vector2.ZERO, radius * (0.9 + k * 1.4), 0, TAU, 24, Color(1, 0.6, 0.7, 0.85 * (1.0 - k)), 2.0, true)
		draw_circle(Vector2.ZERO, radius * 0.5, Color(1, 0.85, 0.9, 0.35 * (1.0 - k)))
	# 突撃の予兆：狙いの線
	if kind == "charger" and _state == 1:
		var pl := _player()
		if pl != null:
			var d := (pl.position - position).normalized()
			draw_line(Vector2.ZERO, d * 900.0, Color(1, 0.4, 0.5, 0.25 + 0.2 * sin(t * 30.0)), 2.0, true)
	if kind == "bomber" and _state == 0 and position.y > 40.0:
		var pl2 := _player()
		if pl2 != null:
			draw_line(Vector2.ZERO, (pl2.position - position).normalized() * 120.0, Color(1, 0.6, 0.3, 0.3), 1.5, true)

	# ダメージを受けた個体だけ小さなHPバー
	if hp < max_hp and kind != "mini":
		var w := radius * 2.0
		var y := -radius - 9.0
		draw_rect(Rect2(-w * 0.5, y, w, 3.0), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-w * 0.5, y, w * (hp / max_hp), 3.0), Color(1, 0.45, 0.5, 0.95))


func _draw_body(c: Color) -> void:
	var r := radius
	match kind:
		"grunt":
			# 鬼火：揺れる炎の輪郭
			var pts := PackedVector2Array()
			for i in 12:
				var a := TAU * float(i) / 12.0
				var rr := r * (0.85 + 0.2 * sin(a * 3.0 + t * 9.0))
				if a > PI * 1.2 and a < PI * 1.8:
					rr *= 1.35
				pts.append(Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, c)
			draw_circle(Vector2(-r * 0.3, r * 0.05), r * 0.16, Color(1, 1, 1, 0.9))
			draw_circle(Vector2(r * 0.3, r * 0.05), r * 0.16, Color(1, 1, 1, 0.9))
		"weaver":
			# 傘の怪：菱形の傘
			var pts2 := PackedVector2Array([
				Vector2(0, r * 1.05), Vector2(r * 1.15, 0), Vector2(0, -r * 1.05),
				Vector2(-r * 1.15, 0)])
			draw_colored_polygon(pts2, c)
			draw_polyline(pts2 + PackedVector2Array([pts2[0]]), Color(1, 1, 1, 0.7), 1.6, true)
			draw_circle(Vector2.ZERO, r * 0.3, Color(1, 1, 1, 0.9))
			draw_circle(Vector2.ZERO, r * 0.14, Cfg.C_INK)
		"charger":
			var stretch := 1.0 if _state != 2 else 1.35
			var pts3 := PackedVector2Array([
				Vector2(0, r * 1.2 * stretch), Vector2(r * 0.85, -r * 0.7),
				Vector2(0, -r * 0.3), Vector2(-r * 0.85, -r * 0.7)])
			draw_colored_polygon(pts3, c)
			if _state == 1:
				var blink: float = 0.5 + 0.5 * sin(t * 30.0)
				draw_circle(Vector2.ZERO, r * 0.45, Color(1, 0.9, 0.3, blink))
			else:
				draw_circle(Vector2.ZERO, r * 0.32, Color(1, 1, 1, 0.9))
		"turret":
			# 百目：回転する目玉の輪
			draw_circle(Vector2.ZERO, r, c)
			draw_arc(Vector2.ZERO, r * 1.28, 0.0, TAU, 26, Color(1, 1, 1, 0.55), 2.0, true)
			for i in 6:
				var a := t * 0.6 + TAU * float(i) / 6.0
				var p := Vector2(cos(a), sin(a)) * r * 1.28
				draw_circle(p, 3.5, Color(1, 1, 1, 0.9))
				draw_circle(p, 1.6, Cfg.C_INK)
			draw_circle(Vector2.ZERO, r * 0.42, Cfg.C_BG)
			draw_circle(Vector2.ZERO, r * 0.2, Color(1, 0.3, 0.3))
		"splitter":
			draw_circle(Vector2.ZERO, r, c)
			var seg := Color(0.05, 0.1, 0.1, 0.9)
			draw_line(Vector2(0, -r), Vector2(0, r), seg, 3.0)
			draw_arc(Vector2.ZERO, r * 0.62, 0.0, TAU, 22, Color(1, 1, 1, 0.6), 2.0, true)
		"mini":
			draw_circle(Vector2.ZERO, r, c)
			draw_circle(Vector2.ZERO, r * 0.45, Color(1, 1, 1, 0.85))
		"spirit":
			# 人魂：尾を引く青白い炎
			var tail := Vector2(-sin(t * 2.6 + _phase) * 6.0, -r * 2.2)
			draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.8, 0), tail, Vector2(r * 0.8, 0)]), Cfg.with_a(c, 0.5))
			draw_circle(Vector2.ZERO, r, c)
			draw_circle(Vector2(-r * 0.3, -r * 0.1), r * 0.15, Cfg.C_INK)
			draw_circle(Vector2(r * 0.3, -r * 0.1), r * 0.15, Cfg.C_INK)
		"lantern":
			# 提灯：丸い紙に骨、下に房
			draw_rect(Rect2(-r * 0.6, -r * 1.25, r * 1.2, r * 0.25), Cfg.C_INK)
			draw_circle(Vector2.ZERO, r, c)
			for i in 5:
				var yy := -r + r * 2.0 * float(i + 1) / 6.0
				var hw := sqrt(maxf(0.0, r * r - yy * yy))
				draw_line(Vector2(-hw, yy), Vector2(hw, yy), Color(0.4, 0.1, 0.1, 0.6), 1.0)
			draw_rect(Rect2(-r * 0.6, r * 1.0, r * 1.2, r * 0.25), Cfg.C_INK)
			draw_line(Vector2(0, r * 1.25), Vector2(0, r * 1.7), Cfg.with_a(c, 0.9), 2.0)
			# 一つ目と口
			draw_circle(Vector2(0, -r * 0.2), r * 0.32, Color(1, 1, 0.9))
			draw_circle(Vector2(0, -r * 0.2), r * 0.14, Cfg.C_INK)
			draw_arc(Vector2(0, r * 0.35), r * 0.3, 0.2, PI - 0.2, 10, Cfg.C_INK, 2.0, true)
		"kite":
			# 凧：赤い菱形に骨と尾
			var pts4 := PackedVector2Array([Vector2(0, -r * 1.3), Vector2(r, 0), Vector2(0, r * 1.3), Vector2(-r, 0)])
			draw_colored_polygon(pts4, c)
			draw_polyline(pts4 + PackedVector2Array([pts4[0]]), Color(1, 1, 1, 0.8), 1.5, true)
			draw_line(Vector2(0, -r * 1.3), Vector2(0, r * 1.3), Color(1, 1, 1, 0.6), 1.0)
			draw_line(Vector2(-r, 0), Vector2(r, 0), Color(1, 1, 1, 0.6), 1.0)
			draw_circle(Vector2(0, 0), r * 0.3, Color(1, 1, 1, 0.9))
			draw_circle(Vector2(0, 0), r * 0.14, Cfg.C_INK)
			for i in 3:
				var tp := Vector2(-_dir * float(i + 1) * 9.0, r * 1.3 + sin(t * 8.0 + float(i)) * 4.0)
				draw_circle(tp, 2.5, Cfg.with_a(c, 0.8 - 0.2 * float(i)))
		"oni":
			# 小鬼：大きな体に角と牙
			draw_circle(Vector2.ZERO, r, c)
			draw_arc(Vector2.ZERO, r, 0, TAU, 28, Color(0, 0, 0, 0.35), 2.0, true)
			for sgn in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([Vector2(sgn * r * 0.35, -r * 0.7), Vector2(sgn * r * 0.5, -r * 1.35), Vector2(sgn * r * 0.7, -r * 0.6)]), Color(1, 0.95, 0.85))
				draw_circle(Vector2(sgn * r * 0.35, -r * 0.15), r * 0.18, Color(1, 0.95, 0.6))
				draw_circle(Vector2(sgn * r * 0.35, -r * 0.15), r * 0.08, Cfg.C_INK)
			draw_arc(Vector2(0, r * 0.3), r * 0.4, 0.3, PI - 0.3, 12, Cfg.C_INK, 3.0, true)
			for i in 4:
				var x := (float(i) - 1.5) * r * 0.22
				draw_colored_polygon(PackedVector2Array([Vector2(x - 2, r * 0.45), Vector2(x + 2, r * 0.45), Vector2(x, r * 0.7)]), Color(1, 0.95, 0.85))
		"caster":
			# 陰陽師：白い衣と烏帽子、周りを回る式神の珠
			draw_colored_polygon(PackedVector2Array([Vector2(-r, r), Vector2(r, r), Vector2(r * 0.35, -r * 0.5), Vector2(-r * 0.35, -r * 0.5)]), Cfg.C_PAPER)
			draw_circle(Vector2(0, -r * 0.7), r * 0.4, Color(1, 0.9, 0.85))
			draw_rect(Rect2(-r * 0.3, -r * 1.5, r * 0.6, r * 0.55), Cfg.C_INK)
			draw_line(Vector2(-r * 0.4, r * 0.2), Vector2(r * 0.4, r * 0.2), Cfg.with_a(c, 0.9), 2.0)
			for i in 3:
				var a := t * 3.0 + TAU * float(i) / 3.0
				draw_circle(Vector2(cos(a), sin(a)) * r * 1.5, 3.0, Cfg.with_a(c, 0.9))
		"bomber":
			# 火の玉：揺れる炎、突撃中は激しく
			var fl := 1.0 + (0.35 if _state == 1 else 0.15) * sin(t * 30.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -r * 2.2 * fl), Vector2(r * 1.1, 0), Vector2(0, r * 1.1), Vector2(-r * 1.1, 0)]), c)
			draw_circle(Vector2.ZERO, r * 0.6, Color(1, 0.95, 0.7, 0.95))
			draw_circle(Vector2.ZERO, r * 0.3, Color(1, 0.4, 0.2))


func _draw_status() -> void:
	var f: Font = Game.inst.ui.font if (Game.inst != null and Game.inst.ui != null) else null
	if f == null:
		return
	_draw_status_aura()
	var icons: Array = []
	if st["exposed"] > 0.0: icons.append("exposed")
	if st["rupture"] > 0.0: icons.append("rupture")
	if st["jolted"] > 0.0: icons.append("jolted")
	if not (st["doom"] as Dictionary).is_empty(): icons.append("doom")
	if st["weak"] > 0.0: icons.append("weak")
	if st["charm"] > 0.0: icons.append("charm")
	if st["marked"]: icons.append("marked")
	if int(st["hangover"]["stacks"]) > 0: icons.append("hangover")
	if int(st["chill"]["stacks"]) > 0: icons.append("chill")
	if st["frozen"] > 0.0: icons.append("frozen")
	if icons.is_empty():
		return
	var w := 14.0
	var x0 := -float(icons.size() - 1) * w * 0.5
	var y := radius + 16.0
	for i in icons.size():
		var g: Array = STATUS_GLYPH[icons[i]]
		var col: Color = g[1]
		var pos := Vector2(x0 + float(i) * w, y)
		draw_circle(pos - Vector2(0, 4), 7.0, Cfg.with_a(col, 0.28))
		draw_string(f, pos + Vector2(-6, 0), g[0], HORIZONTAL_ALIGNMENT_CENTER, 12.0, 10, col)
		var n := 0
		if icons[i] == "hangover": n = int(st["hangover"]["stacks"])
		elif icons[i] == "chill": n = int(st["chill"]["stacks"])
		if n > 1:
			draw_string(f, pos + Vector2(4, 2), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.9))
	# 宿命のカウント：縮む輪
	var d: Dictionary = st["doom"]
	if not d.is_empty():
		var k := clampf(float(d["t"]) / 1.1, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius * (1.0 + k * 1.2), 0.0, TAU, 24,
				Cfg.with_a(Color(0.78, 0.72, 1.0), 0.8), 2.0, true)


## 状態異常ごとの、体に重なる見える演出（オーラ・泡・結晶・火花・花弁）
func ci_star(pos: Vector2, r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + TAU * float(i) / 10.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(pos + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, c)


func _draw_status_aura() -> void:
	var r := radius
	# 照覧：金色の輪郭と光条
	if st["exposed"] > 0.0:
		var c := Color(1.0, 0.84, 0.42)
		draw_arc(Vector2.ZERO, r + 4.0, 0, TAU, 28, Cfg.with_a(c, 0.85), 2.5, true)
		for i in 6:
			var a := t * 1.5 + TAU * float(i) / 6.0
			draw_line(Vector2(cos(a), sin(a)) * (r + 6.0), Vector2(cos(a), sin(a)) * (r + 12.0 + 3.0 * sin(t * 6.0 + float(i))), Cfg.with_a(c, 0.7), 1.5, true)
	# 弱体：桃色の花弁が舞い落ちる
	if st["weak"] > 0.0:
		var c := Color(1.0, 0.58, 0.78)
		draw_circle(Vector2.ZERO, r * 1.5, Cfg.with_a(c, 0.10))
		for i in 4:
			var k := fmod(t * 0.7 + float(i) * 0.25, 1.0)
			var pos := Vector2(sin(t * 2.0 + float(i) * 1.7) * r, -r * 1.4 + k * r * 2.8)
			var dd := Vector2(cos(t * 3.0 + float(i)), sin(t * 3.0 + float(i)))
			draw_colored_polygon(PackedVector2Array([pos + dd * 4.0, pos + dd.orthogonal() * 2.0, pos - dd * 4.0, pos - dd.orthogonal() * 2.0]), Cfg.with_a(c, 0.85 * (1.0 - k)))
	# 魅了：桃色の心と輪
	if st["charm"] > 0.0:
		var c := Color(1.0, 0.45, 0.7)
		draw_arc(Vector2.ZERO, r + 3.0, 0, TAU, 24, Cfg.with_a(c, 0.5 + 0.3 * sin(t * 6.0)), 2.0, true)
		var hp2 := Vector2(0, -r - 14.0 + sin(t * 4.0) * 2.0)
		draw_circle(hp2 + Vector2(-3, -2), 3.0, c)
		draw_circle(hp2 + Vector2(3, -2), 3.0, c)
		draw_colored_polygon(PackedVector2Array([hp2 + Vector2(-6, -1), hp2 + Vector2(6, -1), hp2 + Vector2(0, 6)]), c)
	# 酩酊：緑の泡が立ち上る、体が少し揺れる
	var hs: int = int(st["hangover"]["stacks"])
	if hs > 0:
		var c := Color(0.62, 1.0, 0.55)
		draw_circle(Vector2.ZERO, r * 1.35, Cfg.with_a(c, 0.10 + 0.02 * float(hs)))
		for i in mini(hs + 2, 8):
			var k := fmod(t * 0.9 + float(i) * 0.37, 1.0)
			var pos := Vector2(sin(float(i) * 2.1 + t) * r * 0.8, r * 0.6 - k * r * 2.4)
			draw_arc(pos, 2.0 + 2.0 * (1.0 - k), 0, TAU, 10, Cfg.with_a(c, 0.9 * (1.0 - k)), 1.2, true)
	# 冷気：青白い結晶が体に付く。凍結で全体が氷に
	var cs: int = int(st["chill"]["stacks"])
	if cs > 0 or st["frozen"] > 0.0:
		var c := Color(0.8, 0.95, 1.0)
		var n := mini(cs * 2, 10) if st["frozen"] <= 0.0 else 12
		for i in n:
			var a := float(i) * 2.4 + 0.3
			var pos := Vector2(cos(a), sin(a)) * r * 0.85
			var dd := Vector2(cos(a), sin(a))
			draw_colored_polygon(PackedVector2Array([pos + dd * 7.0, pos + dd.orthogonal() * 2.5, pos - dd * 2.0, pos - dd.orthogonal() * 2.5]), Cfg.with_a(c, 0.9))
		if st["frozen"] > 0.0:
			draw_circle(Vector2.ZERO, r * 1.25, Cfg.with_a(c, 0.35))
			draw_arc(Vector2.ZERO, r * 1.25, 0, TAU, 24, Color(1, 1, 1, 0.8), 2.0, true)
	# 怯み：頭の上で回る白い星
	if st["stagger"] > 0.0:
		for i in 3:
			var a := t * 7.0 + TAU * float(i) / 3.0
			var pos := Vector2(cos(a) * (r + 6.0), -r - 10.0 + sin(a) * 4.0)
			ci_star(pos, 3.5, Color(1, 1, 0.85, 0.9))
	# 帯電：黄色い火花がまとわりつく
	if st["jolted"] > 0.0:
		var c := Color(1.0, 0.95, 0.5)
		for i in 3:
			var a := t * 9.0 + float(i) * 2.1
			var p0 := Vector2(cos(a), sin(a)) * (r + 4.0)
			var p1 := p0 + Vector2(randf_range(-6, 6), randf_range(-6, 6))
			draw_line(p0, p1, Cfg.with_a(c, 0.9), 1.5, true)
		draw_arc(Vector2.ZERO, r + 3.0, 0, TAU, 20, Cfg.with_a(c, 0.35), 1.0, true)
	# 裂傷：青い裂け目
	if st["rupture"] > 0.0:
		var c := Color(0.35, 0.82, 0.95)
		for i in 3:
			var a := float(i) * 2.0 + 0.5
			var p0 := Vector2(cos(a), sin(a)) * r * 0.2
			var p1 := Vector2(cos(a), sin(a)) * r * 0.95
			draw_line(p0, p1, Cfg.with_a(c, 0.9), 2.0, true)
			draw_line(p0, p1, Color(1, 1, 1, 0.6), 0.8, true)
	# 狐憑き：橙の狐面の印
	if st["marked"]:
		var c := Color(1.0, 0.62, 0.3)
		var mp := Vector2(0, -r - 12.0)
		draw_colored_polygon(PackedVector2Array([mp + Vector2(0, 6), mp + Vector2(6, 0), mp + Vector2(5, -7), mp + Vector2(0, -3), mp + Vector2(-5, -7), mp + Vector2(-6, 0)]), Cfg.with_a(Cfg.C_PAPER, 0.95))
		draw_line(mp + Vector2(-3, -1), mp + Vector2(-1, 1), Color(0.85, 0.2, 0.3), 1.5)
		draw_line(mp + Vector2(3, -1), mp + Vector2(1, 1), Color(0.85, 0.2, 0.3), 1.5)
		draw_arc(Vector2.ZERO, r + 3.0, 0, TAU, 20, Cfg.with_a(c, 0.5), 1.5, true)
