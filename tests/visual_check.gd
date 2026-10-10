extends Node

# Render real game views through Godot; no OS screenshot or UI automation required.
func _ready() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile.path = "/private/tmp/umbrust-visual-profile.cfg"
	add_child(game)
	await snap("home")
	game.start_run()
	game.set_process(false)
	await get_tree().create_timer(0.3).timeout
	await snap("play")
	game.player.inventory.clear()
	for i in 6:
		game.player.inventory.append(Armory.make_weapon(Armory.TYPES[i % 3], i % 3, "tower", game.rng))
	game.player.equipped = [0, 1]
	game.player.recalculate()
	game.pickup = game.current.add_drop(Armory.make_weapon("axe", 2, "mine", game.rng), Vector2(700, 650))
	game.ui.show_inventory()
	await snap("inventory")
	game.ui.show_map()
	await snap("map")
	game.ui.show_settings()
	await snap("settings")
	game.ui.close_overlay()
	game.enter_room("tower_base", "forge_road")
	await snap("tower")
	game.enter_room("tower_top", "tower_mid")
	game.elapsed = 410
	await snap("rust")
	game.elapsed = 420
	game.enter_room("forge", "forge_road")
	await snap("boss")
	game.player.position = Vector2(850, 690)
	game.player.velocity = Vector2.ZERO
	game.player.set_physics_process(false)
	game.player.camera.reset_smoothing()
	var night: RustEnemy = game.night_boss
	night.set_physics_process(false)
	night.position = Vector2(1030, 690)
	night.phase = 2
	night.facing = -1
	night.begin_attack("eruption")
	night.begin_strike()
	game._process(0.01)
	night.queue_redraw()
	game.effects.queue_redraw()
	await snap("combat-warning")
	game.clear_hazards()
	game.player.position.x = 930
	game.player.facing = 1
	game.player.inventory[0] = Armory.starter("axe")
	game.player.equipped[0] = 0
	game.player.start_attack(0)
	game.player.attack_clock = 0.36
	for i in 3:
		game.attack(game.player.position + Vector2(0, -30), 104, 35, 1, Armory.attack_profile(game.player.inventory[0]))
	game._process(0.01)
	game.player.queue_redraw()
	night.queue_redraw()
	game.effects.queue_redraw()
	await snap("combat-break")
	game.finish_run(true)
	await snap("result")
	game.queue_free()
	await get_tree().process_frame
	var art = load("res://scenes/art_preview.tscn").instantiate()
	add_child(art)
	await snap("runner-art")
	print("UMBRUST VISUAL CHECK: saved 12 frames in /private/tmp/umbrust-*.png")
	art.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func snap(view: String) -> void:
	for i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error = get_viewport().get_texture().get_image().save_png("/private/tmp/umbrust-" + view + ".png")
	assert(error == OK)
