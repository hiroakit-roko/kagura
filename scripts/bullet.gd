class_name Bullet
extends Area2D

## 自機弾／敵弾の共通クラス。貫通・ホーミング・反射・消弾・各種の形状に対応する。
##
## 自機弾は Combat.hit() を通してダメージと神威を与える。
## slot と kami をもとに Combat 側で神威を判定するので、弾自身は「どのスロットの弾か」を知っていればよい。

var vel := Vector2.ZERO
var dmg := 10.0
var friendly := true
var pierce := 0
var radius := 4.0
var color := Cfg.C_PBULLET
var homing := 0.0          # 追尾の旋回速度(rad/s)。0で直進
var is_crit := false
var crit_chance := -1.0    # 0 以上なら命中時にこの確率で会心判定を行う
var life := 5.0
var trail_len := 14.0
var shape_kind := 0        # 0:弾 1:御札 2:詠唱の珠 3:狐火 4:大波 5:光鏡 6:渦 7:敵弾(鬼火)
var slot: int = Cfg.Slot.ATTACK
var kami := ""             # 神威を持つ弾の神 id（"" なら素の弾）
var tag := "attack"
var eraser := false        # 触れた敵弾を消す
var reflect := false       # 触れた敵弾を跳ね返す（自機弾に変える）
var zone_kind := ""        # 命中地点に残す領域
var zone_r := 60.0
var zone_life := 2.0
var zone_dmg := 10.0
var kb := 0.0              # 押し戻しの強さ
var mode := ""             # "cloud": 一定距離で止まり雷雲になる  "vortex": 敵を引き寄せる
var charmed := false       # 魅了された敵が撃った弾
var split_on_hit := 0      # 命中時にこの数の小弾に砕ける（伊邪那美の氷柱）
var travel := 0.0

var _hit: Dictionary = {}
var _target: Node2D = null
var _retarget := 0.0
var _t := 0.0


func setup(p: Vector2, v: Vector2, d: float, friend: bool) -> void:
	position = p
	vel = v
	dmg = d
	friendly = friend


func _ready() -> void:
	z_index = Cfg.Z_PBULLET if friendly else Cfg.Z_EBULLET
	collision_layer = Cfg.L_PBULLET if friendly else Cfg.L_EBULLET
	collision_mask = Cfg.L_ENEMY if friendly else Cfg.L_PLAYER
	if friendly and (eraser or reflect):
		collision_mask |= Cfg.L_EBULLET
	monitoring = true
	monitorable = not friendly
	if not friendly:
		add_to_group("ebullet")
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c
	add_child(cs)
	area_entered.connect(_on_area)


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	if life <= 0.0:
		_expire()
		return

	if homing > 0.0:
		_retarget -= delta
		if _retarget <= 0.0 or _target == null or not is_instance_valid(_target):
			_retarget = 0.12
			_target = _find_target()
		if _target != null and is_instance_valid(_target):
			var want := (_target.global_position - global_position).angle()
			var cur := vel.angle()
			var na := cur + clampf(wrapf(want - cur, -PI, PI), -homing * delta, homing * delta)
			vel = Vector2(cos(na), sin(na)) * vel.length()

	var v := vel
	if not friendly:
		var sf := Game.enemy_bullet_slow
		if sf > 0.0:
			v *= maxf(0.35, 1.0 - sf)
	position += v * delta
	travel += v.length() * delta
	rotation = v.angle() + PI * 0.5

	if mode == "vortex":
		_vortex_pull(delta)
	elif mode == "cloud" and travel > 300.0:
		_become_cloud()
		return

	if Cfg.off_screen(position, 60.0 if shape_kind != 4 else 200.0):
		queue_free()


func _expire() -> void:
	if zone_kind != "" and friendly:
		_leave_zone(position)
	queue_free()


func _find_target() -> Node2D:
	var best: Node2D = null
	var bd := 1e9
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or _hit.has(e.get_instance_id()):
			continue
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best


func _vortex_pull(delta: float) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_boss:
			continue
		var d: float = e.position.distance_to(position)
		if d < 140.0 and d > 4.0:
			e.position += (position - e.position).normalized() * 260.0 * delta
			e.add_rupture(2.0)


func _become_cloud() -> void:
	var z := Zone.new()
	z.setup(position, "cloud", 170.0, 3.0, zone_dmg, color)
	Game.inst.world.add_child.call_deferred(z)
	queue_free()


func _leave_zone(at: Vector2) -> void:
	var z := Zone.new()
	z.setup(at, zone_kind, zone_r, zone_life, zone_dmg, color)
	Game.inst.world.add_child.call_deferred(z)


func _on_area(a: Area2D) -> void:
	if _hit.has(a.get_instance_id()):
		return

	# 自機弾が敵弾に触れた：反射／消弾
	if friendly and a is Bullet:
		var eb := a as Bullet
		if eb.friendly:
			return
		if reflect:
			eb.reflect_to_friendly(dmg * 0.6)
			Sfx.play("deflect", -14.0, randf_range(0.95, 1.15), 0.03)
		elif eraser:
			eb.vanish()
		return

	if not a.has_method("take_damage"):
		return
	_hit[a.get_instance_id()] = true

	if friendly:
		var crit := is_crit
		if crit_chance >= 0.0 and randf() < crit_chance:
			crit = true
		var opts := {"tag": tag, "slot": slot, "kami": kami, "crit": crit,
				"dir": vel.normalized(), "kb": kb}
		Combat.hit(a, dmg, global_position, opts)
		if zone_kind != "":
			_leave_zone(global_position)
			zone_kind = ""
		if split_on_hit > 0:
			_split(split_on_hit)
			split_on_hit = 0
		Fx.cone(global_position, -vel.normalized(), color, 4, 150.0, 0.9, 2.5, 0.22)
		if shape_kind == 4:
			pierce = 999
	else:
		a.take_damage(dmg, false, global_position)
		Fx.burst(global_position, color, 6, 130.0, 3.0, 0.25, true)

	if pierce > 0:
		pierce -= 1
	else:
		queue_free()


## 氷片に砕ける：周囲へ小さな弾を撒く
func _split(n: int) -> void:
	Fx.burst(global_position, Color(0.85, 0.95, 1.0), 8, 200.0, 3.0, 0.35)
	Sfx.play("hit_ice", -10.0, 1.2, 0.05)
	for i in n:
		var a := -PI * 0.5 + (float(i) - float(n - 1) * 0.5) * (PI / float(n)) + randf_range(-0.15, 0.15)
		var b := Bullet.new()
		b.radius = 4.0
		b.color = Color(0.85, 0.95, 1.0)
		b.kami = kami
		b.slot = Cfg.Slot.ATTACK      # 氷片 1 つにつき冷気 1 段階
		b.tag = "attack"
		b.trail_len = 10.0
		b.life = 0.7
		b.crit_chance = crit_chance
		b.setup(global_position, Vector2(cos(a), sin(a)) * 420.0, dmg * 0.4, true)
		Game.inst.world.add_child.call_deferred(b)


## 敵弾を自機弾に変える（天照の反射）
func reflect_to_friendly(new_dmg: float) -> void:
	if friendly:
		return
	Fx.sparks(global_position, -vel.normalized(), Color(1.0, 0.9, 0.6), 5, 300.0)
	var b := Bullet.new()
	b.radius = radius
	b.color = Color(1.0, 0.9, 0.6)
	b.tag = "deflect"
	b.kami = "ama"
	b.slot = Cfg.Slot.PASSIVE
	b.trail_len = 16.0
	var target := _nearest_enemy()
	var dir := -vel.normalized()
	if target != null:
		dir = (target.global_position - global_position).normalized()
	b.setup(global_position, dir * maxf(vel.length(), 420.0), new_dmg, true)
	Game.inst.world.add_child.call_deferred(b)
	queue_free()


func vanish() -> void:
	Fx.burst(global_position, Cfg.with_a(color, 0.7), 3, 80.0, 2.0, 0.2, true)
	queue_free()


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var bd := 1e9
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best


func _draw() -> void:
	var glow := color
	glow.a = 0.30
	match shape_kind:
		1: # 御札：細長い紙に朱印
			draw_circle(Vector2.ZERO, radius * 2.0, glow)
			draw_rect(Rect2(-4.5, -9, 9, 18), Cfg.C_PAPER)
			draw_rect(Rect2(-4.5, -9, 9, 18), color, false, 1.2)
			draw_rect(Rect2(-2.5, -5, 5, 6), Color(0.85, 0.2, 0.25, 0.95))
			draw_line(Vector2(0, 3), Vector2(0, 7), Cfg.C_INK, 1.2)
		2: # 詠唱の珠：大きな光球
			draw_circle(Vector2.ZERO, radius * 2.4, Cfg.with_a(color, 0.18))
			draw_circle(Vector2.ZERO, radius * 1.4, Cfg.with_a(color, 0.55))
			draw_circle(Vector2.ZERO, radius * 0.9, color)
			draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.35, Color(1, 1, 1, 0.9))
			for i in 3:
				var a := _t * 5.0 + TAU * float(i) / 3.0
				draw_circle(Vector2(cos(a), sin(a)) * radius * 1.6, 2.0, Color(1, 1, 1, 0.7))
		3: # 狐火：揺れる炎
			draw_circle(Vector2.ZERO, radius * 2.2, glow)
			var fl := 1.0 + 0.2 * sin(_t * 30.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -radius * 2.4 * fl), Vector2(radius * 1.1, 0), Vector2(0, radius * 1.2),
				Vector2(-radius * 1.1, 0)]), color)
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -radius * 1.3 * fl), Vector2(radius * 0.5, 0), Vector2(0, radius * 0.7),
				Vector2(-radius * 0.5, 0)]), Color(1, 1, 0.85, 0.95))
		4: # 大波：横に広い弧
			var w := radius
			draw_arc(Vector2(0, w * 0.6), w, PI + 0.35, TAU - 0.35, 26, Cfg.with_a(color, 0.25), 18.0, true)
			draw_arc(Vector2(0, w * 0.6), w, PI + 0.35, TAU - 0.35, 26, color, 6.0, true)
			draw_arc(Vector2(0, w * 0.6), w * 0.92, PI + 0.5, TAU - 0.5, 26, Color(1, 1, 1, 0.8), 2.0, true)
			for i in 7:
				var a := PI + 0.4 + (TAU - PI - 0.8) * float(i) / 6.0
				var p := Vector2(0, w * 0.6) + Vector2(cos(a), sin(a)) * w
				draw_circle(p + Vector2(0, -4.0 - 3.0 * sin(_t * 12.0 + float(i))), 3.0, Color(1, 1, 1, 0.8))
		5: # 光鏡：大きな円盤
			draw_circle(Vector2.ZERO, radius * 1.15, Cfg.with_a(color, 0.16))
			draw_circle(Vector2.ZERO, radius, Cfg.with_a(Color(1, 1, 0.95), 0.35))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 40, color, 3.0, true)
			draw_arc(Vector2.ZERO, radius * 0.7, _t * 2.0, _t * 2.0 + 2.5, 20, Color(1, 1, 1, 0.8), 2.0, true)
			for i in 8:
				var a := _t * 1.5 + TAU * float(i) / 8.0
				draw_line(Vector2(cos(a), sin(a)) * radius * 0.8, Vector2(cos(a), sin(a)) * radius * 1.0, Color(1, 1, 1, 0.6), 1.5, true)
		6: # 渦
			draw_circle(Vector2.ZERO, radius * 1.3, Cfg.with_a(color, 0.14))
			for i in 3:
				var a0 := -_t * 6.0 + TAU * float(i) / 3.0
				for j in 6:
					var k := float(j) / 6.0
					var rr := radius * (0.3 + k * 0.9)
					var a := a0 + k * 2.4
					draw_circle(Vector2(cos(a), sin(a)) * rr, 2.5 + k * 2.0, Cfg.with_a(color, 0.9 - k * 0.5))
			draw_circle(Vector2.ZERO, radius * 0.3, Color(1, 1, 1, 0.9))
		7: # 敵弾：鬼火
			draw_circle(Vector2.ZERO, radius * 2.2, glow)
			var fl2 := 1.0 + 0.25 * sin(_t * 26.0)
			draw_circle(Vector2.ZERO, radius * 1.1, color)
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, radius * 2.6 * fl2), Vector2(radius * 0.9, 0), Vector2(-radius * 0.9, 0)]),
				Cfg.with_a(color, 0.7))
			draw_circle(Vector2.ZERO, radius * 0.5, Color(1, 1, 1, 0.95))
		_:
			draw_line(Vector2(0, trail_len), Vector2.ZERO, Color(color.r, color.g, color.b, 0.18),
					radius * 2.2, true)
			draw_line(Vector2(0, trail_len * 0.55), Vector2.ZERO,
					Color(color.r, color.g, color.b, 0.4), radius * 1.2, true)
			draw_circle(Vector2.ZERO, radius * 2.2, glow)
			# 進行方向に伸びたカプセル状のコア
			draw_line(Vector2(0, radius * 0.7), Vector2(0, -radius * 0.9), color, radius * 2.0, true)
			draw_line(Vector2(0, radius * 0.3), Vector2(0, -radius * 0.6),
					Color(1, 1, 1, 0.95), radius * 0.9, true)
