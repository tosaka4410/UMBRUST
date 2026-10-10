class_name RustEnemy
extends CharacterBody2D

signal defeated(enemy: RustEnemy)
signal projectile(origin: Vector2, direction: Vector2, damage: float)
signal hazard(spec: Dictionary)
signal phase_changed(enemy: RustEnemy)

const DATA = {
	"crawler": {"name": "錆走り", "hp": 52.0, "damage": 12.0, "speed": 130.0, "reach": 66.0, "windup": 0.55, "size": 1.0},
	"guard": {"name": "黒殻の番人", "hp": 100.0, "damage": 21.0, "speed": 72.0, "reach": 100.0, "windup": 0.8, "size": 1.3},
	"wisp": {"name": "燻り火", "hp": 42.0, "damage": 14.0, "speed": 80.0, "reach": 460.0, "windup": 0.85, "size": 0.85},
	"bellkeeper": {"name": "中ボス · 鐘守", "hp": 430.0, "damage": 23.0, "speed": 105.0, "reach": 135.0, "windup": 0.85, "size": 1.8},
	"foreman": {"name": "中ボス · 埋葬坑夫", "hp": 510.0, "damage": 27.0, "speed": 85.0, "reach": 155.0, "windup": 1.0, "size": 1.9},
	"strong": {"name": "強ボス · 鐘を喰らうもの", "hp": 960.0, "damage": 32.0, "speed": 110.0, "reach": 180.0, "windup": 1.05, "size": 2.35},
	"night": {"name": "夜ボス · 黒錆の王", "hp": 1500.0, "damage": 28.0, "speed": 125.0, "reach": 190.0, "windup": 0.95, "size": 2.7},
}
const PLANS = {
	"rush": {"name": "突進", "windup": 0.65, "active": 0.32, "recover": 0.8, "range": 310.0, "height": 70.0, "speed": 560.0},
	"cleave": {"name": "重い薙ぎ払い", "windup": 0.85, "active": 0.18, "recover": 1.0, "range": 150.0, "height": 95.0, "speed": 30.0},
	"bolt": {"name": "狙い火", "windup": 0.9, "active": 0.16, "recover": 1.0, "range": 500.0, "height": 35.0, "speed": 0.0},
	"bell_wave": {"name": "鐘鳴り / 跳び越える", "windup": 0.95, "active": 0.20, "recover": 1.15, "range": 410.0, "height": 42.0, "speed": 0.0},
	"slam": {"name": "地砕き / 跳び越える", "windup": 1.1, "active": 0.24, "recover": 1.2, "range": 270.0, "height": 44.0, "speed": 0.0},
	"eruption": {"name": "黒岩噴出 / 範囲から離れる", "windup": 0.9, "active": 0.16, "recover": 1.0, "range": 700.0, "height": 170.0, "speed": 0.0},
	"fan": {"name": "散り火 / 弾の間を抜ける", "windup": 1.0, "active": 0.18, "recover": 0.9, "range": 700.0, "height": 100.0, "speed": 0.0},
}
var kind = "crawler"
var target: Runner
var hp = 50.0
var max_hp = 50.0
var state = "approach"
var clock = 0.0
var animation = 0.0
var facing = -1.0
var attack_direction = -1.0
var attack_target = Vector2.ZERO
var attack_anchor = Vector2.ZERO
var flash = 0.0
var attack_number = 0
var dead = false
var data: Dictionary
var plan: Dictionary = {}
var attack_kind = "rush"
var phase = 1
var poise = 0.0
var poise_max = 90.0
var poise_delay = 0.0
var hit_pause = 0.0
var hit_player = false

func _ready() -> void:
	data = DATA[kind]
	hp = data.hp
	max_hp = hp
	poise_max = {"crawler": 30.0, "guard": 60.0, "wisp": 25.0, "bellkeeper": 95.0, "foreman": 110.0, "strong": 150.0, "night": 175.0}[kind]
	collision_layer = 4
	collision_mask = 1
	var collider = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(28, 44) * data.size
	collider.shape = shape
	collider.position.y = -shape.size.y / 2
	add_child(collider)

func attack_sequence() -> Array:
	match kind:
		"crawler": return ["rush"]
		"guard": return ["cleave"]
		"wisp": return ["bolt"]
		"bellkeeper": return ["rush", "bell_wave", "cleave"]
		"foreman": return ["slam", "eruption", "cleave"]
		"strong": return ["fan", "rush", "bell_wave", "eruption"] if phase == 2 else ["cleave", "fan", "rush"]
		"night": return ["rush", "eruption", "bell_wave", "fan", "slam"] if phase == 2 else ["cleave", "bell_wave", "fan"]
	return ["cleave"]

func begin_attack(forced: String = "") -> void:
	var sequence = attack_sequence()
	attack_kind = forced if forced != "" else sequence[attack_number % sequence.size()]
	plan = PLANS[attack_kind].duplicate()
	state = "windup"
	clock = plan.windup
	attack_direction = facing
	attack_target = target.global_position
	attack_anchor = global_position
	hit_player = false
	velocity.x = 0

func begin_strike() -> void:
	attack_number += 1
	state = "strike"
	clock = plan.active
	if attack_kind in ["bolt", "fan"]:
		var origin = global_position + Vector2(0, -45 * data.size)
		var aim = (attack_target + Vector2(0, -26) - origin).normalized()
		var angles: Array = [-0.32, -0.16, 0.0, 0.16, 0.32] if attack_kind == "fan" else [0.0]
		for angle in angles: projectile.emit(origin, aim.rotated(angle), data.damage * (0.65 if attack_kind == "fan" else 1.0))
	elif attack_kind == "bell_wave":
		for direction in [-1.0, 1.0]:
			hazard.emit({"kind": "wave", "position": global_position + Vector2(direction * 55, 0), "width": 32.0, "height": 38.0, "warning": 0.15, "duration": 1.55, "speed": direction * 350, "damage": data.damage * 0.8, "source": self})
	elif attack_kind == "slam":
		hazard.emit({"kind": "wave", "position": global_position, "width": 260.0, "height": 44.0, "warning": 0.08, "duration": 0.22, "speed": 0.0, "damage": data.damage, "source": self})
	elif attack_kind == "eruption":
		var offsets: Array = [-150.0, 0.0, 150.0] if phase == 2 else [-100.0, 100.0]
		for i in offsets.size():
			var point = Vector2(clampf(attack_target.x + offsets[i], get_parent().global_position.x + 60, get_parent().global_position.x + 1740), global_position.y)
			hazard.emit({"kind": "spike", "position": point, "width": 46.0, "height": 170.0, "warning": 0.65 + i * 0.18, "duration": 0.25, "speed": 0.0, "damage": data.damage * 0.8, "source": self})

func _physics_process(delta: float) -> void:
	if dead or target == null or not target.active: return
	animation += delta
	flash = maxf(0, flash - delta)
	poise_delay = maxf(0, poise_delay - delta)
	if poise_delay == 0: poise = maxf(0, poise - 12 * delta)
	hit_pause = maxf(0, hit_pause - delta)
	if hit_pause > 0:
		queue_redraw()
		return
	clock -= delta
	velocity.y += 1700 * delta
	if kind in ["strong", "night"] and hp <= max_hp * 0.5 and phase == 1:
		phase = 2
		state = "enrage"
		clock = 1.25
		poise = 0
		velocity.x = 0
		phase_changed.emit(self)
	var distance = target.global_position - global_position
	if state == "approach":
		if absf(distance.x) < 720 or data.size > 1.5:
			if absf(distance.x) > 2: facing = signf(distance.x)
			var sequence = attack_sequence()
			var next_plan: Dictionary = PLANS[sequence[attack_number % sequence.size()]]
			var range_limit: float = next_plan.range
			if kind == "crawler": range_limit = 230
			velocity.x = facing * data.speed * (1.18 if phase == 2 else 1.0) if absf(distance.x) > range_limit * 0.8 else 0.0
			# Ranged enemies retreat to a readable shooting distance.
			var can_retreat = position.x > 80 if facing > 0 else position.x < 1720
			if kind == "wisp" and absf(distance.x) < 190 and can_retreat:
				velocity.x = -facing * data.speed
			elif absf(distance.x) < range_limit and (absf(distance.y) < 140 or next_plan == PLANS.bolt or next_plan == PLANS.fan):
				begin_attack()
		else:
			velocity.x = 0
	elif state == "windup":
		velocity.x = 0
		if clock <= 0: begin_strike()
	elif state == "strike":
		velocity.x = attack_direction * plan.speed
		if attack_kind in ["rush", "cleave"]:
			var reach: float = 75.0 if attack_kind == "rush" else plan.range
			if not hit_player and absf(distance.y) < plan.height and absf(distance.x) < reach and distance.x * attack_direction > -18:
				hit_player = true
				target.take_damage(data.damage)
		if clock <= 0:
			state = "recover"
			clock = plan.recover * (0.8 if phase == 2 else 1.0)
	elif state in ["recover", "stagger", "broken", "enrage"]:
		velocity.x = move_toward(velocity.x, 0, 1000 * delta)
		if clock <= 0: state = "approach"
	move_and_slide()
	queue_redraw()

func take_damage(amount: float, direction: float, impact: float = 18.0) -> Dictionary:
	if dead: return {"damage": 0.0, "blocked": false, "broken": false}
	var blocked = kind == "guard" and direction * facing < 0 and state in ["approach", "windup"] and impact < 60
	var received = amount * (0.35 if blocked else 1.0) * (1.2 if state == "broken" else 1.0)
	hp -= received
	flash = 0.14
	hit_pause = 0.045
	poise_delay = 2.0
	var broken = false
	if state != "broken":
		poise += impact * (0.3 if blocked else 1.0)
		if poise >= poise_max:
			poise = 0
			state = "broken"
			clock = 1.25
			velocity.x = direction * 100
			broken = true
		elif data.size < 1.5 and not blocked:
			state = "stagger"
			clock = 0.20
			velocity.x = direction * minf(300, 120 + impact * 2)
	if hp <= 0:
		dead = true
		defeated.emit(self)
		queue_free()
	return {"damage": received, "blocked": blocked, "broken": broken}

func _draw() -> void:
	if data == null: return
	var s: float = data.size
	var color: Color = Color("9b7668") if kind != "wisp" else Color("88bcb6")
	if kind in ["strong", "night"]: color = Color("b29479")
	if flash > 0: color = Color("fff0cd")
	if state == "windup":
		var width: float = plan.range
		var h: float = plan.height
		if attack_kind in ["rush", "cleave"]:
			var area = Rect2(0.0 if attack_direction > 0 else -width, -h, width, h)
			draw_rect(area, Color(0.96, 0.3, 0.18, 0.13))
			draw_rect(area, Color("e89a70"), false, 1)
		elif attack_kind in ["slam", "bell_wave"]:
			draw_rect(Rect2(-width, -h, width * 2, h), Color(0.96, 0.5, 0.18, 0.16))
			draw_line(Vector2(-width, -h), Vector2(width, -h), Color("f1b369"), 2)
		elif attack_kind in ["bolt", "fan"]:
			var origin = Vector2(0, -45 * s)
			var end = attack_target - global_position + Vector2(0, -26)
			draw_dashed_line(origin, end, Color(0.93, 0.57, 0.4, 0.65), 2, 10)
			draw_arc(end, 18, 0, TAU, 24, Color("e6a278"), 2)
		else:
			var end = attack_target - global_position
			draw_line(Vector2(end.x - 165, -3), Vector2(end.x + 165, -3), Color("cb7599"), 4)
		draw_arc(Vector2(0, -65 * s), 10, -PI / 2, -PI / 2 + TAU * (1 - maxf(0, clock) / plan.windup), 24, Color("ffbf80"), 3)
	if state == "strike" and attack_kind in ["rush", "cleave"]:
		draw_arc(Vector2(0, -28 * s), 75.0 if attack_kind == "rush" else plan.range, -1.3 if attack_direction > 0 else 1.8, 1.3 if attack_direction > 0 else 4.5, 16, Color("e5795f"), 6)
	if state == "enrage":
		draw_arc(Vector2(0, -30 * s), 70 + sin(animation * 6) * 7, 0, TAU, 48, Color("d58099"), 4)
	if state == "broken":
		for i in 3: draw_circle(Vector2(cos(animation * 5 + i * TAU / 3) * 22, -70 * s), 3, Color("8de6c8"))
	draw_set_transform(Vector2.ZERO, 0, Vector2(facing * s, s))
	if kind == "wisp":
		var bob = sin(animation * 3) * 7
		draw_circle(Vector2(0, -34 + bob), 20, Color(0.3, 0.7, 0.65, 0.15))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -60 + bob), Vector2(16, -30 + bob), Vector2(0, -14 + bob), Vector2(-16, -30 + bob)]), color)
		draw_circle(Vector2(4, -35 + bob), 5, Color("d2f3cb"))
	else:
		draw_line(Vector2(-8, -17), Vector2(-12 + sin(animation * 7) * 3, 0), color.darkened(0.25), 7)
		draw_line(Vector2(8, -17), Vector2(12, 0), color.darkened(0.25), 7)
		draw_colored_polygon(PackedVector2Array([Vector2(-20, -40), Vector2(8, -48), Vector2(22, -28), Vector2(13, -10), Vector2(-16, -13)]), color.darkened(0.3))
		draw_rect(Rect2(-11, -57, 26, 21), color)
		draw_line(Vector2(0, -48), Vector2(18, -46), Color("ff8968"), 3)
		draw_line(Vector2(-8, -48), Vector2(-17, -66), color, 5)
		draw_line(Vector2(14, -27), Vector2(29, -48), Color("9ca8a0"), 4)
		if kind == "guard":
			draw_rect(Rect2(18, -42, 10, 34), Color("b1a77f") if state in ["approach", "windup"] else Color("5c6260"))
		if kind in ["strong", "night"]:
			for i in 4: draw_line(Vector2(-9 + i * 7, -56), Vector2(-14 + i * 10, -73 - (i % 2) * 7), color, 4)
	draw_set_transform(Vector2.ZERO)
	if hp < max_hp or data.size > 1.5:
		draw_rect(Rect2(-30 * s, -83 * s, 60 * s, 4), Color("222e32"))
		draw_rect(Rect2(-30 * s, -83 * s, 60 * s * maxf(0, hp / max_hp), 4), Color("d28a6c"))

	if data.size > 1.5:
		draw_rect(Rect2(-30 * s, -83 * s + 8, 60 * s, 3), Color("27383e"))
		draw_rect(Rect2(-30 * s, -83 * s + 8, 60 * s * poise / poise_max, 3), Color("85d6c0"))
