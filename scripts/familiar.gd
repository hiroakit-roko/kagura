class_name Familiar
extends Node2D

## 使い魔：開始時に 3 匹から 1 匹選ぶ。自機の後ろを付いて回り、自動で撃つ。
## 神がいない序盤の支えで、威力は位（レベル）に応じて少しずつ伸びる。
##
##   karasu  烏      正面へ速い弾を連射する。移動もわずかに速くなる
##   neko    猫又    3 方向に弱い弾を撒く。勾玉を引き寄せる範囲が広がる
##   shiki   式神    敵を追う紙の鳥を放つ。被弾後の無敵が少し長い

const LIST := [
	{"id": "karasu", "name": "烏", "kana": "からす", "role": "直進・連射",
		"desc": "正面へ速い弾を絶え間なく放つ。足の速い相棒で、移動速度も少し上がる",
		"passive": "移動速度 +6%", "color": Color(0.55, 0.55, 0.75)},
	{"id": "neko", "name": "猫又", "kana": "ねこまた", "role": "3 方向・広範囲",
		"desc": "尾を振って 3 方向に弾を撒く。ひと弾は弱いが取りこぼしが少なく、勾玉を引き寄せる範囲も広がる",
		"passive": "勾玉の吸引範囲 +35%", "color": Color(0.95, 0.75, 0.45)},
	{"id": "shiki", "name": "式神", "kana": "しきがみ", "role": "誘導・命中保証",
		"desc": "紙の鳥を折って放つ。ゆっくりだが敵を追って必ず届く。護符の力で被弾後の無敵が少し長い",
		"passive": "被弾後の無敵時間 +25%", "color": Color(0.95, 0.95, 1.0)},
]

var kind := "karasu"
var p: Player
var col := Color(1, 1, 1)
var cd := 0.0
var t := 0.0
var _vel := Vector2.ZERO
var _side := -1.0
var mirror := false   # 分身：本体と反対側に付く


static func info(id: String) -> Dictionary:
	for f in LIST:
		if f["id"] == id:
			return f
	return {}


func setup(id: String, player: Player) -> void:
	kind = id
	p = player
	col = info(id)["color"]
	z_index = Cfg.Z_PLAYER - 1
	position = player.position + Vector2(-36, 40)


func dmg() -> float:
	return p.base_damage() * 0.55 * (1.6 if p.has_relic("r_fam_dmg") else 1.0)


func _rate(sec: float) -> float:
	return sec / (1.4 if p.has_relic("r_fam_rate") else 1.0)


func _physics_process(delta: float) -> void:
	if p == null or not is_instance_valid(p) or not p.alive:
		visible = false
		return
	t += delta
	# 自機の後ろ・やや横に遅れて付いていく。左右に動くと反対側へ回り込む
	if absf(p._move_dir.x) > 0.3:
		_side = -signf(p._move_dir.x)
	var side := -_side if mirror else _side
	var want := p.position + Vector2(side * 34.0, 44.0 + sin(t * 3.0) * 3.0)
	position = position.lerp(want, clampf(7.0 * delta, 0.0, 1.0))
	cd -= delta
	if cd <= 0.0:
		_fire()
	queue_redraw()


func _fire() -> void:
	var from := position + Vector2(0, -12)
	match kind:
		"karasu":
			cd = _rate(0.22)
			var b := _bullet()
			b.radius = 3.5
			b.trail_len = 18.0
			b.setup(from, Vector2(randf_range(-20, 20), -1000.0), dmg(), true)
			Game.inst.world.add_child(b)
		"neko":
			cd = _rate(0.55)
			for i in 3:
				var b := _bullet()
				b.radius = 3.5
				var a := -PI * 0.5 + (float(i) - 1.0) * deg_to_rad(16.0)
				b.setup(from, Vector2(cos(a), sin(a)) * 720.0, dmg() * 0.7, true)
				Game.inst.world.add_child(b)
		"shiki":
			cd = _rate(0.7)
			var target := Combat.nearest_enemy(position, 900.0)
			var b := _bullet()
			b.shape_kind = 12
			b.radius = 5.0
			b.homing = 4.5
			var dir := (target.position - from).normalized() if target != null else Vector2.UP
			b.setup(from, dir * 420.0, dmg() * 1.3, true)
			Game.inst.world.add_child(b)
	Sfx.play("shoot", -26.0, 1.3, 0.05)


func _bullet() -> Bullet:
	var b := Bullet.new()
	b.color = col
	b.kami = ""
	b.tag = "familiar"
	b.crit_chance = p.crit_chance()
	return b


func _draw() -> void:
	var bob := sin(t * 6.0) * 1.5
	match kind:
		"karasu":
			# 烏：黒い翼と黄色い目
			var flap := sin(t * 14.0) * 4.0
			draw_colored_polygon(PackedVector2Array([Vector2(-2, bob), Vector2(-16, bob - 6 + flap), Vector2(-14, bob + 2)]), Color(0.12, 0.10, 0.18))
			draw_colored_polygon(PackedVector2Array([Vector2(2, bob), Vector2(16, bob - 6 + flap), Vector2(14, bob + 2)]), Color(0.12, 0.10, 0.18))
			draw_circle(Vector2(0, bob), 6.0, Color(0.14, 0.12, 0.2))
			draw_circle(Vector2(0, bob - 6), 4.0, Color(0.16, 0.14, 0.22))
			draw_circle(Vector2(-1.5, bob - 7), 1.2, Color(1, 0.85, 0.2))
			draw_circle(Vector2(1.5, bob - 7), 1.2, Color(1, 0.85, 0.2))
			draw_colored_polygon(PackedVector2Array([Vector2(-1.5, bob - 5), Vector2(1.5, bob - 5), Vector2(0, bob - 1)]), Color(0.6, 0.5, 0.3))
		"neko":
			# 猫又：丸い体、二本の尾、三角の耳
			draw_circle(Vector2(0, bob), 7.5, col)
			draw_circle(Vector2(0, bob - 8), 5.5, col)
			draw_colored_polygon(PackedVector2Array([Vector2(-5, bob - 10), Vector2(-3, bob - 16), Vector2(-1, bob - 11)]), col)
			draw_colored_polygon(PackedVector2Array([Vector2(5, bob - 10), Vector2(3, bob - 16), Vector2(1, bob - 11)]), col)
			for sgn in [-1.0, 1.0]:
				var pts := PackedVector2Array()
				for i in 6:
					var k := float(i) / 5.0
					pts.append(Vector2(sgn * (4.0 + k * 10.0) + sin(t * 5.0 + k * 3.0 + sgn) * 2.0, bob + 4.0 + k * 8.0))
				draw_polyline(pts, col.darkened(0.15), 2.5, true)
			draw_circle(Vector2(-2, bob - 8), 1.2, Cfg.C_INK)
			draw_circle(Vector2(2, bob - 8), 1.2, Cfg.C_INK)
			draw_line(Vector2(-2, bob - 5), Vector2(2, bob - 5), Cfg.C_INK, 1.0)
		"shiki":
			# 式神：折り紙の人形。淡く光る
			draw_circle(Vector2(0, bob), 11.0, Cfg.with_a(Color(0.85, 0.75, 1.0), 0.15))
			draw_colored_polygon(PackedVector2Array([Vector2(0, bob - 12), Vector2(5, bob - 4), Vector2(3, bob - 4), Vector2(6, bob + 8), Vector2(-6, bob + 8), Vector2(-3, bob - 4), Vector2(-5, bob - 4)]), Cfg.C_PAPER)
			draw_line(Vector2(-9, bob - 2), Vector2(-3, bob - 3), Cfg.C_PAPER, 2.0)
			draw_line(Vector2(9, bob - 2), Vector2(3, bob - 3), Cfg.C_PAPER, 2.0)
			draw_rect(Rect2(-2, bob - 1, 4, 5), Color(0.85, 0.2, 0.25, 0.9))
			draw_line(Vector2(0, bob - 12), Vector2(0, bob - 8), Cfg.C_INK, 1.0)
