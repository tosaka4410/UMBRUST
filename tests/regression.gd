extends SceneTree

var failures: Array[String] = []
var checks = 0
var game: Node2D
var visual = false

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("CHECK FAILED: " + message)

func frames(count: int = 3) -> void:
	for i in count: await physics_frame

func tap_key(code: Key) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)

func screenshot(name: String) -> void:
	if not visual: return
	await process_frame
	await RenderingServer.frame_post_draw
	var result = root.get_texture().get_image().save_png("/private/tmp/umbrust-" + name + ".png")
	check(result == OK, "Screenshot " + name)

func run() -> void:
	visual = "--visual" in OS.get_cmdline_user_args()
	var rng = RandomNumberGenerator.new()
	rng.seed = 6292026
	for region in ["forge", "tower", "mine"]:
		for rarity in 3:
			for i in 300:
				var w = Armory.make_weapon(Armory.TYPES[i % 3], rarity, region, rng)
				check(w.effects.size() == 2, "Always two affixes")
				check(w.effects[0].id != w.effects[1].id, "No repeated affix")
				check(w.effects.filter(func(e): return e.id not in Armory.CAPS).size() <= 1, "At most one mobility affix")
	var weapons: Array = []
	for i in 6:
		weapons.append({"kind": "axe", "rarity": 2, "effects": [{"id": "attack", "value": 0.13}, {"id": "double_jump", "value": 1.0}]})
	var totals = Armory.totals(weapons, {"attack": 0.05})
	check(is_equal_approx(totals.attack, 0.65), "Stat cap plus at most 5% permanent")
	check(totals.double_jump == true, "Mobility does not stack")
	check(Atlas.validate_routes(), "Mandatory and return routes reachable")
	check(not Atlas.is_rusted("tower_top", 299.9), "No early erosion")
	check(Atlas.is_rusted("tower_top", 300), "Outer room erodes first")
	check(Atlas.is_rusted("mine_entry", 390), "Inner room erodes later")
	check(not Atlas.is_rusted("forge", 9000), "Final room always safe")
	game = load("res://scenes/main.tscn").instantiate()
	game.profile.path = "/private/tmp/umbrust-test-profile-%s.cfg" % Time.get_ticks_usec()
	root.add_child(game)
	await frames()
	await screenshot("home")
	var start_button = root.gui_get_focus_owner()
	tap_key(KEY_DOWN)
	check(root.gui_get_focus_owner().text.begins_with("短縮テスト"), "Arrow down moves on home menu")
	tap_key(KEY_UP)
	check(root.gui_get_focus_owner() == start_button, "Arrow up moves back on home menu")
	tap_key(KEY_D)
	check(root.gui_get_focus_owner() == start_button, "WASD no longer navigates menus")
	game.start_run()
	game.set_process(false)
	await frames()
	check(game.player.inventory.size() == 1, "One initial weapon")
	check(game.player.flasks == 3, "Three initial heals")
	check(game.player.equipped == [0, -1], "Initial loadout")
	check(game.rooms.size() == 10, "Ten independent room scenes")
	check(game.current_id == "forge", "Start at forge")
	await screenshot("play")
	# Actual physics/input verifies floor, movement, jump and recovery cancel.
	await frames(20)
	check(game.player.is_on_floor(), "Player lands on collision floor")
	var initial_x = game.player.position.x
	Input.action_press(game.player.controls.action_name("move_right"))
	await frames(20)
	Input.action_release(game.player.controls.action_name("move_right"))
	check(game.player.position.x > initial_x + 40, "Keyboard movement through InputMap")
	Input.action_press(game.player.controls.action_name("jump"))
	await frames(2)
	Input.action_release(game.player.controls.action_name("jump"))
	check(game.player.velocity.y < 0, "Jump takes off")
	await frames(70)
	game.player.start_attack(0)
	check(game.player.attack_clock > 0, "Attack begins")
	game.player.inventory.append(Armory.starter("axe"))
	game.player.equipped[1] = 1
	game.player.start_attack(1)
	check(game.player.attack_weapon.kind == "sword", "Other weapon cannot interrupt attack")
	Input.action_press(game.player.controls.action_name("dodge"))
	await frames(2)
	Input.action_release(game.player.controls.action_name("dodge"))
	check(game.player.attack_clock == 0 and game.player.dodge_clock > 0, "Dodge cancels attack")
	var hp_before: float = game.player.hp
	game.player.take_damage(20)
	check(game.player.hp == hp_before, "Dodge grants invulnerability")
	game.player.take_damage(3, true)
	check(game.player.hp == hp_before - 3, "Rust bypasses invulnerability")
	await frames(50)
	game.player.hp = 20
	game.player.start_heal()
	var flasks: int = game.player.flasks
	game.player.start_attack(0)
	check(game.player.attack_clock == 0, "Cannot attack while healing")
	await frames(55)
	check(game.player.hp > 60 and game.player.flasks == flasks, "Healing finishes after animation")
	# Inventory swap, effective affixes and dropped items.
	game.player.inventory = weapons.duplicate(true)
	game.player.inventory[2] = Armory.starter("spear")
	game.player.equipped = [0, 1]
	game.player.recalculate()
	var incoming = {"kind": "spear", "rarity": 1, "effects": [{"id": "wall_break", "value": 1.0}, {"id": "hp", "value": 0.095}]}
	game.pickup = game.current.add_drop(incoming, Vector2(700, 650))
	game.ui.show_inventory()
	await frames()
	await screenshot("inventory")
	check(game.ui.inventory_cells.size() == 6, "Inventory shows six fixed cells")
	check(game.player.equipped == [game.player.weapon_slots[0], game.player.weapon_slots[3]], "Left column defines both attacks")
	tap_key(KEY_RIGHT)
	check(game.ui.selected_cell == 1, "Right selects middle top cell")
	tap_key(KEY_DOWN)
	check(game.ui.selected_cell == 4, "Down selects same column in bottom row")
	tap_key(KEY_LEFT)
	check(game.ui.selected_cell == 3, "Left selects weapon B cell")
	tap_key(KEY_UP)
	check(game.ui.selected_cell == 0, "Up selects weapon A cell")
	var old_slots = game.player.weapon_slots.duplicate()
	var old_stats = game.player.stats.duplicate()
	tap_key(KEY_ENTER)
	await frames()
	check(game.ui.swap_source == 0, "Enter lifts the selected weapon")
	tap_key(KEY_RIGHT)
	tap_key(KEY_ENTER)
	await frames()
	check(game.player.weapon_slots[0] == old_slots[1] and game.player.weapon_slots[1] == old_slots[0], "Enter swaps the two grid positions")
	check(game.player.equipped[0] == old_slots[1], "Moving weapon into top left equips A immediately")
	check(game.player.stats == old_stats, "Rearranging retains every passive affix")
	game.player.cancel_attack()
	game.player.start_attack(0)
	check(game.player.attack_weapon == game.player.inventory[old_slots[1]], "Attack A uses top-left weapon")
	game.player.cancel_attack()
	game.player.start_attack(1)
	check(game.player.attack_weapon == game.player.inventory[game.player.weapon_slots[3]], "Attack B uses bottom-left weapon")
	game.player.cancel_attack()
	game.player.swap_weapon_slots(0, 1)
	game.ui.show_inventory()
	await frames()
	var focused_cell = root.gui_get_focus_owner()
	tap_key(KEY_D)
	check(root.gui_get_focus_owner() == focused_cell, "D never changes inventory focus")
	var move_start: float = game.player.position.x
	Input.action_press(game.player.controls.action_name("move_right"))
	tap_key(KEY_DOWN)
	await frames(20)
	Input.action_release(game.player.controls.action_name("move_right"))
	check(game.player.position.x > move_start + 40, "Player moves while navigating inventory")
	check(game.ui.selected_cell == 4, "Inventory selection changes while moving")
	var stick = InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	root.push_input(stick)
	check(game.ui.selected_cell == 4, "Movement stick does not navigate the inventory")
	tap_key(KEY_ENTER)
	await frames()
	tap_key(KEY_ESCAPE)
	await frames()
	check(game.ui.swap_source == -1 and game.ui.overlay_kind == "inventory", "Escape cancels pending swap without closing inventory")
	game.take_pickup(1)
	check(game.player.inventory.size() == 6, "Full inventory stays six")
	check(game.player.inventory[1] == incoming, "Selected weapon replaced")
	check(game.current.drops.size() == 1, "Replaced weapon remains on ground")
	check(game.player.stats.wall_break, "Passive mobility from held weapon")
	game.player.equip(1, 0)
	check(game.player.equipped[0] == 1 and game.player.equipped[1] == 0, "Equipped weapons swap without duplicate")
	# Inventory does not pause gameplay or world clock.
	var before: float = game.elapsed
	game._process(1.0)
	check(game.elapsed > before, "Clock continues while inventory open")
	game.ui.close_overlay()
	game.enter_room("mine_cross", "mine_entry")
	game.player.global_position = game.current.global_position + Vector2(800, 685)
	game.attack(game.player.global_position + Vector2(0, -30), 146, 20, 1)
	check("mine_bonus" in game.current.opened, "Wall-break permanently opens gate")
	game.enter_room("mine_bonus", "mine_cross")
	game.player.inventory = [Armory.starter("sword")]
	game.player.equipped = [0, -1]
	game.player.recalculate()
	game.player.position = game.current.position + Vector2(1620, 680)
	game.transition_cooldown = 0
	game.interact()
	check(game.current_id == "mine_cross", "Bonus room return does not need ability")
	# Room objects and slain enemies stay resolved after leaving.
	var enemy: RustEnemy = game.current.enemies[0]
	enemy.take_damage(10000, 1)
	var room: RustRoom = game.current
	await frames()
	game.enter_room("forge", "mine_entry")
	game.enter_room("mine_cross", "mine_entry")
	check(game.current == room, "Room state retained across transitions")
	check(not is_instance_valid(enemy), "Enemies do not respawn")
	# Mandatory vertical route is reachable with the basic jump alone.
	game.enter_room("tower_base", "forge_road")
	for foe in game.current.enemies:
		if is_instance_valid(foe): foe.set_physics_process(false)
	game.player.position = game.current.position + Vector2(450, 685)
	game.player.velocity = Vector2.ZERO
	await frames(5)
	Input.action_press(game.player.controls.action_name("jump"))
	await frames(50)
	Input.action_release(game.player.controls.action_name("jump"))
	check(absf(game.player.position.y - 565) < 3, "First tower step reachable without double jump")
	for i in range(1, 4):
		var previous_step: Array = game.current.data.platforms[i - 1]
		game.player.position.x = game.current.position.x + previous_step[0] + previous_step[2] - 35
		await frames(3)
		Input.action_press(game.player.controls.action_name("move_right"))
		Input.action_press(game.player.controls.action_name("jump"))
		await frames(42)
		Input.action_release(game.player.controls.action_name("jump"))
		Input.action_release(game.player.controls.action_name("move_right"))
		await frames(5)
		check(absf(game.player.position.y - game.current.data.platforms[i][1]) < 3, "Tower stair %d reachable by basic jump" % i)
	# Enemy projectiles and boss reward categories.
	game.enter_room("tower_top", "tower_mid")
	var strong: RustEnemy = game.current.enemies[0]
	strong.take_damage(10000, 1)
	check(game.current.drops.any(func(d): return d.weapon.rarity == 2), "Strong boss guarantees rare weapon")
	game.enter_room("tower_mid", "tower_base")
	game.current.enemies[0].take_damage(10000, 1)
	check(game.current.drops.any(func(d): return d.weapon.rarity == 1), "Mid boss guarantees uncommon")
	game.elapsed = 299.9
	game.ui.show_map()
	await frames()
	await screenshot("map")
	game.ui.close_overlay()
	game.enter_room("tower_top", "tower_mid")
	game.elapsed = 301
	game.player.hp = game.player.max_hp
	game.erosion_clock = 0
	game._process(1.0)
	check(is_equal_approx(game.player.hp, game.player.max_hp * 0.97), "Erosion is 3% maximum HP per second")
	await frames()
	await screenshot("rust")
	game.elapsed = 420
	game._process(0.01)
	check(not game.boss_started and game.current_id == "tower_top", "Night never auto teleports player")
	game.player.flasks = 0
	game.enter_room("forge", "forge_road")
	check(game.boss_started and is_instance_valid(game.night_boss), "Night boss starts on arrival")
	check(game.player.flasks == game.player.flask_capacity, "Pre-boss replenishment")
	game.ui.show_settings()
	await frames()
	await screenshot("settings")
	game.ui.listening = "heal"
	tap_key(KEY_D)
	check(game.key_hint("heal") == "D", "WASD can still be registered during key rebinding")
	game.ui.close_overlay()
	var drops_before: int = game.current.drops.size()
	game.night_boss.take_damage(10000, 1)
	check(not game.running and game.profile.clears == 1, "Victory ends run")
	check(game.current.drops.size() == drops_before, "Night boss does not drop weapons")
	var saved_currency: int = game.profile.currency
	check(saved_currency >= 80, "Victory rewards banked")
	var loaded = Profile.new()
	loaded.path = game.profile.path
	loaded.load_data()
	check(loaded.currency == saved_currency and loaded.clears == 1, "Profile save/load round trip")
	await frames()
	await screenshot("result")
	game.start_run()
	game.set_process(false)
	check(game.player.inventory.size() == 1 and game.player.flask_capacity == 3, "Run inventory and flask reset")
	check(game.elapsed == 0 and not game.boss_started, "Run clock and boss reset")
	check(game.player.weapon_slots == [0, -1, -1, -1, -1, -1], "New run resets all six grid positions")
	game.pickup = game.current.add_drop(Armory.starter("axe"), Vector2(700, 650))
	game.take_pickup()
	check(game.player.weapon_slots[3] == 1 and game.player.equipped[1] == 1, "Second pickup fills bottom-left weapon B")
	game.player.swap_weapon_slots(3, 5)
	game.player.recalculate()
	check(game.player.weapon_slots[3] == -1 and game.player.weapon_slots[5] == 1 and game.player.equipped[1] == -1, "Weapon moved into empty reserve slot stays there and unequips B")
	game.drop_weapon(0)
	check(game.player.weapon_slots == [-1, -1, -1, -1, -1, 0], "Dropping a weapon preserves every other grid position")
	check(game.player.inventory[0].kind == "axe" and game.player.equipped == [-1, -1], "Dropping corrects inventory references without silently equipping reserves")
	game.player.equip(0, 1)
	check(game.player.weapon_slots[3] == 0 and game.player.weapon_slots[5] == -1, "Equipping from reserve moves weapon into the fixed attack slot")
	game.run_currency = 7
	game.finish_run(false)
	check(game.profile.currency == saved_currency + 7, "Defeat banks earned currency")
	var binding = InputEventKey.new()
	binding.physical_keycode = KEY_H
	game.rebind("heal", binding)
	check(game.key_hint("heal") == "H", "Rebinding takes effect")
	loaded.load_data()
	check(loaded.bindings.heal[0].code == KEY_H, "Rebinding persists")
	loaded.currency = 10000
	for i in 7: loaded.buy_upgrade("attack")
	check(loaded.levels.attack == 5, "Permanent upgrades capped at 5%")
	var combat_checks = preload("res://tests/combat_checks.gd").new()
	await combat_checks.run(self)
	check(RunnerVisual.BODY.get_image().detect_alpha() != Image.ALPHA_NONE, "Character atlas has transparent alpha")
	check(RunnerVisual.WEAPONS.get_image().detect_alpha() != Image.ALPHA_NONE, "Weapon atlas has transparent alpha")
	check(RunnerVisual.REGIONS.size() == 16 and RunnerVisual.ANIMATIONS.size() == 8, "Character art provides sixteen frames and eight states")
	for i in RunnerVisual.REGIONS.size():
		var region: Rect2 = RunnerVisual.REGIONS[i]
		check(Rect2(Vector2.ZERO, RunnerVisual.BODY.get_size()).encloses(region), "Sprite frame %d lies inside atlas" % i)
		for j in range(i + 1, RunnerVisual.REGIONS.size()):
			check(not region.intersects(RunnerVisual.REGIONS[j]), "Sprite regions do not overlap: %d / %d" % [i, j])
	var art: RunnerVisual = game.player.visual
	game.player.heal_clock = 0.5
	game.player.hurt_flash = 0
	check(art.choose_animation() == "heal", "Healing selects flask pose")
	game.player.heal_clock = 0
	game.player.dodge_clock = 0.2
	check(art.choose_animation() == "dodge", "Dodge selects low dash pose")
	game.player.hurt_flash = 0.16
	check(art.choose_animation() == "hurt", "Damage selects hurt pose")
	print("UMBRUST REGRESSION: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures: print("  FAIL: " + failure)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
