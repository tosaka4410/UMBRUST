extends RefCounted

func run(suite) -> void:
	var game = suite.game
	game.start_run()
	game.set_process(false)
	var player: Runner = game.player
	player.set_physics_process(false)
	player.inventory = [Armory.starter("sword"), Armory.starter("axe")]
	player.equipped = [0, 1]
	player.recalculate()
	player.position = Vector2(900, 690)
	await suite.frames()
	player.start_attack(0)
	suite.check(player.combo_stage == 0, "Sword combo starts at first hit")
	player.start_attack(1)
	suite.check(player.attack_weapon.kind == "sword" and player.buffered_slot == -1, "Early input cannot interrupt or queue another weapon")
	player.attack_clock = 0
	player.start_attack(0)
	suite.check(player.combo_stage == 1, "Sword second hit follows within combo window")
	player.attack_clock = 0
	player.start_attack(0)
	suite.check(player.combo_stage == 2 and player.attack_profile.damage > Armory.damage(player.inventory[0]), "Sword third hit deals increased damage")
	suite.check(player.attack_profile.impact > Armory.BASE.sword.impact, "Sword finisher adds stagger")
	player.attack_clock = 0.10
	player.start_attack(1)
	suite.check(player.buffered_slot == 1 and player.attack_weapon.kind == "sword", "Recovery input queues without interrupting")
	player._physics_process(0.11)
	suite.check(player.attack_weapon.kind == "axe" and player.buffered_slot == -1, "Buffered weapon starts after recovery")
	player.attack_clock = 0.10
	player.start_attack(0)
	player.start_dodge(-1)
	suite.check(player.buffered_slot == -1 and player.attack_clock == 0 and player.step_direction == -1, "Dodge clears queued attack and follows chosen direction")
	player.dodge_clock = 0
	player.dodge_cooldown = 0
	player.start_attack(0)
	player.attack_clock = 0.10
	player.start_attack(1)
	player.ui_captures_input = true
	player._physics_process(0.11)
	suite.check(player.buffered_slot == -1 and player.attack_clock <= 0, "Opening UI cancels pending automatic attack")
	player.ui_captures_input = false
	player.cancel_attack()
	player.hp = player.max_hp
	player.invulnerable = 0

	var guard: RustEnemy = game.current.spawn_enemy("guard", Vector2(1000, 690))
	guard.set_physics_process(false)
	guard.facing = -1
	var receipt = guard.take_damage(20, 1, 18)
	suite.check(receipt.blocked and is_equal_approx(receipt.damage, 7.0), "Guard reduces frontal light attack damage")
	guard.state = "approach"
	receipt = guard.take_damage(20, -1, 18)
	suite.check(not receipt.blocked and receipt.damage == 20, "Guard vulnerable from behind")
	guard.state = "approach"
	guard.poise = 0
	receipt = guard.take_damage(20, 1, 65)
	suite.check(not receipt.blocked and receipt.broken and guard.state == "broken", "Axe penetrates shield and breaks guard")
	receipt = guard.take_damage(10, 1, 18)
	suite.check(is_equal_approx(receipt.damage, 12), "Broken enemy takes 20% extra damage")
	guard.queue_free()
	await suite.frames()

	var dummy: RustEnemy = game.current.spawn_enemy("crawler", Vector2(1020, 690))
	dummy.set_physics_process(false)
	dummy.hp = 1000
	var spear = Armory.attack_profile(Armory.starter("spear"))
	game.attack(Vector2(900, 660), spear.reach, 100, 1, spear)
	suite.check(is_equal_approx(dummy.hp, 880), "Spear tip receives 20% damage bonus")
	dummy.hp = 1000
	dummy.position.x = 955
	dummy.state = "approach"
	dummy.poise = 0
	game.attack(Vector2(900, 660), spear.reach, 100, 1, spear)
	suite.check(is_equal_approx(dummy.hp, 900), "Spear shaft does normal damage")
	dummy.hp = 1000
	dummy.position.y = 500
	game.attack(Vector2(900, 660), spear.reach, 100, 1, spear)
	suite.check(dummy.hp == 1000, "Spear narrow hitbox does not hit distant upper target")
	var before: float = game.elapsed
	game._process(0.05)
	suite.check(game.elapsed > before and player.hit_pause > 0, "Hit feedback does not pause world clock")
	dummy.queue_free()
	await suite.frames()

	var boss: RustEnemy = game.current.spawn_enemy("bellkeeper", Vector2(950, 690))
	boss.set_physics_process(false)
	boss.facing = -1
	player.position = Vector2(900, 690)
	player.velocity = Vector2.ZERO
	player.invulnerable = 0
	player.hp = player.max_hp
	boss.begin_attack("cleave")
	boss._physics_process(boss.plan.windup - 0.01)
	suite.check(player.hp == player.max_hp and boss.state == "windup", "Melee telegraph causes no damage")
	player.position.x = 1000
	suite.check(boss.attack_direction == -1, "Attack direction locks during telegraph")
	player.position.x = 900
	boss._physics_process(0.02)
	boss._physics_process(0.01)
	suite.check(player.hp < player.max_hp, "Melee damage begins after telegraph")
	var after_first: float = player.hp
	player.invulnerable = 0
	boss._physics_process(0.01)
	suite.check(player.hp == after_first, "One melee strike cannot damage repeatedly")
	boss.take_damage(10, 1, 65)
	receipt = boss.take_damage(10, 1, 65)
	suite.check(receipt.broken and boss.state == "broken", "Repeated axe attacks interrupt a boss by breaking poise")
	boss.queue_free()
	await suite.frames()

	player.hp = player.max_hp
	player.invulnerable = 0
	var spec = {"kind": "spike", "position": Vector2(900, 690), "width": 45.0, "height": 170.0, "warning": 0.7, "duration": 0.25, "speed": 0.0, "damage": 20.0}
	var hazard: CombatHazard = game.spawn_hazard(spec)
	hazard.set_physics_process(false)
	hazard.advance(0.69)
	suite.check(player.hp == player.max_hp and not hazard.triggered, "Ground warning is harmless until armed")
	hazard.advance(0.02)
	suite.check(is_equal_approx(player.hp, player.max_hp - 20), "Ground hazard damages after warning")
	player.invulnerable = 0
	hazard.advance(0.01)
	suite.check(is_equal_approx(player.hp, player.max_hp - 20), "Persistent hazard damages only once")
	hazard.advance(0.30)
	suite.check(hazard.dead, "Ground hazard expires")
	game.clear_hazards()
	player.hp = player.max_hp
	player.invulnerable = 0
	player.position.y = 620
	spec.kind = "wave"
	spec.height = 38.0
	hazard = game.spawn_hazard(spec)
	hazard.set_physics_process(false)
	hazard.advance(0.71)
	suite.check(player.hp == player.max_hp, "Jump clears low shockwave")
	game.clear_hazards()
	player.position.y = 690
	player.dodge_cooldown = 0
	player.start_dodge()
	hazard = game.spawn_hazard(spec)
	hazard.set_physics_process(false)
	hazard.advance(0.71)
	suite.check(player.hp == player.max_hp, "Dodge invulnerability protects from ground hazard")
	game.clear_hazards()
	player.invulnerable = 0
	spec.position = Vector2(800, 690)
	spec.warning = 0.0
	spec.duration = 1.0
	spec.speed = 1000.0
	hazard = game.spawn_hazard(spec)
	hazard.set_physics_process(false)
	hazard.advance(0.2)
	suite.check(player.hp < player.max_hp, "Fast shockwave uses swept collision")
	game.clear_hazards()

	var night: RustEnemy = game.current.spawn_enemy("night", Vector2(1200, 690))
	night.set_physics_process(false)
	var phase_events = [0]
	night.phase_changed.connect(func(_enemy): phase_events[0] += 1)
	var old_sequence = night.attack_sequence()
	night.hp = night.max_hp * 0.49
	night._physics_process(0.02)
	suite.check(night.phase == 2 and night.state == "enrage", "Night boss enters a visible phase transition below half HP")
	suite.check(night.attack_sequence() != old_sequence, "Second phase has a different attack sequence")
	night._physics_process(0.02)
	suite.check(phase_events[0] == 1, "Second phase announces exactly once")
	night.begin_attack("eruption")
	night.begin_strike()
	suite.check(game.hazards.size() == 3, "Second-phase eruption creates three staggered warnings")
	for h in game.hazards:
		suite.check(h.warning_time >= 0.65 and not h.triggered, "Eruption always provides reaction time")
	var owned: CombatHazard = game.hazards[0]
	night.dead = true
	owned.advance(0.01)
	suite.check(owned.dead, "Unresolved hazard cancels when its caster dies")
	night.queue_free()
	game.spawn_hazard(spec)
	game.enter_room("forge_road", "forge")
	suite.check(game.hazards.is_empty() and game.projectiles.is_empty(), "Room changes remove combat hazards and projectiles")
	game.profile.screen_shake = false
	game.profile.save_data()
	var loaded = Profile.new()
	loaded.path = game.profile.path
	loaded.load_data()
	suite.check(not loaded.screen_shake, "Screen-shake preference persists")
	game.shake = 5
	game._process(0.01)
	suite.check(player.camera.offset == Vector2.ZERO, "Screen shake can be disabled")
	game.spawn_hazard(spec)
	game.finish_run(false)
	suite.check(game.hazards.is_empty(), "Run end clears all hazards")
	player.set_physics_process(true)
	await suite.frames()
