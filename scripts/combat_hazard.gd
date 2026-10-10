class_name CombatHazard
extends Node2D

signal activated(point: Vector2)

var target: Runner
var source: WeakRef
var kind = "wave"
var damage = 20.0
var half_width = 80.0
var height = 40.0
var warning_time = 0.7
var active_time = 0.25
var age = 0.0
var speed = 0.0
var triggered = false
var hit_player = false
var dead = false

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if dead: return
	if not is_instance_valid(target) or not target.active:
		discard()
		return
	if source != null:
		var enemy = source.get_ref()
		if enemy == null or enemy.dead:
			discard()
			return
	var previous_age = age
	age += delta
	if age >= warning_time:
		if not triggered:
			triggered = true
			activated.emit(global_position)
		var previous_x = global_position.x
		var active_delta = maxf(0, minf(age, warning_time + active_time) - maxf(previous_age, warning_time))
		position.x += speed * active_delta
		# Sweep the area so a fast shockwave cannot pass through a player between ticks.
		var left = minf(previous_x, global_position.x) - half_width
		var right = maxf(previous_x, global_position.x) + half_width
		var area = Rect2(left, global_position.y - height, right - left, height + 4)
		var body = Rect2(target.global_position + Vector2(-12, -52), Vector2(24, 52))
		if not hit_player and area.intersects(body):
			hit_player = true
			target.take_damage(damage)
	if age >= warning_time + active_time: discard()
	queue_redraw()

func discard() -> void:
	dead = true
	queue_free()

func _draw() -> void:
	var c = Color("f19665") if kind == "wave" else Color("cc7191")
	var area = Rect2(-half_width, -height, half_width * 2, height)
	if age < warning_time:
		var progress = clampf(age / maxf(warning_time, 0.001), 0, 1)
		draw_rect(area, Color(c, 0.09 + progress * 0.12))
		draw_rect(area, Color(c, 0.65), false, 2)
		draw_line(Vector2(-half_width, -3), Vector2(lerpf(-half_width, half_width, progress), -3), c, 4)
		for x in range(-int(half_width), int(half_width), 22):
			draw_line(Vector2(x, -height), Vector2(minf(x + 20, half_width), 0), Color(c, 0.18), 1)
	else:
		draw_rect(area, Color(c, 0.25))
		if kind == "wave":
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, height / half_width))
			draw_arc(Vector2.ZERO, half_width, PI, TAU, 20, c, 5)
			draw_set_transform(Vector2.ZERO)
		else:
			for i in 5:
				var x = lerpf(-half_width, half_width, i / 4.0)
				draw_colored_polygon(PackedVector2Array([Vector2(x - 12, 0), Vector2(x + 8, -height), Vector2(x + 17, 0)]), c)
