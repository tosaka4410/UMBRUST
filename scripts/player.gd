class_name Runner
extends CharacterBody2D

signal fell
signal struck(origin: Vector2, reach: float, damage: float, direction: float, profile: Dictionary)
signal feedback(message: String)
signal damaged(amount: float, rust: bool)

var inventory: Array = []
var equipped = [0, -1]
# Row-major grid. Left column is always weapon A (0) and weapon B (3).
var weapon_slots: Array[int] = [0, -1, -1, -1, -1, -1]
var permanent: Dictionary = {}
var stats: Dictionary = {}
var hp = 100.0
var max_hp = 100.0
var flasks = 3
var flask_capacity = 3
var facing = 1.0
var attack_clock = 0.0
var attack_total = 0.0
var attack_hit = 0.0
var attack_weapon: Dictionary = {}
var hit_done = false
var dodge_clock = 0.0
var dodge_cooldown = 0.0
var skill_cooldown = 0.0
var skill_clock = 0.0
var heal_clock = 0.0
var invulnerable = 0.0
var jumps = 0
var coyote = 0.0
var jump_buffer = 0.0
var ui_captures_input = false
var ui_allows_movement = false
var active = false
var animation = 0.0
var hurt_flash = 0.0
var camera: Camera2D
var controls = PlayerControls.new()
var visual: RunnerVisual
var attack_profile: Dictionary = {}
var attack_facing = 1.0
var step_direction = 1.0
var combo_stage = 0
var combo_window = 0.0
var last_attack_slot = -1
var buffered_slot = -1
var hit_pause = 0.0

func _ready() -> void:
	controls.sync_bindings()
	collision_layer = 2
	collision_mask = 1
	var collider = CollisionShape2D.new()
	var shape = CapsuleShape2D.new()
	shape.radius = 12
	shape.height = 52
	collider.shape = shape
	collider.position.y = -26
	add_child(collider)
	camera = Camera2D.new()
	camera.position = Vector2(0, -220)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 10
	add_child(camera)
	visual = RunnerVisual.new()
	visual.name = "RunnerArt"
	visual.runner = self
	add_child(visual)

func reset(kind: String, bonuses: Dictionary) -> void:
	inventory = [Armory.starter(kind)]
	weapon_slots = [0, -1, -1, -1, -1, -1]
	equipped = [0, -1]
	permanent = bonuses
	recalculate()
	hp = max_hp
	flask_capacity = 3
	flasks = 3
	velocity = Vector2.ZERO
	attack_clock = 0
	dodge_clock = 0
	skill_clock = 0
	dodge_cooldown = 0
	skill_cooldown = 0
	heal_clock = 0
	invulnerable = 0
	attack_profile = {}
	combo_stage = 0
	combo_window = 0
	last_attack_slot = -1
	buffered_slot = -1
	hit_pause = 0
	jump_buffer = 0
	jumps = 0
	coyote = 0
	hurt_flash = 0
	active = true

func recalculate() -> void:
	sync_weapon_slots()
	stats = Armory.totals(inventory, permanent)
	max_hp = 100.0 * (1.0 + stats.hp)
	hp = minf(hp, max_hp)

func equip(index: int, slot: int) -> void:
	if index < 0 or index >= inventory.size() or slot not in [0, 1]: return
	sync_weapon_slots()
	swap_weapon_slots(weapon_slots.find(index), 0 if slot == 0 else 3)

func sync_weapon_slots() -> void:
	var seen: Array[int] = []
	for cell in 6:
		var index = weapon_slots[cell]
		if index < 0 or index >= inventory.size() or index in seen:
			weapon_slots[cell] = -1
		else:
			seen.append(index)
	for index in inventory.size():
		if index in seen: continue
		for cell in [0, 3, 1, 4, 2, 5]:
			if weapon_slots[cell] == -1:
				weapon_slots[cell] = index
				break
	equipped = [weapon_slots[0], weapon_slots[3]]

func swap_weapon_slots(from: int, to: int) -> void:
	if from < 0 or from >= 6 or to < 0 or to >= 6: return
	var previous = weapon_slots[to]
	weapon_slots[to] = weapon_slots[from]
	weapon_slots[from] = previous
	equipped = [weapon_slots[0], weapon_slots[3]]
	buffered_slot = -1
	combo_window = 0

func _physics_process(delta: float) -> void:
	if not active: return
	animation += delta
	hurt_flash = maxf(0, hurt_flash - delta)
	invulnerable = maxf(0, invulnerable - delta)
	dodge_cooldown = maxf(0, dodge_cooldown - delta)
	skill_cooldown = maxf(0, skill_cooldown - delta)
	combo_window = maxf(0, combo_window - delta)
	hit_pause = maxf(0, hit_pause - delta)
	if is_on_floor():
		jumps = 0
		coyote = 0.10
	else:
		coyote -= delta
	var move = controls.axis() if not ui_captures_input or ui_allows_movement else 0.0
	if absf(move) > 0.15 and attack_clock <= 0 and dodge_clock <= 0 and skill_clock <= 0: facing = signf(move)
	if not ui_captures_input:
		if controls.pressed("jump"): jump_buffer = 0.12
		if controls.pressed("dodge") and dodge_cooldown <= 0 and heal_clock <= 0:
			start_dodge(move)
		if controls.pressed("skill") and skill_cooldown <= 0 and heal_clock <= 0:
			skill_clock = 0.13
			skill_cooldown = 2.5
			step_direction = signf(move) if absf(move) > 0.15 else facing
			cancel_attack()
		if controls.pressed("heal"): start_heal()
		if controls.pressed("attack_a"): start_attack(0)
		if controls.pressed("attack_b"): start_attack(1)
	if ui_captures_input: buffered_slot = -1
	if hit_pause > 0 and dodge_clock <= 0 and skill_clock <= 0:
		queue_redraw()
		return
	velocity.y += 1700 * delta
	jump_buffer -= delta
	if jump_buffer > 0 and heal_clock <= 0 and dodge_clock <= 0:
		if coyote > 0 or (stats.get("double_jump", false) and jumps < 2):
			if coyote <= 0 and jumps == 0: jumps = 1
			velocity.y = -710
			jumps += 1
			coyote = 0
			jump_buffer = 0
	if not ui_captures_input and controls.released("jump") and velocity.y < -250:
		velocity.y = -250
	if heal_clock > 0:
		heal_clock -= delta
		velocity.x = move_toward(velocity.x, 0, 2200 * delta)
		if heal_clock <= 0:
			hp = minf(max_hp, hp + max_hp * 0.4)
			feedback.emit("回復 +40%")
	elif dodge_clock > 0:
		dodge_clock -= delta
		velocity.x = step_direction * 740
	elif skill_clock > 0:
		skill_clock -= delta
		velocity.x = step_direction * 960
	else:
		var speed = 320 * (1.0 + stats.get("speed", 0.0))
		if attack_clock > 0: speed *= 0.8
		velocity.x = move_toward(velocity.x, move * speed, 2600 * delta)
	if attack_clock > 0:
		attack_clock -= delta
		if not hit_done and attack_total - attack_clock >= attack_hit:
			hit_done = true
			struck.emit(global_position + Vector2(0, -30), attack_profile.reach, attack_profile.damage * (1 + stats.attack), attack_facing, attack_profile)
		if attack_clock <= 0 and buffered_slot >= 0 and not ui_captures_input:
			var next_slot = buffered_slot
			buffered_slot = -1
			start_attack(next_slot)
	move_and_slide()
	queue_redraw()

func start_attack(slot: int) -> void:
	if not active or heal_clock > 0 or dodge_clock > 0 or skill_clock > 0: return
	if attack_clock > 0:
		if attack_clock <= 0.14: buffered_slot = slot
		return
	var index: int = equipped[slot]
	if index < 0 or index >= inventory.size():
		feedback.emit("Tabで左上に武器Aをセットできます" if slot == 0 else "Tabで左下に武器Bをセットできます")
		return
	attack_weapon = inventory[index].duplicate(true)
	var chain_length = 3 if attack_weapon.kind == "sword" else (2 if attack_weapon.kind == "dagger" else 1)
	combo_stage = (combo_stage + 1) % chain_length if last_attack_slot == slot and combo_window > 0 else 0
	attack_profile = Armory.attack_profile(attack_weapon, combo_stage)
	attack_total = attack_profile.duration
	attack_clock = attack_total
	attack_hit = attack_profile.hit
	attack_facing = facing
	last_attack_slot = slot
	combo_window = attack_total + 0.45
	hit_done = false
	buffered_slot = -1

func cancel_attack() -> void:
	attack_clock = 0
	buffered_slot = -1
	combo_window = 0
	hit_pause = 0

func start_dodge(move: float = 0.0) -> void:
	if not active or dodge_cooldown > 0 or heal_clock > 0: return
	dodge_clock = 0.22
	dodge_cooldown = 0.65
	invulnerable = 0.20
	step_direction = signf(move) if absf(move) > 0.15 else facing
	facing = step_direction
	cancel_attack()

func start_heal() -> void:
	if heal_clock > 0 or dodge_clock > 0 or skill_clock > 0 or flasks <= 0 or hp >= max_hp: return
	flasks -= 1
	heal_clock = 0.8
	cancel_attack()

func take_damage(amount: float, bypass: bool = false) -> void:
	if not active or (invulnerable > 0 and not bypass): return
	hp = maxf(0, hp - amount)
	hurt_flash = 0.18
	if not bypass: invulnerable = 0.65
	damaged.emit(amount, bypass)
	if hp <= 0:
		active = false
		fell.emit()

func rest() -> void:
	hp = max_hp
	flasks = flask_capacity
	heal_clock = 0

func _draw() -> void:
	# Gameplay effects remain procedural; body and equipment use the art atlas.
	if attack_clock > 0 and attack_weapon.kind != "spear":
		var t = 1.0 - attack_clock / attack_total
		var reach: float = attack_profile.reach
		var angle = lerpf(-1.5, 1.2, t)
		if combo_stage == 1 and attack_weapon.kind == "sword": angle = -angle
		if t > 0.15 and t < 0.8:
			draw_set_transform(Vector2.ZERO, 0, Vector2(facing, 1))
			draw_arc(Vector2(8, -30), reach, angle - 0.75, angle, 18, Color(0.98, 0.83, 0.56, 0.55), 8 if combo_stage == 2 else 4)
			draw_set_transform(Vector2.ZERO)
	if heal_clock > 0:
		draw_arc(Vector2(0, -29), 42, -PI / 2, -PI / 2 + TAU * (1 - heal_clock / 0.8), 32, Color("7bd6bb"), 3)
