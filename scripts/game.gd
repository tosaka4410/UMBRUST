extends Node2D

const INPUTS = {
	"move_left": ["左移動", KEY_A, -1], "move_right": ["右移動", KEY_D, -1],
	"jump": ["ジャンプ", KEY_SPACE, JOY_BUTTON_A],
	"attack_a": ["武器A", KEY_J, JOY_BUTTON_RIGHT_SHOULDER],
	"attack_b": ["武器B", KEY_K, JOY_BUTTON_LEFT_SHOULDER],
	"dodge": ["回避", KEY_SHIFT, JOY_BUTTON_B],
	"heal": ["回復", KEY_Q, JOY_BUTTON_DPAD_UP],
	"interact": ["調べる・拾う", KEY_E, JOY_BUTTON_X],
	"inventory": ["武器管理", KEY_TAB, JOY_BUTTON_Y],
	"map": ["全体マップ", KEY_M, JOY_BUTTON_BACK],
	"skill": ["疾走者ステップ", KEY_L, JOY_BUTTON_RIGHT_STICK],
	"menu": ["設定", KEY_ESCAPE, JOY_BUTTON_START],
}
var profile = Profile.new()
var rng = RandomNumberGenerator.new()
var player: Runner
var ui: GameUI
var sound: RustSound
var rooms: Dictionary = {}
var current: RustRoom
var current_id = "forge"
var elapsed = 0.0
var run_currency = 0
var running = false
var boss_started = false
var night_boss: RustEnemy
var speed_factor = 1.0
var erosion_clock = 0.0
var announced = 0
var transition_cooldown = 0.0
var projectiles: Array = []
var particles: Array = []
var pickup: Dictionary = {}
var defeated_count = 0
var effects: Node2D
var hazards: Array = []
var floating_text: Array = []
var shake = 0.0
var feedback_clock = 0.0

func _ready() -> void:
	profile.load_data()
	setup_input()
	rng.randomize()
	assert(Atlas.validate_routes(), "Mandatory route or bonus return is unreachable")
	player = Runner.new()
	player.struck.connect(attack)
	player.fell.connect(func(): finish_run(false))
	player.feedback.connect(func(message): ui.notify(message))
	player.damaged.connect(on_player_damaged)
	add_child(player)
	sound = RustSound.new()
	add_child(sound)
	effects = Node2D.new()
	effects.z_index = 10
	effects.draw.connect(draw_effects)
	add_child(effects)
	ui = GameUI.new()
	ui.game = self
	add_child(ui)
	player.reset(profile.selected, profile.bonuses())
	build_world()
	player.active = false
	current.process_mode = Node.PROCESS_MODE_DISABLED
	ui.show_home()
	if "--smoke" in OS.get_cmdline_user_args(): start_run(true)

func setup_input() -> void:
	for action in INPUTS:
		if not InputMap.has_action(action): InputMap.add_action(action, 0.22)
		InputMap.action_erase_events(action)
		var key = InputEventKey.new()
		key.physical_keycode = INPUTS[action][1]
		InputMap.action_add_event(action, key)
		if INPUTS[action][2] >= 0:
			var button = InputEventJoypadButton.new()
			button.button_index = INPUTS[action][2]
			InputMap.action_add_event(action, button)
		if action in ["move_left", "move_right"]:
			var axis = InputEventJoypadMotion.new()
			axis.axis = JOY_AXIS_LEFT_X
			axis.axis_value = -1 if action == "move_left" else 1
			InputMap.action_add_event(action, axis)
		if action in profile.bindings:
			for stored in profile.bindings[action]:
				var event: InputEvent
				if stored.type == "key":
					event = InputEventKey.new()
					event.physical_keycode = stored.code
				elif stored.type == "axis":
					event = InputEventJoypadMotion.new()
					event.axis = stored.code
					event.axis_value = stored.value
				else:
					event = InputEventJoypadButton.new()
					event.button_index = stored.code
				for old in InputMap.action_get_events(action):
					if old.get_class() == event.get_class(): InputMap.action_erase_event(action, old)
				InputMap.action_add_event(action, event)
	if is_instance_valid(player): player.controls.sync_bindings()

func rebind(action: String, event: InputEvent) -> void:
	var stored: Dictionary
	if event is InputEventKey:
		stored = {"type": "key", "code": event.physical_keycode}
	elif event is InputEventJoypadMotion:
		stored = {"type": "axis", "code": event.axis, "value": signf(event.axis_value)}
	else:
		stored = {"type": "button", "code": event.button_index}
	var entries: Array = profile.bindings.get(action, [])
	entries = entries.filter(func(e): return e.type != stored.type)
	entries.append(stored)
	profile.bindings[action] = entries
	profile.save_data()
	setup_input()

func key_hint(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey: return OS.get_keycode_string(event.physical_keycode)
	return "—"

func build_world() -> void:
	for room in rooms.values():
		remove_child(room)
		room.queue_free()
	rooms.clear()
	var index = 0
	for id in Atlas.ROOMS:
		var room: RustRoom = load("res://scenes/rooms/%s.tscn" % id).instantiate()
		room.game = self
		room.position = Vector2(index * 2400, 0)
		add_child(room)
		room.visible = false
		room.process_mode = Node.PROCESS_MODE_DISABLED
		rooms[id] = room
		index += 1
	# Player renders in front of the architecture.
	move_child(player, get_child_count() - 1)
	enter_room("forge", "")

func start_run(quick: bool = false) -> void:
	elapsed = 0
	run_currency = 0
	defeated_count = 0
	announced = 0
	boss_started = false
	night_boss = null
	speed_factor = 6.0 if quick else 1.0
	erosion_clock = 0
	projectiles.clear()
	particles.clear()
	floating_text.clear()
	clear_hazards()
	shake = 0
	player.camera.offset = Vector2.ZERO
	pickup = {}
	player.reset(profile.selected, profile.bonuses())
	build_world()
	running = true
	ui.show_run()
	ui.notify("炉跡から出発。鐘楼か廃坑へ。宝箱を探し、2本目の武器をセットしよう。", 6)

func enter_room(id: String, from: String) -> void:
	clear_hazards()
	floating_text.clear()
	player.cancel_attack()
	player.heal_clock = 0
	if current != null and is_instance_valid(current):
		current.visible = false
		current.process_mode = Node.PROCESS_MODE_DISABLED
	current_id = id
	current = rooms[id]
	current.visible = true
	current.process_mode = Node.PROCESS_MODE_INHERIT
	var x = 700.0
	var y = 680.0
	for door in current.data.exits:
		if door[1] == from:
			x = clampf(door[0] + (95 if door[0] < 900 else -95), 70, 1730)
			if door.size() > 4: y = door[4] + 45
	player.global_position = current.global_position + Vector2(x, y)
	player.velocity = Vector2.ZERO
	player.camera.limit_left = int(current.position.x)
	player.camera.limit_right = int(current.position.x + 1800)
	player.camera.limit_top = 0
	player.camera.limit_bottom = 900
	player.camera.reset_smoothing()
	projectiles.clear()
	particles.clear()
	shake = 0
	player.camera.offset = Vector2.ZERO
	transition_cooldown = 0.4
	pickup = {}
	if running:
		ui.close_overlay()
		ui.notify(current.data.name, 2.5)
		if is_night() and id == "forge": start_boss()

func is_night() -> bool:
	return elapsed >= 420

func _process(delta: float) -> void:
	if not running: return
	elapsed += delta * speed_factor
	transition_cooldown = maxf(0, transition_cooldown - delta)
	if elapsed >= 240 and announced < 1:
		announced = 1
		ui.notify("黒錆の予兆。外側の部屋から侵食が始まる。地図を確認しよう。", 7)
	if elapsed >= 300 and announced < 2:
		announced = 2
		ui.notify("黒錆が侵食を開始。危険な部屋では毎秒 最大HPの3%を失う。", 7)
	if is_night() and announced < 3:
		announced = 3
		ui.notify("夜が来た。炉跡へ自力で帰還し、黒錆の王を倒せ。", 7)
		if current_id == "forge": start_boss()
	if Atlas.is_rusted(current_id, elapsed):
		erosion_clock += delta
		while erosion_clock >= 1.0 and running:
			erosion_clock -= 1
			player.take_damage(player.max_hp * 0.03, true)
	else:
		erosion_clock = 0
	if not running: return
	var local = player.global_position - current.global_position + Vector2(0, -25)
	var near = current.nearest(local)
	ui.set_interaction(near)
	for obj in current.objects:
		if obj.type == "rest" and not Atlas.is_rusted(current_id, elapsed) and not boss_started:
			if local.distance_to(obj.position) < 55 and (player.hp < player.max_hp or player.flasks < player.flask_capacity):
				player.rest()
				ui.notify("休憩の火 · HPと回復回数を補充")
	update_projectiles(delta)
	for particle in particles:
		particle.life -= delta
		particle.position += particle.velocity * delta
	particles = particles.filter(func(p): return p.life > 0)
	for item in floating_text:
		item.life -= delta
		item.position.y -= delta * 38
	floating_text = floating_text.filter(func(item): return item.life > 0)
	hazards = hazards.filter(func(h): return is_instance_valid(h) and not h.dead)
	feedback_clock += delta
	shake = move_toward(shake, 0, delta * 26)
	player.camera.offset = Vector2(sin(feedback_clock * 97), cos(feedback_clock * 113)) * shake if profile.screen_shake else Vector2.ZERO
	effects.queue_redraw()

func _input(event: InputEvent) -> void:
	if ui == null or ui.listening != "": return
	if ui.handle_inventory_input(event):
		get_viewport().set_input_as_handled()
		return
	if not running and ui.overlay_kind == "result": return
	if event.is_action_pressed("menu"):
		if ui.overlay_kind == "settings": ui.close_overlay()
		else: ui.show_settings()
		get_viewport().set_input_as_handled()
		return
	if not running: return
	if event.is_action_pressed("inventory"):
		if ui.overlay_kind == "inventory": ui.close_overlay()
		else: ui.show_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map"):
		if ui.overlay_kind == "map": ui.close_overlay()
		else: ui.show_map()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and not player.ui_captures_input:
		interact()

func interact() -> void:
	if transition_cooldown > 0 or not running: return
	var near = current.nearest(player.global_position - current.global_position + Vector2(0, -25))
	if near.is_empty(): return
	match near.type:
		"exit":
			var door: Array = near.door
			if boss_started:
				ui.notify("決戦中は炉跡から離れられない")
				return
			if door[3] == "wall_break" and door[1] not in current.opened:
				ui.notify("壁破壊の付与効果を所持し、攻撃で黒岩を砕こう")
				return
			if door[3] == "double_jump" and not player.stats.double_jump:
				ui.notify("二段ジャンプの付与効果で高所の入口へ")
				return
			sound.play("door")
			enter_room(door[1], current_id)
		"chest":
			near.used = true
			if rng.randf() < 0.8:
				current.add_drop(random_weapon(0), near.position + Vector2(45, -10))
				ui.notify("宝箱から武器を発見。近づいて %s で拾う" % key_hint("interact"))
			else:
				run_currency += 8
				ui.notify("残火の欠片 +8 · 敗北しても持ち帰れる")
			sound.play("loot")
		"currency":
			near.used = true
			run_currency += 12
			ui.notify("残火の欠片 +12")
			sound.play("loot")
		"flask":
			near.used = true
			player.flask_capacity = mini(5, player.flask_capacity + 1)
			player.flasks = mini(player.flask_capacity, player.flasks + 1)
			ui.notify("回復回数の上限 +1 · この周回中有効")
			sound.play("heal")
		"rest":
			if Atlas.is_rusted(current_id, elapsed) or boss_started: ui.notify("この休憩の火は使えない")
			else:
				player.rest()
				ui.notify("HP・回復回数を全補充。時計は進み続ける。")
		"weapon":
			pickup = near.item
			ui.show_inventory()

func random_weapon(rarity: int) -> Dictionary:
	return Armory.make_weapon(Armory.TYPES[rng.randi_range(0, 2)], rarity, current.data.region, rng)

func take_pickup(replace_index: int = -1) -> void:
	if pickup.is_empty() or pickup not in current.drops: return
	var old: Dictionary = {}
	if player.inventory.size() < 6:
		player.inventory.append(pickup.weapon)
	elif replace_index >= 0 and replace_index < 6:
		old = player.inventory[replace_index]
		player.inventory[replace_index] = pickup.weapon
	else: return
	current.drops.erase(pickup)
	if not old.is_empty():
		current.add_drop(old, player.global_position - current.global_position + Vector2(-player.facing * 40, -25))
	pickup = {}
	player.recalculate()
	sound.play("loot")
	ui.show_inventory()

func drop_weapon(index: int) -> void:
	if index < 0 or index >= player.inventory.size(): return
	if player.inventory.size() <= 1:
		ui.notify("最後の1本は捨てられません")
		return
	var weapon: Dictionary = player.inventory[index]
	player.inventory.remove_at(index)
	for cell in 6:
		if player.weapon_slots[cell] == index: player.weapon_slots[cell] = -1
		elif player.weapon_slots[cell] > index: player.weapon_slots[cell] -= 1
	current.add_drop(weapon, player.global_position - current.global_position + Vector2(45, -25))
	player.recalculate()
	ui.show_inventory()

func attack(origin: Vector2, reach: float, damage: float, direction: float, profile_data: Dictionary = {}) -> void:
	sound.play("swing")
	var height: float = profile_data.get("height", 56.0)
	var impact: float = profile_data.get("impact", 18.0)
	var attack_rect = Rect2(origin + Vector2(-20.0 if direction > 0 else -reach, -height / 2), Vector2(reach + 20, height))
	for enemy in current.enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		var body_rect = Rect2(enemy.global_position + Vector2(-14, -44) * enemy.data.size, Vector2(28, 44) * enemy.data.size)
		if attack_rect.intersects(body_rect):
			var tip_hit: bool = profile_data.get("kind", "") == "spear" and absf(enemy.global_position.x - origin.x) >= reach * 0.7
			var receipt = enemy.take_damage(damage * (1.2 if tip_hit else 1.0), direction, impact)
			burst(enemy.global_position + Vector2(0, -35), Armory.COLORS[1], 12)
			var caption = "%d" % roundi(receipt.damage)
			if receipt.blocked: caption += "  GUARD"
			elif tip_hit: caption += "  TIP"
			add_floating_text(enemy.global_position + Vector2(0, -60 * enemy.data.size), caption, Color("a8c9c3") if receipt.blocked else Color("f5d39b"))
			if receipt.broken:
				add_floating_text(enemy.global_position + Vector2(0, -60 * enemy.data.size - 26), "BREAK", Color("8ce4c4"))
				sound.play("break")
			else: sound.play("guard" if receipt.blocked else "hit")
			player.hit_pause = maxf(player.hit_pause, 0.065 if impact >= 60 else 0.035)
			shake = maxf(shake, 5 if impact >= 60 else 2)
	if player.stats.wall_break:
		for door in current.data.exits:
			if door[3] == "wall_break" and door[1] not in current.opened:
				var diff = current.global_position + Vector2(door[0], 650) - origin
				if absf(diff.x) < reach + 25 and absf(diff.y) < 90 and diff.x * direction >= -20:
					current.opened.append(door[1])
					burst(current.global_position + Vector2(door[0], 650), Color("dfba78"), 25)
					ui.notify("黒岩を破壊。能力を失っても、この道は開いたまま。")

func enemy_defeated(enemy: RustEnemy, room: RustRoom) -> void:
	defeated_count += 1
	burst(enemy.global_position + Vector2(0, -40), Color("e3ab72"), 22)
	var rarity = -1
	match enemy.kind:
		"night":
			run_currency += 50
			finish_run(true)
			return
		"strong":
			rarity = 2
			run_currency += 25
		"bellkeeper", "foreman":
			rarity = 1
			run_currency += 15
		_:
			if rng.randf() < 0.10: rarity = 0
	if rarity >= 0:
		room.add_drop(random_weapon(rarity), enemy.position + Vector2(0, -30))
		ui.notify("%s · %s武器を入手可能" % [enemy.data.name, Armory.RARITIES[rarity]])

func start_boss() -> void:
	if boss_started or not running: return
	boss_started = true
	player.rest()
	night_boss = current.spawn_enemy("night", Vector2(1250 if player.position.x < 900 else 500, 680))
	ui.notify("黒錆の王 · 決戦開始 / HP・回復回数を補充しました", 6)

func finish_run(won: bool) -> void:
	if not running: return
	running = false
	player.active = false
	current.process_mode = Node.PROCESS_MODE_DISABLED
	clear_hazards()
	projectiles.clear()
	player.camera.offset = Vector2.ZERO
	if won:
		run_currency += 30
		profile.clears += 1
	profile.currency += run_currency
	var saved = profile.save_data()
	sound.play("loot" if won else "death")
	ui.show_result(won)
	if saved != OK: ui.notify("セーブに失敗しました。保存先の空き容量と権限を確認してください。", 20)

func go_home() -> void:
	if running: finish_run(false)
	ui.show_home()

func spawn_projectile(origin: Vector2, direction: Vector2, damage: float) -> void:
	projectiles.append({"position": origin, "velocity": direction * 330, "damage": damage, "life": 3.5})

func spawn_hazard(spec: Dictionary) -> CombatHazard:
	var hazard = CombatHazard.new()
	hazard.target = player
	hazard.kind = spec.kind
	hazard.half_width = spec.width
	hazard.height = spec.height
	hazard.warning_time = spec.warning
	hazard.active_time = spec.duration
	hazard.speed = spec.speed
	hazard.damage = spec.damage
	hazard.source = weakref(spec.source) if spec.has("source") else null
	hazard.position = spec.position - current.global_position
	hazard.z_index = 6
	hazard.activated.connect(func(point):
		burst(point + Vector2(0, -8), Color("d39b7b"), 12)
		shake = maxf(shake, 3))
	current.add_child(hazard)
	hazards.append(hazard)
	return hazard

func clear_hazards() -> void:
	for hazard in hazards:
		if is_instance_valid(hazard): hazard.discard()
	hazards.clear()

func on_phase_changed(enemy: RustEnemy) -> void:
	ui.notify("%s · 第二形態 / 攻撃の組み合わせが変化" % enemy.data.name, 4)
	add_floating_text(enemy.global_position + Vector2(0, -200), "PHASE II", Color("e88daa"))
	shake = 5
	sound.play("phase")

func on_player_damaged(amount: float, rust: bool) -> void:
	add_floating_text(player.global_position + Vector2(0, -75), "−%d" % ceili(amount), Color("ef997c"))
	if not rust:
		shake = 5
		burst(player.global_position + Vector2(0, -28), Color("f09a75"), 9)
		sound.play("hurt")

func add_floating_text(point: Vector2, caption: String, color: Color) -> void:
	for existing in floating_text:
		if existing.position.distance_to(point) < 30: point.y -= 26
	floating_text.append({"position": point, "text": caption, "color": color, "life": 0.85})

func update_projectiles(delta: float) -> void:
	for shot in projectiles:
		var previous: Vector2 = shot.position
		shot.position += shot.velocity * delta
		shot.life -= delta
		var center = player.global_position + Vector2(0, -26)
		var closest = Geometry2D.get_closest_point_to_segment(center, previous, shot.position)
		if closest.distance_to(center) < 25:
			player.take_damage(shot.damage)
			shot.life = 0
		elif shot.position.y >= 690:
			shot.life = 0
	projectiles = projectiles.filter(func(s): return s.life > 0)

func burst(point: Vector2, color: Color, count: int) -> void:
	for i in count:
		particles.append({"position": point, "velocity": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(40, 240), "life": rng.randf_range(0.15, 0.5), "color": color})

func draw_effects() -> void:
	for shot in projectiles:
		effects.draw_circle(shot.position, 17, Color(0.95, 0.4, 0.25, 0.13))
		effects.draw_circle(shot.position, 7, Color("f09875"))
	for particle in particles:
		effects.draw_circle(particle.position, 2.5, Color(particle.color, particle.life * 2))
	for item in floating_text:
		var alpha = minf(1, item.life * 4)
		effects.draw_string(ui.font, item.position + Vector2(1, 2), item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(0, 0, 0, alpha))
		effects.draw_string(ui.font, item.position, item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(item.color, alpha))
