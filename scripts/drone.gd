class_name Drone
extends Node2D

## 眷属の狐（稲荷の加護）。自機の周りを回り、最も近い敵へ狐火を放つ。

var index := 0
var total := 1
var orbit_r := 54.0
var owner_ship: Player
var cd := 0.0
var t := 0.0
var aim := -PI * 0.5


func _process(delta: float) -> void:
	t += delta
	var a := t * 1.6 + TAU * float(index) / float(maxi(total, 1))
	position = Vector2(cos(a), sin(a) * 0.7) * orbit_r
	queue_redraw()

	if owner_ship == null or not is_instance_valid(owner_ship):
		return
	cd -= delta
	if cd > 0.0:
		return

	var target := Combat.nearest_enemy(global_position, 480.0)
	if target == null:
		return
	aim = (target.global_position - global_position).angle()
	cd = 1.0 / maxf(0.6, float(owner_ship.stats["fire_rate"]) * owner_ship.fire_rate_mult() * 0.4)
	owner_ship.spawn_foxfire(global_position, target, owner_ship.shot_damage(Cfg.Slot.ATTACK) * 0.5)


func _draw() -> void:
	var c := Color(1.0, 0.62, 0.30)
	var fl := 1.0 + 0.15 * sin(t * 14.0 + float(index))
	draw_circle(Vector2.ZERO, 11.0, Cfg.with_a(c, 0.2))
	# 狐火の炎
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -12 * fl), Vector2(6, -2), Vector2(4, 6), Vector2(-4, 6), Vector2(-6, -2)]), c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -6 * fl), Vector2(3, 0), Vector2(0, 4), Vector2(-3, 0)]), Color(1, 1, 0.85, 0.95))
	# 耳
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -2), Vector2(-9, -10), Vector2(-2, -5)]), c)
	draw_colored_polygon(PackedVector2Array([Vector2(6, -2), Vector2(9, -10), Vector2(2, -5)]), c)
	# 目
	draw_circle(Vector2(-2.5, 1), 1.2, Cfg.C_INK)
	draw_circle(Vector2(2.5, 1), 1.2, Cfg.C_INK)
